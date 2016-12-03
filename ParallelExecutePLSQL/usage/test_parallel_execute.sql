create table t (id integer);

truncate table t;

declare
    v_task_name parallel_tasks.task_name%type;
    v_item_id parallel_task_items.item_id%type;
begin
    pk_util_log.stop_logging;
    pk_util_log.open_next_level(p_comments_in => 'test_parallel_execute');
    dbms_output.put_line(pk_util_log.get_start_log_id); 
    
    v_task_name := pk_util_parallel_execute.create_task(p_task_prefix_in => 'test', p_comments_in => 'first test',p_parallel_level_in => 4);
    
    for i in 1 .. 10 loop
        v_item_id := pk_util_parallel_execute.add_item_to_task(p_task_name_in => v_task_name, p_plsql_block_in => 'begin insert into t(id) values (' 
                                                                                                                    || to_char(i) || '); end;');
    end loop;
    
    pk_util_parallel_execute.execute_task(p_task_name_in => v_task_name);
    
    pk_util_log.close_level_success;
exception
	when others then
		pk_util_log.close_level_fail;
		raise;
end; 
/

select * from t ; 

SELECT    
	l.start_log_id,
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
    l.clob_text,
    l.exception_message
FROM
	tech_log_table l
START WITH l.log_id = 369
CONNECT BY
	l.parent_log_id = PRIOR l.log_id
ORDER SIBLINGS BY
	l.log_id ASC;


select *
from user_parallel_execute_chunks
where task_name = 'test31'
order by chunk_id
;

select * from parallel_tasks t where t.task_name = 'test31' ;
select * from parallel_task_items i where i.task_name = 'test31' ;  

select * from user_scheduler_job_run_details t where t.JOB_NAME = 'TASK$_3528_1' ; 

begin
    delete from parallel_task_items;
    delete from parallel_tasks;
    commit;
end;
/
