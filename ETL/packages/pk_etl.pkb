CREATE OR REPLACE PACKAGE BODY pk_etl AS   
    
    g_business_fields_cons constant varchar2(100) := 'BUSINESS_FIELDS';
    g_tech_fields_cons constant varchar2(100) := 'TECH_FIELDS';
    g_business_hash_key_cons constant varchar2(100) := 'BUSINESS_HASH_KEY';
    g_delta_hash_key_cons constant varchar2(100) := 'DELTA_HASH_KEY';

    function private_get_fields (p_entity_in IN varchar2
                                , p_type_in in varchar2
                                , p_alias_in in varchar2 default null) return varchar2 result_cache is
        type t_string_ntt is table of varchar2(32767);
        v_string_list t_string_ntt;
        v_result varchar2(32767);
        v_delimiter varchar2(1);
    begin
        case p_type_in
            when g_business_fields_cons then
                select p_alias_in || t.attribute_name bulk collect into v_string_list
                from entity_attributes t
                where t.entity = p_entity_in
                    and t.is_business_field = 'Y'
                order by t.attribute_name;
            when g_tech_fields_cons then
                select p_alias_in || t.attribute_name bulk collect into v_string_list
                from entity_attributes t
                where t.entity = p_entity_in
                    and t.is_technical_field = 'Y'
                order by t.attribute_name;
            when g_business_hash_key_cons then
                select 'pk_etl.make_md5_hash(' || 
                        listagg(t.attribute_name, q'{ || '|' || }' ) within group (order by t.attribute_name) || ')' into v_result                       
                from entity_attributes t
                where t.entity = p_entity_in
                    and t.is_part_of_business_key = 'Y';
            when g_delta_hash_key_cons then
                select 'pk_etl.make_md5_hash(' || 
                        listagg(t.attribute_name, q'{ || '|' || }' ) within group (order by t.attribute_name) || ')' into v_result                       
                from entity_attributes t
                where t.entity = p_entity_in
                    and t.is_part_of_business_delta = 'Y';
        end case;
        
        if v_string_list is not null then
            for i in 1 .. v_string_list.COUNT loop
                v_result := v_result || v_delimiter || v_string_list(i);
                v_delimiter := ',';    
            end loop;
        end if;
        
        return v_result;
    end private_get_fields; 

    procedure private_populate_table_a(p_entity_in IN varchar2, 
                                    p_x_vstart   IN timestamp, 
                                    p_table_a_in IN varchar2, 
                                    p_table_s_in IN varchar2, 
                                    p_table_m_in IN varchar2) is
        v_sql_ins_into_a varchar2(32767);
        v_rowcount number;
    begin
        v_sql_ins_into_a := q'{insert into /*+ append */ [TABLE_A] ([BUSINESS_FIELDS], [TECH_FIELDS])
                        with s as (
                            select [BUSINESS_FIELDS]
                                , [BUSINESS_HASH_KEY] as x_business_hkey
                                , [DELTA_HASH_KEY] as x_delta_hkey
                                , [X_VEND] as x_vend
                                , 'CURRENT' as x_version_status
                                , [X_VSTART] as x_vstart
                            from [TABLE_S]),
                            m as (select * from [TABLE_M] partition ([END_PARTITION]) t)
                        select [BUSINESS_FIELDS_S_ALIAS]
                                , s.x_business_hkey
                                , s.x_delta_hkey
                                , s.x_vend
                                , s.x_version_status
                                , decode(s.x_delta_hkey, m.x_delta_hkey, m.x_vstart, s.x_vstart) as x_vstart
                        from s left join m on s.x_business_hkey = m.x_business_hkey }';
        
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[TABLE_A]', p_table_a_in);
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[BUSINESS_FIELDS]', private_get_fields(p_entity_in, g_business_fields_cons));
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[BUSINESS_FIELDS_S_ALIAS]', private_get_fields(p_entity_in, g_business_fields_cons, 's.'));        
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[TECH_FIELDS]', private_get_fields(p_entity_in, g_tech_fields_cons));
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[BUSINESS_HASH_KEY]', private_get_fields(p_entity_in, g_business_hash_key_cons)); 
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[DELTA_HASH_KEY]', private_get_fields(p_entity_in, g_delta_hash_key_cons));
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[TABLE_S]', p_table_s_in);       
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[TABLE_M]', p_table_m_in);   
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[END_PARTITION]', c_x_vend_partition);
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[X_VSTART]', pk_etl.prepare_timestamp_replace(p_x_vstart));  
        v_sql_ins_into_a := replace(v_sql_ins_into_a, '[X_VEND]', pk_etl.prepare_timestamp_replace(c_x_vend));
        pk_util_log.log_and_execute_dml(p_action_name_in => 'Insert into ' || p_table_a_in
                                        , p_sql_in => v_sql_ins_into_a
                                        , p_commit_after_dml_in => true
                                        , p_rowcount_out => v_rowcount);
    end private_populate_table_a;   
    
    procedure private_move_dlta_to_partition (p_entity_in IN varchar2
                                        , p_partition_name_in IN varchar2 
                                        , p_x_vstart_in IN varchar2
                                        , p_table_m_in IN varchar2
                                        , p_table_a_in IN varchar2) is
        v_ins_into_prev_partition varchar2(32767);
        v_rowcount_sql number;
    begin
        v_ins_into_prev_partition := q'{insert /*+ append */ into [TABLE_M] partition ([PREV_PARTITION]) ([BUSINESS_FIELDS], [TECH_FIELDS]) 
                                select [BUSINESS_FIELDS_M_ALIAS], 
                                        m.x_business_hkey,
                                        m.x_delta_hkey,
                                        [X_VSTART] as x_vend,
                                        nvl2(a.x_business_hkey, 'UPDATED', 'DELETED') as x_version_status,
                                        m.x_vstart
                                from [TABLE_M] partition ([VEND_PARTITION]) m 
                                    left join [TABLE_A] a on m.x_business_hkey = a.x_business_hkey 
                                where m.x_delta_hkey <> nvl(a.x_delta_hkey, 'NULL')}';
        v_ins_into_prev_partition := replace(v_ins_into_prev_partition, '[TABLE_M]', p_table_m_in);
        v_ins_into_prev_partition := replace(v_ins_into_prev_partition, '[PREV_PARTITION]', p_partition_name_in);
        v_ins_into_prev_partition := replace(v_ins_into_prev_partition, '[BUSINESS_FIELDS]', private_get_fields(p_entity_in, g_business_fields_cons));
        v_ins_into_prev_partition := replace(v_ins_into_prev_partition, '[TECH_FIELDS]', private_get_fields(p_entity_in, g_tech_fields_cons));
        v_ins_into_prev_partition := replace(v_ins_into_prev_partition, '[BUSINESS_FIELDS_M_ALIAS]', 
                                                            private_get_fields(p_entity_in, g_business_fields_cons, 'm.'));
        v_ins_into_prev_partition := replace(v_ins_into_prev_partition, '[X_VSTART]', pk_etl.prepare_timestamp_replace(p_x_vstart_in));
        v_ins_into_prev_partition := replace(v_ins_into_prev_partition, '[VEND_PARTITION]', c_x_vend_partition);
        v_ins_into_prev_partition := replace(v_ins_into_prev_partition, '[TABLE_A]', p_table_a_in);
        
        pk_util_log.log_and_execute_dml(p_action_name_in => 'Move delta to previous partition'
                                        , p_sql_in => v_ins_into_prev_partition
                                        , p_rowcount_out => v_rowcount_sql);
        if v_rowcount_sql = 0 then
            pk_util_log.log_and_execute_ddl(p_action_name_in => 'No delta was detected. Drop empty partition.'
                                        , p_sql_in => 'alter table ' || p_table_m_in || ' drop partition ' || p_partition_name_in);
        end if;
    end private_move_dlta_to_partition; 
    
    function make_md5_hash(p_src_str_in IN varchar2) 
        return varchar2
        deterministic
        parallel_enable is        
    begin
        return RAWTOHEX(dbms_crypto.Hash(utl_raw.cast_to_raw(p_src_str_in), typ => dbms_crypto.HASH_MD5));
    end;
    
    function prepare_timestamp_replace (p_timestamp_in IN timestamp) 
        return varchar2
        deterministic is
    begin
        return 'to_timestamp(''' || to_char(p_timestamp_in, 'dd.mm.yyyy HH24.MI.SS.FF') || ''', ''' ||
                'dd.mm.yyyy HH24.MI.SS.FF' || ''')';
    end; 
    
    procedure load_entity(p_entity_in IN varchar2,
                        p_x_vstart_in IN timestamp) is
        v_table_s varchar2(30);
        v_table_a varchar2(30);
        v_table_m varchar2(30);
        v_prev_partition_name varchar2(30);
    begin
        pk_util_log.start_logging(p_log_instance_name_in => 'Load entity: ' || p_entity_in);
        dbms_output.put_line(pk_util_log.get_start_log_id); 
        
        select t.s_table, t.a_table, t.m_table into v_table_s, v_table_a, v_table_m
        from entities t
        where t.entity = p_entity_in;
        
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Truncate ' || v_table_a
                                    , p_sql_in => 'truncate table ' || v_table_a);
        
        private_populate_table_a(p_entity_in => p_entity_in, 
                            p_x_vstart => p_x_vstart_in, 
                            p_table_a_in => v_table_a, 
                            p_table_s_in => v_table_s, 
                            p_table_m_in => v_table_m);
        
        v_prev_partition_name := 'p_' || to_char(p_x_vstart_in, 'YYYYmmDDhh24MIssFF');
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Create partition for delta in: ' ||  v_table_m
                                        , p_sql_in => 'alter table ' || v_table_m || ' add partition ' 
                                                    || v_prev_partition_name || ' values (' || 
                                                    pk_etl.prepare_timestamp_replace(p_x_vstart_in) || ') ');
        
        private_move_dlta_to_partition (p_entity_in, v_prev_partition_name, p_x_vstart_in, v_table_m, v_table_a);
        
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Load latest data via exchange partition'
                                    , p_sql_in => 'alter table ' || v_table_m || ' exchange partition ' || c_x_vend_partition || ' with table ' 
                                                    || v_table_a || ' including indexes');
        
        pk_util_log.stop_log_success;
    exception
    	when others then
    		pk_util_log.stop_log_fail;
    		raise;
    end; 
          
END pk_etl;
/
