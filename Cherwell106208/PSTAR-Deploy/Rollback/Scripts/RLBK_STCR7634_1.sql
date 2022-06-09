-----------------------------------------------------------------------------------------
-- Filename = RLBK_STCR7634_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Jan 22nd 2021                                                                 --
-----------------------------------------------------------------------------------------
-- This script rolls back 1 minutes delay to start of SAP interface to STAR for Standby DB
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool RLBK_STCR7634_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> This rolls back 1 minutes delay to start of SAP interface to STAR for Standby DB
PROMPT >>
PROMPT >> Log file = RLBK_STCR7634_1_output.txt 
PROMPT >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Restore Package Body PK_STAR_WEBSERVICES                             >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@RLBK_PK_STAR_WEBSERVICES.pkb
  
PROMPT >> End of STCR7634_Rollback Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off