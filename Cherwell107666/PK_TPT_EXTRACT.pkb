CREATE OR REPLACE PACKAGE BODY STAR.pk_tpt_extract AS
/*
  --
  -- $Revision:   1.4  $
  -- $Date:   09 Jun 2020 19:42:44  $
  --
  
   NAME:       PK_TPT_EXTRACT
   PURPOSE:   Repository for procedure / functions used to extract TPT and sample data. First utilised to satisfy STCR 6966.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        24/09/2015      sphillips       1. Created this package.
   1.2       04/04/2020   jslanker         Updated to include site 23 -- STCR 7491
             05/29/2020   jslanker         Add Site 11 STCR 7522
  1.5        12/9/2021   jslanker         Correct code to update EX_TPT_CONTROL  --STCR 7626
                                          was not updating JOB_RUNNING_YN to N
            12/13/2021  jslanker          Create new procedure prGetOrderRequirement23
                                          based on prGetOrderRequirement24 STCR 7563           
   
*/
--------------------------------------------------------------------------------
-- Procedure to extract the long / medium order requirement 
--------------------------------------------------------------------------------
PROCEDURE prGetOrderRequirement(pvcSite_in    IN   st_sites.site%TYPE,
                                                pvcCreateType_in   IN  ex_tpt_order_requirement.creation_indicator%TYPE)
IS
--
-- Variables
nmPosId     PLS_INTEGER;      -- Position within code indicator used for error reporting.
clIndx        PLS_INTEGER;      -- Index for order requirement collection

--
-- CURSORS and associated records and tables
--
-- Curosr to get control data for the given site
CURSOR  crGetControlData (cpvcSite_in   IN  st_sites.site%TYPE)
IS
    SELECT  *
    FROM    ex_tpt_control
    WHERE   site = cpvcSite_in
    AND     job_id = decode(pvcSite_in,'24',1,'23',5,99)       --STCR 7563 added Decode
    FOR UPDATE;
    
-- Record declaration against the control table    
recGetControlData    crGetControlData%ROWTYPE; 

--
-- Cursor to get the requirement for all orders (where order line status is 'L' - Linked to T/E)
CURSOR crGetOrderRequirement (cpvcSite_in   IN  st_sites.site%TYPE)
IS
    SELECT  DISTINCT so.sap_sold_to_name, so.r3_sales_order, 
                soi.r3_sales_order_item, soi.key_size_entered, soi.key_size_uom, soi.item_status,
                sch.spec_code_name, sch.spec_code_desc, sch.shape_type, sch.product_type,
                rcs.NAME conv_stage, rsl.spec_sample_freq_descr, rsl.sample_freq_comments,
                tr.route_ref, tr.NAME route_desc, srs.NAME section_name,
                srd.instruction_seq, srd.description instruction_desc, trp.phase_code, rpt.description, scl.test_type
    FROM    r3_sales_orders so, r3_sales_order_items soi, te_spec_code_header sch,
                te_spec_conversion_stages scs, te_test_route_conv_stages rcs,
                te_test_route_spec_links rsl, te_test_routes tr, te_tr_spec_route_sections srs,
                te_tr_spec_route_details srd, te_test_route_phases trp, te_test_route_phase_texts rpt,
                te_tr_spec_link_test_types ltt, te_spec_code_limits scl
    WHERE   soi.plant_no = cpvcSite_in                           -- For site number passed in
    AND      soi.item_status = 'L'                                    -- Live / Linked order lines only
    AND      so.r3_sales_order = soi.r3_sales_order            -- Sales Order and item
    AND     sch.spec_code_id = soi.spec_code_id             -- Spec details
    AND     scs.spec_code_id = sch.spec_code_id             -- Conversion stage link
    AND     rcs.ttrcst_id = scs.ttrcst_id                           -- Conversion stage name
    AND     rsl.tscsta_id = scs.tscsta_id                          -- Sample frequency
    AND     tr.ttrout_id = rsl.ttrout_id                             -- Test route ref  and description (name)
    AND     srs.ttrsli_id = rsl.ttrsli_id                               -- Section name
    AND     srd.ttsrse_id = srs.ttsrse_id                           -- Phase seq (instruction_seq)
    AND     trp.ttrpha_id = srd.ttrpha_id                          --  Phase code
    AND     rpt.ttrpte_id = trp.ttrpte_id
    AND     ltt.ttrsli_id   = rsl.ttrsli_id                             -- Test types linked to route
    AND     scl.spec_code_id = sch.spec_code_id
    AND      scl.test_type = ltt.test_type
    ORDER BY  so.r3_sales_order, soi.r3_sales_order_item, tr.route_ref,
                   srs.NAME, srd.instruction_seq;

-- Record declaration against TPT extract table                                         
recOrderRequirement     ex_tpt_order_requirement%ROWTYPE;

