create table log_instances (
    start_log_id number(16) not null
    , log_instance_name varchar2(100) not null
    , start_ts timestamp(6) not null
    , end_ts timestamp(6)
    , status varchar2(1) not null
    , log_date date not null
    , constraint log_instances_pk primary key(start_log_id));

create index log_instances_name_idx on log_instances(log_instance_name);

create table log_table (
    action_name varchar2(64) not null,
    log_id  NUMBER(16) not null,
    parent_log_id NUMBER(16),
    start_ts timestamp(6) not null,
    end_ts timestamp(6),
    sid NUMBER not null,
    username varchar2(30) not null,
    status varchar2(1) not null,
    row_count number(12),        
    comments varchar2(4000),
    exception_message varchar2(4000),
    clob_text CLOB,
    log_date date not null,
    constraint log_table_status_chck check (status in ('C'/*completed*/, 'R'/*running*/, 'F'/*failed*/))
)
partition by range (log_date)
interval(NUMTODSINTERVAL(7,'day'))
(partition p_fst_day_of_week values less than (date '2018-07-09'))
;

create index log_table_log_id_idx on log_table(log_id) local;
    
create index log_table_parent_id_idx on log_table(parent_log_id) local;

create index log_table_action_name_idx on log_table(action_name) local;
        
CREATE SEQUENCE SEQ_LOG_TABLE
    START WITH 1
    MAXVALUE 999999999999999999999999999
    MINVALUE 1
    NOCYCLE
    CACHE 100
    NOORDER;
    
create or replace public synonym tech_log_table for log_table;
create or replace public synonym tech_log_table_seq for SEQ_LOG_TABLE;
create or replace public synonym tech_log_instances for log_instances;

grant select on log_table to public;
grant select on log_instances to public;
grant select on  SEQ_LOG_TABLE to public; 
