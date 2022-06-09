-----------------------------------------------------------------------------------------
-- Filename = RLBK_STCR7632_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Jan 22nd 2021                                                                 --
-----------------------------------------------------------------------------------------
-- This script Resolves issue with Upload SAP Schedule Adherence Report                --  
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool RLBK_STCR7632_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> This script Resolves issue with Upload SAP Schedule Adherence Report 
PROMPT >>
PROMPT >> Log file = RLBK_STCR7632_1_output.txt 
PROMPT >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Restore Trigger RSAIMP_BIUD_R to current version                    >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@RLBK_rsaimp_biud_r.trg
  

PROMPT >> End of STCR7632 Roll Back Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off