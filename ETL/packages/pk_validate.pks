CREATE OR REPLACE PACKAGE pk_validate AUTHID CURRENT_USER AS
   
	procedure do_validate (p_validated_table_in varchar2
                            ,p_val_error_table_s_in varchar2
                            ,p_val_error_table_m_in varchar2
                            ,p_val_error_mapping_name_in varchar2
                            ,p_x_vstart_in timestamp);
                        	
   
END pk_validate;
/
