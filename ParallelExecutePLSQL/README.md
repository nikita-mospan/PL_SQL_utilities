# ParallelExecutePLSQL
> The project contains source code to run PL/SQL units (procedures, functions, packages) in parallel

The project's package "pk_util_parallel_execute" allows to run your PL/SQL units (anonymous blocks, functions, procedures) in parallel. The idea is to utilize functionality of dbms_parallel_execute package and add timeout functionality support. 

## Installing / Uninstalling

0. Source code can be installed into your existing schema. This schema must have grants "CREATE PROCEDURE", "CREATE TABLE", "CREATE TABLE", "CREATE SEQUENCE", "CREATE PUBLIC SYNONYM", "CREATE JOB", "EXECUTE on DBMS_LOCK", "MANAGE SCHEDULER". In this case you can skip point 1 (creation of technical user).
1. The preferrable way is to create separate schema (I call it TECH_USER). Open your command line, go to the PL_SQL_utilities/sys_scripts. Then connect to your database under SYS schema via sqlplus and run "@create_tech_user.sql".
```shell
SYS@ora12c> @create_tech_user.sql
```
2. Created TECH_USER has default password "tech_user". You might consider changing it.
3. Go to PL_SQL_utilities/ParallelExecutePLSQL directory of the project. Then connect to your database under TECH_USER or your own schema (see point 0). Run "@install.sql"
```shell
TECH_USER@ora12c> @install.sql
```
4. To uninstall (drop pk_util_package and logging tables) go to PL_SQL_utilities/ParallelExecutePLSQL directory of the project. Then connect to your database under TECH_USER or your own schema (see point 0). Run "@uninstall.sql"
```shell
TECH_USER@ora12c> @uninstall.sql
```

##Examples

You can test installation success by running examples from PL_SQL_utilities/ParallelExecutePLSQL/examples/test_parallel_execute.sql

## Features

* Support of desired parallel degree
* Support of timeout

## Configuration

You should explicitly grant execute on "pk_util_parallel_execute" package to the schema in which you want to use it. You should also grant SELECT privilege on "tech_parallel_tasks" and "tech_parallel_task_items" tables.

