CREATE OR REPLACE PACKAGE BODY pk_util_lock AS
	
    function priv_get_lock_handle (p_lock_name_in varchar2) return varchar2 is
        PRAGMA AUTONOMOUS_TRANSACTION; 
        v_lock_handle varchar2(128);
    begin
        dbms_lock.allocate_unique(lockname => p_lock_name_in, lockhandle => v_lock_handle);
        return v_lock_handle;
    end; 

    procedure acquire(p_lock_name_in varchar2
                    , p_timeout_sec_in pls_integer default 0) is
        v_lock_request_return pls_integer;
        v_lock_handle varchar2(128);
        PRAGMA AUTONOMOUS_TRANSACTION;        
    begin
        pk_util_log.open_next_level(p_action_name_in => 'pk_util_lock.acquire'
                                , p_comments_in => 'p_lock_name_in: ' || p_lock_name_in || pk_constants.eol ||
                                                    'p_timeout_sec_in: ' || to_char(p_timeout_sec_in));
        
        v_lock_handle := priv_get_lock_handle(p_lock_name_in);
        
        v_lock_request_return := dbms_lock.request(lockhandle => v_lock_handle
                                                , lockmode => dbms_lock.x_mode
                                                , timeout => p_timeout_sec_in
                                                , release_on_commit => false);
        
        case v_lock_request_return
            when 1 then raise_application_error(-20001, 'Lock timeout (dbms_lock.request returned 1)', TRUE); 
            when 2 then raise_application_error(-20002, 'Deadlock (dbms_lock.request returned 2)', TRUE);
            when 3 then raise_application_error(-20003, 'Parameter error (dbms_lock.request returned 3)', TRUE);
            when 5 then raise_application_error(-20005, 'Illegal lockhandle (dbms_lock.request returned 5)', TRUE);
            else null;
        end case;
                       
        commit;
        
        pk_util_log.close_level_success;
    exception
    	when others then
    		pk_util_log.close_level_fail;
    		raise;
    end; 
    
    procedure release(p_lock_name_in varchar2) is
        v_lock_handle varchar2(128);
        v_lock_release_return pls_integer;
        PRAGMA AUTONOMOUS_TRANSACTION; 
    begin
        pk_util_log.open_next_level(p_action_name_in => 'pk_util_lock.release'
                                    , p_comments_in => 'p_lock_name_in: ' || p_lock_name_in);
        
        v_lock_handle := priv_get_lock_handle(p_lock_name_in);
        
        v_lock_release_return := dbms_lock.release(lockhandle => v_lock_handle);
        
        case v_lock_release_return
            when 3 then raise_application_error(-20003, 'Parameter error (dbms_lock.release returned 3)', TRUE);
            when 4 then raise_application_error(-20004, 'Lock handle not owned (dbms_lock.release returned 4)', TRUE);
            when 5 then raise_application_error(-20005, 'Illegal lockhandle (dbms_lock.release returned 5)', TRUE);
            else null;
        end case;
        
        commit;   
        
        pk_util_log.close_level_success;
    exception
    	when others then
    		pk_util_log.close_level_fail;
    		raise;
    end; 
	
       
END pk_util_lock;
/
