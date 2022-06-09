-----------------------------------------------------------------------------------------
-- Filename = IMPL_STCR7578_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: March 28th 2022                                                               --
-----------------------------------------------------------------------------------------
-- Update Package PK_TECH_EDIT to use rounding to prevent out of spec emails           --
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool IMPL_STCR7578_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> Update Package PK_TECH_EDIT to use rounding to prevent out of spec emails
PROMPT >>
PROMPT >> Log file = IMPL_STCR7578_1_output.txt 
PROMPT >>

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Compile Package Body PK_TECH_EDIT                                   >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set define OFF
@PK_TECH_EDIT.pkb


set define on
PROMPT >> End of IMPL_STCR7578_1 Implementation Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off