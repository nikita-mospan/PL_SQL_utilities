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

    procedure deploy_master_table (p_master_table_in varchar2) is
        v_master_exists pls_integer := 0;
        v_auxil_table master_tables.auxillary_table%type;
    begin
        pk_util_log.open_next_level(p_action_name_in => 'Deploying ' || p_master_table_in);
        
        select t.auxillary_table into v_auxil_table from master_tables t where t.master_table = p_master_table_in;
        
        --Check if table exists
        select count(*) into v_master_exists
        from user_tables t
        where t.TABLE_NAME = p_master_table_in;
        
        if v_master_exists > 0 then
            null;
        else
            priv_create_master_table(p_master_table_in);   
            priv_create_auxil_table(p_table_a_in => v_auxil_table, p_master_table_in => p_master_table_in);                             
        end if;
        
        pk_util_log.close_level_success;
    exception
    	when others then
    		pk_util_log.close_level_fail;
    		raise;
    end deploy_master_table;
       
END pk_deploy;
/
