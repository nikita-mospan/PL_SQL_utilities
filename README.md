# PL_SQL_hierarchical_log
> The project contains source code to log Oracle PL/SQL activity of your project in hierarchical fashion.

The project's package "pk_util_log" allows to log runtimes of your PL/SQL units (anonymous blocks, functions, procedures). Moreover it provides ability to create parent/child relationship between calling PL/SQL unit and invoked unit. Thus a log hierarchy is created which is helpful in troubleshooting your PL/SQL processes. The code does not use any particular features of Oracle Enterprise Edition and should run fine on both Oracle Standard Edition and Enterprise Edition 11g or higher.

## Installing / Getting started

0. Source code (package, sequence and 2 tables) can be installed into your existing schema. This schema must have grants "CREATE PROCEDURE", "CREATE TABLE", "CREATE TABLE", "CREATE SEQUENCE", "CREATE PUBLIC SYNONYM". In this case you can skip point 1 (creation of technical user).
1. Open your command line, go to the root of the project. Then connect to your database under SYSTEM schema via sqlplus and run "@create_tech_user.sql".
```shell
cd PL_SQL_hierarchical_log
sqlplus system/***@ora12c
SYSTEM@ora12c> @create_tech_user.sql
```
2. Created TECH_USER has default password "tech_user". You might consider changing it.
3. Go to "source" directory of the project. Then connect to your database under TECH_USER or your own schema (see point 0). Run "@deploy.sql"
```shell
cd PL_SQL_hierarchical_log/source
sqlplus tech_user/tech_user@ora12c
TECH_USER@ora12c> @deploy.sql
```

Test successfull installation by doing simple logging example:

```PLSQL
declare
    v_sql varchar2(4000);
    v_dummy pls_integer;
begin
    v_sql := 'select 1 from dual';
    pk_util_log.set_log_name(p_name_in => 'Dummy log');
    pk_util_log.open_next_level(p_comments_in => v_sql);
    execute immediate v_sql into v_dummy;
    pk_util_log.log_record(p_comments_in => 'Just a dummy record', p_status_in => pk_util_log.g_status_completed);
    pk_util_log.close_level(p_status_in => pk_util_log.g_status_completed, p_row_count_in => sql%rowcount);
    dbms_output.put_line('start_log_id: ' || pk_util_log.get_start_log_id);
end;
/
```

```shell
sqlplus scott/scott
SCOTT@ora12c> declare
  2      v_sql varchar2(4000);
  3      v_dummy pls_integer;
  4  begin
  5      v_sql := 'select 1 from dual';
  6      pk_util_log.set_log_name(p_name_in => 'Dummy log');
  7      pk_util_log.open_next_level(p_comments_in => v_sql);
  8      execute immediate v_sql into v_dummy;
  9      pk_util_log.log_record(p_comments_in => 'Just a dummy record', p_status_in => pk_util_log.g_status_completed);
 10      pk_util_log.close_level(p_status_in => pk_util_log.g_status_completed, p_row_count_in => sql%rowcount);
 11      dbms_output.put_line('start_log_id: ' || pk_util_log.get_start_log_id);
 12  end;
 13  /
start_log_id: 8

PL/SQL procedure successfully completed.
```

Use the value printed in output in the following query:

```PLSQL
SELECT    
    l.start_log_id,
	lpad('  ', (level - 1) * 2) || to_char(l.log_id) as log_id,
    l.parent_log_id,
	l.start_ts,
	l.end_ts,
	l.status as status,
    l.name,
	lpad('  ', (level - 1) * 2) || l.comments as comments,
    l.row_count
FROM
	tech_log_table l
START WITH
	l.log_id IN 8
CONNECT BY
	l.parent_log_id = PRIOR l.log_id
ORDER SIBLINGS BY
	l.log_id ASC;
```

The result should be similar to this:

| START_LOG_ID  | LOG_ID | PARENT_LOG_ID | START_TS | END_TS | STATUS | NAME | COMMENTS | ROW_COUNT |
| ------------- | ------------- | ------------- | ------------- | ------------- | ------------- | ------------- | ------------- | ------------- |
| 8  | 8  | | 03-OCT-16 12.09.57.177096 AM | 03-OCT-16 12.09.57.179340 AM | C | Dummy log | Just a dummy record | 1 |
| 8  |   9  | 8 | 03-OCT-16 12.09.57.178061 AM | 03-OCT-16 12.09.57.178721 AM | C | Dummy log |   Just a dummy record | |


## Features

* Logs runtimes of PL/SQL units
* Log table support storage of exception information in case PL/SQL unit fails
* Log table support storage of the number of rows that were affected by DML statement.
* Log table automatically logs username and session id.

## Configuration

The package "pk_util_log" by default is granted to PUBLIC role, so every schema can use it. Log table has public synonym "tech_log_table" and SELECT on it is granted to PUBLIC role also. The DML against "tech_log_table" is performed only via "pk_util_log" API.

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.

## Licensing

This project is licensed under Unlicense license. This license does not require you to take the license with you to your project.
