CREATE OR REPLACE PACKAGE BODY pk_util_parallel_execute AS
    -----
    
    function create_task (p_task_prefix_in in tech_parallel_tasks.task_prefix%type
                        , p_comments_in in tech_parallel_tasks.comments%type
                        , p_parallel_level_in in tech_parallel_tasks.parallel_level%type
                        , p_timeout_seconds_in in tech_parallel_tasks.timeout_seconds%type default g_no_timeout ) return varchar2
    is
        PRAGMA AUTONOMOUS_TRANSACTION; 
        v_task_name tech_parallel_tasks.task_name%type;
    begin
        pk_util_log.open_next_level(p_comments_in => 'PK_UTIL_PARALLEL_EXECUTE.CREATE_TASK' || g_new_line ||
                                                    'TASK_PREFIX: ' || p_task_prefix_in || g_new_line ||
                                                    'See comments in clob_text'
                                , p_clob_text_in => p_comments_in);
        
        v_task_name := dbms_parallel_execute.generate_task_name(prefix => p_task_prefix_in);
        
        insert into tech_parallel_tasks (task_name, comments, status, parallel_level, timeout_seconds, task_prefix)
            values(v_task_name, p_comments_in, g_status_new, p_parallel_level_in, p_timeout_seconds_in, p_task_prefix_in);
        
        pk_util_log.log_record(p_comments_in => 'TASK_NAME: ' || v_task_name
                            , p_status_in => pk_util_log.g_status_completed);
        
        dbms_parallel_execute.create_task(task_name => v_task_name,
                                    comment => p_comments_in);
        
        pk_util_log.close_level_success;
        commit;
        return v_task_name;
    exception
    	when others then
            rollback;
    		pk_util_log.close_level_fail;
    		raise;
    end create_task;
    
    ----
    
    function add_item_to_task (p_task_name_in in tech_parallel_tasks.task_name%type
                            , p_plsql_block_in in tech_parallel_task_items.plsql_block%type) return number 
    is
        PRAGMA AUTONOMOUS_TRANSACTION; 
        v_item_id tech_parallel_task_items.item_id%type;
    begin
        pk_util_log.open_next_level(p_comments_in => 'PK_UTIL_PARALLEL_EXECUTE.ADD_ITEM_TO_TASK ' || g_new_line ||
                                                    'TASK_NAME: ' || p_task_name_in || g_new_line ||
                                                    'See PL/SQL block in clob_text'
                                , p_clob_text_in => p_plsql_block_in);
        
        insert into parallel_task_items(item_id, task_name, plsql_block, status)
            values(seq_parallel_item_id.nextval, p_task_name_in, p_plsql_block_in, g_status_new) 
        returning item_id into v_item_id;
        
        pk_util_log.close_level_success;
        commit;
        return v_item_id;
    exception
    	when others then
            rollback;
    		pk_util_log.close_level_fail;
    		raise;       
    end add_item_to_task;
   
	-----
    
    procedure execute_task (p_task_name_in in tech_parallel_tasks.task_name%type) is
        v_chunk_sql varchar2(32767);
        v_plsql_task_str varchar2(32767);
        v_plsql_task_run_str varchar2(32767);
        v_parallel_level tech_parallel_tasks.parallel_level%type;
        v_cur_log_id tech_log_table.log_id%type;
        v_execution_start tech_parallel_tasks.start_of_execution%type;
        v_timeout_seconds tech_parallel_tasks.timeout_seconds%type;
        v_task_prefix tech_parallel_tasks.task_prefix%type;
        v_timeout_occured boolean :=  false;
        --
        procedure set_chunk_for_items is
            PRAGMA AUTONOMOUS_TRANSACTION; 
        begin
            update tech_parallel_task_items i 
            set i.chunk_id = (select up.CHUNK_ID from user_parallel_execute_chunks up where up.TASK_NAME = p_task_name_in
                                                                                and up.START_ID = i.item_id)
            where i.task_name = p_task_name_in;
            commit;
        exception
        	when others then
                rollback;
        		pk_util_log.log_record(p_comments_in => 'execute_task-->set_chunk_for_items failed'
                                    , p_status_in => g_status_failed);
        		raise;
        end set_chunk_for_items;
        
        --
        procedure log_execution_status (p_status_in in tech_parallel_tasks.status%type) is
            PRAGMA AUTONOMOUS_TRANSACTION; 
        begin
            update tech_parallel_task_items i set i.status = case
                                        (select up.status from user_parallel_execute_chunks up where up.TASK_NAME = p_task_name_in
                                                                                and up.START_ID = i.item_id)
                                        when g_exec_chunk_success_status then  g_status_completed
                                        else g_status_failed end
                where i.task_name = p_task_name_in;
                
            update tech_parallel_tasks t 
                set t.status = p_status_in 
                    , t.duration = case when p_status_in = g_status_completed then NUMTODSINTERVAL((sysdate - v_execution_start), 'day')
                                    else null end 
                where t.task_name = p_task_name_in;
            commit;            
            
        exception
        	when others then
                rollback;
        		pk_util_log.log_record(p_comments_in => 'execute_task-->log_execution_status failed'
                                    , p_status_in => g_status_failed);
        		raise;
        end log_execution_status;
        --
        procedure log_task_start_of_execution is
            PRAGMA AUTONOMOUS_TRANSACTION; 
        begin
            update tech_parallel_tasks t 
            set t.start_of_execution = v_execution_start 
                , t.status = g_status_running
            where t.task_name = p_task_name_in;
            commit;
        exception
        	when others then
        		rollback;
        		raise;
        end;
    ---------------------------------------
    begin
        pk_util_log.open_next_level(p_comments_in => 'PK_UTIL_PARALLEL_EXECUTE.EXECUTE_TASK' || g_new_line ||
                                                    'TASK_NAME: ' || p_task_name_in || g_new_line);
        
        select t.parallel_level, t.timeout_seconds, t.task_prefix 
            into v_parallel_level, v_timeout_seconds, v_task_prefix
        from tech_parallel_tasks t where t.task_name = p_task_name_in;
        
        pk_util_log.log_record(p_comments_in => 'parallel_level: ' || to_char(v_parallel_level) || g_new_line ||
                                                'timeout_seconds: ' || to_char(v_timeout_seconds) || g_new_line ||
                                                'task_prefix ' || v_task_prefix
                            , p_status_in => pk_util_log.g_status_completed);
        
        v_chunk_sql := replace(q'[select i.item_id, i.item_id from tech_parallel_task_items i where i.task_name = '#task_name#']'
                            , '#task_name#'
                            , p_task_name_in); 
        
        pk_util_log.log_record(p_comments_in => 'chunk SQL'
                            , p_clob_text_in => v_chunk_sql
                            , p_status_in => pk_util_log.g_status_completed);
        
        dbms_parallel_execute.create_chunks_by_SQL(task_name => p_task_name_in, sql_stmt => v_chunk_sql, by_rowid => false);
        
        set_chunk_for_items;        
        
        v_plsql_task_str := q'[
                        declare
                            v_plsql_block CLOB;
                            v_item_id tech_parallel_task_items.item_id%type;
                            v_cur_log_id tech_log_table.log_id%type;
                            --
                            procedure set_item_log_id is
                                PRAGMA AUTONOMOUS_TRANSACTION;
                            begin
                                update tech_parallel_task_items i 
                                set i.log_id = v_cur_log_id,
                                     i.status = pk_util_parallel_execute.g_status_running
                                where i.item_id = :start_id;
                                
                                commit;
                            exception when others then
                                rollback;
                                raise;
                            end;
                        begin
                            select plsql_block, item_id into v_plsql_block, v_item_id 
                            from parallel_task_items i where i.item_id between :start_id and :end_id;
                            
                            pk_util_log.resume_logging(p_parent_log_id => #log_id#);
                            pk_util_log.open_next_level(p_comments_in => 'Executing item_id: ' || to_char(v_item_id));
                            v_cur_log_id := pk_util_log.get_current_log_id;
                                                        
                            set_item_log_id;
                            
                            execute immediate v_plsql_block ;
                            
                            pk_util_log.close_level_success;
                        exception
    	                    when others then
                                pk_util_log.add_clob_text(p_clob_text_in => v_plsql_block);
    		                    pk_util_log.close_level_fail;
    		                    raise;
                        end;]';       
        
        v_cur_log_id := pk_util_log.get_current_log_id;       
        
        v_plsql_task_str := replace(v_plsql_task_str, '#log_id#', to_char(v_cur_log_id));
        
        v_plsql_task_run_str := q'[begin
                            dbms_parallel_execute.run_task(task_name => '#p_task_name_in#'
                                    , language_flag => dbms_sql.native
                                    , sql_stmt => #v_plsql_task_str#
                                    , parallel_level => #v_parallel_level#); 
                            end;]';
        
        v_plsql_task_run_str := replace(v_plsql_task_run_str, '#p_task_name_in#', p_task_name_in);
        v_plsql_task_run_str := replace(v_plsql_task_run_str, '#v_plsql_task_str#', 'q''~' || v_plsql_task_str || '~''');
        v_plsql_task_run_str := replace(v_plsql_task_run_str, '#v_parallel_level#', to_char(v_parallel_level));
        
        pk_util_log.log_record(p_comments_in => 'plsql_task'
                            , p_clob_text_in => v_plsql_task_run_str
                            , p_status_in => pk_util_log.g_status_completed);
        
        v_execution_start := sysdate;
        log_task_start_of_execution;
        
        if v_timeout_seconds = g_no_timeout then
            execute immediate v_plsql_task_run_str;
        else
            dbms_scheduler.create_job(job_name => p_task_name_in
                                    , job_type => 'PLSQL_BLOCK'
                                    , job_action => v_plsql_task_run_str
                                    , enabled => TRUE);
            
            while (dbms_parallel_execute.task_status(task_name => p_task_name_in) not in
                                            ( dbms_parallel_execute.FINISHED, dbms_parallel_execute.FINISHED_WITH_ERROR)) loop
                if ( (sysdate - v_execution_start) * 24 * 60 * 60 > v_timeout_seconds ) then
                    v_timeout_occured := true;
                    for i in (select t.JOB_NAME, t.START_ID as item_id from user_parallel_execute_chunks t where t.TASK_NAME = p_task_name_in) loop
                        declare
                            v_job_to_stop_timeout_items user_scheduler_jobs.job_name%type;
                            v_stop_item_job_action varchar2(32767);
                            v_item_log_id tech_parallel_task_items.log_id%type;
                        begin
                            v_job_to_stop_timeout_items := dbms_scheduler.generate_job_name(prefix => v_task_prefix);
                            
                            select t.log_id into v_item_log_id 
                            from tech_parallel_task_items t where t.item_id = i.item_id;
                            
                            v_stop_item_job_action := replace(replace(q'[begin
                                                            dbms_scheduler.stop_job(job_name => '#job_name#');
                                                            pk_util_log.resume_logging(p_parent_log_id => #log_id#);
                                                            pk_util_log.close_level_fail;
                                                       end;]', '#job_name#', i.job_name),
                                                            '#log_id#' , to_char(v_item_log_id));
                            
                            dbms_scheduler.create_job(job_name => v_job_to_stop_timeout_items
                                                    , job_type => 'PLSQL_BLOCK'
                                                    , job_action => v_stop_item_job_action
                                                    , enabled => true);   
                            
                            pk_util_log.log_record(p_comments_in => 'Job ' || v_job_to_stop_timeout_items || ' started to stop job ' ||
                                                                               i.job_name || ' for item_id: ' || to_char(i.item_id)
                                                , p_status_in => pk_util_log.g_status_completed);
                            
                           
                        exception
                        	when others then
                        		pk_util_log.log_record(p_comments_in => 'Job ' || v_job_to_stop_timeout_items || ' failed(!!!) to stop job ' ||
                                                                               i.job_name || ' for item_id: ' || to_char(i.item_id)
                                                        , p_clob_text_in => 'v_stop_item_job_action: ' || g_new_line ||
                                                                            v_stop_item_job_action
                                                        , p_status_in => pk_util_log.g_status_failed);
                        end;
                    end loop;
                    ------
                    exit;
                    ------
                end if;
                
                dbms_lock.sleep(g_wait_timeout_sleep_secs);        
            end loop; 
        
        end if;
                
        if (dbms_parallel_execute.task_status(task_name => p_task_name_in) = dbms_parallel_execute.FINISHED) then
            log_execution_status(p_status_in => g_status_completed);
        else
            log_execution_status(p_status_in => g_status_failed);
            
            if v_timeout_occured then
                raise_application_error(g_task_failed_due_timeout_code, 'Task ' || p_task_name_in || ' failed due to timeout! See TECH_PARALLEL_TASK_ITEMS for details');        
            else              
                raise_application_error(g_task_failed_err_code, 'Task ' || p_task_name_in || ' failed! See TECH_PARALLEL_TASK_ITEMS for details');        
            end if;
        end if;                
        
        pk_util_log.close_level_success;
    exception
    	when others then
    		pk_util_log.close_level_fail;
    		raise;        
    end execute_task;    
       
END pk_util_parallel_execute;
/
