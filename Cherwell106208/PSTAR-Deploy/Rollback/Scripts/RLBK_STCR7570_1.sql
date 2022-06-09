-----------------------------------------------------------------------------------------
-- Filename = RLBK_STCR7570_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Jan 22nd 2021                                                                 --
-----------------------------------------------------------------------------------------
-- This script Restores column TEST_NUMBER in NS_EVENTS_LINES to 6 from 40 Characters  --
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool RLBK_STCR7570_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> This script Restores column TEST_NUMBER in NS_EVENTS_LINES to 6 from 40 Characters 
PROMPT >>
PROMPT >> Log file = RLBK_STCR7570_1_output.txt 
PROMPT >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Restore table NS_EVENT_LINES column TEST_NUMBER back to 6 chars     >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ALTER table  STAR.NS_EVENT_LINES
 MODIFY TEST_NUMBER   VARCHAR2(6);
  



PROMPT >> End of STCR7570_Rollback Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off