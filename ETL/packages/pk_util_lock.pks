CREATE OR REPLACE PACKAGE pk_util_lock AUTHID CURRENT_USER AS
    
    e_timeout exception;
    e_deadlock exception;
    e_parameter_error exception;
    e_lock_handle_is_not_owned exception;
    e_illegal_lockhandle exception;
    
    pragma exception_init(e_timeout, -20001);
    pragma exception_init(e_deadlock, -20002);
    pragma exception_init(e_parameter_error, -20003);
    pragma exception_init(e_lock_handle_is_not_owned, -20004);
    pragma exception_init(e_timeout, -20005);

	procedure acquire(p_lock_name_in varchar2
                    , p_timeout_sec_in pls_integer default 0);
    
    procedure release(p_lock_name_in varchar2);
	
   
END pk_util_lock;
/