-- Table type to hold order requirement records to utilise FORALL .... INSERT into the extract table
TYPE ttOrderRequirement  IS TABLE OF ex_tpt_order_requirement%ROWTYPE    
        INDEX BY PLS_INTEGER;

-- Collection for the declared table type
clOrderRequirement  ttOrderRequirement;   

--
-- Exceptions
exNoControlRec      EXCEPTION;

--
-- Update the control tabel and run the extract
BEGIN
    -- ID position
    nmPosId := 1;  
    
    -- Check the control table to ensure job not currently running. If not update flag to show execution
    OPEN    crGetControlData(cpvcSite_in   =>  pvcSite_in);
    FETCH   crGetControlData
        INTO    recGetControlData;
        
    IF  crGetControlData%NOTFOUND
    THEN
        -- No control record for this job
        nmPosId := 2;
          
        CLOSE crGetControlData;   
        RAISE exNoControlRec;
    ELSE        
       -- Update the control table with job details and flag as running
       nmPosId := 3;
       
       UPDATE   ex_tpt_control
       SET      last_run_date = SYSTIMESTAMP,
                  last_run_by = USER,
                  job_running_yn = 'Y'
       WHERE CURRENT OF crGetControlData ;
       CLOSE crGetControlData;
       
       -- Commit the control table data
       COMMIT;
      
    END IF;
     
    --        
    -- Extract the order requirement data
    nmPosId := 4;
    clIndx := 0;
     
    FOR frGetOrderRequirement IN crGetOrderRequirement (cpvcSite_in  => pvcSite_in)
    LOOP
        -- Increment the collection index
        clIndx := clIndx + 1;
        
        -- Buld the extract record
        recOrderRequirement.order_req_id := extptdata_seq.NEXTVAL;
        recOrderRequirement.supplying_site :=  pvcSite_in;
        recOrderRequirement.creation_indicator := pvcCreateType_in;
        recOrderRequirement.created_date := SYSDATE;
        recOrderRequirement.created_by := USER;
        recOrderRequirement.sales_order := frGetOrderRequirement.r3_sales_order;
        recOrderRequirement.item_no := frGetOrderRequirement.r3_sales_order_item;
        recOrderRequirement.sold_to_party := frGetOrderRequirement.sap_sold_to_name;
        recOrderRequirement.key_size := frGetOrderRequirement.key_size_entered;
        recOrderRequirement.key_size_uom := frGetOrderRequirement.key_size_uom;
        recOrderRequirement.item_status := frGetOrderRequirement.item_status;
        recOrderRequirement.spec_code_name := frGetOrderRequirement.spec_code_name;
        recOrderRequirement.spec_code_description := frGetOrderRequirement.spec_code_desc;
        recOrderRequirement.shape_type := frGetOrderRequirement.shape_type;
        recOrderRequirement.product_type := frGetOrderRequirement.product_type;
        recOrderRequirement.conversion_stage := frGetOrderRequirement.conv_stage;
        recOrderRequirement.route_ref := frGetOrderRequirement.route_ref;
        recOrderRequirement.route_ref_description := frGetOrderRequirement.route_desc;
        recOrderRequirement.sample_frequency := frGetOrderRequirement.spec_sample_freq_descr;
        recOrderRequirement.sample_freq_comments := frGetOrderRequirement.sample_freq_comments;
        recOrderRequirement.section_name := frGetOrderRequirement.section_name;
        recOrderRequirement.phase_seq := frGetOrderRequirement.instruction_seq;
        recOrderRequirement.instruction_desc := frGetOrderRequirement.instruction_desc;
        recOrderRequirement.phase_code := frGetOrderRequirement.phase_code;
        recOrderRequirement.phase_description := frGetOrderRequirement.description;
        recOrderRequirement.test_type := frGetOrderRequirement.test_type;
        
        -- Now assign to the collection
        clOrderRequirement(clIndx) := recOrderRequirement;
        DEBUG_REC('Cursor Loop crGetOrderRequirement    sales order =' || frGetOrderRequirement.r3_sales_order); -- TEMP TEMP TEMP TEMP STCR7563
    END LOOP;
    
    /*
    pk_debug.prWriteDebugRec(ptModuleName_in =>  'pk_tpt_extract.prGetOrderRequirement',
                                         vcDebugText_in =>  'Collection populated. Total records = '||TO_CHAR(clIndx)||
                                                                    ' About to INSERT via FORALL ..... '||TO_CHAR(SYSDATE, 'HH24:MI:SS'));    
    */
    -- Insert the extract data into the table
    FORALL indx IN clOrderRequirement.FIRST .. clOrderRequirement.LAST
        INSERT INTO ex_tpt_order_requirement
            VALUES  clOrderRequirement(indx);
    /*            
    pk_debug.prWriteDebugRec(ptModuleName_in =>  'pk_tpt_extract.prGetOrderRequirement',
                                         vcDebugText_in =>  'INSERT Complete at  '||TO_CHAR(SYSDATE, 'HH24:MI:SS'));                
   */
   
    -- Update control table to unlock run flag & update next run date and time
    UPDATE  ex_tpt_control
    SET     job_running_yn = 'N'
            ,records_processed = clIndx
            ,next_run_date = (SELECT next_date
                                     FROM user_jobs
                                     WHERE what LIKE UPPER('%pk_tpt_extract.prGetOrderRequirement24%'))
    WHERE   site = pvcSite_in
    AND     job_id = decode(pvcSite_in,'24',1,'23',5,99);      --STCR 7563 added Decode
    
    -- Commit the extract data and control table update
    COMMIT;
   
    
