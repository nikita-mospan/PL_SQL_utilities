--main hierarchical query
SELECT
    LPAD (' ', 2* (LEVEL- 1)) || l.log_id as log_id,
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
START WITH l.log_id = &start_log_id
CONNECT BY
    l.parent_log_id = PRIOR l.log_id
ORDER SIBLINGS BY
	l.log_id ASC;

--Table that stores hierarchical log instances
select * from tech_log_instances ; 

--basic logging example
--note: the schema must have execute grant on pk_util_log package
DECLARE
    PROCEDURE b(p_name_in IN VARCHAR2) IS
        v_dummy_cnt PLS_INTEGER;
    BEGIN
        pk_util_log.open_next_level(p_comments_in => 'procedure B(), line: ' || $$PLSQL_LINE || chr(13) || chr(10) ||
                                                     'p_name_in: ' || p_name_in);
        dbms_lock.sleep(3);
        pk_util_log.close_level_success;
    EXCEPTION
        WHEN OTHERS THEN
            pk_util_log.close_level_fail;
            RAISE;
    END;

    PROCEDURE a(p_name_in IN VARCHAR2) IS
    BEGIN
        pk_util_log.open_next_level('procedure A(), line: ' || $$PLSQL_LINE || chr(13) || chr(10) ||
                                    'p_name_in: ' || p_name_in);
        b('dummy_b');
        dbms_lock.sleep(2);
        pk_util_log.close_level_success;
    EXCEPTION
        WHEN OTHERS THEN
            pk_util_log.close_level_fail;
            RAISE;
    END;

BEGIN
    pk_util_log.start_logging('Test log');
    a('dummy_a');
    dbms_output.put_line(pk_util_log.get_start_log_id);
END;
/

--sql row_count example
declare
    v_sql varchar2(32767) := 'select 1 from dual';
    v_dummy_value pls_integer;
BEGIN
    pk_util_log.start_logging('sql_rowcount_example');
    pk_util_log.open_next_level(p_comments_in => v_sql);
    dbms_output.put_line(pk_util_log.get_start_log_id); 
    execute immediate v_sql into v_dummy_value;
    pk_util_log.close_level_success(p_row_count_in => sql%rowcount);
EXCEPTION
    WHEN OTHERS THEN
        pk_util_log.close_level_fail;
        RAISE;
END;
/

--resume logging example
--note: the schema must have grants to create dbms_scheduler jobs.
declare
    v_plsql_block varchar2(32767);
    v_last_log_id tech_log_table.log_id%type;
    v_cur_log_id tech_log_table.log_id%type;
BEGIN
    pk_util_log.start_logging('resume_logging_example');
    pk_util_log.open_next_level(p_comments_in => 'Some comment');
    dbms_output.put_line(pk_util_log.get_start_log_id); 
    v_cur_log_id := pk_util_log.get_current_log_id;
    for i  in 1 .. 5 loop
        v_plsql_block :=
            'begin
                pk_util_log.resume_logging(p_parent_log_id => #log_id#);
                pk_util_log.open_next_level(p_comments_in => ''Job record'');
                dbms_lock.sleep(#i#);
                pk_util_log.close_level_success;
            exception
	            when others then
                    pk_util_log.close_level_fail;
                    raise;
            end;';
        dbms_scheduler.create_job(job_name        => 'RESUME_LOGGING_JOB_' || to_char(i)
                                 ,job_type        => 'PLSQL_BLOCK'
                                 ,job_action      => replace(replace(v_plsql_block, '#log_id#', to_char(v_cur_log_id)), 
                                                            '#i#', to_char(i))
                                 ,enabled         => TRUE
                                 , auto_drop => TRUE);
    end loop;
    pk_util_log.close_level_success;
exception
	when others then
		pk_util_log.close_level_fail;
		raise;
END;
/
 
