CREATE OR REPLACE PACKAGE pk_util_parallel_execute AUTHID CURRENT_USER AS
    
    e_task_failed exception;
    g_task_failed_err_code constant number := -20001;
    pragma exception_init(e_task_failed, -20001);

	function create_task (p_task_prefix_in in varchar2
                        , p_comments_in in parallel_tasks.comments%type
                        , p_parallel_level_in in parallel_tasks.parallel_level%type) return varchar2;
    
    function add_item_to_task (p_task_name_in in parallel_tasks.task_name%type
                            , p_plsql_block_in in parallel_task_items.plsql_block%type) return number;
    
    procedure execute_task (p_task_name_in in varchar2);    
                            
   
END pk_util_parallel_execute;
/
