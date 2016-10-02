declare
    v_sql varchar2(4000);
    v_dummy pls_integer;
begin
    pk_util_log.stop_logging;
    v_sql := 'select 1 from dual';
    pk_util_log.set_log_name(p_name_in => 'Dummy log');
    pk_util_log.open_next_level(p_comments_in => v_sql);
    execute immediate v_sql into v_dummy;
    pk_util_log.log_record(p_comments_in => 'Just a dummy record', p_status_in => pk_util_log.g_status_completed);
    pk_util_log.close_level(p_status_in => pk_util_log.g_status_completed, p_row_count_in => sql%rowcount);
    dbms_output.put_line(pk_util_log.get_start_log_id);
exception
	when others then
		pk_util_log.close_level(p_status_in => pk_util_log.g_status_failed);
        dbms_output.put_line(pk_util_log.get_start_log_id);
		raise;
end;
/

declare
    v_plsql_block varchar2(32767);
BEGIN
    v_plsql_block :=
        'begin
            pk_util_log.resume_logging(p_start_log_id => 4, p_parent_log_id => 4);
            pk_util_log.log_record(p_comments_in => ''Job record'', p_status_in => pk_util_log.g_status_completed);
        end;';
    dbms_scheduler.create_job(job_name        => 'resume_logging_job'
                             ,job_type        => 'PLSQL_BLOCK'
                             ,job_action      => v_plsql_block
                             ,enabled         => TRUE
                             , auto_drop => TRUE);
END;
/

SELECT    
    l.start_log_id,
	lpad('  ', (level - 1) * 2) || to_char(l.log_id) as log_id,
    l.parent_log_id,
	l.start_ts,
	l.end_ts,
	l.status as status,
    l.name,
	lpad('  ', (level - 1) * 2) || l.comments as comments,
	l.clob_text,
    l.row_count,
	l.exception_message
FROM
	tech_log_table l
--where olg.olg_status = 'F'
--where SUBSTR ( (olg.olg_end - olg.olg_start), 13, 9) >= '0:00:00.0'
START WITH
	l.log_id IN 4
CONNECT BY
	l.parent_log_id = PRIOR l.log_id
ORDER SIBLINGS BY
	l.log_id ASC;  

