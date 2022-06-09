-----------------------------------------------------------------------------------------
-- Filename = IMPL_STCR7563_1.sql                                                      --
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
spool IMPL_STCR7563_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> Correct issue with Toronto Batch Tracking Extracts from not running
PROMPT >> Also includes a new procedure to extract order requirements for site 23   
PROMPT >>
PROMPT >> Log file = IMPL_STCR7563_1_output.txt 
PROMPT >>

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Compile Package Spec and Body PK_TPT_EXTRACT update the running     >>
PROMPT >> flag to N for Toronto Site 11                                       >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set define off
@PK_TPT_EXTRACT.pks
@PK_TPT_EXTRACT.pkb

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #2                                                             >>         
PROMPT >> Update the Batch Tracking Update Control table to set Site 11       >>
PROMPT >> Running flag to N   STCR 7563                                       >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UPDATE ex_tpt_control
    set JOB_RUNNING_YN = 'N'
    where site = '11'
      and job_id = 3;
COMMIT;

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #3                                                             >>         
PROMPT >> Insert into the Batch Tracking Update Control table for site 23     >>
PROMPT >> Order Requirement extract    STCR 7563                              >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INSERT INTO EX_TPT_CONTROL (JOB_ID,
                            JOB_NAME,
                            SITE,
                            LAST_RUN_DATE,
                            JOB_RUNNING_YN)
     VALUES (5,
             'Live Order Requirement',
             '23',
             SYSDATE,
             'N');
COMMIT;

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #4                                                             >>         
PROMPT >> Submit new DBMS Job for processing Site 23 Order Requirements       >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DECLARE
  X NUMBER;
BEGIN
  SYS.DBMS_JOB.SUBMIT
  ( job       => X 
   ,what      => 'STAR.PK_TPT_EXTRACT.PRGETORDERREQUIREMENT23;'
   ,next_date => to_date('12/12/2021 06:00:00','dd/mm/yyyy hh24:mi:ss')
   ,interval  => 'TRUNC(SYSDATE+1)+6/24'
   ,no_parse  => FALSE
  );
  SYS.DBMS_OUTPUT.PUT_LINE('Job Number is: ' || to_char(x));
COMMIT;
END;
/


PROMPT >> End of STCR7563_implement Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off