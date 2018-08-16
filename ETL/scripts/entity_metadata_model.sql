drop table master_tables_attributes;

drop table mappings2master;

drop table master_tables;

drop table master_tech_attributes;

create table master_tables (
    master_table varchar2(30),
    auxillary_table as (substr(master_table, 1, length(master_table) - 1) || 'A'),
    constraint c_master_table_pk primary key(master_table)
);

create table master_tables_attributes (
    master_table varchar2(30) not null,
    attribute_name varchar2(30) not null,
    attribute_type varchar2(100) not null,
    is_part_of_business_key varchar2(1) check (is_part_of_business_key in ('Y', 'N')),
    is_part_of_business_delta varchar2(1) check (is_part_of_business_delta in ('Y', 'N')),
    constraint c_master_tables_attributes_pk primary key (master_table, attribute_name),
    constraint c_master_tables_attributes_fk foreign key (master_table) references master_tables
);

create table master_tech_attributes (
    attribute_name varchar2(30) not null,
    attribute_type varchar2(100) not null,
    description    varchar2(4000), 
    constraint c_master_tech_attributes_pk primary key (attribute_name)); 

create table mappings2master (
    mapping_name varchar2(30),   
    master_table varchar2(30) not null,
    mapping_sql  clob ,
    constraint c_mappings2master_fk foreign key (master_table) references master_tables,
    constraint c_mappings2master_pk primary key (mapping_name) );
    

insert into master_tables(master_table)
    values ('COMPANY_M');

insert into master_tables_attributes (
        master_table,   attribute_name,     attribute_type,     is_part_of_business_key, is_part_of_business_delta)
select 'COMPANY_M',     'COMPANY_ID',       'NUMBER',           'Y',                     'N'                        from dual union all
select 'COMPANY_M',     'NAME',             'VARCHAR2(100)',    'Y',                     'N'                        from dual union all
select 'COMPANY_M',     'SEGMENT',          'VARCHAR2(50)',     'N',                     'Y'                        from dual
;

insert into master_tech_attributes (
        attribute_name,         attribute_type )
select  'X_BUSINESS_HKEY',      'VARCHAR2(32)'      from dual union all
select  'X_DELTA_HKEY',         'VARCHAR2(32)'      from dual union all
select  'X_VERSION_STATUS',     'VARCHAR2(50)'      from dual union all
select  'X_VSTART',             'TIMESTAMP'         from dual union all
select  'X_VEND',               'TIMESTAMP'         from dual
;

insert into mappings2master (
        mapping_name,                   master_table,   mapping_sql)
select  'TRIVIAL_LOAD_TO_COMPANY_M',    'COMPANY_M',    'select company_id,name,segment from company_s' from dual; 

commit;


