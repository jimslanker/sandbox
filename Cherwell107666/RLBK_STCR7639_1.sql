-----------------------------------------------------------------------------------------
-- Filename = RLBK_STCR7639_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Dec 13th 2021                                                                 --
-----------------------------------------------------------------------------------------
-- Rollback changes from STCR7639 - Restore Global Temp Table, Restore Package         --
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool RLBK_STCR7639_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> Rollback changes from STCR7639 - Restore Global Temp Table, Restore Package 
PROMPT >>
PROMPT >> Log file = RLBK_STCR7639_1_output.txt 
PROMPT >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Drop  Globl Temp Table GTT_TE_TEST_RESULTS                          >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DROP TABLE STAR.GTT_TE_TEST_RESULTS CASCADE CONSTRAINTS;
 
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #2                                                             >>         
PROMPT >> Create Global Temp Table GTT_TE_TEST_RESULTS with option to Preserve>>
PROMPT >> rows on COMMIT instead of DELETING                                  >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE GLOBAL TEMPORARY TABLE STAR.GTT_TE_TEST_RESULTS
(
  BATCH_NO            VARCHAR2(13 BYTE),
  CAST_NO             VARCHAR2(13 BYTE),
  SAMPLE_TYPE         VARCHAR2(2 BYTE),
  SAMPLE_ID           NUMBER,
  PIECE_ID            VARCHAR2(20 BYTE),
  HT_CODE             VARCHAR2(10 BYTE),
  ALLOY               VARCHAR2(10 BYTE),
  TEST_TYPE           VARCHAR2(10 BYTE),
  TEST_CODE           VARCHAR2(10 BYTE),
  TEST_NUMBER         VARCHAR2(15 BYTE),
  ACT_RESULT          VARCHAR2(10 BYTE),
  ACT_RESULT_OP       VARCHAR2(1 BYTE),
  MIN_LIMIT           NUMBER,
  MIN_LIMIT_SPEC      VARCHAR2(50 BYTE),
  MAX_LIMIT           NUMBER,
  MAX_LIMIT_SPEC      VARCHAR2(50 BYTE),
  FAILURE_TYPE        VARCHAR2(1 BYTE),
  EVENT_ID            NUMBER,
  EMAIL_TYPE          VARCHAR2(20 BYTE),
  SPEC_CODE_ID        NUMBER,
  SPEC_NAME           VARCHAR2(50 BYTE),
  MULTI_SPEC_CODE_ID  NUMBER,
  SITE                VARCHAR2(2 BYTE),
  SALES_ORDER         VARCHAR2(40 BYTE),
  SALES_ORDER_ITEM    VARCHAR2(40 BYTE)
)
ON COMMIT DELETE ROWS
RESULT_CACHE (MODE DEFAULT)
NOCACHE;


PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #3                                                             >>         
PROMPT >> Grant full access to STAR_USER on Table GTT_TE_TEST_RESULTS         >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GRANT ALTER, DELETE, INSERT, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON STAR.GTT_TE_TEST_RESULTS TO STAR_USER;

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #4                                                             >>         
PROMPT >> Compile Package Body PK_TEST_RESULTS with change to delete from     >>
PROMPT >> Global Temp Table after processing for outbound emails              >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@PK_TEST_RESULTS_RLBK.pkb

PROMPT >> End of STCR7639 Rollback Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off