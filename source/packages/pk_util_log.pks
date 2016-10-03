CREATE OR REPLACE PACKAGE pk_util_log AUTHID DEFINER AS
    
    --Statuses of log_entries
    --'C' - completed, means that the action specified by the logging entry completed without throwing exception
    --'R' - running, means that the action specified by the logging entry is still running 
    --          (ex. you executed "pk_util_log.open_next_level" at the begining of some
    --          function/procedure and it still did not reach corresponding "pk_util_log.close_level" call at its end).
    --'F' - failed, means that the action specified by the logging entry failed (i.e. action threw exception)
    g_status_completed CONSTANT VARCHAR2(1) := 'C';
    g_status_running   CONSTANT VARCHAR2(1) := 'R';
    g_status_failed    CONSTANT VARCHAR2(1) := 'F';
    
    --Procedure clears session logging variables, so that the next logging attempt will be made into the new logging hierarchy
    PROCEDURE stop_logging;
    
    --procedure initializes logging context in case you created a separate session (for ex. via dbms_scheduler) 
    --and you want this session to write into the same logging hierarchy instance
    PROCEDURE resume_logging(p_parent_log_id IN tech_log_table.parent_log_id%TYPE);
    
    --Get root log_id of hierarchy instance
    FUNCTION get_start_log_id RETURN tech_log_table.start_log_id%TYPE;
    
    --Procedure creates next level of the logging hierarchy.
    --It creates new instance of logging hierarchy if it does not exist
    PROCEDURE open_next_level(p_comments_in  IN tech_log_table.comments%TYPE
                             ,p_clob_text_in IN tech_log_table.clob_text%TYPE DEFAULT NULL);
    
    --Procedure updates the status, end_ts and optionally row_count (if some DML was performed) of the current log level in log_table
    --It also saves exception message if current level threw exception.
    PROCEDURE close_level(p_status_in    IN tech_log_table.status%TYPE
                         ,p_row_count_in IN tech_log_table.row_count%TYPE DEFAULT NULL);
    
    --Logs a single record
    PROCEDURE log_record(p_comments_in  IN tech_log_table.comments%TYPE
                        ,p_clob_text_in IN tech_log_table.clob_text%TYPE DEFAULT NULL
                        ,p_status_in    IN tech_log_table.status%TYPE
                        ,p_row_count_in IN tech_log_table.row_count%TYPE DEFAULT NULL);
    
    --Procedure sets the name for logging hierarchy instance
    PROCEDURE set_log_name(p_name_in IN tech_log_instances.name%TYPE);
    
    --Procedure gets the name of the logging hierarchy instance
    FUNCTION get_log_name RETURN tech_log_instances.name%TYPE;
    
    --Get current log_id for the session
    FUNCTION get_current_log_id RETURN tech_log_table.log_id%TYPE;

END pk_util_log;
/
