--drop package
declare
    e_package_does_not_exist exception;
    pragma exception_init(e_package_does_not_exist, -4043); 
    v_package_name varchar2(30) := 'PK_UTIL_PARALLEL_EXECUTE';
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
    drop_publ_synonym_if_exists(p_public_synonym_in => 'tech_parallel_tasks');
    drop_publ_synonym_if_exists(p_public_synonym_in => 'tech_parallel_task_items');
    drop_publ_synonym_if_exists(p_public_synonym_in => 'tech_parallel_tasks_stats_v');
    drop_publ_synonym_if_exists(p_public_synonym_in => 'tech_seq_parallel_item_id');
    drop_publ_synonym_if_exists(p_public_synonym_in => 'pk_util_parallel_execute');
end;
/

--drop sequence
declare
    e_sequence_does_not_exist exception;
    pragma exception_init(e_sequence_does_not_exist, -2289); 
    v_sequence_name varchar2(30) := 'SEQ_PARALLEL_ITEM_ID';
begin
    execute immediate 'drop sequence ' || v_sequence_name ;
exception
	when e_sequence_does_not_exist then
		dbms_output.put_line('Ignore exception: sequence ' || v_sequence_name || ' does not exist.'); 
end;
/

--drop tables and views
declare 
    procedure drop_table_veiew_if_exists(p_type_in varchar2, p_name_in varchar2) is 
        e_table_does_not_exist exception;
        pragma exception_init(e_table_does_not_exist, -942);
    begin
        execute immediate 'drop ' || p_type_in || ' ' ||  p_name_in;
    exception
        when e_table_does_not_exist then
            dbms_output.put_line('Ignore exception: table ' || p_name_in || ' does not exist.'); 
    end;
begin
    drop_table_veiew_if_exists(p_type_in => 'table', p_name_in => 'PARALLEL_TASK_ITEMS');
    drop_table_veiew_if_exists(p_type_in => 'table', p_name_in =>  'PARALLEL_TASKS');   
    drop_table_veiew_if_exists(p_type_in => 'view', p_name_in =>  'PARALLEL_TASKS_STATS_V');   
end;
/
