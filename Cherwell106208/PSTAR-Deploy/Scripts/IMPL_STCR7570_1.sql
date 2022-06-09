-----------------------------------------------------------------------------------------
-- Filename = IMPL_STCR7570_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Jan 22nd 2021                                                                 --
-----------------------------------------------------------------------------------------
-- This script Expands column TEST_NUMBER in NS_EVENTS_LINES from 6 to 40 Characters   --
-----------------------------------------------------------------------------------------
-- Comment line added for demonstrating updating a file in a GitHub Repository Jim Slanker
-- created Thursday June 9th 2022                                                      --
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool IMPL_STCR7570_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> This script Expands column TEST_NUMBER in NS_EVENTS_LINES from 6 to 40 Characters 
PROMPT >>
PROMPT >> Log file = IMPL_STCR7570_1_output.txt 
PROMPT >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Alter table NS_EVENT_LINES                                          >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@NS_EVENT_LINES_tabAlter.sql
  



PROMPT >> End of STCR7570_implement Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off