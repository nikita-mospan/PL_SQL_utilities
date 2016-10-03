declare
    v_sql varchar2(32767);
    
    procedure create_if_not_exists(p_sql_in varchar2) is
        v_exptn_table_alr_exts exception;
        pragma exception_init(v_exptn_table_alr_exts, -955);
    begin
        execute immediate p_sql_in;
    EXCEPTION 
        WHEN v_exptn_table_alr_exts then
            dbms_output.put_line('Ignore exception (name is already used by existing object)'); 
    end create_if_not_exists;
    
begin
    v_sql := 'create table log_table (' || chr(10) ||
        '    start_log_id NUMBER(16) not null,' || chr(10) ||
        '    log_id  NUMBER(16),' || chr(10) ||
        '    parent_log_id NUMBER(16),' || chr(10) ||
        '    start_ts timestamp(6) not null,' || chr(10) ||
        '    end_ts timestamp(6),' || chr(10) ||
        '    sid NUMBER not null,' || chr(10) ||
        '    username varchar2(30) not null,' || chr(10) ||
        '    status varchar2(1 char),' || chr(10) ||
        '    row_count number(12),' || chr(10) ||        
        '    comments varchar2(4000 char),' || chr(10) ||
        '    exception_message varchar2(4000 char),' || chr(10) ||
        '    clob_text CLOB,' || chr(10) ||
        '    constraint log_table_id_pk primary key (log_id), ' || chr(10) ||
        '    constraint log_table_parent_id_fk foreign key (parent_log_id) references log_table(log_id), ' || chr(10) ||
        '    constraint log_table_status_chck check (status in (''C''/*completed*/, ''R''/*running*/, ''F''/*failed*/))' || chr(10) ||
        ')' ;
    
    create_if_not_exists(p_sql_in => v_sql);
   
    --index foreign key
    v_sql := 'create index log_table_parent_id_idx on log_table(parent_log_id)';    
    create_if_not_exists(p_sql_in => v_sql);
    
    v_sql := 'CREATE SEQUENCE SEQ_LOG_TABLE' || chr(10) ||
            '    START WITH 1' || chr(10) ||
            '    MAXVALUE 999999999999999999999999999' || chr(10) ||
            '    MINVALUE 1' || chr(10) ||
            '    NOCYCLE' || chr(10) ||
            '    CACHE 100' || chr(10) ||
            '    NOORDER';
    
    create_if_not_exists(p_sql_in => v_sql);
    
    v_sql := 'create table log_instances (' || chr(10) ||
            '    start_log_id number(16) not null,' || chr(10) ||
            '    name varchar2(32 char),' || chr(10) ||
            '    start_ts timestamp(6) not null,' || chr(10) ||
            '    constraint log_instances_pk primary key(start_log_id))';
    
    create_if_not_exists(p_sql_in => v_sql);


exception 
    when others then
        dbms_output.put_line(v_sql);
        raise; 
end;
/

create or replace public synonym tech_log_table for log_table;
create or replace public synonym tech_log_table_seq for SEQ_LOG_TABLE;
create or replace public synonym tech_log_instances for log_instances;

grant select on tech_log_table to public;
grant select on log_instances to public;
grant select on  SEQ_LOG_TABLE to public; 
