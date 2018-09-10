CREATE OR REPLACE PACKAGE BODY pk_validate AS

	procedure do_validate (p_validated_table_in varchar2
                            ,p_val_error_table_m_in varchar2
                            ,p_x_vstart_in timestamp) is
        v_ins_into_val_error_sql varchar2(32767);
        v_at_least_one_rule_found boolean default false;
        v_ins_rule_violation_templ varchar2(32767) ;
        v_ins_cur_rule_violation varchar2(32767);
        v_ins_all_rule_violations varchar2(32767);
        v_rule_check_templ varchar2(32767) := 'case when $VALIDATION_CHECK then null else 1 end $RULE_CODE, ';
        v_cur_rule_check varchar2(32767);
        v_all_rule_checks varchar2(32767);
        v_row_cnt pls_integer;
        v_val_error_table_s_in master_tables.staging_table%type;
    begin
        pk_util_log.open_next_level(p_action_name_in => 'do_validate'
                                , p_comments_in => 'Validated table: ' || p_validated_table_in);
        
        select t.staging_table into v_val_error_table_s_in from master_tables t where t.master_table = p_val_error_table_m_in;
        
        v_ins_rule_violation_templ := ' when ($RULE_CODE is not null) then into ' || v_val_error_table_s_in ||
                                                q'{(rule_code, source_x_business_hkey, source_x_vstart)
                                                values ('$RULE_CODE', x_business_hkey, x_vstart) }';
        
        pk_util_log.log_and_execute_ddl(p_action_name_in => 'Truncate ' || v_val_error_table_s_in
                                        , p_sql_in => 'truncate table ' || v_val_error_table_s_in);
        
        v_ins_into_val_error_sql := q'{insert /*+ append */ 
                                    all $INS_RULE_VIOLATIONS
                                    select $RULE_CHECKS
                                        x_business_hkey,
                                        x_vstart
                                    from $VALIDATED_TABLE }';
        
        for rule_rec in (select *
                         from VALID_RULES_CONFIG_M t
                            where t.x_vend = pk_constants.c_x_vend
                                and t.validated_table = p_validated_table_in) loop        
            v_at_least_one_rule_found := true;
            
            v_ins_cur_rule_violation := v_ins_rule_violation_templ;
            v_ins_cur_rule_violation := replace(v_ins_cur_rule_violation, '$RULE_CODE', rule_rec.rule_code);
            v_ins_all_rule_violations := v_ins_all_rule_violations || v_ins_cur_rule_violation;
            
            v_cur_rule_check := v_rule_check_templ;
            v_cur_rule_check := replace(v_cur_rule_check, '$VALIDATION_CHECK', rule_rec.validation_check);
            v_cur_rule_check := replace(v_cur_rule_check, '$RULE_CODE', rule_rec.rule_code);
            v_all_rule_checks := v_all_rule_checks || v_cur_rule_check;          
            
        end loop;
        
        if not v_at_least_one_rule_found then
            pk_util_log.log_record(p_action_name_in => 'No rules found. Validation is skipped'
                                , p_status_in => pk_util_log.g_status_completed);
        else
        
            v_ins_into_val_error_sql := replace(v_ins_into_val_error_sql, '$INS_RULE_VIOLATIONS', v_ins_all_rule_violations);
            v_ins_into_val_error_sql := replace(v_ins_into_val_error_sql, '$RULE_CHECKS', v_all_rule_checks); 
            v_ins_into_val_error_sql := replace(v_ins_into_val_error_sql, '$VALIDATED_TABLE', p_validated_table_in || ' partition (' 
                                                                                            || pk_constants.c_x_vend_partition || ')'); 
            
            pk_util_log.log_and_execute_dml(p_action_name_in => 'Populate ' || v_val_error_table_s_in, 
                                        p_sql_in => v_ins_into_val_error_sql, 
                                        p_rowcount_out => v_row_cnt, 
                                        p_commit_after_dml_in => true);
            
            pk_etl.load_master_table(p_master_table_in => p_val_error_table_m_in, 
                            p_x_vstart_in => p_x_vstart_in);
        end if;
        
        pk_util_log.close_level_success;
    exception
    	when others then
    		pk_util_log.close_level_fail;
    		raise;
    end do_validate; 
      
END pk_validate;
/
