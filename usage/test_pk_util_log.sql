DECLARE
    PROCEDURE b(p_name_in IN VARCHAR2) IS
        v_dummy_cnt PLS_INTEGER;
    BEGIN
        pk_util_log.open_next_level(p_comments_in => 'procedure B(), line: ' || $$PLSQL_LINE || chr(13) || chr(10) ||
                                                     'p_name_in: ' || p_name_in);
        dbms_lock.sleep(10);
        pk_util_log.close_level(p_status_in => 'C');
    EXCEPTION
        WHEN OTHERS THEN
            pk_util_log.close_level(p_status_in => pk_util_log.g_status_failed);
            RAISE;
    END;

    PROCEDURE a(p_name_in IN VARCHAR2) IS
    BEGIN
        pk_util_log.open_next_level('procedure A(), line: ' || $$PLSQL_LINE || chr(13) || chr(10) ||
                                    'p_name_in: ' || p_name_in);
        b('dummy_b');
        dbms_lock.sleep(5);
        pk_util_log.close_level(p_status_in => pk_util_log.g_status_completed);
    EXCEPTION
        WHEN OTHERS THEN
            pk_util_log.close_level(p_status_in => pk_util_log.g_status_failed);
            RAISE;
    END;

BEGIN
    pk_util_log.stop_logging;
    a('dummy_a');
    dbms_output.put_line(pk_util_log.get_start_log_id);
END;
/

SELECT    
	l.start_log_id,
    LPAD (' ', 2* (LEVEL- 1)) || l.log_id,
    l.parent_log_id,
    l.start_ts,
    l.end_ts,
    LPAD (' ', 2* (LEVEL- 1)) || SUBSTR ( (l.end_ts - l.start_ts), 13, 9) AS elapsed,
    l.sid,
    l.username,
    l.status,
    l.row_count,
    LPAD (' ', 2* (LEVEL- 1)) || l.comments AS comments,
    l.exception_message
FROM
	tech_log_table l
START WITH l.log_id = 103
CONNECT BY
	l.parent_log_id = PRIOR l.log_id
ORDER SIBLINGS BY
	l.log_id ASC;

declare
    v_plsql_block varchar2(32767);
    v_last_log_id tech_log_table.log_id%type;
BEGIN
    v_last_log_id  := pk_util_log.get_current_log_id;
    dbms_output.put_line(v_last_log_id); 
    v_plsql_block :=
        'begin
            pk_util_log.resume_logging(p_parent_log_id => #log_id#);
            pk_util_log.log_record(p_comments_in => ''Job record'', p_status_in => pk_util_log.g_status_completed);
        end;';
    dbms_scheduler.create_job(job_name        => 'resume_logging_job'
                             ,job_type        => 'PLSQL_BLOCK'
                             ,job_action      => replace(v_plsql_block, '#log_id#', v_last_log_id)
                             ,enabled         => TRUE
                             , auto_drop => TRUE);
END;
/
