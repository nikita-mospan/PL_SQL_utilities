CREATE OR REPLACE PACKAGE pk_util_parallel_execute AUTHID CURRENT_USER AS
    
    e_task_failed exception;
    g_task_failed_err_code constant number := -20001;
    pragma exception_init(e_task_failed, -20001);
    
    e_task_failed_due_timeout exception;
    g_task_failed_due_timeout_code constant number := -20002;
    pragma exception_init(e_task_failed_due_timeout, -20002);
        
    g_new_line constant varchar2(2) := chr(13) || chr(10);
    g_status_new constant varchar2(1) := 'N';
    g_status_completed constant varchar2(1) := 'C';
    g_status_failed constant varchar2(1) := 'F';
    g_status_running constant varchar2(1) := 'R';
    g_exec_chunk_success_status constant user_parallel_execute_chunks.status%type := 'PROCESSED';
    g_no_timeout constant pls_integer := 0;
    g_wait_timeout_sleep_secs constant pls_integer := 3;

	function create_task (p_task_prefix_in in varchar2
                        , p_comments_in in parallel_tasks.comments%type
                        , p_parallel_level_in in parallel_tasks.parallel_level%type
                        , p_timeout_seconds_in in parallel_tasks.timeout_seconds%type default g_no_timeout) return varchar2;
    
    function add_item_to_task (p_task_name_in in parallel_tasks.task_name%type
                            , p_plsql_block_in in parallel_task_items.plsql_block%type) return number;
    
    procedure execute_task (p_task_name_in in varchar2);    
                            
   
END pk_util_parallel_execute;
/
