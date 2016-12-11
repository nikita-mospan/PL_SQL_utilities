# PL_SQL_hierarchical_log
> The project contains source code to log PL/SQL activity of your project in hierarchical fashion.

The project's package "pk_util_log" allows to log runtimes of your PL/SQL units (anonymous blocks, functions, procedures). The idea is to create logging parent/child hierarchy where parent is calling PL/SQL unit and child is invoked unit. Such approach is helpful in troubleshooting your PL/SQL processes. 

## Installing / Uninstalling

0. Source code (package, sequence and 2 tables) can be installed into your existing schema. This schema must have grants "CREATE PROCEDURE", "CREATE TABLE", "CREATE TABLE", "CREATE SEQUENCE", "CREATE PUBLIC SYNONYM". In this case you can skip point 1 (creation of technical user).
1. The preferrable way is to create separate schema (I call it TECH_USER). Open your command line, go to the PL_SQL_utilities/sys_scripts. Then connect to your database under SYS schema via sqlplus and run "@create_tech_user.sql".
```shell
SYS@ora12c> @create_tech_user.sql
```
2. Created TECH_USER has default password "tech_user". You might consider changing it.
3. Go to PL_SQL_utilities/HierarchicalLog directory of the project. Then connect to your database under TECH_USER or your own schema (see point 0). Run "@install.sql"
```shell
TECH_USER@ora12c> @install.sql
```
4. To uninstall (drop pk_util_package and logging tables) go to PL_SQL_utilities/HierarchicalLog directory of the project. Then connect to your database under TECH_USER or your own schema (see point 0). Run "@uninstall.sql"
```shell
TECH_USER@ora12c> @uninstall.sql
```

##Examples

You can test installation success by running examples from PL_SQL_utilities/HierarchicalLog/examples/test_pk_util_log.sql

## Features

* Log runtimes of PL/SQL units
* Log exception information in case PL/SQL unit fails
* Log number of rows that were affected by DML statement.
* Log schema and session id.

## Configuration

Execute on package "pk_util_log" by default is granted to PUBLIC role, so every schema can use it. Log tables have public synonyms "tech_log_instances" and "tech_log_table" and SELECT on it is granted to PUBLIC role also. The DML against "tech_log_instances" and tech_log_table" must be performed only via "pk_util_log" API.

