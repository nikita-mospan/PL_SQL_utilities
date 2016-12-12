create table parallel_tasks (
    task_prefix varchar2(18) not null
    , task_name varchar2(128)
    , comments varchar2(4000)
    , creation_date date default sysdate
    , status varchar2(1)
    , parallel_level integer not null
    , timeout_seconds number(16) not null
    , start_of_execution date
    , duration interval day (1) to second (0)
    , constraint c_parallel_task_name_pk primary key (task_name)
    , constraint c_parallel_task_status_chck check (status in ('N', 'R', 'C', 'F'))
    , constraint c_timeout_seconds_chck check (timeout_seconds >= 0 )
)
;

create table parallel_task_items (
    item_id number(16)
    , chunk_id number
    , task_name varchar2(128) not null
    , log_id NUMBER(16)
    , plsql_block CLOB
    , status varchar2(1)
    , creation_date date default sysdate
    , constraint c_parallel_item_id_pk primary key (item_id)
    , constraint c_parallel_task_name_fk foreign key (task_name) references parallel_tasks (task_name)
    , constraint c_parallel_item_status_chck check (status in ('N', 'R', 'C', 'F'))
);

CREATE SEQUENCE seq_parallel_item_id
START WITH 1
MAXVALUE 999999999999999999999999999
MINVALUE 1
NOCYCLE
CACHE 100
NOORDER;

create or replace public synonym tech_parallel_tasks for parallel_tasks;
create or replace public synonym tech_parallel_task_items for parallel_task_items;
create or replace public synonym tech_seq_parallel_item_id for seq_parallel_item_id;