--
-- Exceptions
EXCEPTION
    
    -- No control record for the given site
    WHEN    exNoControlRec
    THEN
        -- Record error and report to user
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                                    p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                                    p_ModuleName_in =>  'pk_tpt_extract.prGetOrderRequirement',
                                                    p_KeyData_in    =>  'JOB flagged AS currently running. Unable TO execute.');
        
    
    -- Untrapped error
    WHEN OTHERS
    THEN
        -- Write to error log and ROLLBACK  extract data
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                                    p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                                    p_ModuleName_in =>  'pk_tpt_extract.prGetOrderRequirement',
                                                    p_KeyData_in    =>  'WHEN OTHERS. nmnPosId = '||TO_CHAR(nmPosId));        
        ROLLBACK;
          
--
-- End prGetOrderRequirement    
END prGetOrderRequirement;   


--------------------------------------------------------------------------------
-- Procedure to delete the order requirement rows from the extract table for the given site
--------------------------------------------------------------------------------
PROCEDURE prDelOrdReqData (pvcSite_in    IN   st_sites.site%TYPE,
                                         pnmRowsDeleted_out     OUT   PLS_INTEGER)
IS
--
-- Delete the rows for the given site
BEGIN

    DELETE  FROM ex_tpt_order_requirement
    WHERE   supplying_site = pvcSite_in;
    
    pnmRowsDeleted_out := SQL%ROWCOUNT;
       
    COMMIT;
    
--
-- End prDelOrdReqData
END prDelOrdReqData;


--------------------------------------------------------------------------------
-- Procedure to extract tracking data for batches.
--------------------------------------------------------------------------------
PROCEDURE prGetBatchTrackData (pvcSite_in    IN   st_sites.site%TYPE,
                                                 pvcCreateType_in   IN  ex_tpt_order_requirement.creation_indicator%TYPE)
IS
--
-- Variables
nmPosId     PLS_INTEGER;      -- Position within code indicator used for error reporting.
clIndx        PLS_INTEGER;      -- Index for order requirement collection

--
-- CURSORS:
--
-- Curosr to get control data for the given site
CURSOR  crGetControlData (cpvcSite_in   IN  st_sites.site%TYPE)
IS
    SELECT  *
    FROM    ex_tpt_control
    WHERE   site = cpvcSite_in
    AND     job_id = DECODE(cpvcSite_in,'24',2,
                                        -- '26',3,         --STCR 7481 Add Site 26 Remove by Test Issue 53003
                                         '23',4,           --STCR 7491 Add Site 23
                                         '11',3,           --STCR 7522 Add Site 11
                                         2)
    FOR UPDATE;

--  Record declaration against control table
recGetControlData    crGetControlData%ROWTYPE;    

--
-- Get batch tracking data
CURSOR  crGetBatchTrackData  (cpvcSite_in   IN  st_sites.site%TYPE)
IS
SELECT po.r3_batch_number, po.r3_ingot_ref, po.r3_sales_order, po.r3_sales_order_item,
            soi.key_size_entered, soi.key_size_uom,
            sch.spec_code_name, sch.spec_code_desc, sch.product_type, sch.shape_type,
            po.date_created, SYSDATE, rcs.NAME conv_stage,
            tr.route_ref, tr.NAME route_desc,            
            asl.sample_size, asl.sample_uom_ref, asl.spec_sample_freq_descr sample_freq, asl.sample_freq_comments, rts.NAME section_title,
            trt.instruction_seq, trt.description,  trp.phase_code,            
            olp.piece_id, olp.piece_count, olp.test_type, olp.ht_code, olp.ht_comment,
            olp.sample_id, ta.test_area, olp.sample_comment, ts.sign_off_status, ts.signed_unsigned_date, ts.sample_id_copied_from,
            TO_CHAR(tpc.date_created, 'DD_MON_YYYY') date_confirmed, TO_CHAR(tpc.date_created, 'HH24:MI:SS') time_confirmed,
            tpc.confirmation_user_login confirmed_by, pcs.sample_id sample_id_confirmed
