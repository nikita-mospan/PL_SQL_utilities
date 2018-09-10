drop table master_tables_attributes;

drop table mappings2etl_stage;

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
    business_key_order number,
    constraint c_master_tables_attributes_pk primary key (master_table, attribute_name),
    constraint c_master_tables_attributes_fk foreign key (master_table) references master_tables
);

create table master_tech_attributes (
    attribute_name varchar2(30) not null,
    attribute_type varchar2(100) not null,
    description    varchar2(4000), 
    constraint c_master_tech_attributes_pk primary key (attribute_name)); 

create table mappings2etl_stage (
    mapping_name varchar2(30),   
    mapping_sql  clob ,
    constraint c_mappings2master_pk primary key (mapping_name) );

insert into master_tables(master_table)
select 'COMPANY_M' as master_table from dual
union all
select 'VALID_RULES_CONFIG_M' from dual
union all
select 'COMPANY_ERR_M' from dual
;

insert into master_tables_attributes (
        master_table,   attribute_name,     attribute_type,     is_part_of_business_key, is_part_of_business_delta, business_key_order)
select 'COMPANY_M',     'COMPANY_ID',       'NUMBER NOT NULL',           'Y',                     'Y',                 1          from dual union all
select 'COMPANY_M',     'NAME',             'VARCHAR2(100) NOT NULL',    'Y',                     'Y',                 2           from dual union all
select 'COMPANY_M',     'SEGMENT',          'VARCHAR2(50) NOT NULL',     'N',                     'Y',                 NULL           from dual union all
select 'VALID_RULES_CONFIG_M',     'RULE_CODE', 'VARCHAR2(30) NOT NULL', 'Y',                     'Y',                 1           from dual union all
select 'VALID_RULES_CONFIG_M',     'VALIDATED_TABLE', 'VARCHAR2(30) NOT NULL', 'N',               'Y',                  NULL          from dual union all
select 'VALID_RULES_CONFIG_M',     'RULE_DESCRIPTION', 'VARCHAR2(4000) NOT NULL', 'N',            'Y',                  NULL          from dual union all
select 'VALID_RULES_CONFIG_M',     'VALIDATION_CHECK', 'VARCHAR2(4000) NOT NULL', 'N',            'Y',                  NULL          from dual union all
select 'COMPANY_ERR_M', 'RULE_CODE', 'VARCHAR2(30) NOT NULL', 'Y', 'Y', 1 from dual union all
select 'COMPANY_ERR_M', 'SOURCE_X_BUSINESS_HKEY', 'VARCHAR2(32) NOT NULL', 'Y', 'Y', 2 from dual union all
select 'COMPANY_ERR_M', 'SOURCE_X_VSTART', 'TIMESTAMP(6) NOT NULL', 'Y', 'Y', 3 from dual 
;

insert into master_tech_attributes (
        attribute_name,         attribute_type )
select  'X_BUSINESS_HKEY',      'VARCHAR2(32) NOT NULL'      from dual union all
select  'X_DELTA_HKEY',         'VARCHAR2(32) NOT NULL'      from dual union all
select  'X_VERSION_STATUS',     'VARCHAR2(50) NOT NULL'      from dual union all
select  'X_VSTART',             'TIMESTAMP(6) NOT NULL'         from dual union all
select  'X_VEND',               'TIMESTAMP(6) NOT NULL'         from dual
;

insert into mappings2etl_stage (
        mapping_name,    mapping_sql)
select  'DUMMY_COMPANY',    q'{insert into company_s (company_id,name,segment)
                                select 123 as company_id, 'Sberbank' as name, 'Big' as segment from dual}' from dual union all
select  'POPULATE_VALID_RULES_CONFIG',        
                                q'{insert into valid_rules_config_s (rule_code,validated_table,rule_description, validation_check)
                                   select 'RULE_1' as rule_code,
                                            'COMPANY_M' as validated_table,
                                            'SEGMENT field must be uppercase' as rule_description,
                                            'segment = upper(segment) ' as validation_check from dual}' from dual
; 

commit;


