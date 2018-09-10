drop table master_tables_attributes;

drop table mappings2master;

drop table master_tables;

drop table master_tech_attributes;

create table master_tables (
    master_table varchar2(30),
    auxillary_table as (substr(master_table, 1, length(master_table) - 1) || 'A'),
    staging_table as (substr(master_table, 1, length(master_table) - 1) || 'S'),
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
select 'COMPANY_M' as master_table from dual
union all
select 'VALID_RULES_CONFIG_M' from dual
union all
select 'COMPANY_ERR_M' from dual
;

insert into master_tables_attributes (
        master_table,   attribute_name,     attribute_type,     is_part_of_business_key, is_part_of_business_delta)
select 'COMPANY_M',     'COMPANY_ID',       'NUMBER NOT NULL',           'Y',                     'Y'            from dual union all
select 'COMPANY_M',     'NAME',             'VARCHAR2(100) NOT NULL',    'Y',                     'Y'            from dual union all
select 'COMPANY_M',     'SEGMENT',          'VARCHAR2(50) NOT NULL',     'N',                     'Y'            from dual union all
select 'VALID_RULES_CONFIG_M',     'RULE_CODE', 'VARCHAR2(30) NOT NULL', 'Y',                     'Y'            from dual union all
select 'VALID_RULES_CONFIG_M',     'VALIDATED_TABLE', 'VARCHAR2(30) NOT NULL', 'N',               'Y'            from dual union all
select 'VALID_RULES_CONFIG_M',     'RULE_DESCRIPTION', 'VARCHAR2(4000) NOT NULL', 'N',            'Y'            from dual union all
select 'VALID_RULES_CONFIG_M',     'VALIDATION_CHECK', 'VARCHAR2(4000) NOT NULL', 'N',            'Y'            from dual union all
select 'COMPANY_ERR_M', 'RULE_CODE', 'VARCHAR2(30) NOT NULL', 'Y', 'Y' from dual union all
select 'COMPANY_ERR_M', 'SOURCE_X_BUSINESS_HKEY', 'VARCHAR2(32) NOT NULL', 'Y', 'Y' from dual union all
select 'COMPANY_ERR_M', 'SOURCE_X_VSTART', 'TIMESTAMP(6) NOT NULL', 'Y', 'Y' from dual 
;

insert into master_tech_attributes (
        attribute_name,         attribute_type )
select  'X_BUSINESS_HKEY',      'VARCHAR2(32) NOT NULL'      from dual union all
select  'X_DELTA_HKEY',         'VARCHAR2(32) NOT NULL'      from dual union all
select  'X_VERSION_STATUS',     'VARCHAR2(50) NOT NULL'      from dual union all
select  'X_VSTART',             'TIMESTAMP(6) NOT NULL'         from dual union all
select  'X_VEND',               'TIMESTAMP(6) NOT NULL'         from dual
;

insert into mappings2master (
        mapping_name,                   master_table,   mapping_sql)
select  'POPULATE_COMPANY_M',    'COMPANY_M',    'select company_id,name,segment from company_s' from dual union all
select  'POPULATE_VALID_RULES_CONFIG_M',    'VALID_RULES_CONFIG_M',    
                                'select rule_code,validated_table,rule_description, validation_check from valid_rules_config_s' from dual union all
select  'POPULATE_COMPANY_ERR_M',    'COMPANY_ERR_M',    
                                'select rule_code,SOURCE_X_BUSINESS_HKEY,SOURCE_X_VSTART from COMPANY_ERR_S' from dual 

; 

commit;


