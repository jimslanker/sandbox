-----------------------------------------------------------------------------------------
-- Filename = RLBK_STCR7578_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: March 28th 2022                                                               --
-----------------------------------------------------------------------------------------
-- Restore Package PK_TECH_EDIT to previous version                                    --
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool RLBK_STCR7578_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> Restore Package PK_TECH_EDIT to previous version
PROMPT >>
PROMPT >> Log file = RLBK_STCR7578_1_output.txt 
PROMPT >>

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Compile Package Body PK_TECH_EDIT restore previous version          >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set define OFF
@PK_TECH_EDIT_RLBK.pkb


set define on
PROMPT >> End of RLBK_STCR7578_1 Rollback Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off