FROM r3_process_orders po,  r3_sales_order_items soi, te_spec_code_header sch,
         te_allocated_spec_conv_stages scs, te_test_route_conv_stages rcs,
         te_test_route_alloc_spec_links asl, te_test_routes tr, te_troute_ord_link_pieces olp,
         te_test_route_traveler_sects rts, te_test_route_travelers trt, te_test_route_phases trp, te_test_route_phase_texts rpt,
         te_test_areas ta, te_test_sample_id ts, te_troute_phase_confirmations tpc, te_troute_phase_conf_samples pcs
WHERE   soi.plant_no = pvcSite_in                                                               -- Site
AND     soi.item_status = 'L'                                                                 -- item status
AND     sch.spec_code_id = soi.spec_code_id                                         -- Spec
AND     po.r3_sales_order = soi.r3_sales_order                                         -- Batch (created within 6 months of now)
AND     po.r3_sales_order_item = soi.r3_sales_order_item
AND     po.date_created > (ADD_MONTHS (SYSDATE, -3))                           -- Change from -3 to -16 for testing in DSTAR and - 12 in TSTAR STCR 7481, 7522
AND     po.process_order_status != 'E'                                                  -- Exclude expired allocations
AND     scs.r3_process_order = po.r3_batch_number                               -- Conversion stage
AND     rcs.ttrcst_id = scs.ttrcst_id 
AND     rcs.rec_status = 'A'
AND     asl.tascst_id = scs.tascst_id                                                   -- Size and uom
AND     tr.ttrout_id = asl.ttrout_id
AND     olp.ttrasl_id = asl.ttrasl_id 
AND     rts.ttrtse_id = olp.ttrtse_id                                                       -- Section title and restrict links to route traveler sects (subs line below)
AND     trt.ttrtse_id = rts.ttrtse_id                                                       -- Instruction_seq
AND     trp.ttrpha_id = trt.ttrpha_id                                                     -- Phase code
AND     rpt.ttrpte_id = trp.ttrpte_id 
AND     tpc.ttrtra_id(+) = trt.ttrtra_id                                                   -- Confirmations
AND     pcs.ttpcon_id(+) = tpc.ttpcon_id
AND     ta.test_area_id = olp.test_area_id
AND     ts.sample_id = olp.sample_id                                                    -- Sample Details
ORDER BY po.date_created ASC, section_title, trt.instruction_seq, ts.sample_id ASC;
-- Record declaration against TPT extract table
recBatchTrackData       ex_tpt_batch_tracking%ROWTYPE;

-- Table type top hold batch track data records to utilise FORALL .... INSERT into extract table
TYPE    ttBatchTrackData    IS TABLE OF  ex_tpt_batch_tracking%ROWTYPE
            INDEX BY PLS_INTEGER;

-- Collection for the declared table type
clBatchTrackData        ttBatchTrackData;

--
-- Exceptions
exNoControlRec      EXCEPTION;

