-----------------------------------------------------------------------------------------
-- Filename = IMPL_STCR7623_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Jan 22nd 2021                                                                 --
-----------------------------------------------------------------------------------------
-- This script Creates three new Views for STCR 7623                                                          --  
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool IMPL_STCR7623_2_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> This script reates three new Views for STCR 7623
PROMPT >>
PROMPT >> Log file = IMPL_STCR7623_2_output.txt 
PROMPT >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> New View TD_CPAR_LINKED_ROOT_CAUSES_BIVW                            >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@TD_CPAR_LINKED_ROOT_CAUSES_BIVW.sql
  
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #2                                                             >>
PROMPT >> New View TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW                         >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW.sql

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #3                                                             >>
PROMPT >> New View TD_CPAR_ROOT_CAUSE_CODES_BIVW                              >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@TD_CPAR_ROOT_CAUSE_CODES_BIVW




PROMPT >> End of STCR7623_implement Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off