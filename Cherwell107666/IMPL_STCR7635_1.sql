-----------------------------------------------------------------------------------------
-- Filename = IMPL_STCR7635_1.sql                                                      --
-- Author: Jim Slanker                                                                 --
-- Date: Dec 13th 2021                                                                 --
-----------------------------------------------------------------------------------------
-- Creates two new views for test piece tracking / sample status                       --
-----------------------------------------------------------------------------------------
set serveroutput on
set define on


--------------------------------------------------------------------------------
-- Start Commands to Spool Output for logging of script Execution             --
-- spool off command is needed at the end of the script to close the log file --
--------------------------------------------------------------------------------
spool IMPL_STCR7635_1_output.txt
alter session set nls_date_format = 'DD-MON-YYYY HH:MI:SS PM';
select sysdate from dual;
select instance_name, host_name from v$instance;


PROMPT
PROMPT >>---------------------------------------------------------------------<<
PROMPT >>
PROMPT >> Creates two new views for test piece tracking / sample status 
PROMPT >> TE_TEST_PIECES_BIVW
PROMPT >> TE_TEST_PIECE_DETAILS_BIVW
PROMPT >>
PROMPT >> Log file = IMPL_STCR7635_1_output.txt 
PROMPT >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #1                                                             >>         
PROMPT >> Create new View TE_TEST_PIECES_BIVW                                 >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
create or replace view TE_TEST_PIECES_BIVW
as 
select ttrout.site,
       tascst.r3_process_order batch_no,
       r3pord.r3_ingot_ref heat,
       r3pord.process_order_status po_status,
       tascst.r3_sales_order sales_order,
       tascst.r3_sales_order_item item,
       ttrcst.descr conversion_stage,  
       pk_test_piece_tracking.f_display_route_ref(ttrasl.ttrout_id) route_ref,
       ttrasl.spec_sample_freq_descr sample_frequency,
       ttrasl.sample_freq_comments sample_frequency_comments,
       ttolpi.piece_id,
       ttolpi.piece_count,
       ttolpi.test_type,  
       ttolpi.sample_id,
       tta.test_area test_lab, 
       ttrtse.name trav_section,
       ttolpi.sample_comment,
       ttaltt.test_type route_test_type,      
       tascst.sap_process_order,
       tascst.stock_week,
       ttolpi.ttrtse_id                 --To be used to Link TE_TEST_PIECE_DETAILS_BIVW    
 from te_allocated_spec_conv_stages tascst,
      te_test_route_alloc_spec_links ttrasl,
      te_troute_ord_link_pieces ttolpi,
      te_tr_alloc_link_test_types ttaltt,
      te_test_routes ttrout,
      r3_process_orders r3pord,
      te_test_route_conv_stages ttrcst,
      te_test_areas tta,
      te_test_route_traveler_sects ttrtse 
 where tascst.rec_status = 'A'
   and ttrasl.tascst_id = tascst.tascst_id --join te_test_route_alloc_spec_links to te_allocated_spec_conv_stages
   and ttrasl.rec_status = 'A'
   and ttolpi.ttrasl_id = ttrasl.ttrasl_id --join te_troute_ord_link_pieces to te_test_route_alloc_spec_links
   and ttolpi.rec_status = 'A'
   and ttaltt.ttrasl_id = ttrasl.ttrasl_id --join te_tr_alloc_link_test_types to te_test_route_alloc_spec_links
   and ttaltt.test_type = ttolpi.test_type --join te_tr_alloc_link_test_types to te_troute_ord_link_pieces    Cuts SAP_PROCESS_ORDER 11765114 from 124 lines to 35
   and ttaltt.rec_status = 'A'
   and ttrout.ttrout_id = ttrasl.ttrout_id --join te_test_routes to te_test_route_alloc_spec_links
   and ttrout.rec_status = 'A'
   and r3pord.r3_process_order = tascst.r3_process_order --join r3_process_orders to te_allocated_spec_conv_stages
   and r3pord.r3_sales_order = tascst.r3_sales_order     --join r3_process_orders to te_allocated_spec_conv_stages 
   and r3pord.r3_sales_order_item = tascst.r3_sales_order_item --join r3_process_orders to te_allocated_spec_conv_stages
   and ttrcst.ttrcst_id = tascst.ttrcst_id   --join te_test_route_conv_stages to te_allocated_spec_conv_stages
   and ttrcst.rec_status = 'A'  
   and tta.test_area_id = ttolpi.test_area_id --join te_test_areas to te_troute_ord_link_pieces  
   and ttrtse.ttrtse_id = ttolpi.ttrtse_id    --join te_test_route_traveler_sects to te_troute_ord_link_pieces
  order by  ttolpi.test_type,ttolpi.sample_id; 

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #2                                                             >>         
PROMPT >> Create new View TE_TEST_PIECE_DETAILS_BIVW                          >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
create or replace view TE_TEST_PIECE_DETAILS_BIVW
as
select ttrtse.section_seq               route_section_sequence,
       ttrtse.name                      section_title,
       ttrtse.type_text_key             section_type,
       ttrtra.instruction_seq           sequence,
       ttrpha.phase_code                phase, 
       ttrtra.description               instruction_text,
       tettty.test_type                 phase_test_type, 
       ttpcon.confirmation_user_login   phase_confirm_by,
       ttpcon.date_created              date_confirmed,
       ttpcon.time_created              time_confirmed,      
       ttpcsa.sample_id                 sample_id_confirmed,
       ttolpi.piece_id, 
       ttolpi.test_type,     
       ttrtse.ttrtse_id                 --To be used to join to TE_TEST_PIECES_BIVW
 from te_allocated_spec_conv_stages tascst,
      te_test_route_alloc_spec_links ttrasl,
      te_test_route_traveler_sects ttrtse,
      te_troute_ord_link_pieces ttolpi,
      te_troute_phase_confirmations ttpcon,
      te_test_route_travelers ttrtra,
      te_test_route_phases ttrpha,
      te_troute_phase_conf_samples ttpcsa,
      te_traveler_test_types tettty
 where tascst.rec_status = 'A'
   and ttrasl.tascst_id = tascst.tascst_id --join te_test_route_alloc_spec_links to te_allocated_spec_conv_stages
   and ttrasl.rec_status = 'A'
   and ttrtse.ttrasl_id = ttrasl.ttrasl_id --join te_test_route_traveler_sects to te_test_route_alloc_spec_links
   and ttrtse.rec_status = 'A'
   and ttolpi.ttrasl_id = ttrasl.ttrasl_id --join te_troute_ord_link_pieces to te_test_route_alloc_spec_links
   and ttolpi.rec_status = 'A'
   and ttpcon.ttrtra_id(+) = ttrtra.ttrtra_id -- join te_troute_phase_confirmations to te_test_route_travelers
   and ttrtra.ttrtse_id(+) = ttrtse.ttrtse_id -- join te_test_route_travelers to te_test_route_traveler_sects
   and ttrtra.rec_status = 'A'
   and ttrpha.ttrpha_id = ttrtra.ttrpha_id    -- join te_test_route_phases to te_test_route_travelers
   and ttrpha.rec_status = 'A'
   and ttpcsa.ttpcon_id(+) = ttpcon.ttpcon_id -- join te_troute_phase_conf_samples to te_troute_phase_confirmations
   and ttpcsa.rec_status(+) = 'A'
   and ttpcsa.sample_id(+) = ttolpi.sample_id -- join te_troute_phase_conf_samples to te_troute_ord_link_pieces
   and tettty.ttrtra_id = ttrtra.ttrtra_id    -- join te_traveler_test_types to te_test_route_travelers
  order by ttrtra.instruction_seq; 
  
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #3                                                             >>         
PROMPT >> Create Public Synonyms TE_TEST_PIECES_BIVW                          >>
PROMPT >>                        TE_TEST_PIECE_DETAILS_BIVW                   >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE OR REPLACE PUBLIC SYNONYM TE_TEST_PIECES_BIVW FOR STAR.TE_TEST_PIECES_BIVW;
CREATE OR REPLACE PUBLIC SYNONYM TE_TEST_PIECE_DETAILS_BIVW FOR STAR.TE_TEST_PIECE_DETAILS_BIVW;

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #4                                                             >>         
PROMPT >> Grant SELECT to EXT_TMT_PWRBI on new tables                         >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GRANT SELECT ON STAR.TE_TEST_PIECES_BIVW TO EXT_TMT_PWRBI;
GRANT SELECT ON STAR.TE_TEST_PIECE_DETAILS_BIVW TO EXT_TMT_PWRBI;

PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PROMPT >> Step #5                                                             >>         
PROMPT >> Grant SELECT to DEVELOPER_READ_ONLY on new tables                   >>
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GRANT SELECT ON STAR.TE_TEST_PIECES_BIVW TO DEVELOPER_READ_ONLY;
GRANT SELECT ON STAR.TE_TEST_PIECE_DETAILS_BIVW TO DEVELOPER_READ_ONLY;

PROMPT >> End of STCR7635_implement Script
select sysdate from dual;

------------------------------------------------------------
-- The following command will close the spool output file --
spool off