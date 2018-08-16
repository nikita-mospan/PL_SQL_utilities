CREATE OR REPLACE PACKAGE pk_etl AUTHID CURRENT_USER AS
    
    c_x_vend constant timestamp := to_timestamp('31.12.9999', 'dd.mm.yyyy');
    c_x_vend_partition constant varchar2(30) := 'p_' || to_char(c_x_vend, 'YYYYmmDDhh24MIssFF');
    
	function make_md5_hash(p_src_str_in IN varchar2) 
        return varchar2
        deterministic
        parallel_enable ;	
    
    function prepare_timestamp_replace (p_timestamp_in IN timestamp) 
        return varchar2
        deterministic;
        
    procedure load_entity(p_entity_in IN varchar2,
                        p_x_vstart_in IN timestamp);
   
END pk_etl;
/
