CREATE OR REPLACE PACKAGE BODY pk_util_log AS
    
    --Each session that performs logging must know:
    --1.    Current log_id at which insertion into log_table will be done.
    --2.    Parent log_id to have connection with the parent log entry.
    --3.	Start log_id which is a root of the logging hierarchy.

	g_start_log_id tech_log_instances.start_log_id%type := NULL;
    g_current_log_id tech_log_table.log_id%type := NULL;
    g_parent_log_id tech_log_table.parent_log_id%type := NULL;
    g_is_first_log_entry boolean := true;
    
    --Insertion into/update of into log_table is made in autonomous transaction to preserve the changes even in case of exception
    PROCEDURE private_ins_into_log_table(p_log_record_in IN tech_log_table%ROWTYPE) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO tech_log_table
        VALUES p_log_record_in;
    
        COMMIT;
    END;
    
    PROCEDURE private_upd_log_table(p_status_in            IN tech_log_table.status%TYPE
                                   ,p_exception_message_in IN tech_log_table.exception_message%TYPE
                                   ,p_log_id_in            IN tech_log_table.log_id%TYPE
                                   ,p_row_count_in         IN tech_log_table.row_count%TYPE DEFAULT NULL) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE tech_log_table t
        SET    t.status            = p_status_in
              ,t.exception_message = p_exception_message_in
              ,t.row_count         = p_row_count_in
              ,t.end_ts            = systimestamp
        WHERE  log_id = p_log_id_in;
        COMMIT;
    END;
    
    --Procedure updates the status, end_ts and optionally row_count (if some DML was performed) of the current log level in log_table
    --It also saves exception message if current level threw exception.
    PROCEDURE private_close_level(p_status_in    IN tech_log_table.status%TYPE
                         ,p_row_count_in IN tech_log_table.row_count%TYPE DEFAULT NULL) IS
        v_exception_message tech_log_table.exception_message%TYPE;
        v_new_parent_log_id tech_log_table.parent_log_id%TYPE := NULL;
    BEGIN        
        dbms_application_info.set_action(action_name => NULL);
        dbms_application_info.set_client_info(client_info => NULL);
    
        IF p_status_in = g_status_failed
        THEN
            v_exception_message := dbms_utility.format_error_backtrace || chr(13) || chr(10) ||
                                    dbms_utility.format_error_stack || chr(13) || chr(10) ||
                                    dbms_utility.format_call_stack;
        END IF;
    
        private_upd_log_table(p_status_in            => p_status_in
                             ,p_exception_message_in => v_exception_message
                             ,p_log_id_in            => g_current_log_id
                             ,p_row_count_in         => p_row_count_in);
    
        g_current_log_id := nvl(g_parent_log_id, g_start_log_id);
        
        IF g_parent_log_id IS NOT NULL THEN
            SELECT t.parent_log_id
            INTO   v_new_parent_log_id
            FROM   tech_log_table t
            WHERE  t.log_id = g_parent_log_id;
        END IF;
    
        g_parent_log_id := v_new_parent_log_id;
    
    END private_close_level;
    
    PROCEDURE private_ins_into_log_instances(p_start_log_id_in IN tech_log_instances.start_log_id%TYPE
                                            ,p_log_instance_name_in      IN tech_log_instances.log_instance_name%TYPE
                                            ,p_start_ts_in     IN tech_log_instances.start_ts%TYPE
                                            ,p_status_in        IN tech_log_instances.status%TYPE) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO tech_log_instances
            (start_log_id
            ,log_instance_name
            ,start_ts
            ,log_date
            ,status)
        VALUES
            (p_start_log_id_in
            ,p_log_instance_name_in
            ,p_start_ts_in
            ,trunc(p_start_ts_in)
            ,p_status_in);
        COMMIT;
    END;
    
    --------------------
    
    FUNCTION private_get_log_record(p_log_id_in            IN tech_log_table.log_id%TYPE
                                   ,p_parent_log_id        IN tech_log_table.parent_log_id%TYPE
                                   ,p_start_ts_in          IN tech_log_table.start_ts%TYPE
                                   ,p_end_ts_in            IN tech_log_table.end_ts%TYPE
                                   ,p_comments_in          IN tech_log_table.comments%TYPE
                                   ,p_clob_text_in         IN tech_log_table.clob_text%TYPE
                                   ,p_status_in            IN tech_log_table.status%TYPE
                                   ,p_exception_message_in IN tech_log_table.exception_message%TYPE DEFAULT NULL
                                   ,p_action_name_in        IN tech_log_table.action_name%TYPE)
        RETURN tech_log_table%ROWTYPE IS
        --
        v_log_record tech_log_table%ROWTYPE;
    BEGIN
        v_log_record.log_id            := p_log_id_in;
        v_log_record.parent_log_id     := p_parent_log_id;
        v_log_record.start_ts          := p_start_ts_in;
        v_log_record.end_ts            := p_end_ts_in;
        v_log_record.sid               := to_number(SYS_CONTEXT('userenv', 'SID'));
        v_log_record.username          := SYS_CONTEXT('userenv', 'os_user');
        v_log_record.status            := p_status_in;
        v_log_record.comments          := p_comments_in;
        v_log_record.clob_text         := p_clob_text_in;
        v_log_record.exception_message := p_exception_message_in;
        v_log_record.log_date          := trunc(p_start_ts_in);
        v_log_record.action_name       := p_action_name_in;   
    
        RETURN v_log_record;
    END;
    
    FUNCTION get_start_log_id RETURN tech_log_instances.start_log_id%TYPE IS
    BEGIN
        RETURN g_start_log_id;
    END;
    
    FUNCTION get_current_log_id RETURN tech_log_table.log_id%TYPE IS
    BEGIN
        RETURN g_current_log_id;
    END;
    
    --Procedure clears session logging variables, so that the next logging attempt will be made into the new logging hierarchy
    PROCEDURE start_logging(p_log_instance_name_in IN tech_log_instances.log_instance_name%type) IS
    BEGIN
        g_is_first_log_entry := true;
        g_start_log_id := tech_log_table_seq.nextval;
        g_current_log_id := g_start_log_id;
        g_parent_log_id := NULL;
        private_ins_into_log_instances(p_start_log_id_in            => g_start_log_id
                                      ,p_log_instance_name_in       => p_log_instance_name_in
                                      ,p_start_ts_in                => systimestamp
                                      ,p_status_in                  => g_status_running);
        open_next_level(p_action_name_in => p_log_instance_name_in);
    END;
    
    procedure private_stop_log(p_status_in IN tech_log_instances.status%type) is
        PRAGMA AUTONOMOUS_TRANSACTION; 
    begin
        update tech_log_instances t set t.status = p_status_in, t.end_ts = systimestamp
        where t.start_log_id = g_start_log_id;
        
        private_close_level(p_status_in);
        
        commit;
    end; 
    
    procedure stop_log_success is
    begin
        private_stop_log(g_status_completed);
    end; 
    
    procedure stop_log_fail is
    begin
        private_stop_log(g_status_failed);
    end; 
    
    --Procedure creates next level of the logging hierarchy.
    --It creates new instance of logging hierarchy if it does not exist
    PROCEDURE open_next_level(p_action_name_in IN tech_log_table.action_name%TYPE
                             ,p_comments_in  IN tech_log_table.comments%TYPE DEFAULT NULL
                             ,p_clob_text_in IN tech_log_table.clob_text%TYPE DEFAULT NULL) IS
        v_log_record tech_log_table%ROWTYPE;
    BEGIN
        dbms_application_info.set_action(action_name => p_action_name_in);
        
        IF g_is_first_log_entry THEN            
            g_is_first_log_entry := false;
        ELSE
            g_parent_log_id := g_current_log_id;
            g_current_log_id := tech_log_table_seq.nextval;
        END IF;
    
        v_log_record := private_get_log_record(p_log_id_in       => g_current_log_id
                                              ,p_parent_log_id   => g_parent_log_id
                                              ,p_start_ts_in     => systimestamp
                                              ,p_end_ts_in       => NULL
                                              ,p_comments_in     => p_comments_in
                                              ,p_clob_text_in    => p_clob_text_in
                                              ,p_status_in       => g_status_running
                                              ,p_action_name_in => p_action_name_in);
    
        private_ins_into_log_table(v_log_record);
    
    END open_next_level;   
    
    --Logs a single record
    PROCEDURE log_record(p_action_name_in IN tech_log_table.action_name%TYPE
                        ,p_comments_in  IN tech_log_table.comments%TYPE DEFAULT NULL
                        ,p_clob_text_in IN tech_log_table.clob_text%TYPE DEFAULT NULL
                        ,p_status_in    IN tech_log_table.status%TYPE
                        ,p_row_count_in IN tech_log_table.row_count%TYPE DEFAULT NULL) IS
    BEGIN
        open_next_level(p_action_name_in => p_action_name_in
                        ,p_comments_in  => p_comments_in
                       ,p_clob_text_in => p_clob_text_in);
        private_close_level(p_status_in    => p_status_in
                   ,p_row_count_in => p_row_count_in);
    END;
    
    --procedure initializes logging context in case you created a separate session (for ex. via dbms_scheduler) 
    --and you want this session to write into the same logging hierarchy instance
    PROCEDURE resume_logging(p_parent_log_id IN tech_log_table.parent_log_id%TYPE) IS
    BEGIN        
        g_is_first_log_entry := false;
        g_current_log_id := p_parent_log_id;
    END;
    
    --Close level successfully
    PROCEDURE close_level_success(p_row_count_in IN tech_log_table.row_count%TYPE DEFAULT NULL) IS
    BEGIN
        private_close_level(p_status_in    => pk_util_log.g_status_completed
                   ,p_row_count_in => p_row_count_in);
    END;
    
    --Close level with failure
    PROCEDURE close_level_fail(p_row_count_in IN tech_log_table.row_count%TYPE DEFAULT NULL) IS
    BEGIN
        private_close_level(p_status_in    => pk_util_log.g_status_failed
                   ,p_row_count_in => p_row_count_in);
    END;
    
    ---
    PROCEDURE add_clob_text(p_clob_text_in IN tech_log_table.clob_text%TYPE) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE tech_log_table t
        SET    t.clob_text = t.clob_text || p_clob_text_in
        WHERE  t.log_id = g_current_log_id;
        
        COMMIT;
    END;

    procedure log_and_execute_dml (p_action_name_in IN varchar2
                                    , p_sql_in IN clob
                                    , p_rowcount_out OUT number
                                    , p_commit_after_dml_in IN boolean default false 
                                    , p_raise_if_dml_failed_in IN boolean default true) is
    begin
        open_next_level(p_action_name_in);
                
        add_clob_text(p_clob_text_in => p_sql_in);
        
        execute immediate p_sql_in;
        p_rowcount_out := sql%rowcount;
        
        close_level_success(p_row_count_in => sql%rowcount);
     
        if p_commit_after_dml_in then
            commit;
        end if;
        
    exception
    	when others then
    		close_level_fail;
            if p_raise_if_dml_failed_in then
    		    raise;
            end if;
    end log_and_execute_dml; 
    
    procedure log_and_execute_ddl (p_action_name_in IN varchar2
                                    , p_sql_in IN clob
                                    , p_raise_if_ddl_failed_in IN boolean default true) is
    begin
        open_next_level(p_action_name_in);
        
        add_clob_text(p_clob_text_in => p_sql_in);
        
        execute immediate p_sql_in;
        
        close_level_success;
     exception
    	when others then
    		close_level_fail;
            if p_raise_if_ddl_failed_in then
    		    raise;
            end if;
    end log_and_execute_ddl; 
      
END pk_util_log;
/
