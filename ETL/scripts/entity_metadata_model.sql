drop table entity_attributes;

drop table entities;

create table entities (
    entity varchar2(30),
    s_table varchar2(30) not null,
    a_table varchar2(30) not null,
    m_table varchar2(30) not null,
    constraint entities_pk primary key(entity)
);

create table entity_attributes (
    entity varchar2(30) not null,
    attribute_name varchar2(30) not null,
    attribute_type varchar2(100) not null,
    is_business_field varchar2(1) check (is_business_field in ('Y', 'N')),
    is_technical_field varchar2(1) check (is_technical_field in ('Y', 'N')),
    is_part_of_business_key varchar2(1) check (is_part_of_business_key in ('Y', 'N')),
    is_part_of_business_delta varchar2(1) check (is_part_of_business_delta in ('Y', 'N')),
    constraint entity_attributes_pk primary key (entity, attribute_name),
    constraint entity_attributes_entity_fk foreign key (entity) references entities
);

insert into entities(entity, s_table, a_table, m_table)
    values ('company', 'company_s', 'company_a', 'company_m');

insert into entity_attributes (
        entity,     attribute_name,     attribute_type,     is_business_field, is_technical_field, is_part_of_business_key, is_part_of_business_delta)
select 'company', 'company_id',         'number',           'Y',                'N',                'Y',                    'N' from dual union all
select 'company', 'name',               'varchar2(100)',    'Y',                'N',                'Y',                    'N' from dual union all
select 'company', 'segment',            'varchar2(50)',     'Y',                'N',                'N',                    'Y' from dual union all
select 'company', 'x_business_hkey',    'varchar2(32)',     'N',                'Y',                'N',                    'N' from dual union all
select 'company', 'x_delta_hkey',       'varchar2(32)',     'N',                'Y',                'N',                    'N' from dual union all
select 'company', 'x_version_status',   'varchar2(50)',     'N',                'Y',                'N',                    'N' from dual union all
select 'company', 'x_vstart',           'timestamp',        'N',                'Y',                'N',                    'N' from dual union all
select 'company', 'x_vend',             'timestamp',        'N',                'Y',                'N',                    'N' from dual
;

commit;
