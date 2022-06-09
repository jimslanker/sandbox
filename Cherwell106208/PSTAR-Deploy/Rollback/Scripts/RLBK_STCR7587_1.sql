-----------------------------------------------------------------------------------------
-- Filename = RLBK_STCR7587_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Jan 22nd 2021                                                                 --
-----------------------------------------------------------------------------------------
-- This script Rolls Back new DISPOSTION_DATE in the Non Standard Events               --  
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool RLBK_STCR7587_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> This script Rolls Back new DISPOSTION_DATE in the Non Standard Events
PROMPT >>
PROMPT >> Log file = RLBK_STCR7587_1_output.txt 
PROMPT >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Alter Table NS_PIECE_DISPOSITIONS remove disposition_date column    >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ALTER table  STAR.NS_PIECE_DISPOSITIONS
 DROP COLUMN DISPOSITION_DATE;
 
  
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #2                                                             >>
PROMPT >> Restore Trigger NSPCDI_BI_CR                                         >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@RLBK_NSPCDI_BI_CR.trg

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #3                                                            >>
PROMPT >> Restore Trigger NSPCDI_BUD_R                                         >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@RLBK_NSPCDI_BUD_R.trg

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #4                                                             >>
PROMPT >> Restore View NS_PIECE_DISPOSITIONS_VW                                >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@RLBK_NS_PIECE_DISPOSITIONS_VW.sql

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #5                                                             >>
PROMPT >> RESTORE View NS_PIECE_DISPOSITIONS_BIVW                              >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@RLBK_NS_PIECE_DISPOSITIONS_BIVW.vw

PROMPT >> End of STCR7587_Rollback Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off