-----------------------------------------------------------------------------------------
-- Filename = IMPL_STCR7663_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Nov 10 2021                                                                   --
-----------------------------------------------------------------------------------------
-- Update View TE_TEST_RESULTS_UNITED_MILL_VIEW to include site 23 (Witton)            --
-----------------------------------------------------------------------------------------
set serveroutput on
set define on

--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool IMPL_STCR7663_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;

PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> Update Package PK_MELT add new function fnGetMeltSite
PROMPT >> Update View TE_TEST_RESULTS_UNITED_MILL_VIEW to include site 23 (Witton) 
PROMPT >>
PROMPT >> Log file = IMPL_STCR7663_1_output.txt 
PROMPT >>

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Compile Package Body PK_MELT includes new function                              >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set define OFF
@PK_MELT.pks
@PK_MELT.pkb

set define ON
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #2                                                             >>         
PROMPT >> Update View TE_TEST_RESULTS_UNITED_MILL_VIEW to include site 23     >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
create or replace view TE_TEST_RESULTS_UNITED_MILL_VIEW as
select heat_num,
       pk_melt.fnGetMeltSite(heat_num) melt_site,
       test_code,
       pk_test_result_rounding.fn_e29_rounding ( p_no_of_decimals => 4,
                                                 p_rnd_result     => AVG(act_result)  ) AVG_RESULT
 from (SELECT 
         ttsi.cast_no heat_num,
         ttr.test_code,
         ttr.act_result
    FROM te_test_sample_id ttsi,
         te_test_results ttr,
         te_spec_code_header tsch
   WHERE ttr.sample_id = ttsi.sample_id         -- Link TE_TEST_RESULTS to TE_TEST_SAMPLE_ID
     AND ttsi.test_type = 'A'                   -- Only select Test Type A which is done at Melt Sites
     AND ttsi.sample_id_copied_from is null     -- Exclude if copied from another sample
     AND ttsi.sign_off_status = 'A'             -- Signed off samples only
     AND ttr.rec_status = 'A'                   -- Select Active Test Results Only, 
     AND ttr.material_release_yn = 'Y'          -- Material Released
     AND pk_test_results.fn_is_number_yn(ttr.act_result) = 'Y'-- BYPASS if not valid Numeric Value
     AND tsch.spec_code_id = ttsi.spec_code_id  -- Link TE_SPEC_CODE_HEADER to TE_TEST_SAMPLE_ID
     AND tsch.site in ('13','20','23')          --Limit to Spec Codes from Morgantown,Henderson and Witton
     ) QUERY1
   GROUP BY heat_num,
       test_code
  order by QUERY1.heat_num, QUERY1.test_code;


PROMPT >> End of STCR7663_implement Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off