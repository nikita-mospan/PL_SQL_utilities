declare
    v_task_name tech_parallel_tasks.task_name%type;
    v_item_id tech_parallel_task_items.item_id%type;
begin
    pk_util_log.start_logging('test_parallel_execute');
    dbms_output.put_line(pk_util_log.get_start_log_id); 
    
    v_task_name := pk_util_parallel_execute.create_task(p_task_prefix_in => 'test', p_comments_in => 'first test',p_parallel_level_in => 4
                                                    , p_timeout_seconds_in => 12);
    
    for i in 1 .. 4 loop
        v_item_id := pk_util_parallel_execute.add_item_to_task(p_task_name_in => v_task_name, p_plsql_block_in => 'begin dbms_lock.sleep(10); end;');
    end loop;
    
    pk_util_parallel_execute.execute_task(p_task_name_in => v_task_name);
    
    pk_util_log.stop_log_success;
exception
	when others then
        pk_util_log.stop_log_fail;
		raise;
end; 
/

select * from log_instances order by start_ts desc ; 

SELECT
    LPAD (' ', 2* (LEVEL- 1)) || l.action_name as action_name,
    l.status,
    l.start_ts,
    l.end_ts,
    l.end_ts - l.start_ts AS elapsed,
    l.row_count,
    l.comments,
    l.exception_message,
    l.clob_text,
    l.sid,
    l.username
FROM
    tech_log_table l
START WITH l.log_id = &start_log_id
CONNECT BY
    l.parent_log_id = PRIOR l.log_id
ORDER SIBLINGS BY
	l.log_id ASC;


select *
from user_parallel_execute_chunks
where task_name = '&task_name'
order by chunk_id
;

select * from tech_parallel_tasks t where t.task_name = '&task_name' ;
select * from tech_parallel_task_items i where i.task_name = '&task_name' ;  

select * from user_scheduler_job_run_details t where t.JOB_NAME = '&job_name' ; 