--
-- Update the control tabel and run the extract
BEGIN
    -- ID position
    nmPosId := 1;  
    -- Check the control table to ensure job not currently running. If not update flag to show execution
    OPEN    crGetControlData(cpvcSite_in   =>  pvcSite_in);
    FETCH   crGetControlData
        INTO    recGetControlData;   
    IF  crGetControlData%NOTFOUND
    THEN
        -- No control record for this job
        nmPosId := 2;  
        CLOSE crGetControlData;   
        RAISE exNoControlRec;
    ELSE        
       -- Update the control table with job details and flag as running
       nmPosId := 3; 
       UPDATE   ex_tpt_control
       SET      last_run_date = SYSDATE,
                  last_run_by = USER,
                  job_running_yn = 'Y'
       WHERE CURRENT OF crGetControlData ;
       CLOSE crGetControlData;
       
       -- Commit the control table data
       COMMIT;
    END IF;
    --        
    -- Extract the batch tracking data
    nmPosId := 4;
    clIndx := 0;   

    FOR frGetBatchTrackData IN crGetBatchTrackData (cpvcSite_in  => pvcSite_in)
    LOOP
        -- Increment the collection index
        clIndx := clIndx + 1;

        -- Build the extract record 
        recBatchTrackData.batch_tracking_id := extptdata_seq.NEXTVAL;
        recBatchTrackData.supplying_site :=  pvcSite_in;
        recBatchTrackData.creation_indicator := pvcCreateType_in;
        recBatchTrackData.created_date := SYSTIMESTAMP;
        recBatchTrackData.created_by := USER;
        recBatchTrackData.batch_no := frGetBatchTrackData.r3_batch_number;
        recBatchTrackData.heat_no := frGetBatchTrackData.r3_ingot_ref;
        recBatchTrackData.sales_order := frGetBatchTrackData.r3_sales_order;
        recBatchTrackData.item_no := frGetBatchTrackData.r3_sales_order_item;
        recBatchTrackData.key_size_entered := frGetBatchTrackData.key_size_entered;
        recBatchTrackData.key_size_uom := frGetBatchTrackData.key_size_uom;
        recBatchTrackData.spec_code_name := frGetBatchTrackData.spec_code_name;
        recBatchTrackData.spec_code_desc := frGetBatchTrackData.spec_code_desc;
        recBatchTrackData.product_type := frGetBatchTrackData.product_type;
        recBatchTrackData.shape_type := frGetBatchTrackData.shape_type;
        recBatchTrackData.conversion_stage := frGetBatchTrackData.conv_stage;
        recBatchTrackData.route_ref := frGetBatchTrackData.route_ref;
        recBatchTrackData.route_ref_description := frGetBatchTrackData.route_desc;
        recBatchTrackData.sample_size := frGetBatchTrackData.sample_size;
        recBatchTrackData.sample_uom := frGetBatchTrackData.sample_uom_ref;
        recBatchTrackData.sample_frequency := frGetBatchTrackData.sample_freq;
        recBatchTrackData.section_title := frGetBatchTrackData.section_title;
        recBatchTrackData.phase_seq := frGetBatchTrackData.instruction_seq;
        recBatchTrackData.phase_code_descr :=  frGetBatchTrackData.phase_code;        -- Use phase code instead
        recBatchTrackData.instruction_text := frGetBatchTrackData.description;
        recBatchTrackData.phase_confirmed_by := frGetBatchTrackData.confirmed_by;
        recBatchTrackData.date_confirmed := frGetBatchTrackData.date_confirmed;
        recBatchTrackData.time_confirmed := frGetBatchTrackData.time_confirmed;
        recBatchTrackData.sample_id_confirmed := frGetBatchTrackData.sample_id_confirmed;
        recBatchTrackData.piece_id := frGetBatchTrackData.piece_id;
        recBatchTrackData.piece_count := frGetBatchTrackData.piece_count;
        recBatchTrackData.test_type := frGetBatchTrackData.test_type;
        recBatchTrackData.ht_code := frGetBatchTrackData.ht_code;
        recBatchTrackData.ht_comment := frGetBatchTrackData.ht_comment;
        recBatchTrackData.sample_id := frGetBatchTrackData.sample_id;
        recBatchTrackData.test_lab := frGetBatchTrackData.test_area;
        recBatchTrackData.sample_comment := frGetBatchTrackData.sample_comment;
        recBatchTrackData.sign_off_status := frGetBatchTrackData.sign_off_status;
        recBatchTrackData.signed_unsigned_date := NULL; --frGetBatchTrackData.signed_unsigned_date;
        recBatchTrackData.sample_id_copied_from := frGetBatchTrackData.sample_id_copied_from;
                
        -- Now assign to the collection
        clBatchTrackData(clIndx) := recBatchTrackData;
        
    END LOOP; 
    /*
    pk_debug.prWriteDebugRec(ptModuleName_in =>  'pk_tpt_extract.prGetBatchTrackData',
                                         vcDebugText_in =>  'Collection populated. Total records = '||TO_CHAR(clIndx)||
                                                                    ' About to INSERT via FORALL ..... '||TO_CHAR(SYSDATE, 'HH24:MI:SS'));              
    */
    -- Insert the extract data into the table
    nmPosId := 5;
    
    FORALL indx IN clBatchTrackData.FIRST .. clBatchTrackData.LAST
        INSERT INTO ex_tpt_batch_tracking
            VALUES  clBatchTrackData(indx);
    /*
    pk_debug.prWriteDebugRec(ptModuleName_in =>  'pk_tpt_extract.prGetBatchTrackData',
                                         vcDebugText_in =>  'INSERT Complete at  '||TO_CHAR(SYSDATE, 'HH24:MI:SS'));                
   */
    -- Update control table to unlock run flag
    nmPosId := 6;    
    
    UPDATE  ex_tpt_control
    SET     job_running_yn = 'N'
            ,records_processed = clIndx
            ,next_run_date = (SELECT next_date
                                     FROM user_jobs
                                     WHERE what LIKE UPPER('%pk_tpt_extract.prRunBatchTrackSiteData%'))            
    WHERE   site = pvcSite_in
    AND     job_id = DECODE(pvcSite_in,'24',2,
                                       -- '26',3,--STCR 7481 commented out by Test Issue 53003
                                        '23',4,  -- STCR 7491
                                        '11',3,  --STCR 7626 Add Site 11
                                        2); 
    
    -- Commit the extract data and control table update
    COMMIT;

