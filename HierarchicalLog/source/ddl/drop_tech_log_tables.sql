--drop package
declare
    e_package_does_not_exist exception;
    pragma exception_init(e_package_does_not_exist, -4043); 
    v_package_name varchar2(30) := 'PK_UTIL_LOG';
begin
    execute immediate 'drop package ' || v_package_name;
exception
	when e_package_does_not_exist then
        dbms_output.put_line('Ignore exception: package ' || v_package_name || ' does not exist!'); 
end;
/

--drop public synonyms
declare
    procedure drop_publ_synonym_if_exists (p_public_synonym_in varchar2) is
        e_public_synonym_not_exist exception;
        pragma exception_init(e_public_synonym_not_exist, -1432);
    begin
        execute immediate 'drop public synonym ' || p_public_synonym_in;
    exception
    	when e_public_synonym_not_exist then
    		dbms_output.put_line('Ignore exception: synonym ' || upper(p_public_synonym_in) || ' to be dropped does not exist.'); 
    end;
     
begin
    drop_publ_synonym_if_exists(p_public_synonym_in => 'tech_log_table');
    drop_publ_synonym_if_exists(p_public_synonym_in => 'tech_log_instances');
    drop_publ_synonym_if_exists(p_public_synonym_in => 'tech_log_table_seq');
    drop_publ_synonym_if_exists(p_public_synonym_in => 'pk_util_log');
end;
/

--drop sequence
declare
    e_sequence_does_not_exist exception;
    pragma exception_init(e_sequence_does_not_exist, -2289); 
    v_sequence_name varchar2(30) := 'SEQ_LOG_TABLE';
begin
    execute immediate 'drop sequence ' || v_sequence_name ;
exception
	when e_sequence_does_not_exist then
		dbms_output.put_line('Ignore exception: sequence ' || v_sequence_name || ' does not exist.'); 
end;
/

--drop tables
declare 
    procedure drop_table_if_exists(p_table_name_in varchar2) is 
        e_table_does_not_exist exception;
        pragma exception_init(e_table_does_not_exist, -942);
    begin
        execute immediate 'drop table ' || p_table_name_in;
    exception
        when e_table_does_not_exist then
            dbms_output.put_line('Ignore exception: table ' || p_table_name_in || ' does not exist.'); 
    end;
begin
    drop_table_if_exists(p_table_name_in =>  'LOG_TABLE');   
    drop_table_if_exists(p_table_name_in => 'LOG_INSTANCES');
end;
/
