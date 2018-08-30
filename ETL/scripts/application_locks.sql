drop table application_locks;

create table application_locks (
    lock_name varchar2(128)
    , timeout_sec number
    , sid  number
    , constraint c_application_locks_pk primary key (lock_name)
);