--
-- Exceptions
EXCEPTION
    
    -- No control record for the given site
    WHEN    exNoControlRec
    THEN
        -- Record error and report to user
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                                    p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                                    p_ModuleName_in =>  'pk_tpt_extract.prGetBatchTrackData',
                                                    p_KeyData_in    =>  'Job flagged as currently running. Unable to execute.');
        
    
    -- Untrapped error
    WHEN OTHERS
    THEN
        -- Write to error log and ROLLBACK  extract data
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                                    p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                                    p_ModuleName_in =>  'pk_tpt_extract.prGetBatchTrackData',
                                                    p_KeyData_in    =>  'WHEN OTHERS. nmPosId = '||TO_CHAR(nmPosId));        
        ROLLBACK;

    
--
-- End prGetBatchTrackData    
END prGetBatchTrackData;

--------------------------------------------------------------------------------
-- Procedure to delete the batch tracking data rows from the extract table for the given site.
--------------------------------------------------------------------------------
PROCEDURE prDelBatchTrackData (pvcSite_in  IN   st_sites.site%TYPE,
                                               pnmRowsDeleted_out  OUT  PLS_INTEGER)
IS
                                                 
--
-- Delete the rows for the given site
BEGIN

    DELETE  FROM ex_tpt_batch_tracking
    WHERE   supplying_site = pvcSite_in;
    
    pnmRowsDeleted_out := SQL%ROWCOUNT;
       
    COMMIT;
--
-- End prDelBatchTrackData
END prDelBatchTrackData;


--------------------------------------------------------------------------------
-- Function to return the number of rows processed (extracted) for the given Job ID and site
--------------------------------------------------------------------------------
FUNCTION fnGetExtractRowCount (pvcSite_in  IN   st_sites.site%TYPE,
                                                 pnmJobId_in   IN    ex_tpt_control.job_id%TYPE)
RETURN PLS_INTEGER
IS
--
-- Variables
nmRowCount          PLS_INTEGER;

--
-- Get the number of rows processed fromm the control table
BEGIN
    
    SELECT  records_processed
    INTO    nmRowCount
    FROM    ex_tpt_control
    WHERE   job_id = pnmJobId_in
    AND     site = pvcSite_in;
    
    RETURN(nmRowCount);
    
--
-- Exceptions
EXCEPTION

    -- No control record found
    WHEN    NO_DATA_FOUND
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                               , p_SqlErrm_in    => SQLERRM
                                                , p_ModuleName_in => 'pk_tpt_extract.fnGetExtractRowCount'
                                                , p_KeyData_in    => 'Job ID ['||TO_CHAR(pnmJobId_in )||
                                                                             '] for site ['||pvcSite_in||'] not found in control table !');

        -- Re-raise error back to user                                                                         
        pk_star_programs.p_raise_star_error (1605);
        
   
    -- Untrapped error
    WHEN    OTHERS
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                               , p_SqlErrm_in    => SQLERRM
                                                , p_ModuleName_in => 'pk_tpt_extract.fnGetExtractRowCount'
                                                , p_KeyData_in    => 'Job ID ['||TO_CHAR(pnmJobId_in )||
                                                                             ' for site '||pvcSite_in||' WHEN OTHERS !');
                                                                             
        -- Re-raise error back to user                                                                         
        pk_star_programs.p_raise_star_error (1205);       

--
-- End prGetExtractRowCount    
END fnGetExtractRowCount;
 
--------------------------------------------------------------------------------
-- Function to indicate if selected extract job is currently running
--------------------------------------------------------------------------------
FUNCTION fnExtractRunning(pnmJobId_in   IN  ex_tpt_control.job_id%TYPE,
                                       pvcSite_in     IN   st_sites.site%TYPE)
RETURN BOOLEAN
IS
--
-- Variables
vcJobRunYN      ex_tpt_control.job_running_yn%TYPE;

--
-- Check the control table to determine if the job ID for the site is flagged as currently running
BEGIN
    SELECT  job_running_yn
    INTO    vcJobRunYN
    FROM    ex_tpt_control
    WHERE   job_id = pnmJobId_in
    AND       site = pvcSite_in;
    
    -- Running ?
    IF vcJobRunYN = 'Y'
    THEN
        RETURN(TRUE);
    ELSE
        RETURN(FALSE);
    END IF;                

--
-- Exceptions
EXCEPTION

    -- No control record found
    WHEN    NO_DATA_FOUND
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                               , p_SqlErrm_in    => SQLERRM
                                                , p_ModuleName_in => 'pk_tpt_extract.fnExtractRunning'
                                                , p_KeyData_in    => 'Job ID ['||TO_CHAR(pnmJobId_in )||
                                                                             '] for site ['||pvcSite_in||'] not found in control table !');
                                                                             
        -- Re-raise error back to user                                                                         
        pk_star_programs.p_raise_star_error (1605);
        
   
    -- Untrapped error
    WHEN    OTHERS
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                               , p_SqlErrm_in    => SQLERRM
                                                , p_ModuleName_in => 'pk_tpt_extract.fnExtractRunning'
                                                , p_KeyData_in    => 'Job ID ['||TO_CHAR(pnmJobId_in )||
                                                                             ' for site '||pvcSite_in||' WHEN OTHERS !');

        -- Re-raise error back to user                                                                         
        pk_star_programs.p_raise_star_error (1205);             
        
