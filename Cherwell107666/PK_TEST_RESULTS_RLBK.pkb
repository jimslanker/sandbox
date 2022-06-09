CREATE OR REPLACE PACKAGE BODY STAR.Pk_Test_Results IS
  --
  -- Version control data:
  --
  -- $Revision:   5.23  $
  -- $Date:   26 Nov 2019 16:44:10  $
  --
  /******************************************************************************
     NAME:       Pk_Test_Results
     PURPOSE:

     REVISIONS:
     Ver     Date         Author           Description
     -----  -----------  ---------------  ------------------------------------
     5.13   06-APR-2011  G Ford           2011 Fast Track - STCR 5850 - modifications to function fn_copy_samples_check
     5.14   24-AUG-2011  G Ford           Cycle 19 Scheduled Issues - STCR 5848 - modified va_cur cursor in pr_set_sample_vas
     5.16   06-JUL-2012  A Narayan        Cycle 22 Scheduled Issues - STCR 6240 and 2012 Fast Track - STCR 6297 Added function fnChkNumber
     5.21   31-MAY-2012  S Chopra         Cycle 38 STCR 7069 - Changed pr_set_sample_vas to return VA for an invalid result     
  */
  --
  -- Public data declarations used for package initialisation
  --
  TYPE tSiteTab IS TABLE OF ST_SITES%ROWTYPE
                     INDEX BY VARCHAR2 (2);
  clSiteList     tSiteTab;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if a result has failed test
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION failed_test (p_min_value IN NUMBER, p_max_value IN NUMBER, p_act_result IN VARCHAR2)
    RETURN BOOLEAN IS
  --
  -- Local variables
  --
  /*
  ||
  || FUNCTION LOGIC.
  ||
  */
  BEGIN
    --
    -- Is result is a numeric value :1
    --
    IF Pk_Test_Results.Is_Number (p_act_result) THEN
      -- Result is numeric. Check within any limits applicable.
      IF p_min_value IS NOT NULL AND p_act_result < p_min_value THEN
        RETURN (TRUE); -- Outside min limit;
      ELSIF p_max_value IS NOT NULL AND p_act_result > p_max_value THEN
        RETURN (TRUE); -- Outside max limit;
      ELSE
        RETURN (FALSE); -- NOT outside limits. Return FALSE (NOT failed test).
      END IF; -- END IF for min and max value checks
    -- Not a valid numeric result
    ELSE
      RETURN (FALSE); -- Nno limits to check against, return FALSE.
    END IF;
  END failed_test;

  FUNCTION fn_acceptable_result_text (p_act_result IN TE_TEST_RESULTS.act_result%TYPE)
    RETURN BOOLEAN IS
  BEGIN
    IF p_act_result IN ('PASS', 'FAIL', 'ACCEPT', 'REJECT') THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END fn_acceptable_result_text;

  /*------------------------------------------------------------------------------------
  ||
  || Function to copy given samples to another batch
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_copy_samples (p_sample_list_in         IN     tabCopySampleData
                           ,p_to_batch_in            IN     R3_PROCESS_ORDERS.r3_process_order%TYPE
                           ,p_to_ingot_in            IN     R3_PROCESS_ORDERS.r3_ingot_ref%TYPE
                           ,p_to_spec_id_in          IN     TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                           ,p_copy_status_out           OUT PLS_INTEGER
                           )
    RETURN BOOLEAN IS
    /*
    ||
    || DECLARATIVE SECTION
    ||
    */
    --
    -- Local variables
    --
    recSampleDetails      TE_TEST_SAMPLE_ID%ROWTYPE;
    recTeTestSampleId     TE_TEST_SAMPLE_ID%ROWTYPE;
    recTestResults        TE_TEST_RESULTS%ROWTYPE;
    TYPE tabTestResults IS TABLE OF TE_TEST_RESULTS%ROWTYPE
                             INDEX BY VARCHAR2 (10);
    clTestResults         tabTestResults;
    recSpecLimits         TE_SPEC_CODE_LIMITS%ROWTYPE;
    TYPE tabSpecLimits IS TABLE OF TE_SPEC_CODE_LIMITS%ROWTYPE
                            INDEX BY BINARY_INTEGER;
    clSpecLimits          tabSpecLimits;
    nIndx                 PLS_INTEGER;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Loop through the incoming list of samples
    --
    nIndx               := 1;
    WHILE nIndx <= p_sample_list_in.COUNT LOOP
      -- Populate sample record
      recSampleDetails                          := p_sample_list_in (nIndx);
      -- Create the sample row
      recTeTestSampleId                         := recSampleDetails;
      recTeTestSampleId.sample_id_copied_from   := recSampleDetails.sample_id;
      recTeTestSampleId.sample_id               := fn_get_next_sample_id;
      recTeTestSampleId.spec_code_id            := recSampleDetails.spec_code_id;
      recTeTestSampleId.test_number             := recSampleDetails.test_number;
      recTeTestSampleId.process_order_no        := p_to_batch_in;
      recTeTestSampleId.cast_no                 := p_to_ingot_in;
      recTeTestSampleId.date_created            := NULL;
      recTeTestSampleId.time_created            := NULL;
      recTeTestSampleId.created_by              := NULL;
      recTeTestSampleId.EDITION                 := NULL;
      recTeTestSampleId.valid_sample_yn         := 'Y'; -- 4.12
      INSERT INTO TE_TEST_SAMPLE_ID
           VALUES recTeTestSampleId;
      -- Create the result rows
      FOR test_result_row IN (SELECT *
                                FROM TE_TEST_RESULTS
                               WHERE sample_id = recTeTestSampleId.sample_id_copied_from) LOOP
        -- Set sample_id to be the new one and insert into table
        test_result_row.sample_id      := recTeTestSampleId.sample_id;
        test_result_row.date_created   := NULL;
        test_result_row.time_created   := NULL;
        test_result_row.created_by     := NULL;
        test_result_row.EDITION        := NULL;
        INSERT INTO TE_TEST_RESULTS
             VALUES test_result_row;
      END LOOP;
      nIndx                                     := nIndx + 1; -- Increment loop index for incoming sample list
    END LOOP; -- End loop on sample list
    INSERT INTO te_test_result_averages (test_code
                                        ,avg_result
                                        ,spec_code_id
                                        ,avg_result_op
                                        ,avg_result_uom
                                        ,test_type
                                        ,job_name
                                        ,reported_result
                                        ,std_dev_yn
                                        ,num_of_tests
                                        ,standard_deviation
                                        )
      SELECT test_code
            ,avg_result
            ,spec_code_id
            ,avg_result_op
            ,avg_result_uom
            ,test_type
            ,p_to_batch_in
            ,reported_result
            ,std_dev_yn
            ,num_of_tests
            ,standard_deviation
        FROM te_test_result_averages
       WHERE job_name = recSampleDetails.process_order_no
       AND   recSampleDetails.process_order_no <> p_to_batch_in;  
    --
    -- Commit the child sample(s) and results to the database and return TRUE (Samples successfully copied)
    --
    COMMIT;
    p_copy_status_out   := 0;
    RETURN (TRUE);
  /*
  ||
  || EXCEPTION HANDLING
  ||
  */
  EXCEPTION
    --
    -- A trapped exception means copy aborted
    --
    --
    -- Handles unforseen exceptions
    --
    WHEN OTHERS THEN
      -- Unknown error
      p_copy_status_out   := SQLCODE;
      ROLLBACK;
      RETURN (FALSE);
  --
  -- Exit  fn_copy_samples
  --
  END fn_copy_samples;

  /*------------------------------------------------------------------------------------
  ||
  || Function to check the given samples that will be copied to another batch
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_copy_samples_check (p_sample_list_in         IN tabCopySampleData
                                 ,p_to_batch_in            IN r3_process_orders.r3_process_order%TYPE
                                 ,p_to_ingot_in            IN r3_process_orders.r3_ingot_ref%TYPE
                                 ,p_to_spec_id_in          IN te_spec_code_header.spec_code_id%TYPE
                                 ,pvcCopyDifTotalTests_in  IN VARCHAR2
                                 ,pblCheckLessResults_in   IN BOOLEAN DEFAULT TRUE
                                 ,pblCheckMoreResults_in   IN BOOLEAN DEFAULT TRUE
                                 ,pblCheckHTCode_in        IN BOOLEAN DEFAULT TRUE
                                 )
    RETURN NUMBER IS
    --TYPE tabTestResults IS TABLE OF TE_TEST_RESULTS%ROWTYPE INDEX BY VARCHAR2 (10);
    TYPE tabTestResults IS TABLE OF TE_TEST_RESULTS.test_code%TYPE
                             INDEX BY BINARY_INTEGER;
    TYPE tabSpecLimits IS TABLE OF TE_SPEC_CODE_LIMITS%ROWTYPE
                            INDEX BY BINARY_INTEGER;
    rcSampleDetails     TE_TEST_SAMPLE_ID%ROWTYPE;
    clTestResults       tabTestResults;
    clSpecLimits        tabSpecLimits;
    vcTestCode          TE_TEST_CODES.test_code%TYPE;
    vcHTCode            TE_HT_CODE.ht_code%TYPE;
    vcAlreadyCopied     VARCHAR2 (1);
    vcHtCodeExists      VARCHAR2 (1);
    nmReturnCode        NUMBER;
    nmResultsFound      NUMBER;

    --
    -- Cursor to determine if we have already copied this sample to the target batch
    --
    CURSOR crAlreadyCopied (cpvcToBatch_in           IN R3_PROCESS_ORDERS.r3_process_order%TYPE
                           ,cpnmFromSampleId_in      IN TE_TEST_SAMPLE_ID.sample_id%TYPE
                           ,cpnmToSpecId_in          IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                           ) IS
      SELECT 'Y'
        FROM te_test_sample_id
       WHERE process_order_no = cpvcToBatch_in AND sample_id_copied_from = cpnmFromSampleId_in AND spec_code_id = cpnmToSpecId_in; -- #TAF 1/6/2007 Added to make sure it checks the correct batch based on the Spec Code ID

    --
    -- Cursor to check the target spec contains reference to the HT code against the sample
    --
    CURSOR crCheckHtCode (cpnmSpecId_in IN TE_SPEC_CODE_LIMITS.spec_code_id%TYPE, cpvcHTCode_in IN TE_HT_CODE.ht_code%TYPE) IS
      SELECT 'Y'
        FROM te_spec_code_tst_text
       WHERE spec_code_id = cpnmSpecId_in AND ht_code = cpvcHTCode_in;

    CURSOR crResults (cpnmSampleId_in IN TE_TEST_SAMPLE_ID.sample_id%TYPE) IS
      SELECT *
        FROM te_test_results
       WHERE sample_id = cpnmSampleId_in AND rec_status = 'A';

    exAbortCopy         EXCEPTION;
    exNoHtCode          EXCEPTION;
  BEGIN
    nmReturnCode   := 0;
    --
    -- Loop through the incoming list of samples
    --
    FOR frSampleIndex IN 1 .. p_sample_list_in.COUNT LOOP
      -- Populate sample record
      rcSampleDetails   := p_sample_list_in (frSampleIndex);
      --
      -- Check we haven't previoulsy copied this sample to the target batch
      --
      OPEN crAlreadyCopied (cpvcToBatch_in             => p_to_batch_in
                           ,cpnmFromSampleId_in        => rcSampleDetails.sample_id
                           ,cpnmToSpecId_in            => p_to_spec_id_in);
      FETCH crAlreadyCopied INTO vcAlreadyCopied;
      IF crAlreadyCopied%NOTFOUND THEN
        -- Sample NOT already copied so process
        CLOSE crAlreadyCopied;
        --
        -- Get the individual test codes for this test type from the target spec
        --
        SELECT *
          BULK COLLECT INTO clSpecLimits
          FROM te_spec_code_limits
         WHERE spec_code_id = p_to_spec_id_in AND test_type = rcSampleDetails.test_type;
        SELECT test_code
          BULK COLLECT INTO clTestResults
          FROM te_test_results
         WHERE sample_id = rcSampleDetails.sample_id AND rec_status = 'A';
        --
        -- Check the sample results against the target spec results. If there are more
        -- sample results set the return code to warn the user.
        --
        IF pblCheckMoreResults_in THEN
          nmResultsFound   := 0;
          FOR frResultsIndex IN NVL (clTestResults.FIRST, 0) .. NVL (clTestResults.LAST, -1) LOOP
            FOR frSpecIndex IN NVL (clSpecLimits.FIRST, 0) .. NVL (clSpecLimits.LAST, -1) LOOP
              IF clTestResults (frResultsIndex) = clSpecLimits (frSpecIndex).test_code THEN
                nmResultsFound   := nmResultsFound + 1;
              END IF;
            END LOOP;
          END LOOP;
          IF nmResultsFound != clTestResults.COUNT THEN
            -- These return code represet message numbers
            IF pvcCopyDifTotalTests_in = 'Y' THEN
              -- One or more samples have MORE test results than required on the target specification. Do you wish to continue?
              nmReturnCode   := 1240;
            ELSE
              -- One of the selected tests for copy is NOT a requirement of the target specification. Copy aborted.
              nmReturnCode   := 551;
            END IF;
          END IF;
        END IF;
        --
        -- Check the target spec results against the sample results. If there are more
        -- spec results set the return code to warn the user.
        --
        IF pblCheckLessResults_in THEN
          nmResultsFound   := 0;
          FOR frSpecIndex IN NVL (clSpecLimits.FIRST, 0) .. NVL (clSpecLimits.LAST, -1) LOOP
            FOR frResultsIndex IN NVL (clTestResults.FIRST, 0) .. NVL (clTestResults.LAST, -1) LOOP
              IF clTestResults (frResultsIndex) = clSpecLimits (frSpecIndex).test_code THEN
                nmResultsFound   := nmResultsFound + 1;
              END IF;
            END LOOP;
          END LOOP;
          IF nmResultsFound != clSpecLimits.COUNT THEN
            -- These return code represet message numbers
            IF pvcCopyDifTotalTests_in = 'Y' THEN
              -- One or more samples do NOT have all the test results required on the target specification. Do you wish to continue copying?
              nmReturnCode   := 1236;
            ELSE
              -- One of the test codes against the target specification is NOT present on the sample(s). Copy aborted.
              -- < OLD 552: One of the test codes against the sample is NOT present on the target specification. Copy aborted. >
              nmReturnCode   := 552;
            END IF;
          END IF;
        END IF;
        --
        --  Now check the HT codes are the same.
        --
        IF pblCheckHTCode_in THEN
          IF (rcSampleDetails.ht_code IS NOT NULL)
         AND (rcSampleDetails.ht_code != Pk_Star_Constants.vcAsSupplied)
         AND (rcSampleDetails.ht_code != Pk_Star_Constants.vcElSupplied) THEN --STCR 4576
            -- Read for the HT code on target spec
            OPEN crCheckHtCode (cpnmSpecId_in => p_to_spec_id_in, cpvcHTCode_in => rcSampleDetails.ht_code);
            FETCH crCheckHtCode INTO vcHtCodeExists;
            IF crCheckHtCode%NOTFOUND THEN
              -- No HT code against the target spec
              CLOSE crCheckHtCode;
              nmReturnCode   := 553;
            ELSE
              CLOSE crCheckHtCode;
            END IF;
          END IF;
        END IF;
      ELSE
        -- Sample has already been copied
        CLOSE crAlreadyCopied;
      END IF;
    END LOOP; -- End loop on sample list
    RETURN nmReturnCode;
  EXCEPTION
    WHEN OTHERS THEN -- Unknown error
      RETURN (SQLCODE);
  END fn_copy_samples_check;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if a given HT code is against the given spec.
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_correct_ht_code (p_spec_code_id_in IN NUMBER, p_ht_code_in IN VARCHAR2)
    RETURN BOOLEAN IS
    --
    -- Local variables
    --
    vcDummy     VARCHAR2 (1);

    --
    -- CURSORS:
    --
    -- Cursor to check the HT code is against the spec
    --
    CURSOR check_ht_code_cur IS
      SELECT 'Y'
        FROM TE_SPEC_CODE_TST_TEXT
       WHERE spec_code_id = p_spec_code_id_in AND ht_code = p_ht_code_in;
  /*
  ||
  || FUNCTION LOGIC
  ||
  */
  BEGIN
    --
    -- Read for the HT code against the spec if one is present
    --
    IF p_ht_code_in IS NULL THEN
      -- No HT code entered so don't check
      RETURN (TRUE);
    ELSIF p_ht_code_in = 'AS' THEN
      -- 'As Supplied' - valid for ANY spec
      RETURN (TRUE);
    ELSIF p_ht_code_in = 'EL' THEN
      -- 'EL', 'Etat de Livraison'
      RETURN (TRUE);
    END IF;
    --
    -- We have a HT code so check it is valid
    --
    OPEN check_ht_code_cur;
    FETCH check_ht_code_cur INTO vcDummy;
    CLOSE check_ht_code_cur;
    IF vcDummy = 'Y' THEN
      RETURN (TRUE);
    ELSE
      RETURN (FALSE);
    END IF;
  /*
  ||
  || End check ht code
  ||
  */
  END fn_correct_ht_code;

  /*------------------------------------------------------------------------------------
  ||
  ||  Function to return the value determining whether the result is a caluclated result
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_get_calc_yn (p_test_code IN TE_TEST_CODES.test_code%TYPE)
    RETURN VARCHAR2 IS
    CURSOR get_calc_required IS
      SELECT DECODE (calc_or_entered, 'E', 'N', 'Y')
        FROM TE_TEST_CODES
       WHERE test_code = p_test_code;

    lv_calc_required     VARCHAR2 (1);
  BEGIN
    OPEN get_calc_required;
    FETCH get_calc_required INTO lv_calc_required;
    CLOSE get_calc_required;
    RETURN lv_calc_required;
  END fn_get_calc_yn;

  /*------------------------------------------------------------------------------------
  ||
  ||  Function to return the next ID  number a sample record
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_get_next_sample_id
    RETURN NUMBER IS
    --
    -- Local variables
    --
    nNextId     PLS_INTEGER;
  /*
  ||
  || FUNCTION LOGIC
  ||
  */
  BEGIN
    --
    -- Fetch the next sequence number
    --
    SELECT sample_id_seq.NEXTVAL INTO nNextId FROM DUAL;
    RETURN (nNextId);
  --
  -- Exit  fn_get_next_sample_id
  --
  END fn_get_next_sample_id;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to select the email type which determines the rule for generating the emails
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_Get_Parameter (p_site ST_SITES.site%TYPE, p_param_type TE_TEST_RESULTS_PARAMETERS.parameter_type%TYPE)
    RETURN TE_TEST_RESULTS_PARAMETERS.parameter%TYPE IS
    lv_parameter_type     TE_TEST_RESULTS_PARAMETERS.parameter%TYPE;
    lv_return_value       ST_PROGRAM_PARAMETERS.parameter_value%TYPE;

    CURSOR parameter_cur (p_site IN ST_SITES.site%TYPE, p_param_type TE_TEST_RESULTS_PARAMETERS.parameter_type%TYPE) IS
      SELECT parameter
        FROM TE_TEST_RESULTS_PARAMETERS
       WHERE parameter_type = p_param_type AND site = p_site;
  BEGIN
    -- 4.12 changes. Code left in place to quickly switch back if necessary. Once go live is approved
    -- the code can be removed.
    /*  OPEN parameter_cur (p_site, p_param_type);
      FETCH parameter_cur INTO lv_parameter_type;
      CLOSE parameter_cur;

      RETURN lv_parameter_type;*/
    lv_return_value      := Pk_Star_Programs.fn_Get_Parameter (p_program_name             => 'LAB_TESTS'
                                                              ,p_param_name               => p_param_type
                                                              ,p_site                     => p_site
                                                              );
    IF lv_return_value = 'NULL' THEN
      lv_return_value   := 'X';
    END IF;
    RETURN lv_return_value;
  END fn_Get_Parameter;

  FUNCTION fn_get_single_calc_test_code (p_sample_id IN TE_TEST_SAMPLE_ID.sample_id%TYPE)
    RETURN TE_TEST_RESULTS.test_code%TYPE IS
    lv_test_code     TE_TEST_RESULTS.test_code%TYPE;

    CURSOR sample_test_code_cur (p_sample_id IN TE_TEST_SAMPLE_ID.sample_id%TYPE) IS
      SELECT tr.test_code
        FROM te_test_results tr, te_test_sample_id ts
       WHERE ts.sample_id = p_sample_id AND tr.sample_id = ts.sample_id;
  BEGIN
    OPEN sample_test_code_cur (p_sample_id => p_sample_id);
    FETCH sample_test_code_cur INTO lv_test_code;
    CLOSE sample_test_code_cur;
    RETURN lv_test_code;
  END fn_get_single_calc_test_code;

  FUNCTION fn_get_site_fr_sample_id (p_sample_id IN TE_TEST_SAMPLE_ID.sample_id%TYPE)
    RETURN ST_SITES.site%TYPE IS
    lv_owner_site     LAB_TESTS_VIEW.owner_site%TYPE;

    CURSOR get_plant_no (p_sample_id IN TE_TEST_SAMPLE_ID.sample_id%TYPE) IS
      SELECT NVL (owner_site, site)
        FROM lab_tests_view ltv, te_test_sample_id tsi
       WHERE ltv.batch_number = tsi.process_order_no AND ltv.sample_id = tsi.sample_id AND tsi.sample_id = p_sample_id;
  BEGIN
    OPEN get_plant_no (p_sample_id => p_sample_id);
    FETCH get_plant_no INTO lv_owner_site;
    CLOSE get_plant_no;
    RETURN TO_CHAR (lv_owner_site);
  END fn_get_site_fr_sample_id;

  /*------------------------------------------------------------------------------------
  ||
  || Checks rec_status of spec
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_is_order_expired (p_is_raw_material        IN BOOLEAN
                               ,p_process_order          IN R3_PROCESS_ORDERS.r3_process_order%TYPE
                               ,p_sales_order            IN R3_PROCESS_ORDERS.r3_sales_order%TYPE
                               ,p_sales_order_item       IN R3_PROCESS_ORDERS.r3_sales_order_item%TYPE
                               ,pnmPlantNo_in            IN rm_purchase_orders.site%TYPE
                               )
    RETURN BOOLEAN IS
    TYPE lv_ref_cur_type IS REF CURSOR;

    lv_ref_cur         lv_ref_cur_type;
    lv_select_stmt     VARCHAR2 (200);
    lv_rec_status      R3_PROCESS_ORDERS.process_order_status%TYPE;
    CURSOR crGetRawMaterialStatus(cpvcSalesOrder_in          IN R3_PROCESS_ORDERS.r3_sales_order%TYPE
                                  ,cpvcSalesOrderItem_in     IN R3_PROCESS_ORDERS.r3_sales_order_item%TYPE
                                  ,cpvcPlantNo_in            IN rm_purchase_orders.site%TYPE) IS
    SELECT A.rec_status 
      FROM rm_purchase_orders A
           ,rm_purchase_order_items b
     WHERE A.purchase_order_id = b.purchase_order_id 
       AND A.sap_purchase_order_ref = cpvcSalesOrder_in
       AND b.sap_po_item_ref = cpvcSalesOrderItem_in 
       AND A.site = cpvcPlantNo_in;                             
  BEGIN
    -- This return is used to speed up processing because if the sales order is null
    -- the lab_tests form doesn't need to set a VA for the sales order
    IF p_sales_order IS NULL THEN
      RETURN FALSE;
    END IF;
    IF p_is_raw_material THEN
      OPEN crGetRawMaterialStatus(cpvcSalesOrder_in   => p_sales_order
                                  ,cpvcSalesOrderItem_in   => p_sales_order_item
                                  ,cpvcPlantNo_in => pnmPlantNo_in);
      FETCH crGetRawMaterialStatus INTO lv_rec_status;
      CLOSE crGetRawMaterialStatus;                                  
    ELSE
      lv_select_stmt      := ' SELECT process_order_status' || ' FROM   r3_process_orders' || ' WHERE  r3_process_order = :po' ||
                             ' AND    r3_sales_order = :so' || ' AND    r3_sales_order_item = :soi';
      OPEN lv_ref_cur FOR lv_select_stmt USING p_process_order, p_sales_order, p_sales_order_item;
      FETCH lv_ref_cur INTO lv_rec_status;
      CLOSE lv_ref_cur;
    END IF;
    IF (p_is_raw_material AND lv_rec_status = 'A')
    OR (NOT p_is_raw_material AND lv_rec_status != 'E') THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  END fn_is_order_expired;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if a given test is a requirement of a given spec.
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_required_test (p_spec_code_id_in IN NUMBER, p_test_type_in IN VARCHAR2)
    RETURN BOOLEAN IS
    --
    -- Local variables
    --
    vcDummy     VARCHAR2 (1);

    --
    -- CURSORS:
    --
    -- Cursor to determine if the test is a requirement of the spec
    --
    CURSOR chk_spec_requirement_cur IS
      SELECT 'Y'
        FROM TE_SPEC_CODE_LIMITS
       WHERE spec_code_id = p_spec_code_id_in AND test_type = p_test_type_in;
  /*
  ||
  || FUNCTION LOGIC
  ||
  */
  BEGIN
    --
    -- Read for the test type against the spec
    --
    OPEN chk_spec_requirement_cur;
    FETCH chk_spec_requirement_cur INTO vcDummy;
    CLOSE chk_spec_requirement_cur;
    IF vcDummy = 'Y' THEN
      RETURN (TRUE);
    ELSE
      RETURN (FALSE);
    END IF;
  /*
  ||
  || End check test requirement
  ||
  */
  END fn_required_test;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to send emails based on results that didn't pass checks
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_Send_Email (p_email_type IN VARCHAR2)
    RETURN VARCHAR2 IS
    CURSOR email_cur (cpEmailType_in IN VARCHAR2) IS
        SELECT batch_no
              ,cast_no
              ,sample_type
              ,sample_id
              ,piece_id
              ,ht_code
              ,test_type
              ,test_code
              ,test_number
              ,act_result
              ,act_result_op
              ,min_limit
              ,max_limit
              ,DECODE (failure_type, 'S', 'spec', 'control') failure_type
              ,event_id
              ,email_type
              ,spec_code_id
              ,spec_name
              ,multi_spec_code_id
              ,site
              ,sales_order
              ,sales_order_item
              ,DECODE (sample_type,  'C', 'CHEM',  'M', 'MECH',  'L', 'METL',  'RM') test_category
          FROM gtt_te_test_results
         WHERE email_type = cpEmailType_in
      ORDER BY sample_id, failure_type DESC, test_code;

    -- Cursor to get IDF (if TIMET UK blended material) and associated alloy
    CURSOR get_idf (p_cast_no IN VARCHAR2) IS
      SELECT ing.idf_ref, idf.alloy_code
        FROM bl_ingots ing, bl_idfs idf
       WHERE ing.ingot_ref = p_cast_no AND ing.idf_ref = idf.idf_ref;

    CURSOR get_sample_name (p_sample_id IN NUMBER) IS
      SELECT SUBSTR (process_order_no || '/' || NVL (piece_id, ' '), 1, 30)
        FROM te_test_sample_id
       WHERE sample_id = p_sample_id;

    lv_message_text               st_email_queue_headers.MESSAGE_TEXT%TYPE := NULL;
    lv_subject                    VARCHAR2 (80) := NULL;
    lv_recipient_collection       pk_collection_types.user_login_list_t;
    lv_outcome_status             VARCHAR2 (3); -- Holds STAR WATCH outcome indicator
    lv_outcome_message            VARCHAR2 (250); -- Holds STAR WATCH outcome message
    lv_event_id                   gtt_te_test_results.event_id%TYPE;
    lv_idf                        bl_idfs.idf_ref%TYPE; -- Holds IDF (if applicable)
    lv_idf_alloy                  bl_idfs.alloy_code%TYPE; -- Holds the alloy code from the IDF
    lv_message_set                BOOLEAN := FALSE;
    lv_sample_name                te_test_sample_id.sample_name%TYPE;
    lv_spec_id                    te_spec_code_header.spec_code_id%TYPE;
    lv_last_test_code             te_test_results.test_code%TYPE := ' ';
    lv_message_text_too_large     BOOLEAN := FALSE;
    lv_prev_sample_id             gtt_te_test_results.sample_id%TYPE := 0;

    PROCEDURE pr_append_message_text (p_email_type IN VARCHAR2, p_message_text IN OUT VARCHAR2) IS
    BEGIN
      IF p_email_type = 'UK' THEN
        p_message_text      := p_message_text || CHR (13) || CHR (13) || 'NOTE: Result data may have been amended ' ||
                               'since this message was generated.' || CHR (13) ||
                               '      Please check the data via the test results form.';
      ELSIF p_email_type = 'US' THEN
        p_message_text   := p_message_text || CHR (13) || 'Please access STAR to View sample.';
      END IF;
    END;

    PROCEDURE pr_send_extra_email IS
    BEGIN
      IF lv_message_text_too_large THEN
        lv_message_text   := lv_message_text || CHR (13) || '* More results fail specifications.';
      END IF;
      pr_append_message_text (p_email_type, lv_message_text);
      lv_recipient_collection   := pk_collection_types.user_login_list_t ();
      -- 4.10 Add the author to the recipient list
      pk_email.add_to_user_login_list (lv_recipient_collection, USER);
      pk_email.pr_emaiL_an_event (p_event_id_in              => lv_event_id
                                 ,p_additional_recipients_in => lv_recipient_collection
                                 ,p_message_text_in          => lv_message_text
                                 ,p_subject_in               => lv_subject
                                 ,p_event_specific_data_in   => 'Program : Test Results'
                                 ,p_outcome_status_out       => lv_outcome_status
                                 ,p_outcome_message_out      => lv_outcome_message
                                 );
    END;
  BEGIN
    --FOR frSampleIds IN crSampleIds( cpEmailType_in => p_email_type ) LOOP
    FOR email_rec IN email_cur (cpEmailType_in => p_email_type) LOOP
      IF lv_prev_sample_id != email_rec.sample_id THEN -- new sample id encountered or first loop
        IF lv_prev_sample_id != 0 THEN -- new sample id encountered and not first loop
          IF lv_message_set THEN
            pr_send_extra_email;
            IF NVL (lv_outcome_status, '000') != '000' THEN
              RETURN RPAD (NVL (lv_outcome_status, '000'), 10) || NVL (lv_outcome_message, ' ');
            END IF;
          END IF;
        END IF;
        lv_message_text             := NULL;
        lv_subject                  := NULL;
        lv_recipient_collection     := pk_collection_types.user_login_list_t ();
        lv_outcome_status           := NULL;
        lv_outcome_message          := NULL;
        lv_event_id                 := NULL;
        lv_idf                      := NULL;
        lv_idf_alloy                := NULL;
        lv_message_set              := FALSE;
        lv_sample_name              := NULL;
        lv_spec_id                  := NULL;
        lv_last_test_code           := ' ';
        lv_message_text_too_large   := FALSE;
        lv_prev_sample_id           := email_rec.sample_id;
      END IF;
      --
      -- This check is made to see if a different test code is now in play. New test codes must be separate emails for the US
      -- because of the possibility of multi-spec emails having more information in the message body than can be accommodated.
      IF lv_message_set AND p_email_type = 'US' AND lv_last_test_code != email_rec.test_code THEN
        pr_append_message_text (p_email_type, lv_message_text);
        lv_recipient_collection     := pk_collection_types.user_login_list_t ();
        -- 4.10 Add the author to the recipient list
        pk_email.add_to_user_login_list (lv_recipient_collection, USER);
        pk_email.pr_email_an_event (p_event_id_in              => lv_event_id
                                   ,p_additional_recipients_in => lv_recipient_collection
                                   ,p_message_text_in          => lv_message_text
                                   ,p_subject_in               => lv_subject
                                   ,p_event_specific_data_in   => 'Program : Test Results'
                                   ,p_outcome_status_out       => lv_outcome_status
                                   ,p_outcome_message_out      => lv_outcome_message
                                   );
        IF lv_outcome_status != '000' THEN
          RETURN RPAD (lv_outcome_status, 10) || NVL (lv_outcome_message, ' ');
        END IF;
        lv_message_set              := FALSE;
        lv_message_text_too_large   := FALSE;
      END IF;
      lv_event_id         := email_rec.event_id;
      lv_last_test_code   := email_rec.test_code;
      IF p_email_type = 'POST_FORMULATION' THEN
        IF NOT lv_message_set THEN
          lv_message_text   := 'The following test results have been entered POST formulation release :-' || CHR (13) || CHR (13);
          lv_subject        := 'STAR WATCH: Post Formulation Release result entry.';
          lv_message_set    := TRUE;
        END IF;
        -- 4.14 -- add length check
        IF LENGTH (lv_message_text) >= 700 THEN
          lv_message_text_too_large   := TRUE;
        ELSE
          lv_message_text      := lv_message_text || 'Lot: ' || email_rec.batch_no || ', Test type: ' || email_rec.test_type ||
                                  ', Test code: ' || email_rec.test_code || ', Result: ' || NVL (email_rec.act_result_op, '') -- 4.14
                                                                                                                              ||
                                  email_rec.act_result || CHR (13);
        END IF;
      ELSIF p_email_type = 'UK' THEN
        IF email_rec.sample_type != 'R' AND NOT lv_message_set THEN
          lv_message_set       := TRUE;
          OPEN get_idf (email_rec.cast_no);
          FETCH get_idf
          INTO lv_idf, lv_idf_alloy;
          CLOSE get_idf;
          -- WIP Batch
          lv_subject           := 'STAR WATCH: TF ' || email_rec.site || ' ' || email_rec.failure_type || ' failure on ' ||
                                  email_rec.test_category || '. Batch - ' || email_rec.batch_no;
          lv_message_text      := 'Releasing to spec  - ' || email_rec.spec_name || ' & ' --||:PARAMETER.p_selected_alloy
                                                                                                 || '.' || CHR (13) ||
                                  'IDF  - ' || NVL (lv_idf, 'N/A') || ' & ' || NVL (lv_idf_alloy, 'N/A') || '.' || CHR (13)
                                  || 'Piece id - ' || email_rec.piece_id || ', Heat treatment - ' || NVL (email_rec.ht_code, 'N/A')
                                  || ', Sample ID - ' || TO_CHAR (NVL (email_rec.sample_id, NULL)) || ', Test Type - ' ||
                                  email_rec.test_type || CHR (13) || CHR (13) ||
                                  'The following result(s) are outside the specified limits:' || CHR (13) || CHR (13);
        ELSIF NOT lv_message_set THEN
          lv_message_set       := TRUE;
          -- RM Lot
          lv_subject           := 'STAR WATCH: TF ' || email_rec.site || ' ' || email_rec.failure_type || ' failure on ' ||
                                  email_rec.test_category || ' Lot - ' || email_rec.batch_no;
          lv_message_text      := 'Drum id - ' || email_rec.piece_id || ', Sample ID - ' || TO_CHAR (
                                  NVL (email_rec.sample_id, NULL)) || ', Test Type - ' || email_rec.test_type || CHR (13) || CHR (
                                  13) || 'The following result(s) are outside the specified limits:' || CHR (13) || CHR (13);
        END IF;
        -- 4.14 -- add length check
        IF LENGTH (lv_message_text) >= 700 THEN
          lv_message_text_too_large   := TRUE;
        ELSE
          lv_message_text      := lv_message_text || email_rec.test_code || ' Min value - ' || TO_CHAR (email_rec.min_limit) ||
                                  ' from spec: ' || NVL (email_rec.spec_name, 'N/A') || ' max value - ' || TO_CHAR (
                                  email_rec.max_limit) || ' from spec: ' || NVL (email_rec.spec_name, 'N/A') || ' result = ' ||
                                  NVL (
                                  email_rec.act_result_op
                                                                                                                                 ,
                                  '') -- 4.14
                                      || email_rec.act_result || ' Failed ' || email_rec.failure_type || ' limit.' || CHR (13);
        END IF;
      ELSE -- 'US'
        IF NOT lv_message_set THEN
          lv_message_set       := TRUE;
          IF email_rec.multi_spec_code_id IS NULL THEN
            lv_spec_id   := email_rec.spec_code_id;
          ELSE
            lv_spec_id   := email_rec.multi_spec_code_id;
          END IF;
          OPEN get_sample_name (email_rec.sample_id);
          FETCH get_sample_name INTO lv_sample_name;
          CLOSE get_sample_name;
          IF email_rec.failure_type = 'spec' THEN
            lv_subject   := 'Out-of-Spec Condition(s): ' || email_rec.spec_name;
          ELSE
            lv_subject   := 'Out-of-Control Condition(s): ' || email_rec.spec_name;
          END IF;
          lv_message_text      := 'Sales Order: ' || email_rec.sales_order || CHR (13) || 'Sales Item : ' || email_rec.
                                  sales_order_item || CHR (13) || 'Spec CodeId: ' || TO_CHAR (lv_spec_id) || CHR (13) ||
                                  'Sample ID  : ' || TO_CHAR (email_rec.sample_id) || CHR (13) || 'Sample Name: ' ||
                                  lv_sample_name || CHR (13) || 'Test Number: ' || TO_CHAR (email_rec.test_number) || CHR (13) ||
                                  'Heat Number: ' || email_rec.cast_no || CHR (13) || 'Test Type  : ' || email_rec.test_type ||
                                  CHR                                                                                           (
                                  13) || 'Date       : ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY') || CHR (13) || 'Time       : ' ||
                                  TO_CHAR                                                                                      (
                                  SYSDATE
                                                                                                                               ,
                                  'hh24:mi:ss'
                                                                                                                               ) ||
                                  CHR
                                  (13) || 'Created By : ' || USER ||
                                  CHR (10);
        END IF;
        -- A length of 850 was chosen because there is almost 100 characters that will need to be appended to the message body. Part of that is in the form
        -- of a message explaining the result has failed other specifications and the other part is the standard text appended to US messages. Stopping at or near
        -- 850 characters ensures there is enough of a buffer left over to include all the necessary remaining text.
        IF LENGTH (lv_message_text) >= 700 THEN -- 4.14 change from 850 to 750.
          lv_message_text_too_large   := TRUE;
        ELSE
          lv_message_text      := lv_message_text || CHR (13) || 'Test Code (' || email_rec.test_code || ') for spec name ' ||
                                  email_rec.spec_name || ' is out of ' || email_rec.failure_type || '. Result Value: ' || NVL (
                                  email_rec.act_result_op
                                                                                                                           ,'') -- 4.14
                                                                                                                                ||
                                  email_rec.act_result || ', Min Value: ' || email_rec.min_limit || ', Max Value: ' || email_rec.
                                  max_limit;
        END IF;
      END IF;
    END LOOP;
    IF lv_message_set THEN
      pr_send_extra_email;
      IF NVL (lv_outcome_status, '000') != '000' THEN
        RETURN RPAD (NVL (lv_outcome_status, '000'), 10) || NVL (lv_outcome_message, ' ');
      END IF;
    END IF;
    RETURN lv_outcome_status;
  END fn_Send_Email;

  FUNCTION fn_set_valid_result_yn (p_spec_code_id           IN TE_SPEC_CODE_LIMITS.spec_code_id%TYPE
                                  ,p_test_type              IN TE_SPEC_CODE_LIMITS.test_type%TYPE
                                  ,p_test_code              IN TE_SPEC_CODE_LIMITS.test_code%TYPE
                                  ,p_sales_order            IN R3_SALES_ORDER_ITEMS.r3_sales_order%TYPE
                                  ,p_sales_order_item       IN R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                                  ,p_act_result             IN TE_TEST_RESULTS.act_result%TYPE
                                  ,p_pass_limit             IN VARCHAR2
                                  )
    RETURN VARCHAR2 IS
    lv_return     VARCHAR2 (1);
  BEGIN
    IF Pk_Test_Results.fn_us_site (p_sales_order, p_sales_order_item) THEN
      IF Pk_Test_Results.spec_set_to_no (p_spec_code_id, p_test_code, p_test_type) THEN
        lv_return   := 'N';
      ELSE
        lv_return   := 'Y';
      END IF;
    ELSE
      IF p_act_result IN ('PASS', 'ACCEPT') THEN
        lv_return   := 'Y';
      ELSIF p_act_result IN ('FAIL', 'REJECT') THEN
        lv_return   := 'N';
      ELSIF p_pass_limit != 'N' THEN -- 4.13
        IF Pk_Test_Results.spec_set_to_no (p_spec_code_id, p_test_code, p_test_type) THEN
          lv_return   := 'N';
        ELSE
          lv_return   := 'Y';
        END IF;
      ELSE
        lv_return   := 'N';
      END IF;
    END IF;
    RETURN lv_return;
  END fn_set_valid_result_yn;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if the given sample has been used as the
  || source of a sample copy operation
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_source_sample (p_sample_id_in IN TE_TEST_SAMPLE_ID.sample_id%TYPE)
    RETURN BOOLEAN IS
    /*
    ||
    || DECLARATIVE SECTION
    ||
    */
    --
    -- Local variables
    --
    nSampleId     TE_TEST_SAMPLE_ID.sample_id%TYPE;

    --
    -- Cursor to retrieve any rows copied from the incoming sample ID
    --
    CURSOR get_copied_samples_cur (p_sample_id TE_TEST_SAMPLE_ID.sample_id%TYPE) IS
      SELECT sample_id
        FROM TE_TEST_SAMPLE_ID
       WHERE sample_id_copied_from = p_sample_id;
  /*
  ||
  || FUNCTION LOGIC
  ||
  */
  BEGIN
    --
    -- Lookup if we have any samples where the sample_id_copied_from column
    -- is equal to the incoming sample_id
    --
    OPEN get_copied_samples_cur (p_sample_id_in);
    FETCH get_copied_samples_cur INTO nSampleId;
    IF nSampleId IS NULL THEN
      -- No samples created from this on
      CLOSE get_copied_samples_cur;
      RETURN (FALSE);
    ELSE
      -- Samples HAVE been created from this one
      CLOSE get_copied_samples_cur;
      RETURN (TRUE);
    END IF;
  --
  -- Exit fn_source_sample
  --
  END fn_source_sample;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if the given order item is being made at a US site or not.
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION fn_us_site (p_order_no_in            IN R3_SALES_ORDER_ITEMS.r3_sales_order%TYPE
                      ,p_item_no_in             IN R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                      )
    RETURN BOOLEAN IS
    /*
    ||
    || DECLARATIVE SECTION
    ||
    */
    --
    -- Local variables
    --
    nPlantNo              R3_SALES_ORDER_ITEMS.plant_no%TYPE;
    vcDefaultCurrency     ST_SITES.default_currency_code%TYPE;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Get the site associated with this order / item
    --
    SELECT plant_no
      INTO nPlantNo
      FROM R3_SALES_ORDER_ITEMS
     WHERE r3_sales_order = p_order_no_in AND r3_sales_order_item = p_item_no_in;
    --
    -- Now lookup the site in the site collection (declared and populated in package initialisation)
    -- and retrieve the default currency.
    --
    vcDefaultCurrency   := clSiteList (TO_CHAR (nPlantNo)).default_currency_code;
    --
    -- If the default currency is USD (US Dollar) then the site is a US site
    --
    IF vcDefaultCurrency = 'USD' THEN
      RETURN (TRUE);
    ELSE
      RETURN (FALSE);
    END IF;
  /*
  ||
  || EXCEPTION HANDLING
  ||
  */
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- Problem retrieving order/item or site details. Return FALSE.
      RETURN (FALSE);
    WHEN OTHERS THEN
      -- Unknown error
      RETURN (FALSE);
  --
  -- Exit fn_us_site
  --
  END fn_us_site;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if test is an ingot or product chemistry test
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION ingot_or_product_chemistry (p_test_code IN VARCHAR2)
    RETURN BOOLEAN IS
    --
    -- Local variables
    --
    lv_dummy     VARCHAR2 (1);

    --
    -- CURSORS:
    --
    -- Cursor to check if test is chemistry test
    --
    CURSOR check_if_chemistry IS
      SELECT 'Y'
        FROM TE_TEST_CODES
       WHERE test_code = p_test_code AND test_category = 'C';
  /*
  ||
  || FUNCTION LOGIC
  ||
  */
  BEGIN
    --
    -- See if this test is chemistry
    --
    lv_dummy   := NULL;
    OPEN check_if_chemistry;
    FETCH check_if_chemistry INTO lv_dummy;
    CLOSE check_if_chemistry;
    IF lv_dummy = 'Y' THEN
      RETURN (TRUE);
    ELSE
      RETURN (FALSE);
    END IF;
  END ingot_or_product_chemistry;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if a string is a valid numeric value.
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION Is_Number (p_value IN VARCHAR2)
    RETURN BOOLEAN IS
    --
    -- Local variables
    --
    lv_test           VARCHAR2 (10);
    numeric_error     EXCEPTION;
    PRAGMA EXCEPTION_INIT (numeric_error, -06502);
  /*
  ||
  || FUNCTION LOGIC
  ||
  */
  BEGIN
    IF p_value IS NULL THEN
      RETURN FALSE;
    ELSE
      lv_test   := TO_NUMBER (p_value);
      RETURN TRUE;
    END IF;
  /*
  ||
  || EXCEPTION HANDLING
  ||
  */
  EXCEPTION
    WHEN INVALID_NUMBER THEN
      RETURN FALSE;
    WHEN numeric_error THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      RETURN FALSE;
  END Is_Number;

  /*------------------------------------------------------------------------------------*/
  FUNCTION fn_is_number_yn (p_test_string_in IN VARCHAR2)
    RETURN VARCHAR2 IS
  BEGIN
    IF is_number (p_value => p_test_string_in) THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END fn_is_number_yn;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if sample signed off
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION sample_not_signed (p_test_type_in IN VARCHAR2, p_sample_id IN NUMBER)
    RETURN BOOLEAN IS
    --
    -- Local variables
    --
    lv_count               NUMBER := 0;
    -- Holds count of unsigned samples for this test type
    lv_sign_off_status     VARCHAR2 (1) := NULL;

    --
    -- CURSORS:
    --
    -- Cursor to check if given sample is signed off
    --
    CURSOR chk_sign_off IS
      SELECT sign_off_status
        FROM TE_TEST_SAMPLE_ID
       WHERE sample_id = p_sample_id;
  /*
  ||
  || FUNCTION LOGIC
  ||
  */
  BEGIN
    --
    -- Get the sign off status for this sample id
    --
    OPEN chk_sign_off;
    FETCH chk_sign_off INTO lv_sign_off_status;
    CLOSE chk_sign_off;
    IF lv_sign_off_status IS NULL THEN
      RETURN (TRUE); -- Sample NOT signed off
    ELSE
      RETURN (FALSE); -- Sample IS signed off
    END IF;
  END sample_not_signed;

  FUNCTION fn_spec_code_limits_cur (p_spec_code_id           IN TE_SPEC_CODE_LIMITS.spec_code_id%TYPE
                                   ,p_test_type              IN TE_SPEC_CODE_LIMITS.test_type%TYPE
                                   ,p_test_code              IN TE_SPEC_CODE_LIMITS.test_code%TYPE
                                   )
    RETURN Pk_Test_Results.te_ref_cur IS
    lv_ref_cursor     Pk_Test_Results.te_ref_cur;
  BEGIN
    OPEN lv_ref_cursor FOR 
      SELECT test_code, 
             report_result_yn, 
