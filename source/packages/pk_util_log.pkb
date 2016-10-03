CREATE OR REPLACE PACKAGE BODY pk_util_log AS
    
    --Each session that performs logging must know:
    --1.    Current log_id at which insertion into log_table will be done.
    --2.    Parent log_id to have connection with the parent log entry.
    --3.	Start log_id which is a root of the logging hierarchy.

	g_start_log_id tech_log_table.start_log_id%type := NULL;
    g_current_log_id tech_log_table.log_id%type := NULL;
    g_parent_log_id tech_log_table.parent_log_id%type := NULL;
    g_log_name tech_log_instances.name%type := NULL;
    
    PROCEDURE private_set_start_log_id(p_start_log_id_in IN tech_log_table.start_log_id%TYPE) IS
    BEGIN
        g_start_log_id := p_start_log_id_in;
    END;
    
    PROCEDURE private_set_cur_log_id(p_log_id_in IN tech_log_table.log_id%TYPE) IS
    BEGIN
        g_current_log_id := p_log_id_in;
    END;
    
    PROCEDURE private_set_parent_log_id(p_parent_log_id_in IN tech_log_table.parent_log_id%TYPE) IS
    BEGIN
        g_parent_log_id := p_parent_log_id_in;
    END;    
    
    ------
    
    --Insertion into/update of into log_table is made in autonomous transaction to preserve the changes even in case of exception
    PROCEDURE private_ins_into_log_table(p_log_record_in IN tech_log_table%ROWTYPE) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO tech_log_table
        VALUES p_log_record_in;
    
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
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
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END;
    
    PROCEDURE private_ins_into_log_instances(p_start_log_id_in IN tech_log_instances.start_log_id%TYPE
                                            ,p_name_in      IN tech_log_instances.name%TYPE
                                            ,p_start_ts_in     IN tech_log_instances.start_ts%TYPE) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO tech_log_instances
            (start_log_id
            ,NAME
            ,start_ts)
        VALUES
            (p_start_log_id_in
            ,p_name_in
            ,p_start_ts_in);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END;
    
    --------------------
    
    FUNCTION private_get_log_record(p_start_log_id_in      IN tech_log_table.start_log_id%TYPE
                                   ,p_log_id_in            IN tech_log_table.log_id%TYPE
                                   ,p_parent_log_id        IN tech_log_table.parent_log_id%TYPE
                                   ,p_start_ts_in          IN tech_log_table.start_ts%TYPE
                                   ,p_end_ts_in            IN tech_log_table.end_ts%TYPE
                                   ,p_comments_in          IN tech_log_table.comments%TYPE
                                   ,p_clob_text_in         IN tech_log_table.clob_text%TYPE
                                   ,p_status_in            IN tech_log_table.status%TYPE
                                   ,p_exception_message_in IN tech_log_table.exception_message%TYPE DEFAULT NULL)
        RETURN tech_log_table%ROWTYPE IS
        --
        v_log_record tech_log_table%ROWTYPE;
    BEGIN
        v_log_record.start_log_id      := p_start_log_id_in;
        v_log_record.log_id            := p_log_id_in;
        v_log_record.parent_log_id     := p_parent_log_id;
        v_log_record.start_ts          := p_start_ts_in;
        v_log_record.end_ts            := p_end_ts_in;
        v_log_record.sid               := to_number(SYS_CONTEXT('userenv', 'SID'));
        v_log_record.username          := SYS_CONTEXT('userenv', 'SESSION_USER');
        v_log_record.status            := p_status_in;
        v_log_record.comments          := p_comments_in;
        v_log_record.clob_text         := p_clob_text_in;
        v_log_record.exception_message := p_exception_message_in;
    
        RETURN v_log_record;
    END;
        
    --
    PROCEDURE private_start_logging IS
    BEGIN
        g_start_log_id := tech_log_table_seq.nextval;
        private_set_cur_log_id(g_start_log_id);
        private_set_parent_log_id(NULL);
        private_ins_into_log_instances(p_start_log_id_in => g_start_log_id
                                      ,p_name_in         => g_log_name
                                      ,p_start_ts_in     => systimestamp);
    END;

    FUNCTION get_start_log_id RETURN tech_log_table.start_log_id%TYPE IS
    BEGIN
        RETURN g_start_log_id;
    END;
    
    FUNCTION get_current_log_id RETURN tech_log_table.log_id%TYPE IS
    BEGIN
        RETURN g_current_log_id;
    END;
    
    --Procedure clears session logging variables, so that the next logging attempt will be made into the new logging hierarchy
    PROCEDURE stop_logging IS
    BEGIN
        private_set_start_log_id(NULL);
        private_set_cur_log_id(NULL);
        private_set_parent_log_id(NULL);
    END;
    
    --Procedure creates next level of the logging hierarchy.
    --It creates new instance of logging hierarchy if it does not exist
    PROCEDURE open_next_level(p_comments_in  IN tech_log_table.comments%TYPE
                             ,p_clob_text_in IN tech_log_table.clob_text%TYPE DEFAULT NULL) IS
        v_log_record tech_log_table%ROWTYPE;
    BEGIN
        dbms_application_info.set_action(action_name => g_log_name);
        dbms_application_info.set_client_info(client_info => p_comments_in);
        
        IF g_start_log_id IS NULL
        THEN
            private_start_logging;
        ELSE
            private_set_parent_log_id(g_current_log_id);
            private_set_cur_log_id(tech_log_table_seq.nextval);
        END IF;
    
        v_log_record := private_get_log_record(p_start_log_id_in => g_start_log_id
                                              ,p_log_id_in       => g_current_log_id
                                              ,p_parent_log_id   => g_parent_log_id
                                              ,p_start_ts_in     => systimestamp
                                              ,p_end_ts_in       => NULL
                                              ,p_comments_in     => p_comments_in
                                              ,p_clob_text_in    => p_clob_text_in
                                              ,p_status_in       => g_status_running);
    
        private_ins_into_log_table(v_log_record);
    
    END open_next_level;
    
    --Procedure updates the status, end_ts and optionally row_count (if some DML was performed) of the current log level in log_table
    --It also saves exception message if current level threw exception.
    PROCEDURE close_level(p_status_in    IN tech_log_table.status%TYPE
                         ,p_row_count_in IN tech_log_table.row_count%TYPE DEFAULT NULL) IS
        v_exception_message tech_log_table.exception_message%TYPE;
        v_new_parent_log_id tech_log_table.parent_log_id%TYPE := NULL;
    BEGIN
        IF g_start_log_id IS NULL
        THEN
            RETURN;
        END IF;
        
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
    
        private_set_cur_log_id(nvl(g_parent_log_id, g_start_log_id));
        
        IF g_parent_log_id IS NOT NULL THEN
            SELECT t.parent_log_id
            INTO   v_new_parent_log_id
            FROM   tech_log_table t
            WHERE  t.log_id = g_parent_log_id;
        END IF;
    
        private_set_parent_log_id(v_new_parent_log_id);
    
    END close_level;
    
    --Logs a single record
    PROCEDURE log_record(p_comments_in  IN tech_log_table.comments%TYPE
                        ,p_clob_text_in IN tech_log_table.clob_text%TYPE DEFAULT NULL
                        ,p_status_in    IN tech_log_table.status%TYPE
                        ,p_row_count_in IN tech_log_table.row_count%TYPE DEFAULT NULL) IS
    BEGIN
        open_next_level(p_comments_in  => p_comments_in
                       ,p_clob_text_in => p_clob_text_in);
        close_level(p_status_in    => p_status_in
                   ,p_row_count_in => p_row_count_in);
    END;
    
    PROCEDURE set_log_name(p_name_in IN tech_log_instances.name%TYPE) IS
    BEGIN
        IF g_log_name IS NULL
        THEN
            g_log_name := p_name_in;
        END IF;
    END;
    
    FUNCTION get_log_name RETURN tech_log_instances.name%TYPE IS
    BEGIN
        RETURN g_log_name;
    END;
    
    --procedure initializes logging context in case you created a separate session (for ex. via dbms_scheduler) 
    --and you want this session to write into the same logging hierarchy instance
    PROCEDURE resume_logging(p_parent_log_id IN tech_log_table.parent_log_id%TYPE) IS
        v_start_log_id tech_log_table.start_log_id%TYPE;
    BEGIN
        SELECT t.start_log_id
        INTO   v_start_log_id
        FROM   tech_log_table t
        WHERE  t.log_id = p_parent_log_id;
        
        private_set_start_log_id(v_start_log_id);
        private_set_cur_log_id(p_parent_log_id);
    END;
      
END pk_util_log;
/
