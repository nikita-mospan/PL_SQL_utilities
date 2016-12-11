create table log_instances (
    start_log_id number(16) not null
    , name varchar2(32 char)
    , start_ts timestamp(6) not null
    , constraint log_instances_pk primary key(start_log_id));
    
    

create table log_table (
    start_log_id NUMBER(16) not null,
    log_id  NUMBER(16),
    parent_log_id NUMBER(16),
    start_ts timestamp(6) not null,
    end_ts timestamp(6),
    sid NUMBER not null,
    username varchar2(30) not null,
    status varchar2(1 char),
    row_count number(12),        
    comments varchar2(4000 char),
    exception_message varchar2(4000 char),
    clob_text CLOB,
    constraint log_table_id_pk primary key (log_id), 
    constraint log_table_parent_id_fk foreign key (parent_log_id) references log_table(log_id), 
    constraint log_table_status_chck check (status in ('C'/*completed*/, 'R'/*running*/, 'F'/*failed*/)),
    constraint log_table_start_log_id_fk foreign key (start_log_id) references log_instances(start_log_id)
);
    
create index log_table_parent_id_idx on log_table(parent_log_id);
    
create index log_table_start_log_id_idx on log_table(start_log_id);
        
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

grant select on tech_log_table to public;
grant select on log_instances to public;
grant select on  SEQ_LOG_TABLE to public; 
