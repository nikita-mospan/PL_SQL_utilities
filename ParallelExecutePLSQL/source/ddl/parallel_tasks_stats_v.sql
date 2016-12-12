create or replace view parallel_tasks_stats_v as
select
    t.task_name
    , t.comments
    , t.creation_date as task_creation_date
    , t.status as task_status
    , t.parallel_level
    , t.start_of_execution as task_start_of_execution
    , t.duration as task_execution_duration
    , i.item_id
    , i.log_id as item_log_id
    , i.plsql_block
    , i.status as item_status
    , i.creation_date as item_creation_date
    , up.JOB_NAME
    , up.START_TS as item_start_ts
    , up.END_TS - up.START_TS as item_execution_duration
    , up.ERROR_CODE
    , up.ERROR_MESSAGE
from parallel_tasks t 
    join parallel_task_items i on t.task_name = i.task_name
    left join user_parallel_execute_chunks up on i.item_id = up.START_ID
order by item_execution_duration desc nulls last
;

create or replace public synonym tech_parallel_tasks_stats_v for parallel_tasks_stats_v;
