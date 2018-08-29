CREATE OR REPLACE PACKAGE pk_deploy AUTHID CURRENT_USER AS
   
	procedure deploy_master_table (p_master_table_in varchar2);	
   
END pk_deploy;
/