--
-- End fnExtractRunning
END fnExtractRunning;

--------------------------------------------------------------------------------
-- Procedure to run order requirement extract for site 24 as a scheduled job
--------------------------------------------------------------------------------
PROCEDURE prGetOrderRequirement24
IS
--
-- Variables
nmRowsDeleted      PLS_INTEGER;

-- Exceptions
exJobRunning        EXCEPTION;

--
-- Run the extract
BEGIN
    -- Check that the extract is not already running
    IF pk_tpt_extract.fnExtractRunning(pnmJobId_in    => 1,
                                                    pvcSite_in     => '24')
    THEN
        -- Job ongoing
        RAISE exJobRunning;
    ELSE
        -- Delete any previous data extract rows for this site from the table
        pk_tpt_extract.prDelOrdReqData (pvcSite_in => '24',
                                                     pnmRowsDeleted_out  =>  nmRowsDeleted);            

        -- Run the order requirement extract
        pk_tpt_extract.prGetOrderRequirement(pvcSite_in => '24',
                                                             pvcCreateType_in => 'S');
    END IF;    
    
--
-- Exceptions
EXCEPTION

    WHEN    exJobRunning
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => -20001
                                               , p_SqlErrm_in    => 'exJobRunning '
                                                , p_ModuleName_in => 'pk_tpt_extract.prGetOrderRequirement24'
                                                , p_KeyData_in    => 'Job ID [1] for site [24] flagged as running at scheduled time of execution.');
                                                
    -- Untrapped error
    WHEN    OTHERS
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                               , p_SqlErrm_in    => SQLERRM
                                                , p_ModuleName_in => 'pk_tpt_extract.prGetOrderRequirement24'
                                                , p_KeyData_in    => 'Job ID [1] for site 24 - WHEN OTHERS !');                                                
                                                         
--
-- End rGetOrderRequirement24
END prGetOrderRequirement24;


--------------------------------------------------------------------------------
-- Procedure to run order requirement extract for site 24 as a scheduled job     -- STCR 7563
--------------------------------------------------------------------------------
PROCEDURE prGetOrderRequirement23
IS
--
-- Variables
nmRowsDeleted      PLS_INTEGER;

-- Exceptions
exJobRunning        EXCEPTION;

--
-- Run the extract
BEGIN

    --DEBUG_REC('BEGIN PK_TPT_EXTRACT.prGetOrderRequirement23>>>>>>'); -- TEMP TEMP TEMP TEMP STCR7563
    -- Check that the extract is not already running
    IF pk_tpt_extract.fnExtractRunning(pnmJobId_in    => 5,
                                                    pvcSite_in     => '23')
    THEN
        -- Job ongoing
        RAISE exJobRunning;
    ELSE
        -- Delete any previous data extract rows for this site from the table
        pk_tpt_extract.prDelOrdReqData (pvcSite_in => '23',
                                                     pnmRowsDeleted_out  =>  nmRowsDeleted);            

        -- Run the order requirement extract
        pk_tpt_extract.prGetOrderRequirement(pvcSite_in => '23',
                                                             pvcCreateType_in => 'S');
    END IF;    
    
    
    --DEBUG_REC('End of PK_TPT_EXTRACT.prGetOrderRequirement23>>>>>>'); -- TEMP TEMP TEMP TEMP STCR7563
--
-- Exceptions
EXCEPTION

    WHEN    exJobRunning
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => -20001
                                               , p_SqlErrm_in    => 'exJobRunning '
                                                , p_ModuleName_in => 'pk_tpt_extract.prGetOrderRequirement23'
                                                , p_KeyData_in    => 'Job ID [1] for site [23] flagged as running at scheduled time of execution.');
                                                
    -- Untrapped error
    WHEN    OTHERS
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                               , p_SqlErrm_in    => SQLERRM
                                                , p_ModuleName_in => 'pk_tpt_extract.prGetOrderRequirement23'
                                                , p_KeyData_in    => 'Job ID [1] for site 23 - WHEN OTHERS !');                                                
                                                         
--
-- End rGetOrderRequirement23
END prGetOrderRequirement23;



--------------------------------------------------------------------------------
-- Procedure to batch tracking data extract for site 24 as a scheduled job
--------------------------------------------------------------------------------
PROCEDURE prRunBatchTrackSiteData
IS
--
-- Variables
nmRowsDeleted      PLS_INTEGER;

-- Exceptions
exJobRunning        EXCEPTION;

