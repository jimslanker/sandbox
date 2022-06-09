-----------------------------------------------------------------------------------------
-- Filename = RLBK_STCR7563_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Dec 13th 2021                                                                 --
-----------------------------------------------------------------------------------------
-- Correct issue with Toronto Batch Tracking Extracts from not running                 --
-- Also includes a new procedure to extract order requirements for site 23  <STCR7563> --
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool RLBK_STCR7563_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> Restore Package PK_TPT_EXTRACT to previos version
PROMPT >>
PROMPT >> Log file = RLBK_STCR7563_1_output.txt 
PROMPT >>

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Compile Package Spec and Body PK_TPT_EXTRACT to previous version    >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set define off
@PK_TPT_EXTRACT_RLBK.pks
@PK_TPT_EXTRACT_RLBK.pkb

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #2                                                             >>         
PROMPT >> Delete the Batch Tracking Update Control table for site 23          >>
PROMPT >> Order Requirement extract    STCR 7563                              >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DELETE from EX_TPT_CONTROL 
   where JOB_ID = 5;
COMMIT;



PROMPT >> End of STCR7563 Rollback Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off