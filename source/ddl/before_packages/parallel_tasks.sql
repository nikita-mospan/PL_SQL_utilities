create table parallel_tasks (
    task_name varchar2(128)
    , comments varchar2(4000)
    , creation_date date default sysdate
    , status varchar2(1)
    , parallel_level integer not null
    , constraint parallel_task_name_pk primary key (task_name)
    , constraint parallel_task_status check (status in ('N', 'R', 'C', 'F'))
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
    , constraint parallel_item_id_pk primary key (item_id)
    , constraint parallel_task_name_fk foreign key (task_name) references parallel_tasks (task_name)
    , constraint parallel_item_status check (status in ('N', 'R', 'C', 'F'))
);

CREATE SEQUENCE seq_parallel_item_id
START WITH 1
MAXVALUE 999999999999999999999999999
MINVALUE 1
NOCYCLE
CACHE 100
NOORDER;
