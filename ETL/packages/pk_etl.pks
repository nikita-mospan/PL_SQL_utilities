CREATE OR REPLACE PACKAGE pk_etl AUTHID CURRENT_USER AS
    
    g_business_fields_cons constant varchar2(100) := 'BUSINESS_FIELDS';
    g_tech_fields_cons constant varchar2(100) := 'TECH_FIELDS';
    g_business_hash_key_cons constant varchar2(100) := 'BUSINESS_HASH_KEY';
    g_business_key_cons constant varchar2(100) := 'BUSINESS_KEY';
    g_delta_hash_key_cons constant varchar2(100) := 'DELTA_HASH_KEY';
    
	function make_md5_hash(p_src_str_in IN varchar2) 
        return varchar2
        deterministic
        parallel_enable ;	
    
    function prepare_timestamp_replace (p_timestamp_in IN timestamp) 
        return varchar2
        deterministic;
    
    procedure load_to_staging_table(p_staging_table_in in master_tables.staging_table%type,
                                    p_mapping_name_in in mappings2etl_stage.mapping_name%type,
                                    p_truncate_before_load_in boolean default true);
        
    procedure load_master_table(p_master_table_in IN master_tables.master_table%type,
                                p_x_vstart_in IN timestamp,
                                p_close_version_column_in IN varchar2 default null,
                                p_close_version_value_in IN varchar2 default null);
    
    function get_master_table_fields (p_table_m_in IN varchar2
                                , p_type_in in varchar2
                                , p_alias_in in varchar2 default null) return varchar2 result_cache;
   
END pk_etl;
/
