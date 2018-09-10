CREATE OR REPLACE PACKAGE BODY pk_deploy AS
	
    function priv_get_bus_col_definitions (p_master_table_in varchar2) return varchar2 is
        v_result varchar2(32767);
    begin
        for rec in (select * from master_tables_attributes where master_table = p_master_table_in) loop
            v_result := v_result || rec.attribute_name || ' ' || rec.attribute_type || ',' || pk_constants.eol;
        end loop;
        
        v_result := rtrim(v_result, ',' || pk_constants.eol);
        
        pk_util_log.log_record(p_action_name_in => 'priv_get_bus_col_definitions'
                                , p_status_in => pk_util_log.g_status_completed
                                , p_clob_text_in => v_result);
        
        return v_result;
    end priv_get_bus_col_definitions; 
    
    function priv_get_tech_col_definitions return varchar2 is
        v_result varchar2(32767);
    begin
        for rec in (select * from master_tech_attributes) loop
            v_result := v_result || rec.attribute_name || ' ' || rec.attribute_type || ',' || pk_constants.eol;
        end loop;
        
        v_result := rtrim(v_result, ',' || pk_constants.eol);
        
        pk_util_log.log_record(p_action_name_in => 'priv_get_tech_col_definitions'
                                , p_status_in => pk_util_log.g_status_completed
                                , p_clob_text_in => v_result);
        
        return v_result;
        
    end priv_get_tech_col_definitions; 

    procedure priv_create_master_table(p_master_table_in varchar2) is
        v_crt_table_m_sql varchar2(32767);
    begin
        v_crt_table_m_sql := q'{create table $MASTER_TABLE ( 
                            $BUS_ATTRIBUTES, 
                            $TECH_ATTRIBUTES
                            )
                            partition by list (x_vend)
                            (partition p_99991231000000000000000 values (to_timestamp('99991231', 'yyyymmdd')))
                            }';
        
        v_crt_table_m_sql := replace(v_crt_table_m_sql, '$BUS_ATTRIBUTES', priv_get_bus_col_definitions(p_master_table_in));
        v_crt_table_m_sql := replace(v_crt_table_m_sql, '$TECH_ATTRIBUTES', priv_get_tech_col_definitions());
        v_crt_table_m_sql := replace(v_crt_table_m_sql, '$MASTER_TABLE', p_master_table_in);
        
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Create ' || p_master_table_in, p_sql_in => v_crt_table_m_sql);
        
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Create local index for Primary Key'
                                        , p_sql_in => 'create unique index IDX_' || p_master_table_in || '_PK on ' || 
                                                        p_master_table_in || '(x_vend, x_business_hkey) local' );
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Create Primary Key'
                                        , p_sql_in => 'alter table ' || p_master_table_in || ' add constraint C_' || p_master_table_in || '_PK ' ||
                                                    ' primary key  (x_vend, x_business_hkey) using index IDX_' || p_master_table_in || '_PK');
    end priv_create_master_table; 
    
    procedure priv_create_auxil_table(p_table_a_in varchar2, p_master_table_in varchar2) is
        v_crt_table_a_sql varchar2(32767);
    begin
        v_crt_table_a_sql := q'{create table $AUXIL_TABLE ( 
                            $BUS_ATTRIBUTES ,
                            $TECH_ATTRIBUTES ,
                            constraint C_$AUXIL_TABLE_PK primary key (x_vend, x_business_hkey)
                            )                            
                            }';
        
        v_crt_table_a_sql := replace(v_crt_table_a_sql, '$BUS_ATTRIBUTES', priv_get_bus_col_definitions(p_master_table_in));
        v_crt_table_a_sql := replace(v_crt_table_a_sql, '$TECH_ATTRIBUTES', priv_get_tech_col_definitions);
        v_crt_table_a_sql := replace(v_crt_table_a_sql, '$AUXIL_TABLE', p_table_a_in);
        
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Create ' || p_table_a_in, p_sql_in => v_crt_table_a_sql);
        
    end priv_create_auxil_table; 
    
    procedure priv_create_stage_table(p_table_s_in varchar2, p_master_table_in varchar2) is
        v_crt_table_s_sql varchar2(32767);
    begin
        v_crt_table_s_sql := 'create table $STAGE_TABLE ( 
                            $BUS_ATTRIBUTES ,
                            constraint C_$STAGE_TABLE_PK primary key ($BUS_KEY)
                            )';
        
        v_crt_table_s_sql := replace(v_crt_table_s_sql, '$STAGE_TABLE', p_table_s_in);
        v_crt_table_s_sql := replace(v_crt_table_s_sql, '$BUS_ATTRIBUTES', priv_get_bus_col_definitions(p_master_table_in));
        v_crt_table_s_sql := replace(v_crt_table_s_sql, '$BUS_KEY', 
                                            pk_etl.get_master_table_fields(p_table_m_in => p_master_table_in
                                                                            , p_type_in => pk_etl.g_business_key_cons));
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Create ' || p_table_s_in, p_sql_in => v_crt_table_s_sql);
        
    end priv_create_stage_table; 

    procedure deploy_master_table (p_master_table_in varchar2) is
        v_master_exists pls_integer := 0;
        v_auxil_table master_tables.auxillary_table%type;
        v_stage_table master_tables.staging_table%type;
        e_modified_col_part_of_bus_key exception;
        v_lockname varchar2(128) := 'deploy_' || p_master_table_in;
        pragma exception_init(e_modified_col_part_of_bus_key, -20001);
    begin
        pk_util_log.open_next_level(p_action_name_in => 'Deploying ' || p_master_table_in);
        
        pk_util_lock.acquire(p_lock_name_in => v_lockname);
        
        select t.auxillary_table, t.staging_table into v_auxil_table, v_stage_table 
        from master_tables t where t.master_table = p_master_table_in;
        
        --Check if table exists
        select count(*) into v_master_exists
        from user_tables t
        where t.TABLE_NAME = p_master_table_in;
        
        if v_master_exists > 0 then
            for rec in (with oracle_dict as (
                        select
                            t.COLUMN_NAME
                            , t.DATA_TYPE || 
                                case t.DATA_TYPE
                                    when 'NUMBER' then replace('(' || t.DATA_PRECISION || ',' || t.DATA_SCALE || ')', '(,)')
                                    when 'VARCHAR2' then '(' || t.DATA_LENGTH || ')'
                                end ||
                                case when t.NULLABLE = 'N' then ' NOT NULL' end as column_type,
                            t.NULLABLE
                        from user_tab_columns t
                        where t.TABLE_NAME = p_master_table_in
                            and t.COLUMN_NAME not like 'X@_%' escape '@'
                    ),
                    our_model as (
                        select *
                        from master_tables_attributes mta
                        where mta.master_table = p_master_table_in 
                    )
                    select oracle_dict.column_name as oracle_dict_column_name
                        , our_model.attribute_name as our_model_attribute_name
                        , oracle_dict.column_type as oracle_dict_column_type
                        , case when oracle_dict.nullable = 'N' then replace(our_model.attribute_type, 'NOT NULL') 
                                else our_model.attribute_type end as our_model_attribute_type
                    from oracle_dict full join our_model on oracle_dict.COLUMN_NAME = our_model.attribute_name
                    where oracle_dict.COLUMN_NAME is null
                        or our_model.attribute_name is null
                        or oracle_dict.column_type <> our_model.attribute_type) loop
               
                if (rec.our_model_attribute_name is null) then
                    pk_util_log.log_and_execute_ddl(p_action_name_in => 'Drop column ' || rec.oracle_dict_column_name || ' in ' || p_master_table_in , 
                                            p_sql_in => 'alter table ' || p_master_table_in || ' drop column ' || rec.oracle_dict_column_name );
                    pk_util_log.log_and_execute_ddl(p_action_name_in => 'Drop column ' || rec.oracle_dict_column_name || ' in ' || v_auxil_table,
                                                p_sql_in => 'alter table ' || v_auxil_table || ' drop column ' || rec.oracle_dict_column_name );
                end if;
                
                if (rec.oracle_dict_column_name is null) then
                    pk_util_log.log_and_execute_ddl(p_action_name_in => 'Add column ' || rec.our_model_attribute_name 
                                                                            || ' in table ' || p_master_table_in,
                                                p_sql_in => 'alter table ' || p_master_table_in || ' add ' || rec.our_model_attribute_name 
                                                || ' ' || rec.our_model_attribute_type );
                    pk_util_log.log_and_execute_ddl(p_action_name_in => 'Add column ' || rec.our_model_attribute_name 
                                                                            || ' in table ' || v_auxil_table
                                                , p_sql_in => 'alter table ' || v_auxil_table || ' add ' || rec.our_model_attribute_name 
                                                    || ' ' || rec.our_model_attribute_type );
                end if;
                
                if (rec.our_model_attribute_name is not null and rec.oracle_dict_column_name is not null) then
                    pk_util_log.log_and_execute_ddl(p_action_name_in => 'Modify column ' || rec.our_model_attribute_name 
                                                                            || ' in table ' || p_master_table_in
                                                    , p_sql_in => 'alter table ' || p_master_table_in || ' modify ' || rec.our_model_attribute_name 
                                                            || ' ' || rec.our_model_attribute_type );
                    pk_util_log.log_and_execute_ddl(p_action_name_in => 'Modify column ' || rec.our_model_attribute_name 
                                                                            || ' in table ' || v_auxil_table
                                                    , p_sql_in => 'alter table ' || v_auxil_table || ' modify ' || rec.our_model_attribute_name 
                                                            || ' ' || rec.our_model_attribute_type );
                end if;
                
            end loop;
        else
            priv_create_master_table(p_master_table_in);   
            priv_create_auxil_table(p_table_a_in => v_auxil_table, p_master_table_in => p_master_table_in);
            priv_create_stage_table(p_table_s_in => v_stage_table, p_master_table_in => p_master_table_in);                             
        end if;
        
        pk_util_lock.release(v_lockname);
        
        pk_util_log.close_level_success;
    exception
    	when others then
    		pk_util_log.close_level_fail;
    		raise;
    end deploy_master_table;
    
    procedure deploy_all_master_tables is
    begin
        pk_util_log.start_logging(p_log_instance_name_in => 'deploy_all_master_tables');
        for i in (select * from master_tables) loop
            deploy_master_table(p_master_table_in => i.master_table);
        end loop; 
        pk_util_log.stop_log_success;
    exception
    	when others then
    		pk_util_log.stop_log_fail;
    		raise;
    end ; 
       
END pk_deploy;
/
