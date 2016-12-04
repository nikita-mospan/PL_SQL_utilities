CREATE OR REPLACE PACKAGE BODY pk_util_parallel_execute AS
    -----
    
    function create_task (p_task_prefix_in in varchar2
                        , p_comments_in in parallel_tasks.comments%type
                        , p_parallel_level_in in parallel_tasks.parallel_level%type) return varchar2
    is
        PRAGMA AUTONOMOUS_TRANSACTION; 
        v_task_name parallel_tasks.task_name%type;
    begin
        pk_util_log.open_next_level(p_comments_in => 'PK_UTIL_PARALLEL_EXECUTE.CREATE_TASK' || g_new_line ||
                                                    'TASK_PREFIX: ' || p_task_prefix_in || g_new_line ||
                                                    'See comments in clob_text'
                                , p_clob_text_in => p_comments_in);
        
        v_task_name := dbms_parallel_execute.generate_task_name(prefix => p_task_prefix_in);
        
        insert into parallel_tasks (task_name, comments, status, parallel_level)
            values(v_task_name, p_comments_in, g_status_new, p_parallel_level_in);
        
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
    
    function add_item_to_task (p_task_name_in in parallel_tasks.task_name%type
                            , p_plsql_block_in in parallel_task_items.plsql_block%type) return number 
    is
        PRAGMA AUTONOMOUS_TRANSACTION; 
        v_item_id parallel_task_items.item_id%type;
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
    
    procedure execute_task (p_task_name_in in varchar2) is
        v_chunk_sql varchar2(32767);
        v_plsql_task varchar2(32767);
        v_parallel_level parallel_tasks.parallel_level%type;
        v_cur_log_id tech_log_table.log_id%type;
        --
        procedure set_chunk_for_items is
            PRAGMA AUTONOMOUS_TRANSACTION; 
        begin
            update parallel_task_items i 
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
        procedure task_post_processing is
            PRAGMA AUTONOMOUS_TRANSACTION; 
        begin
            if dbms_parallel_execute.task_status(task_name => p_task_name_in) = dbms_parallel_execute.FINISHED then
                update parallel_task_items i set i.status = g_status_completed where i.task_name = p_task_name_in;
                update parallel_tasks t set t.status = g_status_completed where t.task_name = p_task_name_in;
            else
                update parallel_task_items i set i.status = case
                                        (select up.status from user_parallel_execute_chunks up where up.TASK_NAME = p_task_name_in
                                                                                and up.START_ID = i.item_id)
                                        when g_exec_chunk_success_status then  g_status_completed
                                        else g_status_failed end
                where i.task_name = p_task_name_in; 
                update parallel_tasks t set t.status = g_status_failed where t.task_name =  p_task_name_in;
                commit;
                raise_application_error(g_task_failed_err_code, 'Task ' || p_task_name_in || ' failed! See PARALLEL_TASK_ITEMS for details');        
            end if;
            commit;
        exception
        	when others then
                rollback;
        		pk_util_log.log_record(p_comments_in => 'execute_task-->task_post_processing failed'
                                    , p_status_in => g_status_failed);
        		raise;
        end task_post_processing;
        --
    begin
        pk_util_log.open_next_level(p_comments_in => 'PK_UTIL_PARALLEL_EXECUTE.EXECUTE_TASK' || g_new_line ||
                                                    'TASK_NAME: ' || p_task_name_in || g_new_line);
        
        select t.parallel_level into v_parallel_level from parallel_tasks t where t.task_name = p_task_name_in;
        
        pk_util_log.log_record(p_comments_in => 'parallel_level: ' || to_char(v_parallel_level)
                            , p_status_in => pk_util_log.g_status_completed);
        
        v_chunk_sql := replace(q'[select i.item_id, i.item_id from parallel_task_items i where i.task_name = '#task_name#']'
                            , '#task_name#'
                            , p_task_name_in); 
        
        pk_util_log.log_record(p_comments_in => 'chunk SQL'
                            , p_clob_text_in => v_chunk_sql
                            , p_status_in => pk_util_log.g_status_completed);
        
        dbms_parallel_execute.create_chunks_by_SQL(task_name => p_task_name_in, sql_stmt => v_chunk_sql, by_rowid => false);
        
        set_chunk_for_items;        
        
        v_plsql_task := q'[
                        declare
                            v_plsql_block CLOB;
                            v_item_id parallel_task_items.item_id%type;
                            v_cur_log_id number;
                            --
                            procedure set_item_log_id is
                                PRAGMA AUTONOMOUS_TRANSACTION;
                            begin
                                update parallel_task_items i 
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
        
        pk_util_log.log_record(p_comments_in => 'plsql_task'
                            , p_clob_text_in => v_plsql_task
                            , p_status_in => pk_util_log.g_status_completed);
        
        v_cur_log_id := pk_util_log.get_current_log_id;
        
        dbms_parallel_execute.run_task(task_name => p_task_name_in
                                    , language_flag => dbms_sql.native
                                    , sql_stmt => replace(v_plsql_task, '#log_id#', to_char(v_cur_log_id))
                                    , parallel_level => v_parallel_level); 
        
        task_post_processing;                
        
        pk_util_log.close_level_success;
    exception
    	when others then
    		pk_util_log.close_level_fail;
    		raise;        
    end execute_task;    
       
END pk_util_parallel_execute;
/