lvSite st_sites.site%TYPE;

--
-- Run the extract
BEGIN
    -- Check that the extract is not already running
    IF pk_tpt_extract.fnExtractRunning(pnmJobId_in    => 2,
                                       pvcSite_in     => '24')
    THEN
        lvSite := '24';
        -- Job ongoing
        RAISE exJobRunning;
    ELSE
        -- Delete any previous data extract rows for this site from the table
        pk_tpt_extract.prDelBatchTrackData (pvcSite_in => '24',
                                            pnmRowsDeleted_out  =>  nmRowsDeleted);            

        -- Run the order requirement extract
        pk_tpt_extract.prGetBatchTrackData(pvcSite_in => '24',
                                           pvcCreateType_in => 'S');
    END IF;
    
    --STCR 7481 Add Site 26
     -- Check that the extract is not already running
    /*IF pk_tpt_extract.fnExtractRunning(pnmJobId_in    => 3,
                                       pvcSite_in     => '26')
    THEN
        -- Job ongoing
        lvSite := '26';
        RAISE exJobRunning;
    ELSE
        -- Delete any previous data extract rows for this site from the table
        pk_tpt_extract.prDelBatchTrackData (pvcSite_in => '26',
                                            pnmRowsDeleted_out  =>  nmRowsDeleted);            

        -- Run the order requirement extract
        pk_tpt_extract.prGetBatchTrackData(pvcSite_in => '26',
                                           pvcCreateType_in => 'S');
    END IF; */ -- Commented Out by Test Issue 53003 due to lack of testing

     ------------------------------------------------------------------ --STCR 7491
     --STCR 7491 Add Site 23                                            --STCR 7491
     -- Check that the extract is not already running                   --STCR 7491
    IF pk_tpt_extract.fnExtractRunning(pnmJobId_in    => 4,             --STCR 7491
                                       pvcSite_in     => '23')          --STCR 7491
    THEN                                                                --STCR 7491
        -- Job ongoing                                                  --STCR 7491
        lvSite := '23';                                                 --STCR 7491
        RAISE exJobRunning;                                             --STCR 7491
    ELSE                                                                --STCR 7491
        -- Delete any previous data extract rows for this site from the table
        pk_tpt_extract.prDelBatchTrackData (pvcSite_in => '23',         --STCR 7491
                                            pnmRowsDeleted_out  =>  nmRowsDeleted);            
                                                                        --STCR 7491
        -- Run the order requirement extract                            --STCR 7491
        pk_tpt_extract.prGetBatchTrackData(pvcSite_in => '23',          --STCR 7491
                                           pvcCreateType_in => 'S');    --STCR 7491
    END IF;                                                             --STCR 7491    

    ------------------------------------------------------------------ --STCR 7522
    --STCR 7522 Add Site 11                                            --STCR 7522
    -- Check that the extract is not already running                   --STCR 7522
    IF pk_tpt_extract.fnExtractRunning(pnmJobId_in    => 3,             --STCR 7522
                                       pvcSite_in     => '11')          --STCR 7522
    THEN                                                                --STCR 7522
        -- Job ongoing                                                  --STCR 7522
        lvSite := '11';                                                 --STCR 7522
        RAISE exJobRunning;                                             --STCR 7522
    ELSE                                                                --STCR 7522
        -- Delete any previous data extract rows for this site from the table
        pk_tpt_extract.prDelBatchTrackData (pvcSite_in => '11',         --STCR 7522
                                            pnmRowsDeleted_out  =>  nmRowsDeleted);            
                                                                        --STCR 7522
        -- Run the order requirement extract                            --STCR 7522
        pk_tpt_extract.prGetBatchTrackData(pvcSite_in => '11',          --STCR 7522
                                           pvcCreateType_in => 'S');    --STCR 7522
    END IF;                                                             

--
-- Exceptions
EXCEPTION

    WHEN    exJobRunning
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => -20001
                                               , p_SqlErrm_in    => 'exJobRunning '
                                                , p_ModuleName_in => 'pk_tpt_extract.prRunBatchTrackSiteData'
                                                , p_KeyData_in    => 'Job ID [2] for site '||lvSite||' flagged as running at scheduled time of execution.');
                                                
    -- Untrapped error
    WHEN    OTHERS
    THEN
        -- Record detail to error log.
        pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                               , p_SqlErrm_in    => SQLERRM
                                                , p_ModuleName_in => 'pk_tpt_extract.prRunBatchTrackSiteData'
                                                , p_KeyData_in    => 'Job ID [2] for site '||lvSite||' - WHEN OTHERS !');                                                


--
-- End prGetBatchTrackData24
END prRunBatchTrackSiteData;   
                                                   
    
/*
|| End package spec PK_TPT_EXTRACT
 */
END pk_tpt_extract;
/