--STCR6169   DECODE (min_value_uom, NULL, max_value_uom, min_value_uom) uom -- Brought over from Pk_Mt_Materials.create_mt_results for SCTR 3551.
             min_value_uom uom 
        FROM TE_SPEC_CODE_LIMITS
       WHERE spec_code_id =    p_spec_code_id 
         AND test_type    =    p_test_type 
         AND test_code    LIKE p_test_code;
         
    RETURN lv_ref_cursor;
  END fn_spec_code_limits_cur;

  FUNCTION fn_get_test_code_seq_no (p_test_type              IN TE_TEST_CODE_TYPE_GROUPS.test_type%TYPE
                                   ,p_test_code              IN TE_TEST_CODE_TYPE_GROUPS.test_code%TYPE
                                   )
    RETURN TE_TEST_CODE_TYPE_GROUPS.seq_no%TYPE IS
    CURSOR get_seq_no IS
      SELECT seq_no
        FROM TE_TEST_CODE_TYPE_GROUPS
       WHERE test_type = p_test_type AND test_code = p_test_code;

    lv_seq_no     TE_TEST_CODE_TYPE_GROUPS.seq_no%TYPE;
  BEGIN
    OPEN get_seq_no;
    FETCH get_seq_no INTO lv_seq_no;
    CLOSE get_seq_no;
    RETURN lv_seq_no;
  END fn_get_test_code_seq_no;

  /*------------------------------------------------------------------------------------
  ||
  || Function to determine if a result's spec_limit flag is set
  || to 'N' because it is flagged as not to be reported in the spec.
  ||
  */
  ------------------------------------------------------------------------------------
  FUNCTION spec_set_to_no (p_spec_code_id IN NUMBER, p_test_code IN VARCHAR2, p_test_type IN VARCHAR2)
    RETURN BOOLEAN IS
    --
    -- Local variables
    --
    lv_report_result_yn     VARCHAR2 (1); -- Holds report flag setting from spec

    --
    -- CURSORS:
    --
    -- Cursor to get the report flag setting for the given spec and test code
    --
    -- #TAF 9/25/06 added test type to CURSOR to get report flag for specific test code.
    CURSOR get_report_flag IS
      SELECT report_result_yn
        FROM TE_SPEC_CODE_LIMITS
       WHERE spec_code_id = p_spec_code_id AND test_code = p_test_code AND test_type = p_test_type;
  /*
  ||
  || FUNCTION LOGIC
  ||
  */
  BEGIN
    --
    -- Get the report flag from the spec
    --
    lv_report_result_yn   := NULL;
    OPEN get_report_flag;
    FETCH get_report_flag INTO lv_report_result_yn;
    CLOSE get_report_flag;
    CASE lv_report_result_yn
      WHEN 'N' THEN
        RETURN (TRUE); -- Spec set to NO
      WHEN 'Y' THEN
        RETURN (FALSE);
      ELSE
        RETURN NULL;
    END CASE;
  END spec_set_to_no;

  FUNCTION fnChkNumber (pvcNumString_in IN VARCHAR2)
    RETURN VARCHAR2 IS
    vcNumChk           VARCHAR2 (1);
    exNumericError     EXCEPTION;
    PRAGMA EXCEPTION_INIT (exNumericError, -06502);
    vcStrChk           VARCHAR2 (20);
  BEGIN
    IF pvcNumString_in IS NULL THEN
      vcNumChk   := 'N';
    ELSE
      vcStrChk   := TO_NUMBER (pvcNumString_in, '99999.99999', 'NLS_NUMERIC_CHARACTERS=''.,''');
      vcNumChk   := 'Y';
    END IF;
    RETURN vcNumChk;
  EXCEPTION
    WHEN INVALID_NUMBER THEN
      vcNumChk   := 'N';
      RETURN vcNumChk;
    WHEN exNumericError THEN
      vcNumChk   := 'N';
      RETURN vcNumChk;
    WHEN OTHERS THEN
      vcNumChk   := 'N';
      RETURN vcNumChk;
  END fnChkNumber;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to populate BATCH_STATUS_DATA table for
  || BATCH_STATUS report.
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE Batch_Status (p_rep_id                 IN NUMBER
                         ,p_run_date               IN VARCHAR
                         ,p_run_time               IN VARCHAR
                         ,p_run_by                 IN VARCHAR
                         ) IS
    /*
    ||
    || DECALRATION SECTION.
    ||
    */
    --
    -- Local Variables
    --
    lv_batch_no            VARCHAR2 (10); -- Holds the batch currently being processed
    lv_test_type           VARCHAR2 (10); -- Holds the test type currently being processed
    lv_heat_no             VARCHAR2 (7); -- Holds the heat currently being process
    lv_sign_off_status     VARCHAR2 (1); -- Holds the sign off status of the current sample
    lv_valid_result        VARCHAR2 (1); -- Indicates whether the result for this component was valid
    lv_legend              VARCHAR2 (1); -- Holds the legend applicable for this result
    lv_result_count        NUMBER; -- Holds the number of results entered for this test
    lv_unsigned_sample     BOOLEAN; -- TRUE if at least one sample for test is unsigned
    lv_spec_code_id        NUMBER; -- Holds the spec id the batch is linked to
    --
    -- Error reporting variables
    --
    lv_error_code          NUMBER := NULL; -- Holds error code
    lv_error_msg           VARCHAR2 (200) := NULL; -- Holds error message

    --
    -- CURSORS:
    --
    -- Cursor to get test requirements from the order edit
    --
    CURSOR get_test_reqs IS
      SELECT DISTINCT isl.ship_we_day
                     ,isl.ship_we_mon
                     ,isl.ship_we_year
                     ,isl.sales_order
                     ,isl.line_item
                     ,isl.int_po
                     ,isl.customer
                     ,isl.BATCH
                     ,scl.test_type
                     ,scl.spec_code_id
                     ,po.r3_ingot_ref
        FROM R3_INTF_SCHEDAD_LINES isl
            ,TE_SPEC_CODE_LIMITS scl
            ,R3_PROCESS_ORDERS po
            ,R3_SALES_ORDER_ITEMS soi
       WHERE isl.report_instance_id = p_rep_id
         AND isl.use_or_ignore = 'U'
         AND po.r3_process_order = isl.BATCH
         AND po.r3_sales_order = isl.sales_order
         AND po.r3_sales_order_item = isl.line_item
         AND soi.r3_sales_order = isl.sales_order
         AND soi.r3_sales_order_item = isl.line_item
         AND scl.spec_code_id = soi.spec_code_id;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
   --
   -- Loop thru the test requirement for each batch
   --
   <<test_requirements>>
    FOR get_test_reqs_row IN get_test_reqs LOOP
      -- Initialise local variables
      lv_test_type         := get_test_reqs_row.test_type;
      lv_batch_no          := get_test_reqs_row.BATCH;
      lv_heat_no           := get_test_reqs_row.r3_ingot_ref;
      lv_spec_code_id      := get_test_reqs_row.spec_code_id;
      lv_legend            := ' '; -- Flag sample as good
      lv_unsigned_sample   := TRUE; -- Flag samples as unsigned
      --
      -- Get the sample status for this test type.
      --
      IF No_Sample (lv_test_type, lv_batch_no, lv_heat_no) THEN
        lv_legend   := '!'; -- Sample not booked in
      ELSIF Sample_Not_Signed_Off (lv_test_type, lv_batch_no, lv_heat_no) THEN
        -- Not signed. Test for valid/missing results.
        IF Invalid_Result (lv_test_type, lv_batch_no, lv_heat_no) THEN
          lv_legend   := 'x'; -- One or more result is invalid
        ELSIF Missing_Result (lv_test_type, lv_batch_no, lv_heat_no) THEN
          lv_legend   := '*'; -- One or more results missing
        END IF;
      ELSE -- All samples for this test are signed off
        lv_unsigned_sample   := FALSE;
      END IF;
      --
      -- Insert into batch_status_data if not signed off
      --
      IF lv_unsigned_sample THEN
        INSERT INTO BATCH_STATUS_DATA (report_instance_id
                                      ,run_by
                                      ,process_order
                                      ,batch_no
                                      ,heat_no
                                      ,sales_order
                                      ,sales_order_item
                                      ,customer
                                      ,spec_code_id
                                      ,ship_we_day
                                      ,ship_we_mon
                                      ,ship_we_year
                                      ,test_type
                                      ,legend
                                      )
             VALUES (p_rep_id
                    ,p_run_by
                    ,get_test_reqs_row.int_po
                    ,lv_batch_no
                    ,get_test_reqs_row.r3_ingot_ref
                    ,get_test_reqs_row.sales_order
                    ,get_test_reqs_row.line_item
                    ,get_test_reqs_row.customer
                    ,get_test_reqs_row.spec_code_id
                    ,get_test_reqs_row.ship_we_day
                    ,get_test_reqs_row.ship_we_mon
                    ,get_test_reqs_row.ship_we_year
                    ,lv_test_type
                    ,lv_legend
                    );
      END IF;
    END LOOP test_requirements; -- End loop of test requirements
    COMMIT; -- Commit status records
  /*
  ||
  || EXCEPTION HANDLER SECTION
  ||
  */
  --
  -- Capture any untrapped errors and record details
  --
  EXCEPTION
    WHEN OTHERS THEN
      lv_error_code   := SQLCODE;
      lv_error_msg    := SUBSTR (SQLERRM, 1, 200);
  --
  -- Exit procedure
  --
  END Batch_Status;

  PROCEDURE calc_all_results (p_spec_code_id           IN     NUMBER
                             ,p_process_order          IN     VARCHAR2
                             ,p_heat_no                IN     VARCHAR2
                             ,lv_site                  IN     VARCHAR2
                             ,empty_result                OUT VARCHAR2
                             ,lv_missing_element          OUT VARCHAR2
                             ) IS
    lv_sample_id             TE_TEST_SAMPLE_ID.sample_id%TYPE;
    lv_heat_no               TE_TEST_SAMPLE_ID.process_order_no%TYPE;
    lv_tcode                 TE_TEST_RESULTS.test_code%TYPE;
    lv_calc_yn               TE_TEST_RESULTS.calc_result%TYPE;
    ex_calc_failed           EXCEPTION;
    lr_sample_result_rec     Pk_Test_Result_Rounding.sample_result_rec;
    lr_load_limits_rec       Pk_Test_Result_Rounding.load_limits_rec;

    CURSOR get_samples (p_process_order_no IN TE_TEST_SAMPLE_ID.process_order_no%TYPE) IS
      SELECT sample_id
        FROM TE_TEST_SAMPLE_ID
       WHERE process_order_no = p_process_order_no;

    CURSOR get_test_codes IS
      SELECT test_code, calc_result
        FROM TE_TEST_RESULTS
       WHERE sample_id = lv_sample_id;
  BEGIN
  
    --DEBUG_REC('Site is '||lv_site);
    IF lv_site IN ('11', '13', '20', '26') THEN
      lv_heat_no   := p_process_order;
    ELSE
      lv_heat_no   := p_heat_no;
    END IF;
    
    --DEBUG_REC('Determined Heat Number is : '||lv_heat_no);
    
    empty_result         := 'N'; -- Set empty_result to NO
    lv_missing_element   := 'N'; -- Set missing_element to No.
    OPEN get_samples (p_process_order_no => lv_heat_no);
    --DEBUG_REC('Getting Samples using process_order_no = '||lv_heat_no);
    LOOP
      -- Grabs samples from batch or heat to calculate the results.
      FETCH get_samples INTO lv_sample_id;
      EXIT WHEN get_samples%NOTFOUND;
      OPEN get_test_codes;
      --DEBUG_REC('Getting test_codes for sample = '||to_char(lv_sample_id));  
     LOOP
        FETCH get_test_codes
        INTO lv_tcode, lv_calc_yn;
        EXIT WHEN get_test_codes%NOTFOUND;
        IF lv_calc_yn = 'Y' THEN
        --DEBUG_REC('Found Calculated Test Result = '||lv_tcode);
          lr_sample_result_rec             := NULL;
          lr_load_limits_rec               := NULL;
          lr_sample_result_rec.sample_id   := lv_sample_id;
          lr_sample_result_rec.test_code   := lv_tcode;
          --DEBUG_REC('Calling pk_test_results.pr_calc_result');
          Pk_Test_Results.pr_calc_result (p_sample_result_rec => lr_sample_result_rec, p_load_limits_rec => lr_load_limits_rec);
          --DEBUG_REC('Back from call, act_result = '||lr_sample_result_rec.act_result);
          
          IF lr_sample_result_rec.act_result = 'X' THEN
            -- Error performing calculation. Inform user.
            empty_result   := 'Y';
          -- The M represents that an element for the caculation was missing in the TE_TEST_RESULTS table.
          ELSIF lr_sample_result_rec.act_result = 'M' THEN
            lv_missing_element   := 'Y';
          ELSE -- 4.12 changes
            -- Adds the newly caculated results to the     TE_TEST_RESULTS table.
            --DEBUG_REC ('About to update tests results for sample_id = '||to_char(lr_sample_result_rec.sample_id)||' and test code = '||lr_sample_result_rec.test_code);
            --DEBUG_REC ('...with ack_result = '||lr_sample_result_rec.ack_result||' and act result = '||lr_sample_result_rec.act_result);
            UPDATE TE_TEST_RESULTS
               SET ack_result = lr_sample_result_rec.ack_result, act_result = lr_sample_result_rec.act_result
             WHERE sample_id = lr_sample_result_rec.sample_id AND test_code = lr_sample_result_rec.test_code;
          END IF;
        END IF;
      END LOOP;
      CLOSE get_test_codes;
    END LOOP;
    CLOSE get_samples;
  END calc_all_results;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to perform any calculation for the given test code.
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE pr_calc_result (p_sample_result_rec      IN OUT Pk_Test_Result_Rounding.sample_result_rec
                           ,p_load_limits_rec        IN OUT Pk_Test_Result_Rounding.load_limits_rec
                           ,p_load_record            IN     BOOLEAN DEFAULT TRUE
                           ,pvcResultTable_in        IN     VARCHAR2 DEFAULT 'te_test_results'
                           ) IS
    vcActResult            TE_TEST_RESULTS.act_result%TYPE;
    nmActResult            NUMBER;
    vcActResult2           NUMBER;
    nmCalcResult           NUMBER := 0;
    nmActResult2           NUMBER := 0;
    vcTemp                 VARCHAR2 (20);
    nmPrecision            NUMBER := -1;
    nmOrderBy              NUMBER;
    vcCalcOrEntered        TE_TEST_CODES.calc_or_entered%TYPE;
    vcCalcRoutine          TE_TEST_CODES.calc_routine%TYPE;

    TYPE refCur IS REF CURSOR;

    crGetResult            refCur;
    vcColumnName           VARCHAR2 (10);
    vcCursorSelectStmt     VARCHAR2 (1000);

    --
    -- CURSORS:
    --
    -- Cursor to read for calculation formula
    --
    CURSOR crGetEquivalence (cpTestCode_in IN TE_TEST_RESULTS.test_code%TYPE) IS
      SELECT component_test_code, OPERATOR, factor, component_test_code2
        FROM ST_EQUIVALENCE_FORMULA
       WHERE collective_test_code = cpTestCode_in;

    CURSOR crGetTestCode (cpvcTestCode_in IN TE_TEST_RESULTS.test_code%TYPE) IS
      SELECT calc_or_entered, calc_routine
        FROM TE_TEST_CODES
       WHERE test_code = cpvcTestCode_in;

    --
    -- Exceptions and error handling
    --
    Missing_Result         EXCEPTION; -- Used to handle a missing component result
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --DEBUG_REC('Starting pk_test_resuls.pr_calc_results');
    IF p_load_record THEN
      Pk_Test_Result_Rounding.pr_populate_result_recs (p_sample_result_rec        => p_sample_result_rec
                                                      ,p_load_limits_rec          => p_load_limits_rec
                                                      );
    END IF;
    -- All values should be null for the calculation. However, as the form may have saved information
    -- to the database, or we're doing a recalculation, there will be results in the record structure
    -- which cause problems with reporting the calculation correctly.
    p_sample_result_rec.act_result       := NULL;
    p_sample_result_rec.act_result_rnd   := NULL;
    p_sample_result_rec.ack_result       := NULL;
    vcCursorSelectStmt                   := 'SELECT act_result, 0 order_by ' || 'FROM te_test_results ' ||
                                            'WHERE sample_id = :si ' || 'AND test_code = :tc ' || 'AND rec_status = ''A'' ';
    IF pvcResultTable_in = 'cp_cert_results' THEN
      vcCursorSelectStmt      := vcCursorSelectStmt || 'UNION ' || 'SELECT result act_result, 1 order_by ' || 'FROM ' ||
                                 pvcResultTable_in || ' ' || 'WHERE sample_id = :si2 ' || 'AND test_code = :tc2 ';
    END IF;
    -- The order_by option ensures tha result from te_test_results is used for the calculations if there is a
    -- corresponding result in cp_cert_results. The union should only use test codes from cp_cert_results that
    -- are calculations that need to exist for other calculations not on a spec. Ex: TRANS-064 must exist for
    -- TRANS-64 to be calculated. If Toronto puts both of these on a spec then the TRANS-64 calc has to look
    -- at the cp_cert_results because it probably won't exist in te_test_results. However, if it does, it will
    -- instead correctly use the value from te_test_results.
    vcCursorSelectStmt                   := vcCursorSelectStmt || 'ORDER BY order_by';
    OPEN crGetTestCode (cpvcTestCode_in => p_sample_result_rec.test_code);
    FETCH crGetTestCode
    INTO vcCalcOrEntered, vcCalcRoutine;
    CLOSE crGetTestCode;
  --DEBUG_REC('Test Code : '||p_sample_result_rec.test_code);
  --DEBUG_REC('Calc or Entered : '||vcCalcOrEntered);
  --DEBUG_REC('Calc Routine : '||vcCalcRoutine);
    
    IF vcCalcOrEntered = 'C' THEN
      --
      -- Loop thru all component codes for this test code
      --
    --DEBUG_REC('Looping through Components');
      
      FOR frGetEquivalence IN crGetEquivalence (cpTestCode_in => p_sample_result_rec.test_code) LOOP
        vcTemp        := frGetEquivalence.component_test_code;
        --DEBUG_REC('Processing Component : '||vcTemp);
        IF pvcResultTable_in != 'cp_cert_results' THEN
          OPEN crGetResult FOR vcCursorSelectStmt USING p_sample_result_rec.sample_id, frGetEquivalence.component_test_code;
        ELSE
          OPEN crGetResult FOR vcCursorSelectStmt
            USING p_sample_result_rec.sample_id
                 ,frGetEquivalence.component_test_code
                 ,p_sample_result_rec.sample_id
                 ,frGetEquivalence.component_test_code;
        END IF;
        FETCH crGetResult
        INTO vcActResult, nmOrderBy;
        --DEBUG_REC('Act Result = '||vcActResult);
        --DEBUG_REC('order by   = '||to_char(nmOrderby));
        nmActResult   := Pk_Test_Result_Rounding.fn_remove_operator (p_act_result => vcActResult);
        --DEBUG_REC('About to call pk_Test_Result_Rounding.pr_set_precision');
        --DEBUG_REC('p_act_result = '||vcActResult);
        --DEBUG_REC('p_spec_code_id = '||p_load_limits_rec.spec_code_id);
        Pk_Test_Result_Rounding.pr_set_precision (p_act_result               => vcActResult
                                                 ,p_precision                => nmPrecision
                                                 ,p_sample_result_rec        => p_sample_result_rec
                                                 ,p_spec_code_id             => p_load_limits_rec.spec_code_id
                                                 );
        --DEBUG_REC('back from pr_set_precision, precision is : '||to_char(nmPrecision));
        IF crGetResult%FOUND THEN
          IF nmActResult IS NULL THEN
            CLOSE crGetResult;
            -- Result is missing, set cal result to 0
            RAISE Missing_Result;
          ELSE
            CLOSE crGetResult;
            IF frGetEquivalence.component_test_code2 IS NOT NULL THEN
              IF pvcResultTable_in != 'cp_cert_results' THEN
                OPEN crGetResult FOR vcCursorSelectStmt USING p_sample_result_rec.sample_id, frGetEquivalence.component_test_code2;
              ELSE
                OPEN crGetResult FOR vcCursorSelectStmt
                USING p_sample_result_rec.sample_id
                     ,frGetEquivalence.component_test_code2
                     ,p_sample_result_rec.sample_id
                     ,frGetEquivalence.component_test_code2;
              END IF;
              FETCH crGetResult
              INTO vcActResult2, nmOrderBy;
              --DEBUG_REC('Act Result = '||vcActResult);
              --DEBUG_REC('order by   = '||to_char(nmOrderby));
              nmActResult2   := Pk_Test_Result_Rounding.fn_remove_operator (p_act_result => vcActResult2);
              
              --DEBUG_REC('Operator is : '||frGetEquivalence.OPERATOR);
              -- We have the result, apply the factor and operator to it.
              IF frGetEquivalence.OPERATOR = '+' THEN
                nmActResult   := nmActResult + nmActResult2;
              ELSIF frGetEquivalence.OPERATOR = '-' THEN
                nmActResult   := nmActResult - nmActResult2;
              ELSIF frGetEquivalence.OPERATOR = '*' THEN
                nmActResult   := nmActResult * nmActResult2;
              ELSE
                nmActResult   := nmActResult / nmActResult2;
              END IF;
              -- Add this component to the final calculated result
              --DEBUG_REC ('Previous Value of nmCalcResult : '||to_char(nmCalcResult));
              --DEBUG_REC ('Act result to be factored in   : '||to_char(nmActResult));
              nmCalcResult   := nmCalcResult + nmActResult;
              --DEBUG_REC ('New Value of nmCalcResult      : '||to_char(nmCalcResult));              
            ELSE                     
              --DEBUG_REC('Operator is : '||frGetEquivalence.OPERATOR);
              -- We have the result, apply the factor and operator to it.
              IF frGetEquivalence.OPERATOR = '+' THEN
                nmActResult   := nmActResult + frGetEquivalence.factor;
              ELSIF frGetEquivalence.OPERATOR = '-' THEN
                nmActResult   := nmActResult - frGetEquivalence.factor;
              ELSIF frGetEquivalence.OPERATOR = '*' THEN
                nmActResult   := nmActResult * frGetEquivalence.factor;
              ELSE
                nmActResult   := nmActResult / frGetEquivalence.factor;
              END IF;
              -- Add this component to the final calculated result
              --DEBUG_REC ('Previous Value of nmCalcResult : '||to_char(nmCalcResult));
              --DEBUG_REC ('Act result to be factored in   : '||to_char(nmActResult));
              nmCalcResult   := nmCalcResult + nmActResult;
              --DEBUG_REC ('New Value of nmCalcResult      : '||to_char(nmCalcResult));
            END IF;   
          END IF;
        ELSE
          p_sample_result_rec.act_result   := 'M';
          CLOSE crGetResult;          
        END IF;

      END LOOP;
    ELSIF vcCalcOrEntered = 'X' THEN
      EXECUTE IMMEDIATE 'BEGIN :1 := ' || vcCalcRoutine || '(:2, :3); END;'
        USING OUT p_sample_result_rec.act_result, IN p_sample_result_rec.sample_id, IN p_sample_result_rec.test_code;
    END IF;
    IF NVL (p_sample_result_rec.act_result, 'A') NOT IN ('M', 'X') THEN
      IF vcCalcOrEntered = 'C' THEN
        --DEBUG_REC('About to set p_sample_result_rec.act_result = '||to_char(nmCalcResult));
        p_sample_result_rec.act_result   := SUBSTR (TO_CHAR (nmCalcResult), 1, 10);
      ELSIF vcCalcOrEntered = 'X' THEN
        p_sample_result_rec.ack_result   := p_sample_result_rec.act_result;
      END IF;
      -- The limits must be loaded so the number of decimals can be retrieved for the test code.
      -- If the current precision is greater than the decimals on the spec code the decimals from
      -- the spec code must be used instead.
    --DEBUG_REC('About to call pk_test_result_rounding.pr_load_limits');
      Pk_Test_Result_Rounding.pr_load_limits (p_sample_result_rec => p_sample_result_rec, p_load_limits_rec => p_load_limits_rec);
      -- Only adjust decimals if calculated since complex calculations do their own rounding
      IF vcCalcOrEntered = 'C' THEN
        
      --DEBUG_REC('p_load_limits_rec.decimals = '||to_char(p_load_limits_rec.decimals));
      --DEBUG_REC('nmPrecision = '||to_char(nmPrecision));
        IF p_load_limits_rec.decimals < nmPrecision THEN
          nmPrecision   := p_load_limits_rec.decimals;
        END IF;
      --DEBUG_REC('About to call pk_test_result_rounding.pr_adjust_decimals with precision : '||to_char(nmPrecision));
        Pk_Test_Result_Rounding.pr_adjust_decimals (p_spec_code_id_in          => p_load_limits_rec.spec_code_id
                                                   ,p_no_of_decimals           => nmPrecision
                                                   ,p_sample_result_rec        => p_sample_result_rec
                                                   ,p_is_adjust_for_limit      => FALSE
                                                   );
      --DEBUG_REC('Back from adjust decimals');
      --DEBUG_REC('p_sample_result_rec.act_result     = '||p_sample_result_rec.act_result);
      --DEBUG_REC('p_sample_result_rec.act_result_rnd = '||p_sample_result_rec.act_result_rnd);
      --DEBUG_REC('p_sample_result_rec.ack_result     = '||p_sample_result_rec.ack_result);
        
      END IF;
      
    --DEBUG_REC('Setting p_sample_result_act_result to '||p_sample_result_rec.ack_result);
      p_sample_result_rec.act_result       := p_sample_result_rec.ack_result;
    --DEBUG_REC('Setting p_sample_result_rec.act_result_rnd to NULL');
      
      p_sample_result_rec.act_result_rnd   := NULL;
    --DEBUG_REC('Setting p_sample_result_rec.act_result to NULL');
      p_sample_result_rec.ack_result       := NULL;
    --DEBUG_REC('About to call check limits');
      Pk_Test_Result_Rounding.pr_check_limits (p_sample_result_rec => p_sample_result_rec, p_load_limits_rec => p_load_limits_rec);
    --DEBUG_REC('About to leave pr_calc_result');
    --DEBUG_REC('p_sample_result_rec.act_result     = '||p_sample_result_rec.act_result);
    --DEBUG_REC('p_sample_result_rec.act_result_rnd = '||p_sample_result_rec.act_result_rnd);
    --DEBUG_REC('p_sample_result_rec.ack_result     = '||p_sample_result_rec.ack_result);
    END IF;
  /*
  ||
  || EXCEPTIONS:
  ||
  */
  --
  -- Missing result
  --
  EXCEPTION
    WHEN Missing_Result THEN
      p_sample_result_rec.act_result       := '';
      p_sample_result_rec.act_result_rnd   := '';
  END pr_calc_result;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to populate PL/SQL table with the order and specs a given batch is linked to.
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE get_order_specs (table_data IN OUT order_spec_tab, p_batch_no IN VARCHAR2) IS
    --
    -- Local variables
    --
    lv_index     NUMBER;

    --
    -- CURSORS:
    --
    -- Cursor to get the orders and specs the batch is linked to
    --
    CURSOR get_linked_order_specs IS
        SELECT po.r3_sales_order
              ,po.r3_sales_order_item
              ,po.process_order_status
              ,soi.spec_code_id
              ,soi.plant_no
              ,sch.spec_code_name
              ,sch.alloy_code
              ,po.date_created -- sch.date_created
          FROM R3_PROCESS_ORDERS po, R3_SALES_ORDER_ITEMS soi, TE_SPEC_CODE_HEADER sch
         WHERE po.r3_process_order = p_batch_no
           AND po.process_order_status != 'E'
           AND po.r3_sales_order = soi.r3_sales_order
           AND po.r3_sales_order_item = soi.r3_sales_order_item
           AND soi.spec_code_id = sch.spec_code_id
      ORDER BY po.date_created DESC; -- sch.date_created DESC;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Loop thru the cursor rows and populate the PL/SQL table
    --
    lv_index   := 1;
    FOR get_linked_order_specs_row IN get_linked_order_specs LOOP
      table_data (lv_index).sales_order        := get_linked_order_specs_row.r3_sales_order;
      table_data (lv_index).sales_order_item   := get_linked_order_specs_row.r3_sales_order_item;
      table_data (lv_index).spec_code_id       := get_linked_order_specs_row.spec_code_id;
      table_data (lv_index).spec_code_name     := get_linked_order_specs_row.spec_code_name;
      table_data (lv_index).Batch_Status       := get_linked_order_specs_row.process_order_status;
      table_data (lv_index).plant_no           := get_linked_order_specs_row.plant_no;
      table_data (lv_index).alloy_code         := get_linked_order_specs_row.alloy_code;
      table_data (lv_index).date_created       := get_linked_order_specs_row.date_created;
      lv_index                                 := lv_index + 1;
    END LOOP;
  END get_order_specs;

  PROCEDURE prGetOrderSpec (rcOrderSpec_inOut IN OUT order_spec_recs) IS
    CURSOR crGetLinkedOrderSpec (
      cpvcSalesOrder_in        IN r3_sales_order_items.r3_sales_order%TYPE
     ,cpvcSalesOrderItem_in    IN r3_sales_order_items.r3_sales_order_item%TYPE) IS
      SELECT sch.spec_code_id, sch.spec_code_name
        FROM R3_SALES_ORDER_ITEMS soi, TE_SPEC_CODE_HEADER sch
       WHERE soi.r3_sales_order = cpvcSalesOrder_in
         AND soi.r3_sales_order_item = cpvcSalesOrderItem_in
         AND soi.spec_code_id = sch.spec_code_id;
  BEGIN
    OPEN crGetLinkedOrderSpec (cpvcSalesOrder_in          => rcOrderSpec_inOut.sales_order
                              ,cpvcSalesOrderItem_in      => rcOrderSpec_inOut.sales_order_item);
    FETCH crGetLinkedOrderSpec
    INTO rcOrderSpec_inOut.spec_code_id, rcOrderSpec_inOut.spec_code_name;
    CLOSE crGetLinkedOrderSpec;
  END prGetOrderSpec;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to return the sample type for the given test type.
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE get_sample_type (p_test_type IN VARCHAR2, p_sample_type OUT VARCHAR2) IS
    --
    -- CURSORS:
    --
    -- Cursor to get the sample type
    --
    CURSOR cur_get_sample_type IS
      SELECT sample_type
        FROM TE_TEST_TYPES
       WHERE test_type = p_test_type;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Get the sample type
    --
    OPEN cur_get_sample_type;
    FETCH cur_get_sample_type INTO p_sample_type;
    CLOSE cur_get_sample_type;
  END get_sample_type;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to return the test requirement for the given spec
  || using a PL/SQL table of records.
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE get_test_reqmnt (block_data IN OUT test_type_tab, p_spec_code_id IN NUMBER) IS
    --
    -- Local variables
    --
    lv_index     NUMBER;

    --
    -- CURSORS:
    --
    -- Cursor to get the test requirement for the given spec
    --
    CURSOR get_test_req IS
        SELECT DISTINCT scl.test_type, tt.descr
          FROM TE_SPEC_CODE_LIMITS scl, TE_TEST_TYPES tt
         WHERE scl.spec_code_id = p_spec_code_id AND tt.test_type = scl.test_type
      ORDER BY scl.test_type;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Loop through the test requirement and populate PL/SQL table
    --
    lv_index   := 1;
    FOR get_test_req_row IN get_test_req LOOP
      block_data (lv_index).test_type   := get_test_req_row.test_type;
      block_data (lv_index).descr       := get_test_req_row.descr;
      lv_index                          := lv_index + 1;
    END LOOP;
  END get_test_reqmnt;

  /*------------------------------------------------------------------------------------
  ||
  || Proceedure to create 'empty' result rows directly after a new
  || sample has been inserted
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE p_create_result_rows (p_sample_id_in           IN     NUMBER
                                 ,p_spec_code_id_in        IN     NUMBER
                                 ,p_test_type_in           IN     VARCHAR2
                                 ,p_test_code              IN     VARCHAR2
                                 ,p_error                     OUT NUMBER
                                 ,p_error_msg                 OUT VARCHAR2
                                 ,p_uom_override           IN     VARCHAR2 DEFAULT 'DEFAULT'
                                 ) IS
    --
    -- Local variables
    --
    lv_test_code       VARCHAR2 (10); -- Holds test code from spec
    lv_uom             VARCHAR2 (4); -- Holds minimum value unit of measure
    lv_report_yn       VARCHAR2 (1); -- Holds report flag value from spec
    lv_calc_result     VARCHAR2 (1); -- Holds 'Y' if result can be calculated
    lv_seq_no          NUMBER; -- Holds test code print sequence number
    lv_ref_cur         Pk_Test_Results.te_ref_cur;
  /*
  ||
  || PROCEDURE EXECUTION SECTION
  ||
  */
  BEGIN
    --
    -- Loop thru the test codes from the spec
    --
    lv_ref_cur   := Pk_test_Results.fn_spec_code_limits_cur (p_spec_code_id_in, p_test_type_in, p_test_code);
    LOOP
      FETCH lv_ref_cur
      INTO lv_test_code, lv_report_yn, lv_uom;
      EXIT WHEN lv_ref_cur%NOTFOUND;
      -- Get the print seq no for the test code
      lv_seq_no        := Pk_Test_Results.fn_get_test_code_seq_no (p_test_type_in, lv_test_code);
      -- Check if result can be calculated
      lv_calc_result   := Pk_Test_Results.fn_get_calc_yn (lv_test_code);
      -- The te_lb_0208_add_tests form can override the UoM in the case of making duplicate samples
      -- or at the time of test creation. Thus a need to be able to have the correct UoM inserted with the record.
      IF p_uom_override != 'DEFAULT' THEN
        lv_uom   := p_uom_override;
      END IF;
      --
      -- Insert test code into te_test_results
      --
      INSERT INTO TE_TEST_RESULTS (sample_id
                                  ,test_code
                                  ,valid_result
                                  ,act_result_uom
                                  ,seq_no
                                  ,calc_result
                                  )
           VALUES (p_sample_id_in
                  ,lv_test_code
                  ,lv_report_yn
                  ,lv_uom
                  ,lv_seq_no
                  ,lv_calc_result
                  );
    END LOOP;
    CLOSE lv_ref_cur;
    p_error      := 0;
  /*
  ||
  || EXCEPTION HANDLING
  ||
  */
  EXCEPTION
    WHEN OTHERS THEN
      CLOSE lv_ref_cur;
      p_error       := SQLCODE;
      p_error_msg   := SUBSTR (SQLERRM, 1, 200);
      Pk_Error_Log.prRecordDetails (p_error
                                   ,p_error_msg
                                   ,'Pk_Test_Results.p_create_result_rows'
                                   ,TO_CHAR (p_sample_id_in) || lv_test_code
                                   );
  /*
  ||
  || End create result rows
  ||
  */
  END p_create_result_rows;

  /*------------------------------------------------------------------------------------
  ||
  || Used to count NSN results for reporting in Test Results and Release and Report
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE pr_count_nsn (p_batch_number           IN     TE_TEST_SAMPLE_ID.process_order_no%TYPE
                         ,p_heat_number            IN     TE_TEST_SAMPLE_ID.cast_no%TYPE
                         ,p_batch_count            IN OUT NUMBER
                         ,p_heat_count             IN OUT NUMBER
                         ) IS
  BEGIN
    SELECT heat_count, batch_count
      INTO p_heat_count, p_batch_count
      FROM (SELECT COUNT (*) heat_count
              FROM NSVIEW
             WHERE ns_cast = p_heat_number AND ns_rec_status = 'A')
          ,(SELECT COUNT (*) batch_count
              FROM NSVIEW
             WHERE ns_po = p_batch_number AND ns_rec_status = 'A');
  END pr_count_nsn;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to create a requisition row.
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE pr_create_requisition (p_req_id_in IN NUMBER) --
                                                          -- Creates a row in TE_REQUISITIONS for the given req_id. Initially called from
                                                          -- te_0201_sample_booking to create a req 'header' for multiple samples booked
                                                          -- for the SAME test type and therefore ALL with the same requisition ID.
                                                          --
  IS
    /*
    ||
    || DECLARATIVE SECTION
    ||
    */
    --
    -- Local variables
    --
    recReqDetails     TE_REQUISITIONS%ROWTYPE;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Insert a requisition record
    --
    recReqDetails.requisition_id   := p_req_id_in;
    recReqDetails.status           := NULL;
    recReqDetails.description      := 'Created via sample booking form.';
    recReqDetails.lab_ref          := NULL;
    recReqDetails.date_created     := TRUNC (SYSDATE);
    recReqDetails.time_created     := TO_CHAR (SYSDATE, 'HH24:MI:SS');
    recReqDetails.created_by       := USER;
    recReqDetails.date_updated     := NULL;
    recReqDetails.date_updated     := NULL;
    recReqDetails.last_update_by   := NULL;
    recReqDetails.EDITION          := 1;
    INSERT INTO TE_REQUISITIONS
         VALUES recReqDetails;
    COMMIT;
  --
  -- Exit pr_create_requisition
  --
  END pr_create_requisition;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to select multi spec information
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE pr_get_multi_spec_info (p_spec_code_id           IN     TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                                   ,p_multi_spec_code_id        OUT TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                                   ,p_multi_spec_name           OUT TE_MULTI_SPEC_SET.multi_spec_name%TYPE
                                   ) IS
    CURSOR get_main_multi_spec (p_spec_code_id IN NUMBER) IS
      SELECT multi_spec_code_id, multi_spec_name
        FROM te_multi_spec_set
       WHERE multi_spec_code_id = p_spec_code_id;
  BEGIN
    OPEN get_main_multi_spec (p_spec_code_id);
    FETCH get_main_multi_spec
    INTO p_multi_spec_code_id, p_multi_spec_name;
    CLOSE get_main_multi_spec;
  END pr_get_multi_spec_info;

  PROCEDURE pr_get_result_failure_id (p_site                   IN     ST_SITES.site%TYPE
                                     ,p_spec_code_id           IN     TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                                     ,p_sample_type            IN     TE_TEST_SAMPLE_ID.sample_type%TYPE
                                     ,p_failure_type           IN     VARCHAR2
                                     ,p_event_id                  OUT TE_TEST_FAILURE_EVENTS.event_id%TYPE
                                     ,p_outcome_status            OUT Pk_Email.pv_outcome_status%TYPE
                                     ,p_outcome_message           OUT Pk_Email.pv_outcome_message%TYPE
                                     ) IS
    lv_metal_type     TE_SPEC_CODE_HEADER.metal_type%TYPE;

    CURSOR get_metal_type (p_spec_code_id_in te_spec_code_header.spec_code_id%TYPE) IS
      SELECT metal_type
        FROM te_spec_code_header
       WHERE spec_code_id = p_spec_code_id;
  BEGIN
    p_outcome_status   := '000';
    IF pk_test_results.fn_get_parameter (p_site, 'CHECK_METAL_TYPE') = 'Y' THEN
      OPEN get_metal_type (p_spec_code_id_in => p_spec_code_id);
      FETCH get_metal_type INTO lv_metal_type;
      CLOSE get_metal_type;
      IF lv_metal_type IS NULL THEN
        p_outcome_status    := '-1';
        p_outcome_message   := '621';
        p_event_id          := NULL;
        Pk_Star_Programs.p_raise_star_error (pn_mess_no_in => 621);
      END IF;
    ELSE
      lv_metal_type   := '%';
    END IF;
    IF p_outcome_status = '000' THEN
      Pk_Email.pr_get_us_event_id (p_site
                                  ,lv_metal_type
                                  ,p_sample_type
                                  ,p_failure_type
                                  ,p_event_id
                                  ,p_outcome_status
                                  ,p_outcome_message
                                  );
      IF p_outcome_status <> '000' THEN
        p_outcome_status    := '-1';
        p_outcome_message   := '376';
        p_event_id          := NULL;
        Pk_Star_Programs.p_raise_star_error (pn_mess_no_in => 376);
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_outcome_status    := TO_CHAR (SQLCODE);
      p_outcome_message   := SQLERRM;
      Pk_Star_Programs.p_raise_star_error (pn_mess_no_in              => 0
                                          ,pc_param1_in               => 'pr_get_failure_event_id: Error is - ' ||
                                                                        p_outcome_message
                                          );
  END pr_get_result_failure_id;

  PROCEDURE pr_get_rounding_rules (p_heat_no                IN     LAB_TESTS_VIEW.heat_number%TYPE
                                  ,p_test_area              IN     TE_TEST_SAMPLE_ID.test_area%TYPE
                                  ,p_test_code              IN     TE_TEST_RESULTS.test_code%TYPE
                                  ,p_sample_type            IN     TE_TEST_SAMPLE_ID.sample_type%TYPE
                                  ,p_material_id            IN     RM_MATERIALS.material_id%TYPE
                                  ,p_rule_id                   OUT RESULT_ROUNDING_VIEW.rule_identifier%TYPE
                                  ,p_no_decimals               OUT NUMBER
                                  ) IS
    lv_alloy_or_material     result_rounding_view.alloy_or_material%TYPE;
    lv_ref_cur               Pk_Test_Results.te_ref_cur;
    lv_sql_stmt              VARCHAR2 (2000)
                               := 'SELECT rrv.rule_identifier, rrv.no_of_decimals' ||
                                  ' FROM result_rounding_view rrv, TE_TEST_AREAS ta' || ' WHERE ta.test_area = :ta' ||
                                  ' AND rrv.rule_identifier = ta.rule_identifier' || ' AND rrv.test_code = :tc' ||
                                  ' AND rrv.alloy_or_material = ';
  BEGIN
    p_rule_id       := NULL;
    p_no_decimals   := 0;
    IF p_sample_type != 'R' THEN
      -- Manufacturing batch
      lv_sql_stmt   := lv_sql_stmt || '(SELECT alloy_code' || ' FROM st_heat_view' || ' WHERE heat_no = :hn)';
      OPEN lv_ref_cur FOR lv_sql_stmt USING p_test_area, p_test_code, p_heat_no;
      FETCH lv_ref_cur
      INTO p_rule_id, p_no_decimals;
      CLOSE lv_ref_cur;
    ELSE
      -- Raw material
      lv_sql_stmt   := lv_sql_stmt || '(SELECT material_code' || ' FROM RM_MATERIALS' || ' WHERE material_id = :hn)';
      OPEN lv_ref_cur FOR lv_sql_stmt USING p_test_area, p_test_code, p_material_id;
      FETCH lv_ref_cur
      INTO p_rule_id, p_no_decimals;
      CLOSE lv_ref_cur;
    END IF;
  END pr_get_rounding_rules;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to retrieve order / item details for the given spec ID
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE prGetOrderDetails (p_SpecCodeId_in          IN     te_spec_code_header.spec_code_id%TYPE
                              ,p_recOrderDetails_out       OUT pk_test_results.rt_OrderDetails
                              ) IS
  /*
  ||
  || DECLARATIVE SECTION
  ||
  */
  --
  -- Exceptions and error handling
  --
  /*
  ||
  || EXECUTION SECTION
  ||
  */
  BEGIN
    --
    -- Read for the order / item for the given spec ID
    --
    SELECT r3_sales_order, r3_sales_order_item
      INTO p_recOrderDetails_out
      FROM r3_sales_order_items
     WHERE spec_code_id = p_SpecCodeId_in;
  /*
  ||
  || EXCEPTIONS
  ||
  */
  EXCEPTION
    --
    -- Order details not found
    --
    WHEN NO_DATA_FOUND THEN
      -- Will utilise error package eventually here. For now return '*' in order number
      p_recOrderDetails_out.vcR3SalesOrder   := '*';
    --
    -- Untrapped errors
    --
    WHEN OTHERS THEN
      -- Will utilise error package eventually here. For now return '*' in order number
      p_recOrderDetails_out.vcR3SalesOrder   := '*';
  --
  -- Exit prGetOrderDetails
  --
  END prGetOrderDetails;

  PROCEDURE pr_insert_result_email (p_limit_rec              IN Pk_Test_Result_Rounding.load_limits_rec
                                   ,p_sample_rec             IN Pk_Test_Result_Rounding.sample_result_rec
                                   ,p_email_event_id         IN ST_EVENTS.event_id%TYPE
                                   ) IS
    ln_feed_id        TE_TEST_SAMPLE_ID.feed_id%TYPE;
    lv_lot_status     VARCHAR2 (1);

    CURSOR get_sample_data (p_sample_id IN TE_TEST_SAMPLE_ID.sample_id%TYPE) IS
      SELECT feed_id
        FROM te_test_sample_id
       WHERE sample_id = p_sample_id;
  BEGIN
    IF p_sample_rec.rm_material_id IS NOT NULL THEN
      -- If we are dealing with a RM lot, check if a result being booked is for a lot
      -- that has already been released into formulation, (lot_status = 'R'), and that
      -- we have not already raised STAR WATCH if true.
      -- get feed id
      OPEN get_sample_data (p_sample_id => p_sample_rec.sample_id);
      FETCH get_sample_data INTO ln_feed_id;
      CLOSE get_sample_data;
      -- Check status of this lot
      lv_lot_status   := Pk_Raw_Materials.fn_get_lot_status (ln_feed_id);
      IF lv_lot_status = '*' THEN -- Lot status not found for this feed
        ROLLBACK;
        pk_star_programs.p_raise_star_error (731, p_sample_rec.process_order_no, TO_CHAR (ln_feed_id));
      ELSIF lv_lot_status = 'A' THEN -- Lot released to formulation.
        -- Lot released to formulation.
        INSERT INTO gtt_te_test_results (batch_no
                                        ,test_type
                                        ,test_code
                                        ,act_result
                                        ,email_type
                                        ,event_id
                                        )
             VALUES (p_sample_rec.process_order_no
                    ,p_sample_rec.test_type
                    ,p_sample_rec.test_code
                    ,p_sample_rec.act_result
                    ,'POST_FORMULATION'
                    ,p_email_event_id
                    );
      END IF;
    END IF;
    INSERT INTO GTT_TE_TEST_RESULTS (batch_no
                                    ,cast_no
                                    ,sample_type
                                    ,sample_id
                                    ,piece_id
                                    ,ht_code
                                    ,test_type
                                    ,test_code
                                    ,test_number
                                    ,act_result
                                    ,act_result_op
                                    ,min_limit
                                    ,max_limit
                                    ,failure_type
                                    ,event_id
                                    ,email_type
                                    ,spec_code_id
                                    ,spec_name
                                    ,multi_spec_code_id
                                    ,site
                                    ,sales_order
                                    ,sales_order_item
                                    )
         VALUES (
                  p_sample_rec.process_order_no
                 ,p_sample_rec.cast_no
                 ,p_sample_rec.sample_type
                 ,p_sample_rec.sample_id
                 ,p_sample_rec.piece_id
                 ,p_sample_rec.ht_code
                 ,p_sample_rec.test_type
                 ,p_sample_rec.test_code
                 ,p_sample_rec.test_number
                 ,p_sample_rec.act_result
                 ,p_sample_rec.act_result_op
                 ,DECODE (p_sample_rec.result_failure_type, 'S', p_limit_rec.spec_min_limit, p_limit_rec.conf_min_limit)
                 ,DECODE (p_sample_rec.result_failure_type, 'S', p_limit_rec.spec_max_limit, p_limit_rec.conf_max_limit)
                 ,p_sample_rec.result_failure_type
                 ,p_email_event_id
                 ,pk_test_results.fn_get_parameter (p_sample_rec.site, 'EMAIL')
                 ,p_limit_rec.spec_code_id
                 ,DECODE (p_sample_rec.rm_material_id
                         ,NULL, p_limit_rec.spec_limit_name
                         ,DECODE (p_sample_rec.result_failure_type, 'C', p_limit_rec.conf_limit_name, p_limit_rec.spec_limit_name)
                         )
                 ,p_limit_rec.multi_spec_code_id
                 ,p_sample_rec.site
                 ,p_sample_rec.sales_order
                 ,p_sample_rec.sales_order_item);
  END pr_insert_result_email;

  PROCEDURE pr_send_result_email_types IS
    lv_message_result     VARCHAR2 (500);
  BEGIN
    FOR i IN 1 .. 3 LOOP
      CASE i
        WHEN 1 THEN
          lv_message_result   := pk_test_results.fn_send_email ('POST_FORMULATION');
        WHEN 2 THEN
          lv_message_result   := pk_test_results.fn_send_email ('UK');
        ELSE
          lv_message_result   := pk_test_results.fn_send_email ('US');
      END CASE;
      IF SUBSTR (NVL (lv_message_result, '000'), 1, 3) <> '000' THEN
        ROLLBACK;
        pk_star_programs.p_raise_star_error (
          670
         ,SUBSTR ('[' || TRIM (SUBSTR (lv_message_result, 1, 10)) || '] [' || SUBSTR (lv_message_result, 11) || ']', 1, 120));
      END IF;
    END LOOP;
  END pr_send_result_email_types;

  PROCEDURE pr_set_sample_vas (p_material_type          IN     VARCHAR2
                              ,p_batch_number           IN     LAB_TESTS_VIEW.batch_number%TYPE
                              ,p_sales_order            IN     LAB_TESTS_VIEW.sales_order%TYPE
                              ,p_sales_order_item       IN     LAB_TESTS_VIEW.sales_order_item%TYPE
                              ,p_sample_id              IN     TE_TEST_SAMPLE_ID.sample_id%TYPE
                              ,p_site                   IN     ST_SITES.site%TYPE
                              ,p_display_rec           OUT Pk_Test_Results.sample_va_rec
                              ) IS
    lv_comment_count             NUMBER := 0;
    lv_limit_count               NUMBER := 0;
    lv_control_count             NUMBER := 0;
    lv_pass_2sigma               NUMBER := 0;
    lv_sample_id_copied_from     TE_TEST_SAMPLE_ID.sample_id_copied_from%TYPE := NULL;
    lv_is_raw_material           BOOLEAN;
    lv_test_area                 TE_TEST_SAMPLE_ID.test_area%TYPE;
    lv_process_order_no          TE_TEST_SAMPLE_ID.process_order_no%TYPE;
    lv_valid_sample_yn           TE_TEST_SAMPLE_ID.valid_sample_yn%TYPE;
    lv_sample_result_rec         Pk_Test_Result_Rounding.sample_result_rec;
    lr_load_limits_rec           Pk_Test_Result_Rounding.load_limits_rec;
    lv_dummy_number              NUMBER;

    CURSOR va_cur (
      p_sample_id TE_TEST_SAMPLE_ID.sample_id%TYPE) IS
        SELECT COUNT (tr.result_comment) + COUNT (tr.internal_comments) - trc.rc cc
              ,SUM (DECODE (tr.pass_two_sigma, 'N', 1, 0)) spts
              ,tsi.sample_id_copied_from
              ,tsi.test_area
              ,tsi.process_order_no
              ,tsi.valid_sample_yn
          FROM te_test_results tr
              ,te_test_sample_id tsi
              ,(SELECT COUNT (tr2.result_comment) rc
                  FROM te_test_results tr2, te_test_sample_id tsi2
                 WHERE tr2.sample_id = tsi2.sample_id
                   AND tsi2.sample_id = p_sample_id
                   AND UPPER (tr2.result_comment) = 'AVERAGED RESULT') trc
         WHERE tr.sample_id = tsi.sample_id AND tsi.sample_id = p_sample_id
      GROUP BY tsi.sample_id_copied_from
              ,tsi.test_area
              ,tsi.process_order_no
              ,trc.rc
              ,tsi.valid_sample_yn;

    CURSOR result_cur (p_sample_id IN TE_TEST_SAMPLE_ID.sample_id%TYPE) IS
      SELECT test_code
        FROM te_test_results
       WHERE sample_id = p_sample_id;
  BEGIN
    OPEN va_cur (p_sample_id => p_sample_id);
    FETCH va_cur
    INTO lv_comment_count, lv_pass_2sigma, lv_sample_id_copied_from, lv_test_area, lv_process_order_no, lv_valid_sample_yn;
    CLOSE va_cur;
    IF NVL (p_material_type, 'B') = 'B' THEN
      lv_is_raw_material   := FALSE;
    ELSE
      lv_is_raw_material   := TRUE;
    END IF;
    IF pk_test_results.fn_is_order_expired (lv_is_raw_material
                                           ,p_batch_number
                                           ,p_sales_order
                                           ,p_sales_order_item
                                           ,p_site
                                           ) THEN
      p_display_rec.sales_order_va   := 'VA_AMBER_RECORD';
    ELSE
      p_display_rec.sales_order_va   := 'VA_NORMAL_RECORD';
    END IF;
    IF lv_sample_id_copied_from IS NULL THEN
      p_display_rec.test_type_va   := 'VA_NORMAL_RECORD';
    ELSE
      p_display_rec.test_type_va   := 'VA_AMBER_RECORD';
    END IF;
    IF NVL(lv_valid_sample_yn,'Y') = 'N' THEN
      p_display_rec.sample_id_va   := 'VA_SAMPLE_INVALID_RESULT';    
    ELSE
      FOR result_rec IN result_cur (p_sample_id => p_sample_id) LOOP
        lv_sample_result_rec              := NULL;
        lr_load_limits_rec                := NULL;
        lv_sample_result_rec.sample_id    := p_sample_id;
        lv_sample_result_rec.test_code    := result_rec.test_code;
        Pk_Test_Result_Rounding.pr_populate_result_recs (p_sample_result_rec        => lv_sample_result_rec
                                                        ,p_load_limits_rec          => lr_load_limits_rec
                                                        );
        lv_sample_result_rec.ack_result   := NULL;
        Pk_Test_Result_Rounding.pr_Check_Limits (p_sample_result_rec => lv_sample_result_rec, p_load_limits_rec => lr_load_limits_rec);
        -- Limit VAs take precedence over control VAs. As such, as soon as we have a failed limit
        -- the loop can exit and need not check the rest of the records.
        IF lv_sample_result_rec.pass_limit = 'N' THEN
          lv_limit_count   := 1;
          EXIT;
        END IF;
        IF lv_sample_result_rec.pass_control = 'N' THEN
          lv_control_count   := lv_control_count + 1;
        END IF;
      END LOOP;
      IF lv_limit_count > 0 THEN
        IF lv_pass_2sigma > 0 THEN
          p_display_rec.sample_id_va   := 'VA_SAMPLE_OOS_2SIGMA';
        ELSIF lv_comment_count > 0 THEN
          p_display_rec.sample_id_va   := 'VA_SAMPLE_OOS_COMMENTS';
        ELSE
          p_display_rec.sample_id_va   := 'VA_SAMPLE_OOS_NORMAL';
        END IF;
      ELSIF lv_control_count > 0 THEN
        IF lv_pass_2sigma > 0 THEN
          p_display_rec.sample_id_va   := 'VA_SAMPLE_OOC_2SIGMA';
        ELSIF lv_comment_count > 0 THEN
          p_display_rec.sample_id_va   := 'VA_SAMPLE_OOC_COMMENTS';
        ELSE
          p_display_rec.sample_id_va   := 'VA_SAMPLE_OOC_NORMAL';
        END IF;
      ELSIF lv_pass_2sigma > 0 THEN
        p_display_rec.sample_id_va   := 'VA_2SIGMA';
      ELSIF lv_comment_count > 0 THEN
        p_display_rec.sample_id_va   := 'VA_SAMPLE_COMMENTS';
      ELSE
        p_display_rec.sample_id_va   := 'VA_NORMAL_RECORD';
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      Pk_Error_Log.prRecordDetailsHalt (p_SqlCode_in               => SQLCODE
                                       ,p_SqlErrm_in               => SQLERRM
                                       ,p_ModuleName_in            => 'Pk_Test_Results'
                                       ,p_KeyData_in               => 'Pr_Set_Sample_VAs for batch ' || p_batch_number ||
                                                                     ' and sample ' || TO_CHAR (p_sample_id)
                                       );
  END pr_set_sample_vas;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to reopen a batch
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE reopen_batch (p_batch_no IN VARCHAR2, p_sales_order IN VARCHAR2, p_sales_order_item IN VARCHAR2) IS
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Update the batch status
    --
    UPDATE R3_PROCESS_ORDERS
       SET process_order_status   = 'O'
     WHERE r3_process_order = p_batch_no AND r3_sales_order = p_sales_order AND r3_sales_order_item = p_sales_order_item;
    COMMIT;
  END reopen_batch;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to sign off a test sample
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE sign_off_sample (p_sample_id IN NUMBER, p_username IN VARCHAR2) IS
    --
    -- Local variables
    --
    lv_datetime     DATE; -- Holds the current system date and time
    lv_time         VARCHAR2 (8);

    --
    -- CURSORS:
    --
    -- Cursor to get the current date
    --
    CURSOR get_datetime IS
      SELECT SYSDATE FROM DUAL;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Get the current server data and time
    --
    OPEN get_datetime;
    FETCH get_datetime INTO lv_datetime;
    CLOSE get_datetime;
    lv_time   := TO_CHAR (lv_datetime, 'HH24:MI:SS');
    --
    -- Update the sign off data
    --
    UPDATE TE_TEST_SAMPLE_ID
       SET sign_off_status        = 'A'
          ,signed_unsigned_by     = p_username
          ,signed_unsigned_date   = lv_datetime
          ,signed_unsigned_time   = lv_time
     WHERE sample_id = p_sample_id;
    COMMIT;
  END sign_off_sample;

  /*------------------------------------------------------------------------------------
  ||
  || Procedure to unsign a test sample
  ||
  */
  ------------------------------------------------------------------------------------
  PROCEDURE unsign_sample (p_sample_id IN NUMBER, p_username IN VARCHAR2) IS
    --
    -- Local variables
    --
    lv_datetime     DATE; -- Holds the current system date and time
    lv_time         VARCHAR2 (8);

    --
    -- CURSORS:
    --
    -- Cursor to get the current date
    --
    CURSOR get_datetime IS
      SELECT SYSDATE FROM DUAL;
  /*
  ||
  || PROCEDURE LOGIC
  ||
  */
  BEGIN
    --
    -- Get the current server data and time
    --
    OPEN get_datetime;
    FETCH get_datetime INTO lv_datetime;
    CLOSE get_datetime;
    lv_time   := TO_CHAR (lv_datetime, 'HH24:MI:SS');
    --
    -- Update the sign off data
    --
    UPDATE TE_TEST_SAMPLE_ID
       SET sign_off_status        = NULL
          ,signed_unsigned_by     = p_username
          ,signed_unsigned_date   = lv_datetime
          ,signed_unsigned_time   = lv_time
     WHERE sample_id = p_sample_id;
    COMMIT;
  END unsign_sample;

  /*------------------------------------------------------------------------------------
    -- This procedure will update all associated test results for all samples within the
    -- heat. It updates the pass_two_sigma flag for each record because the average results
    -- table changes with each result entered. Once all results are in the calc_all_results
    -- procedure will update the average results table and then this procedure needs to be
    -- called for re-checking the pass/fail
  ||
  || NOTE: Currently only called by those sites that have TWO_SIGMA_CHECK parameter in
  ||       te_test_results_parameters set to 'Y'. As it stands this is only US sites and
  ||       they want the valid_result flag set according to the order spec. If UK sites
  ||       ever need this the logic to check the site will need to be added because
  ||       UK sites update the flag differently based on the pass_limit flag.
  */
  ------------------------------------------------------------------------------------
  PROCEDURE update_2sigma_samples_results (p_heat_no IN LAB_TESTS_VIEW.heat_number%TYPE) IS
    lv_pass_fail        TE_TEST_RESULTS.pass_two_sigma%TYPE;
    lv_valid_result     TE_TEST_RESULTS.valid_result%TYPE;

    CURSOR sample_cur (p_heat_no IN LAB_TESTS_VIEW.heat_number%TYPE) IS
      SELECT batch_number
            ,spec_code_id
            ,sample_id
            ,test_type
        FROM LAB_TESTS_VIEW
       WHERE heat_number = p_heat_no;

    CURSOR results_cur (p_sample_id IN TE_TEST_SAMPLE_ID.sample_id%TYPE) IS
      SELECT test_code, act_result
        FROM TE_TEST_RESULTS
       WHERE sample_id = p_sample_id;
  BEGIN
    FOR sample_rec IN sample_cur (p_heat_no) LOOP
      FOR results_rec IN results_cur (sample_rec.sample_id) LOOP
        pk_mt_materials.pass_fail_two_sigma (results_rec.test_code
                                            ,sample_rec.sample_id
                                            ,sample_rec.batch_number
                                            ,sample_rec.spec_code_id
                                            ,results_rec.act_result
                                            ,lv_pass_fail
                                            );
        IF pk_test_results.spec_set_to_no (sample_rec.spec_code_id, results_rec.test_code, sample_rec.test_type) THEN
          lv_valid_result   := 'N';
        ELSE
          lv_valid_result   := 'Y';
        END IF;
        UPDATE TE_TEST_RESULTS
           SET pass_two_sigma = lv_pass_fail, valid_result = lv_valid_result
         WHERE sample_id = sample_rec.sample_id AND test_code = results_rec.test_code;
      END LOOP;
    END LOOP;
    COMMIT;
  END update_2sigma_samples_results;

  PROCEDURE pr_check_sample_results (p_sales_order            IN     R3_SALES_ORDER_ITEMS.r3_sales_order%TYPE
                                    ,p_sales_order_item       IN     R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                                    ,p_process_order_no       IN     TE_TEST_SAMPLE_ID.process_order_no%TYPE
                                    ,p_cast_no                IN     TE_TEST_SAMPLE_ID.cast_no%TYPE
                                    ,p_message_no                OUT NUMBER
                                    ,p_missing_test_type         OUT TE_TEST_SAMPLE_ID.test_type%TYPE
                                    ,p_missing_test_code         OUT TE_TEST_RESULTS.test_code%TYPE
                                    ) IS
    lv_dummy                        VARCHAR2 (1);
    ln_dummy                        NUMBER;
    lb_tstc_formula_check           BOOLEAN;
    lb_tstc_formula_count_check     BOOLEAN;
    lv_sales_order_site             R3_SALES_ORDER_ITEMS.plant_no%TYPE;
    lv_fail                         BOOLEAN := FALSE;

    -- Cursor to collate the test requirement
    CURSOR cur_chk_spec (p_sales_order            IN R3_SALES_ORDER_ITEMS.r3_sales_order%TYPE
                        ,p_sales_order_item       IN R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                        ) IS
      SELECT DISTINCT A.test_type, A.test_code
        FROM te_spec_code_limits A, r3_sales_order_items b
       WHERE A.spec_code_id = b.spec_code_id AND b.r3_sales_order = p_sales_order AND b.r3_sales_order_item = p_sales_order_item;

    -- Cursor to check if test received against this ingot
    CURSOR chk_ingot_test (p_test_type              IN TE_TEST_SAMPLE_ID.test_type%TYPE
                          ,p_test_code              IN TE_TEST_RESULTS.test_code%TYPE
                          ,p_cast_no                IN TE_TEST_SAMPLE_ID.cast_no%TYPE
                          ) IS
      SELECT 'X'
        FROM te_test_results A, te_test_sample_id b
       WHERE b.cast_no = p_cast_no AND A.sample_id = b.sample_id AND b.test_type = p_test_type AND A.test_code = p_test_code;

    -- Cursor to check if test received against this batch
    CURSOR chk_batch_test (
      p_test_type              IN TE_TEST_SAMPLE_ID.test_type%TYPE
     ,p_test_code              IN TE_TEST_RESULTS.test_code%TYPE
     ,p_process_order_no       IN TE_TEST_SAMPLE_ID.process_order_no%TYPE) IS
      SELECT 'X'
        FROM te_test_results tr, te_test_sample_id ts
       WHERE ts.process_order_no = p_process_order_no
         AND tr.sample_id = ts.sample_id
         AND ts.test_type = p_test_type
         AND tr.test_code = p_test_code;

    -- Cursor to check material type (ingot or product)
    CURSOR chk_material_test_type (p_test_code IN TE_TEST_RESULTS.test_code%TYPE) IS
      SELECT 'X'
        FROM te_test_codes
       WHERE test_code = p_test_code AND test_material = 'I';

    -- cursor to check if the test code is a formula
    CURSOR chk_test_code_formula (p_test_code IN TE_TEST_RESULTS.test_code%TYPE) IS
      SELECT 'X'
        FROM st_equivalence_formula
       WHERE collective_test_code = p_test_code;

    -- cursor to check if a formula and if all test codes are available
    CURSOR chk_test_code_formula_count (
      p_test_code              IN TE_TEST_RESULTS.test_code%TYPE
     ,p_cast_no                IN TE_TEST_SAMPLE_ID.cast_no%TYPE) IS
        SELECT b.sample_id, COUNT (A.component_test_code) code_count
          FROM st_equivalence_formula A, te_test_results b, te_test_sample_id c
         WHERE A.collective_test_code = p_test_code
           AND A.component_test_code = b.test_code
           AND b.sample_id = c.sample_id
           AND c.cast_no = p_cast_no
           AND b.rec_status = 'A'
      GROUP BY b.sample_id
        HAVING COUNT (A.component_test_code) <> (SELECT COUNT (A.component_test_code)
                                                   FROM st_equivalence_formula A
                                                  WHERE A.collective_test_code = p_test_code);

    CURSOR get_sales_order_site (p_sales_order            IN R3_SALES_ORDER_ITEMS.r3_sales_order%TYPE
                                ,p_sales_order_item       IN R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                                ) IS
      SELECT plant_no
        FROM r3_sales_order_items
       WHERE r3_sales_order = p_sales_order AND r3_sales_order_item = p_sales_order_item;
  BEGIN
    p_message_no   := 0;
    -- Collate test requirement and check we have samples booked in
    FOR cur_chk_spec_rec IN cur_chk_spec (p_sales_order, p_sales_order_item) LOOP
      -- Check for results against this ingot
      -- STCR 4411 - start - check if test code is a formula and if so then check to make sure all the component test codes exist
      OPEN get_sales_order_site (p_sales_order => p_sales_order, p_sales_order_item => p_sales_order_item);
      FETCH get_sales_order_site INTO lv_sales_order_site;
      CLOSE get_sales_order_site;
      IF Pk_Star_Programs.fn_Get_Parameter (p_program_name => 'LAB_TESTS', p_param_name => 'UK_SITE', p_site => lv_sales_order_site) =
           'N' THEN
        OPEN chk_test_code_formula (p_test_code => cur_chk_spec_rec.test_code);
        FETCH chk_test_code_formula INTO lv_dummy;
        IF chk_test_code_formula%FOUND AND cur_chk_spec_rec.test_type = 'A' THEN
          lb_tstc_formula_check   := TRUE;
          OPEN chk_test_code_formula_count (p_test_code => cur_chk_spec_rec.test_code, p_cast_no => p_cast_no);
          FETCH chk_test_code_formula_count
          INTO ln_dummy, ln_dummy;
          IF chk_test_code_formula_count%FOUND THEN
            lb_tstc_formula_count_check   := FALSE;
          ELSE
            lb_tstc_formula_count_check   := TRUE;
          END IF;
          CLOSE chk_test_code_formula_count;
        ELSE
          lb_tstc_formula_check         := FALSE;
          lb_tstc_formula_count_check   := FALSE;
        END IF;
        CLOSE chk_test_code_formula;
      ELSE
        lb_tstc_formula_count_check   := FALSE;
      END IF;
      -- STCR 4411 - end
      OPEN chk_ingot_test (p_test_type                => cur_chk_spec_rec.test_type
                          ,p_test_code                => cur_chk_spec_rec.test_code
                          ,p_cast_no                  => p_cast_no);
      FETCH chk_ingot_test INTO lv_dummy;
      IF chk_ingot_test%NOTFOUND THEN
        IF NOT lb_tstc_formula_count_check THEN -- STCR 4411
          IF lb_tstc_formula_check THEN
            p_message_no   := 959;
          ELSE
            p_message_no   := 193;
          END IF;
          p_missing_test_type   := cur_chk_spec_rec.test_type;
          p_missing_test_code   := cur_chk_spec_rec.test_code;
          lv_fail               := TRUE;
        END IF; -- STCR 4411
      ELSE
        -- Check if sample booked against the batch
        OPEN chk_batch_test (p_test_type                => cur_chk_spec_rec.test_type
                            ,p_test_code                => cur_chk_spec_rec.test_code
                            ,p_process_order_no         => p_process_order_no);
        FETCH chk_batch_test INTO lv_dummy;
        IF chk_batch_test%NOTFOUND THEN -- Sample not against batch
          -- Check if ingot test. If not then sample is missing
          OPEN chk_material_test_type (p_test_code => cur_chk_spec_rec.test_code);
          FETCH chk_material_test_type INTO lv_dummy;
          IF chk_material_test_type%NOTFOUND THEN -- NOT an ingot test so missing
            p_message_no          := 193;
            p_missing_test_type   := cur_chk_spec_rec.test_type;
            p_missing_test_code   := cur_chk_spec_rec.test_code;
            lv_fail               := TRUE;
          END IF;
          CLOSE chk_material_test_type;
        END IF;
        CLOSE chk_batch_test;
      END IF;
      CLOSE chk_ingot_test;
      IF lv_fail THEN
        EXIT;
      END IF;
    END LOOP;
  END pr_check_sample_results;
/*------------------------------------------------------------------------------------
||
|| PACKAGE INITIALISATION SECTION.
||
*/
------------------------------------------------------------------------------------
BEGIN
  --
  -- Populate the site collection.
  -- (NOTE: This colelction is declared as INDEXED BY VARCHAR2(2))
  --
  FOR site_row IN (SELECT * FROM ST_SITES) LOOP
    -- Load up site data into the collection
    clSiteList (site_row.site)   := site_row;
  END LOOP;
/*------------------------------------------------------------------------------------
||
|| End package body PK_TEST_RESULTS
||
*/
------------------------------------------------------------------------------------
END Pk_Test_Results;
/