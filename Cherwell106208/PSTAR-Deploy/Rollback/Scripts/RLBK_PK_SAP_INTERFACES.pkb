create or replace PACKAGE BODY pk_sap_interfaces 
-- 
-- $Revision:   5.15  $ 
-- $Date:   14 Jul 2020 22:43:34  $ 
-- 
/* 
|| 
|| PROGRAM UNITS FOR USE WITHIN STAR SAP INTERFACES 
|| 
|| 1.8 Noel Gelineau June 4/08 STCR 3516: Updated pr_imported_date update section for Order Items where key sizes of zero will not overwrite existing records for sites 20 and 24 
|| 1.9 Adarsh Narayan July 17/08 STCR 4016: Updated pr_import_data procedure to turn on the update functionality.of Item Status from SAP.Also added the check for ITEM STATUS=Blanks 
|| 1.10 Noel Gelineau Aug 6/08 STCR 4247: Undo the changes from version 1.9 to revert to version 1.8. Add space character to the translate function for order item status 
|| 1.11 Noel Gelineau Sep 2/08 STCR 4278: Re-apply some changes from version 1.9 regarding ignoring item status updates from 'L' to 'O' originating from SAP. 
 1.12 Adarsh Narayan Mar 2/09 STCR 2859 AND: JDD2009C9_2_Scheduled Issues  
 4408 
 5.4 Adarsh Narayan Jul 14 2011 Added rec identifier in place of mod date to identify changed/new records  
    5.9      25-Apr-2013    S Phillips       Added program units fnBatchStatusCSV  
    5.10    Aug-2013        S Phillips       Added calls to check for ingot chem failure when allocating Toronto material (STCR 6363)                  -- 
    5.12   Feb-2019         Adarsh          <<Checked into PVCS by Ray Nault on May 1, 2019>>
    5.13   May-2019          Ray Nault    Added support for Sites 12,14  and Sites 40,41 for SXP
    
*/ 
AS 
  PROCEDURE Pr_get_import_data (p_start_date IN VARCHAR2 DEFAULT NULL, 
                                p_end_date   IN VARCHAR2 DEFAULT NULL) 
  IS 
    CURSOR get_import_data IS 
      SELECT A.mod_date, 
             A.vbeln, 
             A.posnr, 
             A.charg, 
             A.delete_flg, 
             A.vkorg, 
             A.vkbur, 
             A.werks, 
             A.gbstk, 
             A.gbsta, 
             A.kunnr, 
             A.kunnr_name1, 
             A.matnr, 
             Upper (A.maktx) maktx, 
             A.vrkme, 
             A.dim_diameter, 
             A.dim_thickness, 
             A.dim_width, 
             A.dim_uom, 
             A.primary_dim, 
             A.grade, 
             A.quality, 
             A.kunwe, 
             A.kunwe_name1, 
             A.bstnk, 
             A.bstdk, 
             A.contract, 
             A.contract_item 
      FROM   r3_sales_import_link A      
      WHERE  counter > (SELECT rec_mod_identifier 
                        FROM   r3_if_control 
                        WHERE  if_name = 'SALES') 
             AND A.werks IN ( '11', '13', '20', '23', 
                              '24', '26', '27', '32',
                              '12','14', '40','41')                               
      ORDER  BY mod_date; 
    out_rec            r3_imported_sales_data%ROWTYPE; 
    CURSOR check_reject_words ( 
      p_reject_word VARCHAR2) IS 
      SELECT 'Y' 
      FROM   r3_if_reject_words 
      WHERE  reject_word = p_reject_word; 
    CURSOR crgetmaxcounter IS 
      SELECT Max(To_number(counter)) 
      FROM   r3_sales_import_link A 
      WHERE  A.werks IN ( '11', '13', '20', '23', 
                          '24', '26', '27', '32' ,
                              '12','14', '40','41') ; 
    CURSOR crGetSnapShotData IS 
      SELECT A.mandt,
             A.mod_date, 
             A.vbeln, 
             A.posnr, 
             A.charg, 
             A.delete_flg, 
             A.vkorg, 
             A.vkbur, 
             A.werks, 
             A.gbstk, 
             A.gbsta, 
             A.kunnr, 
             A.kunnr_name1, 
             A.matnr, 
             Upper (A.maktx) maktx, 
             A.vrkme, 
             A.dim_diameter, 
             A.dim_thickness, 
             A.dim_width, 
             A.dim_uom, 
             A.primary_dim, 
             A.grade, 
             A.quality, 
             A.kunwe, 
             A.kunwe_name1, 
             A.bstnk, 
             A.bstdk, 
             A.contract, 
             A.contract_item, 
             A.counter
      FROM   r3_sales_import_link A      
      WHERE  TO_DATE(mod_date,'YYYYMMDD') > sysdate-7
        AND A.werks IN ( '11', '13', '20', '23', 
                              '24', '26', '27', '32',
                              '12','14', '40','41')                               
      ORDER  BY mod_date; 
    CURSOR crGetCurrCounter IS
    SELECT rec_mod_identifier 
      FROM r3_if_control 
     WHERE  if_name = 'SALES';
    ln_1st_space       NUMBER; 
    ln_size_terminator NUMBER; 
    lv_1st_word        VARCHAR2 (50); 
    lv_ingot_diam      VARCHAR2 (2); 
    lv_reject_record   VARCHAR2 (1); 
    lv_size_uom        VARCHAR2 (2); 
    ln_size_ind_pos    NUMBER; 
    lb_parse_text      BOOLEAN; 
    lb_size_found      BOOLEAN; 
    ln_size_found      NUMBER; 
    lv_size_test       r3_sales_order_items.material_description%TYPE; 
    nmrecmodidentifier r3_if_control.rec_mod_identifier%TYPE; 
    lvSalesOrderRec r3_sales_import_link%ROWTYPE;
    lvCurrSTARCounter r3_if_control.rec_mod_identifier%TYPE;
    
  BEGIN 
      --Get the current STAR Counter STCR 7459
      OPEN crGetCurrCounter;
      FETCH crGetCurrCounter INTO lvCurrSTARCounter;
      CLOSE crGetCurrCounter;
      --Now insert the records for the trace log
      FOR rcGetSnapShotData IN crGetSnapShotData LOOP
        lvSalesOrderRec.mandt := rcGetSnapShotData.mandt;
        lvSalesOrderRec.mod_date := rcGetSnapShotData.mod_date;
        lvSalesOrderRec.vbeln := rcGetSnapShotData.vbeln;
        lvSalesOrderRec.posnr := rcGetSnapShotData.posnr;
        lvSalesOrderRec.charg := rcGetSnapShotData.charg;
        lvSalesOrderRec.delete_flg := rcGetSnapShotData.delete_flg;
        lvSalesOrderRec.vkorg := rcGetSnapShotData.vkorg;
        lvSalesOrderRec.vkbur := rcGetSnapShotData.vkbur;
        lvSalesOrderRec.werks := rcGetSnapShotData.werks;
        lvSalesOrderRec.gbstk := rcGetSnapShotData.gbstk; 
        lvSalesOrderRec.gbsta := rcGetSnapShotData.gbsta;
        lvSalesOrderRec.kunnr := rcGetSnapShotData.kunnr;
        lvSalesOrderRec.kunnr_name1 := rcGetSnapShotData.kunnr_name1;
        lvSalesOrderRec.matnr := rcGetSnapShotData.matnr;
        lvSalesOrderRec.maktx := rcGetSnapShotData.maktx;
        lvSalesOrderRec.vrkme := rcGetSnapShotData.vrkme;
        lvSalesOrderRec.dim_diameter := rcGetSnapShotData.dim_diameter;
        lvSalesOrderRec.dim_thickness := rcGetSnapShotData.dim_thickness;
        lvSalesOrderRec.dim_width := rcGetSnapShotData.dim_width;
        lvSalesOrderRec.dim_uom := rcGetSnapShotData.dim_uom;
        lvSalesOrderRec.primary_dim := rcGetSnapShotData.primary_dim;
        lvSalesOrderRec.grade := rcGetSnapShotData.grade;
        lvSalesOrderRec.quality := rcGetSnapShotData.quality;
        lvSalesOrderRec.kunwe := rcGetSnapShotData.kunwe;
        lvSalesOrderRec.kunwe_name1 := rcGetSnapShotData.kunwe_name1;
        lvSalesOrderRec.bstnk := rcGetSnapShotData.bstnk;
        lvSalesOrderRec.bstdk := rcGetSnapShotData.bstdk;
        lvSalesOrderRec.contract := rcGetSnapShotData.contract;
        lvSalesOrderRec.contract_item := rcGetSnapShotData.contract_item;
        lvSalesOrderRec.counter := rcGetSnapShotData.counter;
        pk_sap_intf_api.prAddInterfaceTrace(pSalesOrderRec_In => lvSalesOrderRec
                                            ,pStarCounter => lvCurrSTARCounter);    
      END LOOP;
      
      -- Read the import table on SAP via the synonym (r3_sales_import_link) 
      FOR in_rec IN get_import_data LOOP 
          -- Filter out records that could not be excluded by the WHERE clause 
          -- First exclude products / services that should not be processed. 
          -- This is done by inspecting the first 'Word' of the material description. 
          -- If this word is in the list of 'excluded' words then flag the record for rejection 
          -- The first word is defined as characters from position 1 to the one before the first space. 
          -- Get position of first space character 
          ln_1st_space := Instr (in_rec.maktx, ' '); 

          -- Get 1st word of material text 
          lv_1st_word := Substr (in_rec.maktx, 1, ln_1st_space - 1); 

          lv_reject_record := 'N'; 

          -- Check the list of words that will cause a reject. 
          -- If found that lv_reject_record will be set to 'Y' 
          OPEN check_reject_words (lv_1st_word); 

          FETCH check_reject_words INTO lv_reject_record; 

          CLOSE check_reject_words; 

          -- Special Case of Toll processing. 
          -- The word will be "Toll" but we should only let through the Output item. 
          IF lv_1st_word = 'Toll' THEN 
            IF Instr (in_rec.maktx, 'Output') = 0 THEN 
              -- Flag rejection of the record required. 
              lv_reject_record := 'Y'; 
            END IF; 
          END IF; 

          -- Check for Free of charge material being shipped from Morgantown 
          IF in_rec.werks = '20' 
             AND in_rec.maktx = 'MATERIAL(S) FREE OF CHARGE - SEE BELOW' THEN 
            lv_reject_record := 'Y'; 
          END IF; 

          -- If not rejected on the basis of the first word , then continue processing 
          IF lv_reject_record = 'N' THEN 
            -- At this point we know that the record should be processed based on the first word 
            -- in the material description. We may still have to reject the record if we cannot get 
            -- the key size. In some cases if we cannot get the key size from the material description 
            -- we can set it to '0' and continue. In other cases we cannot and the record is rejected. 
            -- First check if the key size is present in one of the defined size columns coming from SAP 
            -- If the product is "Configurable" in SAP then one or more of these fields will be set >0 . 
            -- If we do get a size then obviously we do not need to extract one from the material description. 
            IF ( in_rec.dim_diameter + in_rec.dim_thickness 
                 + in_rec.dim_width ) = 0 THEN 
              -- At this point we know that the size has to be extracted from the material description 
              -- Some material descriptions will include a size but others will not. Those that do typically 
              -- will have the size followed by either a " character eg 30" or 'mm' eg 762mm. 
              -- If either " or mm is found in the material description then we can look further for the size 
              -- First assume that we will find the " character indicating inches. 
              lv_size_uom := 'IN'; 

              lb_parse_text := TRUE; 

              -- Set indicator to do the size parse later 
              -- Look for the Inches indicator 
              ln_size_ind_pos := Instr (in_rec.maktx, '"'); 

              -- Check if we found it. 
              IF ln_size_ind_pos = 0 THEN 
                -- Inches not present , look for 'mm'' 
                -- Now assume millimeters will be found 
                lv_size_uom := 'MM'; 

                lb_parse_text := TRUE; 

                -- Set indicator to do the size parse later 
                -- Look for the mm indicator. 
                ln_size_ind_pos := Instr (in_rec.maktx, 'MM'); 

                -- Check if we found it. 
                IF ln_size_ind_pos = 0 THEN 
                  -- At this point we know that the material description does not appear to contain a size. 
                  -- First flag the parsing of the material text as not required. 
                  lb_parse_text := FALSE; 

                  -- Our Actions at this point depend on which mill is shipping the order. 
                  -- Morgantown and Waun wish the order to be added with a size of '0'. For all other mills the record 
                  -- should be rejected as they wish manual control on order entry in these cases. 
                  -- nb Morgantown orders have '20' in the werks column from the interface. 
                  IF in_rec.werks = '20' 
                      OR in_rec.werks = '24' 
                      OR in_rec.werks = '11' 
                      OR in_rec.werks = '32'
                      OR in_rec.werks = '12'
                      OR in_rec.werks = '14'
                      OR in_rec.werks = '40'
                      OR in_rec.werks = '41'                     
                      THEN 
                    -- Set one of the incoming size fields to 0 
                    -- Set the key size indicator to 'D' for diameter 
                    -- Set the uom to IN 
                    -- Morgantown 
                    CASE in_rec.werks 
                      WHEN '20' THEN 
                        in_rec.dim_diameter := '0'; 

                        in_rec.primary_dim := 'D'; 

                        in_rec.dim_uom := 'IN'; 
                      WHEN '11' -- Toronto 
                      THEN 
                        in_rec.dim_diameter := '0'; 

                        in_rec.primary_dim := 'D'; 

                        in_rec.dim_uom := 'IN'; 
                      WHEN '32' THEN 
                        in_rec.dim_diameter := '0'; 

                        in_rec.primary_dim := 'D'; 

                        in_rec.dim_uom := 'IN'; 
                      WHEN '24' THEN 
                        -- Waunarlwydd 
                        in_rec.dim_thickness := '0'; 

                        in_rec.primary_dim := 'T'; 

                        in_rec.dim_uom := 'MM'; 
                      WHEN '12' THEN 
                        in_rec.dim_diameter := '0'; 

                        in_rec.primary_dim := 'D'; 

                        in_rec.dim_uom := 'IN'; 
                      WHEN '14' THEN 
                        in_rec.dim_diameter := '0'; 

                        in_rec.primary_dim := 'D'; 

                        in_rec.dim_uom := 'IN'; 
                      WHEN '40' THEN 
                        in_rec.dim_diameter := '0'; 

                        in_rec.primary_dim := 'D'; 

                        in_rec.dim_uom := 'IN'; 
                      WHEN '41' THEN 
                        in_rec.dim_diameter := '0'; 

                        in_rec.primary_dim := 'D'; 

                        in_rec.dim_uom := 'IN'; 
                      ELSE 
                        NULL; 
                    END CASE; 
                  ELSE 
                    -- For other mills flag the record as reject 
                    lv_reject_record := 'Y'; 
                  END IF; -- End of Check for Morgantown Shippment 
                END IF; -- End of Check if size indicator not found (mm) 
              END IF; -- ENd of Check if size indicator not found (in) 
              -- Now check if we need to parse the material description text to extract the size 
              -- If we do the lv_parse_text_yn flag will be set to 'Y' and the position of the size indicator 
              -- will be contained in ln_size_ind_pos 
              IF lb_parse_text THEN 
                -- We need to do the parsing 
                -- First assume we will find it. (Hey lets be positive !). 
                lb_size_found := TRUE; 

                -- Initialise size fields. 
                ln_size_found := 0; 

                lv_size_test := NULL; 

                -- Now lets go looking 
                -- The process is to seach"backwards" ie right to left through the text staring with the position 
                -- of the size indicator looking for a / or space character. When found then step forwards 
                -- (left to right) one character and parse out all the characters up to the character that is to the left 
                -- of the size indicator. This "extracted" string is checked to see if it is a number , if so use it. If it 
                -- isn't a number then set variable lb_size_found as false. 
                -- Find the position of the / or space character that preceeds the size indicator 
                -- Firstly to make the INSTR function work right to left we need to give it a negative start position. 
                -- It counts backwards from the end of the string to get the start position and to continue searching 
                -- backwards (right to left). What we have at the momment is the start postion from the left hand position 
                -- (The INSTR function ALWAYS return the character position relative to the first left hand character) 
                -- We therefore need to calculate the start position of the size indicator as relative from the right hand 
                -- side of the string. 
                ln_size_terminator := Instr (in_rec.maktx, '/', 
                                      -1 * ( 
                                      Length (in_rec.maktx) - ln_size_ind_pos ) 
                                      - 3 
                                      , 
                                      -- + 1, v1.5 changed by R.Nault Feb 12, 2008 
                                      1); 

                IF ln_size_terminator = 0 THEN 
                  -- If there is no space to the left of the size indicator then ln_previous_space will be set to 0 
                  -- If this is the case look for a previous space 
                  ln_size_terminator := Instr (in_rec.maktx, ' ', 
                                        -1 * ( 
                                        Length (in_rec.maktx) - ln_size_ind_pos 
                                             ) 
                                        - 3, 
                                        -- + 1, v1.5 changed by R.Nault Feb 12, 2008 
                                        1); 
                -- IF not found then ln_size_terminator will be 0 
                -- and hence the extracted string will start from position 1 (See the SUBSTR Command below). 
                END IF; 

                -- Now extract the text 
                -- The first character is one character to the right of the 1st space that is left of the size indicator 
                -- The end character is the character immediately to the left of the size indicator 
                -- The length of the extracted string (needed for the substr command) is therefore 
                -- (position_of_size indicator -1 ) - (previous_space + 1) +1 
                -- ln_size_terminator := LENGTH(in_rec.maktx) - ln_size_terminator; -- added by Steve/Mike Feb 5, 2008  
                -- v1.5 removed by R.Nault Feb 12, 2008 
                lv_size_test := Substr (in_rec.maktx, ln_size_terminator + 1, ( 
                                                ( ln_size_ind_pos - 1 ) - ( 
                                                ln_size_terminator + 1 ) + 1 )); 

                -- We now have the 'candidate' size string in lv_size_test. 
                -- Now we check if it contains a valid number string. Ie it could be converted to a number ok. 
                -- There is a function in the test results part of STAR which determines if the string is numeric 
                -- First of all if the length of the test string is greater than 10 characters then assume it is not a number 
                IF Length (lv_size_test) <= 10 THEN 
                  IF pk_test_results.Is_number (lv_size_test) THEN 
                    -- Move over to number field 
                    ln_size_found := To_number (lv_size_test); 
                  ELSE 
                    -- Indicate no number found 
                    lb_size_found := FALSE; 
                  END IF; 
                ELSE 
                  lb_size_found := FALSE; 
                END IF; -- End of check on length of test string size 
                IF lb_size_found THEN 
                  -- Abitarily choose the diameter 
                  in_rec.dim_diameter := ln_size_found; 

                  in_rec.primary_dim := 'D'; 

                  -- Indicates diameter contains the size 
                  in_rec.dim_uom := lv_size_uom; 
                -- Determined when looking for the size indicator position above 
                ELSE 
                  -- At this point we know that we have not been able to get a valid number from the string 
                  -- even though the string contains one of the size indicators. 
                  -- Several material descriptions have this "problem" for example one of the 'SLB text strings has ...VAR" . 
                  -- What we do know depends on the mill that is shipping the order. 
                  -- For Morgantown , the size is set to '0' and the record accepted. 
                  -- For other mills the order is rejected. 
                  -- Essentially we repeat the check above using WERKS 
                  IF in_rec.werks in ('20','12','14','40','41') THEN 
                    -- Set one of the incoming size fields to 0 
                    -- Set the key size indicator to 'D' for diameter 
                    -- Set the uom to IN 
                    in_rec.dim_diameter := '0'; 

                    in_rec.primary_dim := 'D'; 

                    in_rec.dim_uom := 'IN'; 
                  ELSE 
                    -- For other mills flag the record as reject 
                    lv_reject_record := 'Y'; 
                  END IF; --- End of the check for Morgantown shipments 
                END IF; --- End of the processing when we have found a size 
              END IF; 
            -- End of the Check if we need to parse the material text 
            END IF; --- End of check that incoming sizes are all zero. 
          END IF; 

          --- End of the initial check that the record was not rejected due to the '1st Word' in text 
          -- We now need to check if it is still ok to process the record. 
          IF lv_reject_record = 'N' THEN 
            -- Transform the data 
            -- First the Sales Order Number 
            -- From SAP this is a leading zero filled field. In STAR there are no leading zeros 
            out_rec.r3_sales_order := Ltrim (in_rec.vbeln, '0'); 

            out_rec.r3_sales_order_item := Ltrim (in_rec.posnr, '0'); 

            -- Contract and Contract Item 
            -- From SAP this is a leading zero filled field. In STAR there are no leading zeros 
            out_rec.contract := Ltrim (in_rec.contract, '0'); 

            out_rec.contract_item := Ltrim (in_rec.contract_item, '0'); 

            -- Order and Item status transformation 
            out_rec.order_status := TRANSLATE (in_rec.gbstk, 'AB', 'OO'); 

            out_rec.item_status := TRANSLATE (in_rec.gbsta, 'AB ', 'OOO'); 

            -- Move Over un-transformed columns 
            out_rec.r3_batch_number := in_rec.charg; 

            out_rec.r3_sales_org := in_rec.vkorg; 

            out_rec.r3_sales_office := in_rec.vkbur; 

            out_rec.site := in_rec.werks; 

            out_rec.customer_id := in_rec.kunwe; 

            out_rec.customer_name := in_rec.kunwe_name1; 

            out_rec.material_number := in_rec.matnr; 

            out_rec.material_description := in_rec.maktx; 

            out_rec.sales_uom := in_rec.vrkme; 

            out_rec.dim_diameter := in_rec.dim_diameter; 

            out_rec.dim_thickness := in_rec.dim_thickness; 

            out_rec.dim_uom := in_rec.dim_uom; 

            out_rec.dim_width := in_rec.dim_width; 

            out_rec.primary_dim := in_rec.primary_dim; 

            out_rec.grade := in_rec.grade; 

            out_rec.quality := in_rec.quality; 

            out_rec.mod_date := To_date (in_rec.mod_date, 'YYYYMMDD'); 

            out_rec.customer_po_ref := in_rec.bstnk; 

            out_rec.delete_flg := in_rec.delete_flg; 

            out_rec.sold_to_cust_id := in_rec.kunnr; 

            out_rec.sold_to_cust_name := in_rec.kunnr_name1; 

            --- If customers po date is zeros , then null out. 
            IF in_rec.bstdk = '00000000' THEN 
              out_rec.customer_po_date := NULL; 
            ELSE 
              out_rec.customer_po_date := To_date (in_rec.bstdk, 'YYYYMMDD'); 
            END IF; 

            --- If the customers po reference is just a single space character then null out 
            IF in_rec.bstnk = ' ' THEN 
              out_rec.customer_po_ref := NULL; 
            ELSE 
              out_rec.customer_po_ref := in_rec.bstnk; 
            END IF; 

            -- Insert data into the permanent table of changes to 
            -- be incorportated. 
            INSERT INTO r3_imported_sales_data 
                        (import_id, 
                         r3_sales_order, 
                         r3_sales_order_item, 
                         r3_batch_number, 
                         r3_sales_org, 
                         r3_sales_office, 
                         site, 
                         order_status, 
                         item_status, 
                         customer_id, 
                         customer_name, 
                         material_number, 
                         material_description, 
                         sales_uom, 
                         dim_diameter, 
                         dim_thickness, 
                         dim_width, 
                         dim_uom, 
                         primary_dim, 
                         grade, 
                         quality, 
                         mod_date, 
                         delete_flg, 
                         sold_to_cust_id, 
                         sold_to_cust_name, 
                         customer_po_ref, 
                         customer_po_date, 
                         contract, 
                         contract_item) 
            VALUES      (st_gen_id_seq.NEXTVAL, 
                         out_rec.r3_sales_order, 
                         out_rec.r3_sales_order_item, 
                         out_rec.r3_batch_number, 
                         out_rec.r3_sales_org, 
                         out_rec.r3_sales_office, 
                         out_rec.site, 
                         out_rec.order_status, 
                         out_rec.item_status, 
                         out_rec.customer_id, 
                         out_rec.customer_name, 
                         out_rec.material_number, 
                         out_rec.material_description, 
                         out_rec.sales_uom, 
                         out_rec.dim_diameter, 
                         out_rec.dim_thickness, 
                         out_rec.dim_width, 
                         out_rec.dim_uom, 
                         out_rec.primary_dim, 
                         out_rec.grade, 
                         out_rec.quality, 
                         out_rec.mod_date, 
                         out_rec.delete_flg, 
                         out_rec.sold_to_cust_id, 
                         out_rec.sold_to_cust_name, 
                         out_rec.customer_po_ref, 
                         out_rec.customer_po_date, 
                         out_rec.contract, 
                         out_rec.contract_item ); 
          END IF; --- End of check that the record should not be rejected. 
      END LOOP; -- End of loop that fetches data from import table 
      OPEN crgetmaxcounter; 

      FETCH crgetmaxcounter INTO nmrecmodidentifier; 

      CLOSE crgetmaxcounter; 

      --- Update the control file to show end of Import data fetch
 
      UPDATE r3_if_control 
      SET    rec_mod_identifier = nmrecmodidentifier, 
             control_date1 = SYSDATE 
      WHERE  if_name = 'SALES'; 
 
      --- Now execute the procedure that processes the newly found data. 
      COMMIT; 

      star.pk_sap_interfaces.pr_import_data; 

      COMMIT; 
  END pr_get_import_data; 
  PROCEDURE Pr_import_data 
  IS 
    -- Procedure runs down the R3_Imported_Sales_Data table and attempts to incorporate 
    -- the data into the main tables R3_SALES_ORDERS , R3_SALE_ORDER_ITEMS , 
    -- R3_PROCESS_ORDERS.ALLOY_CODE 
    -- It writes a log of what it has done to table R3_IF_ACTIONS 
    CURSOR get_new_or_changed_order_items IS 
      SELECT import_id, 
             r3_sales_order, 
             r3_sales_order_item, 
             r3_batch_number, 
             r3_sales_org, 
             r3_sales_office, 
             site, 
             order_status, 
             item_status, 
             customer_id, 
             customer_name, 
             material_number, 
             material_description, 
             Lower (sales_uom) sales_uom, 
             dim_diameter, 
             dim_thickness, 
             dim_width, 
             Lower (dim_uom)   dim_uom, 
             primary_dim, 
             grade, 
             quality, 
             mod_date, 
             delete_flg, 
             sold_to_cust_id, 
             sold_to_cust_name, 
             customer_po_ref, 
             customer_po_date, 
             contract, 
             contract_item 
      FROM   r3_imported_sales_data 
      WHERE  delete_flg = ' ' 
             AND r3_batch_number = ' ' 
             AND site IN ( '11', '13', '20', '23', 
                           '24', '26', '27', '32',
                              '12','14', '40','41' ) 
      ORDER  BY import_id; 
    CURSOR get_import_us_heats IS 
      SELECT import_id, 
             r3_sales_order, 
             r3_sales_order_item, 
             r3_batch_number, 
             r3_sales_org, 
             r3_sales_office, 
             site, 
             order_status, 
             item_status, 
             customer_id, 
             customer_name, 
             material_number, 
             material_description, 
             sales_uom, 
             dim_diameter, 
             dim_thickness, 
             dim_width, 
             dim_uom, 
             primary_dim, 
             grade, 
             quality, 
             mod_date, 
             delete_flg, 
             sold_to_cust_id, 
             sold_to_cust_name, 
             customer_po_ref, 
             customer_po_date, 
             contract, 
             contract_item 
      FROM   r3_imported_sales_data 
      WHERE  delete_flg = ' ' 
             AND r3_batch_number <> ' ' 
             -- Select Records where there is a batch number. 
             AND site IN ( '11', '13', '20', '32' ) 
      ORDER  BY import_id; 
    CURSOR get_order_header ( 
      p_sales_order VARCHAR2) IS 
      SELECT customer_name, 
             site, 
             sap_customer_ref, 
             sap_sold_to_ref, 
             order_status, 
             sap_sold_to_name, 
             sap_sales_org, 
             sales_office, 
             customer_po_ref, 
             customer_po_date 
      FROM   r3_sales_orders 
      WHERE  r3_sales_order = p_sales_order; 
    CURSOR get_order_item ( 
      p_sales_order      VARCHAR2, 
      p_sales_order_item VARCHAR2 ) IS 
      SELECT key_size, 
             item_status, 
             plant_no, 
             key_size_entered, 
             key_size_uom, 
             alloy_code, 
             quality_grade_code, 
             dim_diameter, 
             dim_thickness, 
             dim_width, 
             dim_uom, 
             primary_dim, 
             material_number, 
             material_description, 
             contract, 
             contract_item, 
             spec_code_id 
      FROM   r3_sales_order_items 
      WHERE  r3_sales_order = p_sales_order 
             AND r3_sales_order_item = p_sales_order_item; 
    CURSOR get_allocation ( 
      p_sales_order      VARCHAR2, 
      p_sales_order_item VARCHAR2, 
      p_batch_number     VARCHAR2 ) IS 
      SELECT r3_process_order, 
             r3_sales_order, 
             r3_sales_order_item, 
             process_order_status, 
             r3_batch_number, 
             r3_ingot_ref, 
             alloy_code 
      FROM   r3_process_orders 
      WHERE  r3_sales_order = p_sales_order 
             AND r3_sales_order_item = p_sales_order_item 
             AND r3_process_order = p_batch_number; 
    CURSOR get_alloy_code ( 
      p_grade VARCHAR2) IS 
      SELECT alloy_code 
      FROM   st_alloys 
      WHERE  Upper (alloy_code) = Upper (p_grade) 
             AND rec_status = 'A'; 
    CURSOR get_quality_grade_code ( 
      p_quality VARCHAR2) IS 
      SELECT grade_code 
      FROM   te_grade_codes 
      WHERE  Upper (grade_code) = Upper (p_quality); 
    CURSOR get_uom ( 
      p_dim_uom VARCHAR2) IS 
      SELECT uom_ref 
      FROM   st_units_of_measure 
      WHERE  Upper (uom_ref) = Upper (p_dim_uom); 
    CURSOR get_us_heats ( 
      p_heat_number VARCHAR2) IS 
      SELECT alloy_code, 
             heat_num, 
             heat_id, 
             heat_source, 
             site, 
             quality_grade_code 
      FROM   mt_us_heats 
      WHERE  heat_num = p_heat_number; 
    CURSOR get_basis_spec_data ( 
      p_contract_in IN r3_sales_order_items.contract%TYPE) IS 
      SELECT spec_code_id, 
             spec_code_type, 
             pr_filter_low, 
             pr_filter_high, 
             spec_code_name 
      FROM   te_spec_code_header 
      WHERE  spec_code_type = 'B' 
             AND copy_indicator = 'Y' 
             AND ( contract = p_contract_in ) 
             AND rec_status = 'A'; 
    header_out_rec         r3_sales_orders%ROWTYPE; 
    header_curr_rec        get_order_header%ROWTYPE; 
    item_out_rec           r3_sales_order_items%ROWTYPE; 
    item_curr_rec          get_order_item%ROWTYPE; 
    heat_out_rec           mt_us_heats%ROWTYPE; 
    heat_curr_rec          get_us_heats%ROWTYPE; 
    batch_out_rec          r3_process_orders%ROWTYPE; 
    batch_curr_rec         get_allocation%ROWTYPE; 
    lv_header_check        VARCHAR2 (1); 
    lv_allocation_check    VARCHAR2 (1); 
    lv_item_check          VARCHAR2 (1); 
    lv_heat_check          VARCHAR2 (1); 
    lv_dummy               VARCHAR2 (1); 
    lv_heat_number         VARCHAR2 (7); 
    ln_char_pos            NUMBER; 
    lv_new_spec_code_id    te_spec_code_header.spec_code_id%TYPE; 
    lv_spec_code_type      te_spec_code_header.spec_code_type%TYPE; 
    lv_basis_spec_id       te_spec_code_header.spec_code_id%TYPE; 
    lv_filter_low          te_spec_code_header.pr_filter_low%TYPE; 
    lv_filter_high         te_spec_code_header.pr_filter_high%TYPE; 
    lv_spec_code_name      te_spec_code_header.spec_code_name%TYPE; 
    lv_import_status_text  VARCHAR2 (50); 
    lv_import_status_text2 VARCHAR2 (50); 
    lv_import_status_flag  BOOLEAN;
    lvSalesOrder r3_sales_orders.r3_sales_order%TYPE;
    lvSalesOrderItem r3_sales_order_items.r3_sales_order_item%TYPE;
    lvBatchNumber r3_process_orders.r3_process_order%TYPE; 
  BEGIN 
      pk_debug.prWriteDebugRec(ptModuleName_in => 'R3_SALES_ORDERS'
                               ,vcDebugText_in => 'Import Data Proc');
      UPDATE r3_if_control 
      SET    control_date2 = SYSDATE 
      WHERE  if_name = 'SALES'; 
      FOR in_rec IN get_new_or_changed_order_items LOOP 
          pk_sap_intf_api.prAddSalesOrderLog(pImportId_in => in_rec.import_id
                                             ,pSalesOrder_in => in_rec.r3_sales_order
                                             ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                             ,pActionTaken_in => 'Record Picked up from r3_imported_sales_data for processing');
          -- Check if incoming sales order exists 
          OPEN get_order_header (in_rec.r3_sales_order); 

          FETCH get_order_header INTO header_curr_rec; 

          --- Mod 1.2 
          IF get_order_header%NOTFOUND THEN 
            lv_header_check := 'N'; 
          ELSE 
            lv_header_check := 'Y'; 
          END IF; 

          --- Mod 1.2 
          CLOSE get_order_header; 

          -- Order does not exist 
          -- Put Insert Into Headers Table Here 
          header_out_rec.r3_sales_order := in_rec.r3_sales_order; 

          header_out_rec.customer_name := Upper (in_rec.customer_name); 

          header_out_rec.order_status := 'O'; 

          header_out_rec.date_created := SYSDATE; 

          header_out_rec.time_created := To_char (SYSDATE, 'hh24:mi:ss'); 

          header_out_rec.created_by := 'SAP_I/F'; 

          header_out_rec.comments := 'From Interface'; 

          header_out_rec.site := Substr (in_rec.r3_sales_office, 1, 2); 
          
          -- If Timet Germany or Timet Savoie Sales then switch header site to shipping plant 
          -- as Germany and France are not yet on STAR (29-Apr-2004). 
          -- 07-JUL-2006. Savoie added to STAR system. Removed '26' from list below. (Mike Dickson) 
          IF header_out_rec.site IN ( '90', '28', '34' ) THEN 
            header_out_rec.site := in_rec.site; 
          END IF; 

          header_out_rec.edition := 1; 

          header_out_rec.sap_customer_ref := in_rec.customer_id; 

          header_out_rec.sap_sold_to_ref := in_rec.sold_to_cust_id; 

          header_out_rec.sap_sold_to_name := in_rec.sold_to_cust_name; 

          header_out_rec.sap_sales_org := in_rec.r3_sales_org; 

          header_out_rec.sales_office := in_rec.r3_sales_office; 

          header_out_rec.customer_po_ref := in_rec.customer_po_ref; 

          header_out_rec.customer_po_date := in_rec.customer_po_date; 

          lv_import_status_flag := FALSE; 

          IF lv_header_check = 'N' THEN -- insert sales order 
           
            pk_sap_intf_api.prAddSalesOrderLog(pImportId_in => in_rec.import_id
                                             ,pSalesOrder_in => in_rec.r3_sales_order
                                             ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                             ,pActionTaken_in => 'Order Header is not in STAR, Inserting new Order: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
            INSERT INTO r3_sales_orders 
                        (r3_sales_order, 
                         customer_name, 
                         order_status, 
                         date_created, 
                         time_created, 
                         created_by, 
                         comments, 
                         site, 
                         edition, 
                         sap_customer_ref, 
                         sap_sold_to_ref, 
                         sap_sold_to_name, 
                         sap_sales_org, 
                         sales_office, 
                         customer_po_ref, 
                         customer_po_date) 
            VALUES      (header_out_rec.r3_sales_order, 
                         header_out_rec.customer_name, 
                         header_out_rec.order_status, 
                         header_out_rec.date_created, 
                         header_out_rec.time_created, 
                         header_out_rec.created_by, 
                         header_out_rec.comments, 
                         header_out_rec.site, 
                         header_out_rec.edition, 
                         header_out_rec.sap_customer_ref, 
                         header_out_rec.sap_sold_to_ref, 
                         header_out_rec.sap_sold_to_name, 
                         header_out_rec.sap_sales_org, 
                         header_out_rec.sales_office, 
                         header_out_rec.customer_po_ref, 
                         header_out_rec.customer_po_date ); 

            lv_import_status_text := ' : Inserted Header for Order '; 

            lv_import_status_flag := TRUE; 
          ELSE -- update any changed records to sales order. 
            pk_sap_intf_api.prAddSalesOrderLog(pImportId_in => in_rec.import_id
                                             ,pSalesOrder_in => in_rec.r3_sales_order
                                             ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                             ,pActionTaken_in => 'Order Header is in STAR, Update in case of any changes: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
            IF header_curr_rec.customer_name <> header_out_rec.customer_name 
               AND header_out_rec.customer_name IS NOT NULL THEN 
              UPDATE r3_sales_orders 
              SET    customer_name = header_out_rec.customer_name 
              WHERE  r3_sales_order = header_out_rec.r3_sales_order; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF header_curr_rec.sap_customer_ref <> 
               header_out_rec.sap_customer_ref 
               AND header_out_rec.sap_customer_ref IS NOT NULL THEN 
              UPDATE r3_sales_orders 
              SET    sap_customer_ref = header_out_rec.sap_customer_ref 
              WHERE  r3_sales_order = header_out_rec.r3_sales_order; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF header_curr_rec.sap_sold_to_ref <> header_out_rec.sap_sold_to_ref 
               AND header_out_rec.sap_sold_to_ref IS NOT NULL THEN 
              UPDATE r3_sales_orders 
              SET    sap_sold_to_ref = header_out_rec.sap_sold_to_ref 
              WHERE  r3_sales_order = header_out_rec.r3_sales_order; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF header_curr_rec.sap_sold_to_name <> 
               header_out_rec.sap_sold_to_name 
               AND header_out_rec.sap_sold_to_name IS NOT NULL THEN 
              UPDATE r3_sales_orders 
              SET    sap_sold_to_name = header_out_rec.sap_sold_to_name 
              WHERE  r3_sales_order = header_out_rec.r3_sales_order; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF header_curr_rec.sap_sales_org <> header_out_rec.sap_sales_org 
               AND header_out_rec.sap_sales_org IS NOT NULL THEN 
              UPDATE r3_sales_orders 
              SET    sap_sales_org = header_out_rec.sap_sales_org 
              WHERE  r3_sales_order = header_out_rec.r3_sales_order; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF header_curr_rec.sales_office <> header_out_rec.sales_office 
               AND header_out_rec.sales_office IS NOT NULL THEN 
              UPDATE r3_sales_orders 
              SET    sales_office = header_out_rec.sales_office 
              WHERE  r3_sales_order = header_out_rec.r3_sales_order; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF header_curr_rec.customer_po_ref <> header_out_rec.customer_po_ref 
               AND header_out_rec.customer_po_ref IS NOT NULL THEN 
              UPDATE r3_sales_orders 
              SET    customer_po_ref = header_out_rec.customer_po_ref 
              WHERE  r3_sales_order = header_out_rec.r3_sales_order; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF header_curr_rec.customer_po_date <> 
               header_out_rec.customer_po_date 
               AND header_out_rec.customer_po_date IS NOT NULL THEN 
              UPDATE r3_sales_orders 
              SET    customer_po_date = header_out_rec.customer_po_date 
              WHERE  r3_sales_order = header_out_rec.r3_sales_order; 

              lv_import_status_flag := TRUE; 
            END IF; 

            lv_import_status_text := ' : Updated Header for Order '; 
          END IF; 

          IF lv_import_status_flag THEN 
            INSERT INTO r3_if_actions 
                        (interface, 
                         import_id, 
                         action_taken, 
                         r3_sales_order, 
                         r3_sales_order_item) 
            VALUES      ('SALES', 
                         in_rec.import_id, 
                         To_char (SYSDATE, 'dd-MON-yyyy hh24:mi:ss') 
                         || lv_import_status_text 
                         || header_out_rec.r3_sales_order, 
                         header_out_rec.r3_sales_order, 
                         NULL ); 
          END IF; 

          lv_import_status_flag := FALSE; 

          OPEN get_order_item (in_rec.r3_sales_order, 
          in_rec.r3_sales_order_item); 

          FETCH get_order_item INTO item_curr_rec; 

          --- Mod 1.2 
          IF get_order_item%NOTFOUND THEN 
            lv_item_check := 'N'; 
          ELSE 
            lv_item_check := 'Y'; 
          END IF; 

          --- Mod 1.2 
          CLOSE get_order_item; 

          -- Determine the Alloy Code 
          item_out_rec.alloy_code := NULL; 

          OPEN get_alloy_code (in_rec.grade); 

          FETCH get_alloy_code INTO item_out_rec.alloy_code; 

          CLOSE get_alloy_code; 

          -- Determine the quality code 
          item_out_rec.quality_grade_code := NULL; 

          OPEN get_quality_grade_code (in_rec.quality); 

          FETCH get_quality_grade_code INTO item_out_rec.quality_grade_code; 

          CLOSE get_quality_grade_code; 

          -- Determine the dimension 
          OPEN get_uom (in_rec.dim_uom); 

          FETCH get_uom INTO item_out_rec.key_size_uom; 

          CLOSE get_uom; 

          -- Get dimension 
          IF in_rec.primary_dim = 'D' THEN 
            item_out_rec.key_size_entered := in_rec.dim_diameter; 
          ELSIF in_rec.primary_dim = 'T' THEN 
            item_out_rec.key_size_entered := in_rec.dim_thickness; 
          ELSIF in_rec.primary_dim = 'TW' THEN 
            IF in_rec.dim_thickness <= in_rec.dim_width THEN 
              item_out_rec.key_size_entered := in_rec.dim_thickness; 
            ELSE 
              item_out_rec.key_size_entered := in_rec.dim_width; 
            END IF; 
          ELSE 
            item_out_rec.key_size_entered := 0; 
          END IF; 

          -- If key size is notin mm converted 
          IF item_out_rec.key_size_uom <> 'mm' THEN 
            P_conv_uom (item_out_rec.key_size_uom, 'mm', 
            item_out_rec.key_size_entered, 
            item_out_rec.key_size, lv_dummy, lv_dummy); 
          ELSE 
            item_out_rec.key_size := item_out_rec.key_size_entered; 
          END IF; 

          item_out_rec.r3_sales_order := in_rec.r3_sales_order; 

          item_out_rec.r3_sales_order_item := in_rec.r3_sales_order_item; 

          item_out_rec.item_status := 'O'; 

          item_out_rec.date_created := SYSDATE; 

          item_out_rec.time_created := To_char (SYSDATE, 'hh24:mi:ss'); 

          item_out_rec.created_by := 'SAP_I/F'; 

          item_out_rec.plant_no := To_number (in_rec.site); 

          item_out_rec.edition := 1; 

          item_out_rec.dim_diameter := in_rec.dim_diameter; 

          item_out_rec.dim_width := in_rec.dim_width; 

          item_out_rec.dim_thickness := in_rec.dim_thickness; 

          item_out_rec.dim_uom := in_rec.dim_uom; 

          item_out_rec.primary_dim := in_rec.primary_dim; 

          item_out_rec.material_number := in_rec.material_number; 

          item_out_rec.material_description := in_rec.material_description; 

          item_out_rec.contract := in_rec.contract; 

          item_out_rec.contract_item := in_rec.contract_item; 

          lv_import_status_flag := FALSE; 

          IF lv_item_check = 'N' -- insert new sales order item 
          THEN 
            pk_sap_intf_api.prAddSalesOrderLog(pImportId_in => in_rec.import_id
                                             ,pSalesOrder_in => in_rec.r3_sales_order
                                             ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                             ,pActionTaken_in => 'Order Item is NOT in STAR, Insert new Item: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
            INSERT INTO r3_sales_order_items 
                        (r3_sales_order, 
                         r3_sales_order_item, 
                         key_size, 
                         item_status, 
                         date_created, 
                         time_created, 
                         created_by, 
                         plant_no, 
                         key_size_entered, 
                         key_size_uom, 
                         edition, 
                         alloy_code, 
                         quality_grade_code, 
                         dim_diameter, 
                         dim_thickness, 
                         dim_width, 
                         dim_uom, 
                         primary_dim, 
                         material_number, 
                         material_description, 
                         contract, 
                         contract_item) 
            VALUES      (item_out_rec.r3_sales_order, 
                         item_out_rec.r3_sales_order_item, 
                         item_out_rec.key_size, 
                         item_out_rec.item_status, 
                         item_out_rec.date_created, 
                         item_out_rec.time_created, 
                         item_out_rec.created_by, 
                         item_out_rec.plant_no, 
                         item_out_rec.key_size_entered, 
                         item_out_rec.key_size_uom, 
                         item_out_rec.edition, 
                         item_out_rec.alloy_code, 
                         item_out_rec.quality_grade_code, 
                         item_out_rec.dim_diameter, 
                         item_out_rec.dim_thickness, 
                         item_out_rec.dim_width, 
                         in_rec.dim_uom, 
                         item_out_rec.primary_dim, 
                         item_out_rec.material_number, 
                         item_out_rec.material_description, 
                         item_out_rec.contract, 
                         item_out_rec.contract_item ); 

            lv_import_status_flag := TRUE; 

            IF lv_header_check = 'Y' THEN 
              lv_import_status_text := ' : Added Item '; 

              lv_import_status_text2 := ' to existing Order Header '; 
            ELSE 
              lv_import_status_text := ' : Added Item '; 

              lv_import_status_text2 := ' to new Order Header '; 
            END IF; 
          ELSE -- update sales order item 
            pk_sap_intf_api.prAddSalesOrderLog(pImportId_in => in_rec.import_id
                                             ,pSalesOrder_in => in_rec.r3_sales_order
                                             ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                             ,pActionTaken_in => 'Order Item is in STAR, Update Any Changes: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
            IF item_curr_rec.item_status <> in_rec.item_status 
               AND in_rec.item_status IS NOT NULL THEN 
              -- STCR 4278 Start: added nested if statement to ignore SAP item status changes from 'L' to 'O' 
              IF item_curr_rec.item_status = 'L' 
                 AND in_rec.item_status = 'O' THEN 
                NULL; 
              ELSIF item_curr_rec.spec_code_id IS NOT NULL 
                    AND in_rec.item_status = 'O' THEN 
                UPDATE r3_sales_order_items 
                SET    item_status = 'L' 
                WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                       AND r3_sales_order_item = 
                           item_out_rec.r3_sales_order_item; 

                lv_import_status_flag := TRUE; 
              ELSE 
                UPDATE r3_sales_order_items 
                SET    item_status = in_rec.item_status 
                WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                       AND r3_sales_order_item = 
                           item_out_rec.r3_sales_order_item; 

                lv_import_status_flag := TRUE; 
              END IF; 
            END IF; 

            IF item_curr_rec.key_size <> item_out_rec.key_size 
               AND item_out_rec.key_size IS NOT NULL 
               AND ( item_out_rec.plant_no NOT IN ( 20, 24 ) 
                      OR item_out_rec.key_size <> 0 ) THEN 
              UPDATE r3_sales_order_items 
              SET    key_size = item_out_rec.key_size 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            --             if item_curr_rec.plant_no <> item_out_rec.plant_no and item_out_rec.plant_no IS NOT NULL then 
            --               update r3_sales_order_items 
            --                 set plant_no = item_out_rec.plant_no 
            --               where r3_sales_order = item_out_rec.r3_sales_order 
            --                 and r3_sales_order_item = item_out_rec.r3_sales_order_item; 
            --               lv_import_status_flag := TRUE; 
            --             end if; 
            IF item_curr_rec.key_size_entered <> item_out_rec.key_size_entered 
               AND item_out_rec.key_size_entered IS NOT NULL 
               AND ( item_out_rec.plant_no NOT IN ( 20, 24 ) 
                      OR item_out_rec.key_size_entered <> 0 ) THEN 
              UPDATE r3_sales_order_items 
              SET    key_size_entered = item_out_rec.key_size_entered 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.key_size_uom <> item_out_rec.key_size_uom 
               AND item_out_rec.key_size_uom IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    key_size_uom = item_out_rec.key_size_uom 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.alloy_code <> item_out_rec.alloy_code 
               AND item_out_rec.alloy_code IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    alloy_code = item_out_rec.alloy_code 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.quality_grade_code <> 
               item_out_rec.quality_grade_code 
               AND item_out_rec.quality_grade_code IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    quality_grade_code = item_out_rec.quality_grade_code 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.dim_diameter <> item_out_rec.dim_diameter 
               AND item_out_rec.dim_diameter IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    dim_diameter = item_out_rec.dim_diameter 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.dim_thickness <> item_out_rec.dim_thickness 
               AND item_out_rec.dim_thickness IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    dim_thickness = item_out_rec.dim_thickness 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.dim_width <> item_out_rec.dim_width 
               AND item_out_rec.dim_width IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    dim_width = item_out_rec.dim_width 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.dim_uom <> item_out_rec.dim_uom 
               AND item_out_rec.dim_uom IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    dim_uom = item_out_rec.dim_uom 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.primary_dim <> item_out_rec.primary_dim 
               AND item_out_rec.primary_dim IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    primary_dim = item_out_rec.primary_dim 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.material_number <> item_out_rec.material_number 
               AND item_out_rec.material_number IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    material_number = item_out_rec.material_number 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.material_description <> 
               item_out_rec.material_description 
               AND item_out_rec.material_description IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    material_description = item_out_rec.material_description 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.contract <> item_out_rec.contract 
               AND item_out_rec.contract IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    contract = item_out_rec.contract 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            IF item_curr_rec.contract_item <> item_out_rec.contract_item 
               AND item_out_rec.contract_item IS NOT NULL THEN 
              UPDATE r3_sales_order_items 
              SET    contract_item = item_out_rec.contract_item 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item; 

              lv_import_status_flag := TRUE; 
            END IF; 

            lv_import_status_text := ' : Updated Item '; 

            lv_import_status_text2 := ' to existing Order Header '; 
          END IF; 

          IF lv_import_status_flag THEN 
            INSERT INTO r3_if_actions 
                        (interface, 
                         import_id, 
                         action_taken, 
                         r3_sales_order, 
                         r3_sales_order_item) 
            VALUES      ('SALES', 
                         in_rec.import_id, 
                         To_char (SYSDATE, 'dd-MON-yyyy hh24:mi:ss') 
                         || lv_import_status_text 
                         || item_out_rec.r3_sales_order_item 
                         || ' Alloy=*' 
                         || item_out_rec.alloy_code 
                         || '* Quality Code=*' 
                         || item_out_rec.quality_grade_code 
                         || '* ' 
                         || lv_import_status_text2 
                         || item_out_rec.r3_sales_order, 
                         item_out_rec.r3_sales_order, 
                         item_out_rec.r3_sales_order_item ); 
          END IF; 

          lv_import_status_flag := FALSE; 

          -- #TAF 8/6/2007.  Code to auto copy Toronto Sales Order to Order Specs. 
          -- Call the procedure to Copy the basis_spec to an order Spec here.  
          IF ( item_out_rec.plant_no IN ( '11', '32', '13' ) ) 
             AND ( item_out_rec.contract IS NOT NULL ) THEN 
            -- CURSOR to get basis spec data for copy to order function. 
            OPEN get_basis_spec_data (p_contract_in => item_out_rec.contract); 

            FETCH get_basis_spec_data INTO lv_basis_spec_id, lv_spec_code_type, 
            lv_filter_low, lv_filter_high, lv_spec_code_name; 

            CLOSE get_basis_spec_data; 

            --Calls copy to order function to create the new Order Spec ID IF the copy_indicator is Y. 
            IF lv_basis_spec_id IS NOT NULL THEN 
              INSERT INTO gtt_copy_specs 
                          (spec_code_id, 
                           traveler_text_yn, 
                           chem_text_yn, 
                           comp_text_yn, 
                           mech_text_yn, 
                           metl_text_yn, 
                           rel_text_yn, 
                           gen_text_yn, 
                           man_text_yn, 
                           spec_text_yn, 
                           test_text_yn, 
                           trep_text_yn, 
                           note_text_yn, 
                           approvals_yn) 
              VALUES      (lv_basis_spec_id, 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y', 
                           'Y' ); 

              lv_new_spec_code_id := 
              pk_tech_edit.Fncopy_to_order_spec(lv_basis_spec_id, 
              'O' 
              -- should not be lv_spec_code_type because we want to create an ORDER spec, not a BASIS spec 
              , lv_spec_code_name, lv_filter_low, lv_filter_high, 
              item_out_rec.plant_no, 
                                     item_out_rec.r3_sales_order 
              , 
              item_out_rec.r3_sales_order_item); 

              -- UPDATE R3_SALES_ORDER_ITEMS with new spec_code_id 
              UPDATE r3_sales_order_items 
              SET    spec_code_id = lv_new_spec_code_id 
              WHERE  r3_sales_order = item_out_rec.r3_sales_order 
                     AND r3_sales_order_item = item_out_rec.r3_sales_order_item 
                     AND contract = item_out_rec.contract; 
            -- Commit the updated record,     
            --COMMIT; 
            END IF; 
          END IF; -- end #TAF 8/6/2007 
          -- Remove from Imported Data Table 
          DELETE FROM r3_imported_sales_data 
          WHERE  import_id = in_rec.import_id; 

          COMMIT; 
      END LOOP; 
      -- pk_debug.prWriteDebugRec(ptModuleName_in => 'R3_SALES_ORDERS'
      --                        ,vcDebugText_in => 'Now call US Heats');
      -- Now Get US heats and populate R3_PROCESS_ORDERS Table 
      ---Note that the heat number is chars 1-7 of the batch number. 
      FOR in_rec IN get_import_us_heats LOOP 
           pk_sap_intf_api.prAddBatchAllocLog(pImportId_in => in_rec.import_id
                                              ,pSite_in => in_rec.site
                                              ,pSalesOrder_in => in_rec.r3_sales_order
                                              ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                              ,pBatchNumber_in => in_rec.r3_batch_number
                                              ,pAlloyCode_in => ''
                                              ,pActionTaken_in => 'Batch picked up from r3_imported_sales_data for processing: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
          lv_heat_check := 'N'; 
          lv_heat_number := SUBSTR(in_rec.r3_batch_number,1,7); 
          ln_char_pos := INSTR(lv_heat_number,'-'); 

          IF ln_char_pos > 1 THEN 
            lv_heat_number := SUBSTR (lv_heat_number, 1, ( ln_char_pos - 1 )); 
          END IF; 

          OPEN get_us_heats (lv_heat_number); 
          FETCH get_us_heats INTO heat_curr_rec; 
          IF get_us_heats%NOTFOUND THEN 
            lv_heat_check := 'N'; 
          ELSE 
            lv_heat_check := 'Y'; 
          END IF; 
          CLOSE get_us_heats; 

          batch_out_rec.alloy_code := heat_curr_rec.alloy_code; 
          heat_out_rec.heat_num := heat_curr_rec.heat_num; 
          -- Determine the Alloy Code 
          heat_out_rec.alloy_code := NULL; 
          
          -- Check on ST_ALLOYS 
          OPEN get_alloy_code (in_rec.grade); 
          FETCH get_alloy_code INTO heat_out_rec.alloy_code; 
          CLOSE get_alloy_code; 

          -- Special Case for TI153 
          IF heat_out_rec.alloy_code IS NULL 
             AND in_rec.grade = 'TI153' THEN 
            heat_out_rec.alloy_code := 'Ti15-3'; 
          END IF; 

          IF lv_heat_check = 'N' THEN 
            batch_out_rec.alloy_code := heat_out_rec.alloy_code; 
          END IF; 

          -- Start the Insert into MT_US_HEATS Routine 
          -- First check if alloy code is NULL if So dont continue with Insert 
          IF heat_out_rec.alloy_code IS NOT NULL THEN 
            -- Determine the quality code 
            heat_out_rec.quality_grade_code := NULL; 
            OPEN get_quality_grade_code (in_rec.quality); 
            FETCH get_quality_grade_code INTO heat_out_rec.quality_grade_code; 
            CLOSE get_quality_grade_code; 

            IF heat_out_rec.quality_grade_code IS NOT NULL THEN 
              -- Determine the source of the ingot. 
              -- Assume Henderson Mill 
              heat_out_rec.heat_source := '13'; 
              -- Morgantown heats begin with a numeral or have a second character of 'N' 
              IF SUBSTR(lv_heat_number, 1, 1) IN ( '0', '1', '2', '3', 
                                                    '4', '5', '6', '7', 
                                                    '8', '9' ) THEN 
                heat_out_rec.heat_source := '20'; 
              ELSIF SUBSTR(lv_heat_number, 2, 1) = 'N' THEN 
                heat_out_rec.heat_source := '20'; 
              END IF; 

              heat_out_rec.heat_num := lv_heat_number; 
              heat_out_rec.date_created := SYSDATE; 
              heat_out_rec.time_created := To_char (SYSDATE, 'hh24:mi:ss'); 
              heat_out_rec.created_by := 'SAP_IF'; 
              heat_out_rec.edition := 1; 
              heat_out_rec.rec_status := 'A'; 
              heat_out_rec.site := heat_out_rec.heat_source; 
              lv_import_status_flag := FALSE; 
              -- Check if Heat is NOT on MT_US_HEATS . If not then add 
              IF lv_heat_check = 'N' THEN 
                pk_sap_intf_api.prAddBatchAllocLog(pImportId_in => in_rec.import_id
                                              ,pSite_in => in_rec.site
                                              ,pSalesOrder_in => in_rec.r3_sales_order
                                              ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                              ,pBatchNumber_in => in_rec.r3_batch_number
                                              ,pAlloyCode_in => heat_out_rec.alloy_code
                                              ,pActionTaken_in => 'Parent Heat Not in STAR, Adding '||heat_out_rec.heat_num||' to STAR: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
                SELECT mt_us_heat_id_seq.NEXTVAL 
                INTO   heat_out_rec.heat_id 
                FROM   sys.dual; 

                INSERT INTO mt_us_heats 
                            (heat_id, 
                             heat_source, 
                             heat_num, 
                             alloy_code, 
                             date_created, 
                             rec_status, 
                             time_created, 
                             created_by, 
                             edition, 
                             site, 
                             quality_grade_code) 
                VALUES      (heat_out_rec.heat_id, 
                             heat_out_rec.heat_source, 
                             heat_out_rec.heat_num, 
                             heat_out_rec.alloy_code, 
                             heat_out_rec.date_created, 
                             heat_out_rec.rec_status, 
                             heat_out_rec.time_created, 
                             heat_out_rec.created_by, 
                             heat_out_rec.edition, 
                             heat_out_rec.site, 
                             heat_out_rec.quality_grade_code ); 

                lv_import_status_text := ' : Added US Heats - Heat ID: '; 
                lv_import_status_flag := TRUE; 
              ELSE -- update mt_us_heats 
                heat_out_rec.heat_id := heat_curr_rec.heat_id; 
                lv_import_status_text := ' : Updated US Heats - Heat ID: ';
                lv_import_status_flag := TRUE;  
              END IF; 
              IF lv_import_status_flag THEN 
                INSERT INTO r3_if_actions 
                            (interface, 
                             import_id, 
                             action_taken, 
                             r3_sales_order, 
                             r3_sales_order_item) 
                VALUES      ('SALES', 
                             in_rec.import_id, 
                             To_char (SYSDATE, 'dd-MON-yyyy hh24:mi:ss') 
                             || lv_import_status_text 
                             || To_char(heat_out_rec.heat_id), 
                             in_rec.r3_sales_order, 
                             in_rec.r3_sales_order_item ); 
              END IF; 
              lv_import_status_flag := FALSE; 
            END IF; 
          END IF; 
          -- If the batch allocation is for site 11 (Toronto) then insert a record into the r3_process_orders. 
          -- Must have an alloy code 
          -- Ie Alloy code from SAP must have been found on STAR 
          -- Mod 1.1 added the AND INSTR check so dummy records are not added to r3_process_orders 
          -- If the batch number has the sales_order_number anywhere in its string then it is a dummy records 
          pk_sap_intf_api.prAddBatchAllocLog(pImportId_in => in_rec.import_id
                                              ,pSite_in => in_rec.site
                                              ,pSalesOrder_in => in_rec.r3_sales_order
                                              ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                              ,pBatchNumber_in => in_rec.r3_batch_number
                                              ,pAlloyCode_in => heat_out_rec.alloy_code
                                              ,pActionTaken_in => 'Validation for sites 11&32, site is '||in_rec.site||' Alloy Code is '||batch_out_rec.alloy_code||' Batch Number is '||in_rec.r3_batch_number);
          IF in_rec.site IN ( '11', '32' ) 
          AND batch_out_rec.alloy_code IS NOT NULL 
          AND INSTR(in_rec.r3_batch_number, in_rec.r3_sales_order) = 0 THEN 
            -- Now check if the order item is present on STAR. Note that the SAP interface may well send over 
            -- batch allocations for old US orders not booked on STAR. 
            -- Without this check the job will fail with a FK lookup error 
            lv_item_check := 'N'; 

            OPEN get_order_item (in_rec.r3_sales_order, 
            in_rec.r3_sales_order_item); 

            FETCH get_order_item INTO item_curr_rec; 

            IF get_order_item%NOTFOUND THEN 
              lv_item_check := 'N'; 
            ELSE 
              lv_item_check := 'Y'; 
            END IF; 

            CLOSE get_order_item; 

            IF lv_item_check = 'Y' THEN --- Order Item is on STAR 
              pk_sap_intf_api.prAddBatchAllocLog(pImportId_in => in_rec.import_id
                                              ,pSite_in => in_rec.site
                                              ,pSalesOrder_in => in_rec.r3_sales_order
                                              ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                              ,pBatchNumber_in => in_rec.r3_batch_number
                                              ,pAlloyCode_in => heat_out_rec.alloy_code
                                              ,pActionTaken_in => 'Order Item in STAR , Checking Batch Allocation: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
              -- Now check if allocation has already been done manually. 
              lv_allocation_check := 'N'; 

              OPEN get_allocation (in_rec.r3_sales_order, 
              in_rec.r3_sales_order_item, 
              in_rec.r3_batch_number ); 

              FETCH get_allocation INTO batch_curr_rec; 

              IF get_allocation%NOTFOUND THEN 
                lv_allocation_check := 'N'; 
              ELSE 
                lv_allocation_check := 'Y'; 
              END IF; 

              CLOSE get_allocation; 

              batch_out_rec.r3_process_order := in_rec.r3_batch_number; 
              batch_out_rec.r3_sales_order := in_rec.r3_sales_order; 
              batch_out_rec.r3_sales_order_item := in_rec.r3_sales_order_item; 
              batch_out_rec.r3_batch_number := in_rec.r3_batch_number; 
              batch_out_rec.r3_ingot_ref := lv_heat_number; 
              batch_out_rec.process_order_status := 'O'; 
              batch_out_rec.date_created := SYSDATE; 
              batch_out_rec.time_created := To_char (SYSDATE, 'hh24:mi:ss'); 
              batch_out_rec.created_by := 'SAP_I/F'; 
              lv_import_status_flag := FALSE; 
              --STCR 7362 Assign the variables for recording any exception
              lvSalesOrder := batch_out_rec.r3_sales_order;
              lvSalesOrderItem := batch_out_rec.r3_sales_order_item;
              lvBatchNumber := batch_out_rec.r3_batch_number;
              
              IF lv_allocation_check = 'N' THEN 
                pk_sap_intf_api.prAddBatchAllocLog(pImportId_in => in_rec.import_id
                                              ,pSite_in => in_rec.site
                                              ,pSalesOrder_in => in_rec.r3_sales_order
                                              ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                              ,pBatchNumber_in => in_rec.r3_batch_number
                                              ,pAlloyCode_in => heat_out_rec.alloy_code
                                              ,pActionTaken_in => 'Allocation NOT in STAR , Writing to Process Orders: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
                --- Allocation does not exist so add. 
                -- Write record to the R3_process orders table 
                INSERT INTO r3_process_orders 
                            (r3_process_order, 
                             r3_sales_order, 
                             r3_sales_order_item, 
                             process_order_status, 
                             date_created, 
                             time_created, 
                             created_by, 
                             r3_batch_number, 
                             r3_ingot_ref, 
                             alloy_code) 
                VALUES      (batch_out_rec.r3_process_order, 
                             batch_out_rec.r3_sales_order, 
                             batch_out_rec.r3_sales_order_item, 
                             batch_out_rec.process_order_status, 
                             batch_out_rec.date_created, 
                             batch_out_rec.time_created, 
                             batch_out_rec.created_by, 
                             batch_out_rec.r3_batch_number, 
                             batch_out_rec.r3_ingot_ref, 
                             batch_out_rec.alloy_code ); 

                lv_import_status_flag := TRUE; 
                lv_import_status_text := ' : Added Batch '; 
                -- 
                -- Check ingot chemsitry results against order spec (STCR 6363) 
                IF pk_tech_edit.Fningotchemfailure(pnmspeccodeid_in => 
                                                   item_curr_rec.spec_code_id, 
                      pvcheatno_in => batch_out_rec.r3_ingot_ref) THEN 
                  pk_sap_intf_api.prAddBatchAllocLog(pImportId_in => in_rec.import_id
                                              ,pSite_in => in_rec.site
                                              ,pSalesOrder_in => in_rec.r3_sales_order
                                              ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                              ,pBatchNumber_in => in_rec.r3_batch_number
                                              ,pAlloyCode_in => heat_out_rec.alloy_code
                                              ,pActionTaken_in => 'Raising STAR Watch for Ingot Chemistry Failure: '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
                  -- Raise STAR WATCH 
                  pk_tech_edit.Prraiseingotchemfailemail(pvcbatchno_in => batch_out_rec.r3_process_order, 
                                                         pvcheatno_in => batch_out_rec.r3_ingot_ref, pvcsalesorder_in => batch_out_rec.r3_sales_order, 
                                                         pvcsalesorderitem_in => batch_out_rec.r3_sales_order_item, 
                                                         pnmspeccodeid_in => item_curr_rec.spec_code_id); 
                END IF;
              ELSE -- update process order  
                pk_sap_intf_api.prAddBatchAllocLog(pImportId_in => in_rec.import_id
                                              ,pSite_in => in_rec.site
                                              ,pSalesOrder_in => in_rec.r3_sales_order
                                              ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                              ,pBatchNumber_in => in_rec.r3_batch_number
                                              ,pAlloyCode_in => heat_out_rec.alloy_code
                                              ,pActionTaken_in => 'Allocation in STAR , Writing to Actions that Batch Updated : '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
                lv_import_status_flag := TRUE; -- STCR 7351
                lv_import_status_text := ' : Updated Batch '; 
              END IF; -- End Check on Allocation already done. 
        IF lv_import_status_flag THEN 
      --- Write record to interface actions table to record batch added 
          INSERT INTO r3_if_actions 
          (interface, 
          import_id, 
          action_taken, 
          r3_sales_order, 
          r3_sales_order_item) 
          VALUES      ('SALES', 
          in_rec.import_id, 
          To_char (SYSDATE, 'dd-MON-yyyy hh24:mi:ss') 
          || lv_import_status_text 
          || batch_out_rec.r3_batch_number, 
          batch_out_rec.r3_sales_order, 
          batch_out_rec.r3_sales_order_item ); 
          END IF; 

          lv_import_status_flag := FALSE; 
      /* 
       -- 
       -- Check ingot chemsitry results against order spec (STCR 6363) 
      IF pk_tech_edit.fnIngotChemFailure(pnmSpecCodeId_in    =>   item_curr_rec.spec_code_id 
                                                      ,pvcHeatNo_in    =>   batch_out_rec.r3_ingot_ref) 
      THEN 
          -- Raise STAR WATCH 
          pk_tech_edit.prRaiseIngotChemFailEmail(pvcBatchNo_in   => batch_out_rec.r3_process_order 
                                                                ,pvcHeatNo_in    => batch_out_rec.r3_ingot_ref 
                                                                ,pvcSalesOrder_in  => batch_out_rec.r3_sales_order 
                                                                ,pvcSalesOrderItem_in   => batch_out_rec.r3_sales_order_item 
                                                                ,pnmSpecCodeId_in     =>  item_curr_rec.spec_code_id ); 
      END IF;                 
      */ 
        END IF; --- End Check on check that Order Line Is Present 
      END IF; --- End check that order is for Site 11 (Toronto) 
       pk_sap_intf_api.prAddBatchAllocLog(pImportId_in => in_rec.import_id
                                              ,pSite_in => in_rec.site
                                              ,pSalesOrder_in => in_rec.r3_sales_order
                                              ,pSalesOrderItem_in => in_rec.r3_sales_order_item
                                              ,pBatchNumber_in => in_rec.r3_batch_number
                                              ,pAlloyCode_in => heat_out_rec.alloy_code
                                              ,pActionTaken_in => 'Record to be removed from Imported Data Table : '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
       -- Remove from Imported Data Table 
        DELETE FROM r3_imported_sales_data 
        WHERE  import_id = in_rec.import_id; 

        COMMIT; 
      END LOOP; -- End of records 
      -- pk_debug.prWriteDebugRec(ptModuleName_in => 'R3_SALES_ORDERS'
      --                         ,vcDebugText_in => 'After call to US Heats');
      -- Now Process records marked as deleted by SAP 
      -- For now just delete them ! 
      DELETE FROM r3_imported_sales_data 
      WHERE  delete_flg <> ' '; 
      -- Now process records with a batch number but are for sites where we dont need to extract the Heat # nor record the allocation in STAR 
      -- For now just delete them! 
      DELETE FROM r3_imported_sales_data 
      WHERE  delete_flg = ' ' 
             AND r3_batch_number <> ' '; 
      -- Update the control file to indicate job completed. 
      UPDATE r3_if_control 
      SET    control_date3 = SYSDATE 
      WHERE  if_name = 'SALES'; 

      COMMIT; 
  EXCEPTION
      WHEN OTHERS THEN 
        pk_error_log.prRecordDetailsHalt(p_SqlCode_in  => SQLCODE
                                         ,p_SqlErrm_in    => SUBSTR(SQLERRM,1,200)
                                         ,p_ModuleName_in => 'pk_sap_interfaces.pr_import_data'
                                         ,p_KeyData_in    => 'Sales Order: '||lvSalesOrder||' Item: '||lvSalesOrderItem||' Batch: '||lvBatchNumber);
  END pr_import_data; 
/*------------------------------------------------------------------------------------------------------------- 
|| 
||  Procedure to populate STAR tables with SAP WTL data 
|| 
*/ 
  ------------------------------------------------------------------------------------------------------------- 
  PROCEDURE Pr_populatewtldata (p_site_in                IN 
  r3_wtl_headers.site%TYPE, 
                                p_work_centre_in         IN 
  r3_wtl_headers.work_centre%TYPE, 
                                p_mrp_controller_in      IN 
  r3_wtl_headers.mrp_controller%TYPE, 
                                p_customer_in            IN 
  r3_wtl_lines.customer%TYPE, 
                                p_availability_in        IN VARCHAR2, 
                                p_steps_back_in          IN 
  r3_wtl_headers.steps_back%TYPE, 
                                p_import_comments_in     IN 
  r3_wtl_headers.comments%TYPE, 
                                p_import_instance_id_out OUT 
  r3_wtl_headers.import_instance_id%TYPE, 
                                p_sqlcode_out            OUT NUMBER) 
  /* 
  || 
  || Procedure queries the SAP tables ZWTL1 and ZWTL2 via the appropriate synonyms R3_ZWTL1 and R3_ZWTL2, and populates 
  || the tables R3_WTL_HEADERS and R3_WTL_LINES with the relevant data given the incoming parameters. 
  || 
  || This data is then inserted into the table BATCH_STATUS_DATA by the database procedure BATCH_STATUS 
  || called from the AFTERPFORM trigger in the report batch_status_report.rdf. Once this table is populated 
  || queries in the .rdf report read from this table to produce the batch status report. 
  || 
  ||  NOTE: This procedure uses a cursor variable. Why and how this works : 
  || 
  ||        Because a user may want to search for material AVAILABLE at the given resource, or NEARLY AVAILABLE and a number of steps (operations) back 
  ||      from the given resource, then the SELECT statement to query the SAP WTL tables needs to have a different WHERE clause. By using a cursor 
  ||      variable we are able to open this variable and assign the different SELECT statement to it, depeding on the availability parameter. A cursor 
  ||      variable will point to ANY cursor object, so no matter which SELECT statement is used, the SAME cursor variable can be used to reference the 
  ||      corresponding resulting dataset. See online help in TOAD or Feuerstein's Oracle PL/SQL Programming (4th edition p501) for a full explanantion 
  ||      of this feature. 
  || 
  */ 
  IS 
    cspace CONSTANT VARCHAR2 (1) DEFAULT ' '; 
    nindx        PLS_INTEGER; 
    dsysdate     DATE; 
    -- PL/SQL Table definition for holding R3 wtl data  
    TYPE tabwtldata 
      IS TABLE OF r3_wtl_lines%ROWTYPE INDEX BY PLS_INTEGER; 
    -- Collection based on previous table declaration to hold the data 
    clwtldata    TABWTLDATA; 
    recwtldata   r3_wtl_lines%ROWTYPE; 
    recwtlhdr    r3_wtl_headers%ROWTYPE; 
    -- Record structure to return R3 WTL data 
    TYPE rtr3wtldata IS RECORD ( 
      vcprocessorder r3_zwtl1.aufnr%TYPE, 
      vcbatchno r3_zwtl1.charg%TYPE, 
      dschedfindate r3_zwtl1.sseld%TYPE, 
      vcbatchcomments r3_zwtl1.comments%TYPE, 
      vcopno r3_zwtl1.vornr%TYPE, 
      ndayslate r3_zwtl1.dayslate%TYPE, 
      nwaitdays r3_zwtl1.waitdays%TYPE, 
      vcorderno r3_zwtl2.kdauf%TYPE, 
      vcitemno r3_zwtl2.kdpos%TYPE, 
      vccustomer r3_zwtl2.kunnr%TYPE); 
    recr3wtldata RTR3WTLDATA; 
    -- REF CURSOR and cursor variable to select R3 WTL data 
    TYPE rcwtldata IS ref CURSOR 
    RETURN rtr3wtldata; 
    cvwtldata    RCWTLDATA; 
    exbulkinserterror EXCEPTION; 
    PRAGMA EXCEPTION_INIT (exbulkinserterror, -24381); 
    -- Function to return the number of days material has been waiting at the given resource 
    -- 
    FUNCTION Lfn_calcdayswait(p_recwtldata_in IN r3_wtl_lines%ROWTYPE, 
                              p_site_no_in    IN VARCHAR2) 
    RETURN NUMBER 
    IS 
      dlocalsysdate  DATE; 
      vcactfindate   VARCHAR2(8); 
      dactfindate    DATE; 
      nnoofdayswait  NUMBER; 
      vcprocessorder r3_zwtl1.aufnr%TYPE; 
      vcprevop       VARCHAR2(4); 
    BEGIN 
        --Get the previous op and determine actual finish date 
        vcprocessorder := Lpad(p_recwtldata_in.process_order_no, 12, '0'); 

        SELECT prev_vornr 
        INTO   vcprevop 
        FROM   r3_zwtl3 
        WHERE  werks = p_site_no_in 
               AND aufnr = vcprocessorder 
               AND vornr = p_recwtldata_in.op_number; 

        -- 
        -- Now read for the LAST actual finsh date of the previous op and calculate wait days 
        -- 
        SELECT Max(iedd) 
        INTO   vcactfindate 
        FROM   r3_zwtl1 
        WHERE  werks = p_site_no_in 
               AND aufnr = vcprocessorder 
               AND vornr = vcprevop; 

        -- 
        -- Now calculate the wait days. 
        -- 
        IF vcactfindate != '00000000' THEN 
          -- Previous op booked complete 
          dactfindate := Nvl(To_date (vcactfindate, 'YYYYMMDD'), 
                         To_date('19000101', 'YYYYMMDD')); 

          dlocalsysdate := To_date (To_char (SYSDATE, 'YYYYMMDD'), 'YYYYMMDD'); 

          IF dactfindate < dlocalsysdate THEN 
            -- Determine days wait 
            nnoofdayswait := dlocalsysdate - dactfindate; 
          ELSE 
            nnoofdayswait := 0; 
          END IF; 
        ELSE 
          -- Previous op NOT booked complete 
          nnoofdayswait := 0; 
        END IF; 

        RETURN( nnoofdayswait ); 
    -- 
    -- EXCEPTIONS 
    -- 
    EXCEPTION 
      WHEN no_data_found THEN 
                 -- Set wait days to 0 
                 Debug_rec('Calc days wait - NO DATA FOUND .....'); 

                 nnoofdayswait := 0; 

                 RETURN( nnoofdayswait ); WHEN OTHERS THEN 
    -- Set wait days to 0 
    Debug_rec('Untrapped error in local function lfn_CalcDaysWait [' 
              ||To_char(SQLCODE) 
              ||']'); 

    nnoofdayswait := 999; 

    RETURN( nnoofdayswait ); 
    -- 
    -- Exit local function  lfn_CalcDaysWait 
    -- 
    END lfn_calcdayswait; 
  BEGIN 
      -- 
      --  Loop through the WTL records for the given criteria 
      -- 
      nindx := 1; 

      -- Generate the import instance number for this WTL data import 
      p_import_instance_id_out := pk_master_data.fn_gen_id_seq_nextval; 

      -- Execute the appropriate SELECT, via  CURSOR VARIABLE,  depending on availalbility parameter 
      IF p_availability_in = 'A' THEN 
        -- Importing AVAILABLE at resouce batches 
        OPEN cvwtldata FOR 
          SELECT z1.aufnr, 
                 z1.charg, 
                 z1.sseld, 
                 z1.comments, 
                 z1.vornr, 
                 z1.dayslate, 
                 z1.waitdays, 
                 z2.kdauf, 
                 z2.kdpos, 
                 z2.kunnr 
          FROM   r3_zwtl1 z1, 
                 r3_zwtl2 z2 
          WHERE  z1.werks = p_site_in 
                 AND z1.arbpl = p_work_centre_in 
                 AND z1.prev_conf = '*' 
                 AND z1.dispo LIKE p_mrp_controller_in 
                 AND z1.zteco_fg = cspace 
                 AND z2.werks = z1.werks 
                 AND z2.aufnr = z1.aufnr 
                 AND z2.kunnr LIKE p_customer_in; 
      ELSE 
        -- Importing NEARLY AVAILABLE at resource batches 
        OPEN cvwtldata FOR 
          SELECT z1.aufnr, 
                 z1.charg, 
                 z1.sseld, 
                 z1.comments, 
                 z1.vornr, 
                 z1.dayslate, 
                 z1.waitdays, 
                 z2.kdauf, 
                 z2.kdpos, 
                 z2.kunnr 
          FROM   r3_zwtl1 z1, 
                 r3_zwtl2 z2 
          WHERE  z1.werks = p_site_in 
                 AND z1.arbpl = p_work_centre_in 
                 -- AND z1.prev_conf = cSpace 
                 AND To_number(z1.stepsback) <= p_steps_back_in 
                 AND z1.dispo LIKE p_mrp_controller_in 
                 AND z1.zteco_fg = cspace 
                 AND z2.werks = z1.werks 
                 AND z2.aufnr = z1.aufnr 
                 AND z2.kunnr LIKE p_customer_in; 
      END IF; 

      -- 
      -- Loop through the rows and populate collection based on STAR r3_wtl_lines table  
      --  
      LOOP 
          FETCH cvwtldata INTO recr3wtldata; 

          EXIT WHEN cvwtldata%NOTFOUND; 

          -- Build the wtl lines record 
          recwtldata.import_instance_id := p_import_instance_id_out; 

          recwtldata.line_number := nindx; 

          recwtldata.r3_order_no := Ltrim(recr3wtldata.vcorderno, 0); 

          recwtldata.r3_order_item_no := Ltrim(recr3wtldata.vcitemno, 0); 

          recwtldata.customer := Ltrim(recr3wtldata.vccustomer, 0); 

          recwtldata.batch_no := recr3wtldata.vcbatchno; 

          recwtldata.heat_no := Substr (recr3wtldata.vcbatchno, 1, 7); 

          recwtldata.process_order_no := Ltrim(recr3wtldata.vcprocessorder, 0); 

          recwtldata.sched_finish_date := Nvl(To_date ( 
                                          recr3wtldata.dschedfindate, 
                                              'YYYYMMDD'), 
                                          To_date( 
                                          '19000101', 'YYYYMMDD')); 

          recwtldata.op_number := recr3wtldata.vcopno; 

          recwtldata.batch_comments := recr3wtldata.vcbatchcomments; 

          recwtldata.use_or_ignore := 'U'; 

          -- Overdue ? 
          dsysdate := To_date (To_char (SYSDATE, 'YYYYMMDD'), 'YYYYMMDD'); 

          IF recwtldata.sched_finish_date < dsysdate THEN 
            -- Determine days late 
            recwtldata.days_late := dsysdate - recwtldata.sched_finish_date; 
          ELSE 
            recwtldata.days_late := 0; 
          END IF; 

          -- Calculate days wait at resource 
          recwtldata.days_wait := Lfn_calcdayswait(recwtldata, p_site_in); 

          -- recWtlData.days_wait := 0; 
          -- Insert record into collection 
          Clwtldata (nindx) := recwtldata; 

          -- Increment collection subscript 
          nindx := nindx + 1; 
      END LOOP; 

      -- Close the cursor variable 
      CLOSE cvwtldata; 

      -- 
      -- Create WTL header 
      -- 
      recwtlhdr.import_instance_id := p_import_instance_id_out; 

      recwtlhdr.run_date := SYSDATE; 

      recwtlhdr.run_time := To_char (SYSDATE, 'HH24:MI:SS'); 

      recwtlhdr.run_by := USER; 

      recwtlhdr.comments := p_import_comments_in; 

      recwtlhdr.site := p_site_in; 

      recwtlhdr.work_centre := p_work_centre_in; 

      recwtlhdr.availability := p_availability_in; 

      recwtlhdr.steps_back := p_steps_back_in; 

      recwtlhdr.mrp_controller := p_mrp_controller_in; 

      INSERT INTO r3_wtl_headers 
      VALUES recwtlhdr; 

      -- 
      -- Insert WTL lines into table from collection 
      -- 
      forall indx IN clwtldata.first .. clwtldata.last save EXCEPTIONS 
        INSERT INTO r3_wtl_lines 
        VALUES Clwtldata (indx); 

      COMMIT; 
  EXCEPTION 
    -- 
    -- Exception inserting WTLL data 
    -- 
    WHEN exbulkinserterror THEN 
               -- Write exception data to DEBUG 
               FOR indx IN 1 .. SQL%bulk_exceptions.count LOOP 
                   Debug_rec('Error ' 
                             ||To_char(indx) 
                             ||' Oracle error is ' 
                             ||To_char(SQL%Bulk_exceptions(indx).error_code)); 
               END LOOP; 

               p_import_instance_id_out := 0; 

               p_sqlcode_out := SQLCODE; 

               ROLLBACK; 
    -- 
    -- Trap unhandled exceptions 
    -- 
    WHEN OTHERS THEN 
               -- Set import instance to 0 to flag up error 
               p_import_instance_id_out := 0; 

               p_sqlcode_out := SQLCODE; 

               Debug_rec('WHEN OTHERS executed .....[' 
                         ||To_char(p_sqlcode_out) 
                         ||']'); 

               ROLLBACK; 
  -- 
  -- Exit pr_PopulateWtlData 
  -- 
  END pr_populatewtldata; 
/*------------------------------------------------------------------------------------------------------------- 
|| 
||  Procedure to remove WTL Import data greater than 7 days old. 
|| 
|| NOTE: This procedure is called from the POST-FORM trigger in te_0204_sapwtl_extract.fmb and 
||        as such, because it issues a COMMIT, has been declared with 
||    the AUTONOMOUS_TRANSACTION PRAGMA 
|| 
*/ 
  -------------------------------------------------------------------------------------------------------------    
  PROCEDURE Pr_removeoldimportdata 
  IS 
    PRAGMA autonomous_transaction; 
    nimportinstanceid NUMBER; 
    dsysdate          DATE; 
    -- Cursor to identify all reports > 12 days old 
    -- 
    CURSOR get_old_datasets IS 
      SELECT import_instance_id, 
             run_date 
      FROM   r3_wtl_headers 
      WHERE  dsysdate - run_date > 12 
      -- Changed to 12 from 7 for Issue 4408 JDD2009C9_2_Scheduled Issues 
      FOR UPDATE; 
  BEGIN 
      SELECT SYSDATE 
      INTO   dsysdate 
      FROM   dual; 

      -- Loop thru records > 12 days old. 
      FOR get_old_datasets_row IN get_old_datasets LOOP 
          -- save the import instance ID 
          nimportinstanceid := get_old_datasets_row.import_instance_id; 

          -- Delete the line data 
          DELETE FROM r3_wtl_lines 
          WHERE  import_instance_id = nimportinstanceid; 

          -- Delete the header 
          DELETE FROM r3_wtl_headers 
          WHERE  CURRENT OF get_old_datasets; 
      END LOOP; 

      COMMIT; 
  -- 
  -- Exit the form 
  -- 
  END pr_removeoldimportdata; 
/*------------------------------------------------------------------------------------------------------------- 
|| 
||  Procedure to remove Schedule Adherence Import data greater than 12 days old. 
|| 
|| NOTE: This procedure is  declared with the AUTONOMOUS_TRANSACTION PRAGMA 
|| 
*/ 
  -------------------------------------------------------------------------------------------------------------    
  PROCEDURE Prdeleteoldschedad 
  IS 
    PRAGMA autonomous_transaction; 
    -- 
    -- Local variables 
    nmrepid NUMBER; 
    -- 
    -- Cursor to identify all reports > 12 days old 
    CURSOR cridoldreports IS 
      SELECT report_instance_id, 
             import_date 
      FROM   r3_intf_schedad_headers 
      WHERE  SYSDATE - import_date > 12 
      FOR UPDATE; 
  -- 
  -- Remove the old data 
  -- 
  BEGIN 
      -- 
      -- Loop thru records > 12 days old. 
      FOR cridoldreports_row IN cridoldreports LOOP 
          nmrepid := cridoldreports_row.report_instance_id; 

          DELETE FROM export_csv_data 
          WHERE  report_instance_id = nmrepid; 

          -- Delete the line data 
          DELETE FROM r3_intf_schedad_lines 
          WHERE  report_instance_id = nmrepid; 

          -- Delete the header     
          DELETE FROM r3_intf_schedad_headers 
          WHERE  CURRENT OF cridoldreports; 
      END LOOP; 

      COMMIT; 
  -- 
  -- Exceptions 
  EXCEPTION 
    WHEN OTHERS THEN 
               -- Record error and re-raise 
               pk_error_log.Prrecorddetailshalt(p_sqlcode_in => SQLCODE, 
               p_sqlerrm_in => Substr(SQLERRM, 1, 200), 
               p_modulename_in => 'pk_sap_interfaces.prDeleteOldSchedAd', 
               p_keydata_in => 'Attempting to delete import 12 days older than ' 
                               ||To_char(SYSDATE, 'DD-MON-YYYY')); 
  END prdeleteoldschedad; 
  -- Function to create CSV data file to download to client PC and return the export id 
  FUNCTION Fnbatchstatuscsv(pnmreportinstanceid_in IN 
  r3_intf_schedad_headers.report_instance_id%TYPE) 
  RETURN NUMBER 
  IS 
    -- Check Whether Batch  
    CURSOR crchkdataexists( 
      cpnmrepid_in IN r3_intf_schedad_headers.report_instance_id%TYPE) IS 
      SELECT 1 
      FROM   batch_status_data 
      WHERE  report_instance_id = cpnmrepid_in; 
    -- Cursor to retrieve batch, spec and sales details for the given report instance ID 
    CURSOR crgetbatches ( 
      cpnmrepid_in NUMBER) IS 
      SELECT DISTINCT process_order, 
                      batch_no, 
                      heat_no, 
                      sales_order, 
                      spec_code_name, 
                      alloy_code, 
                      key_size 
      FROM   batch_status_view 
      WHERE  report_instance_id = cpnmrepid_in; 
    -- Cursor to retrieve the testing status for each of the bacthes in the given report instance ID 
    CURSOR crgetteststatus ( 
      cpnmrepid_in   NUMBER, 
      cpvcbatchno_in batch_status_data.batch_no%TYPE) IS 
      SELECT test_type, 
             legend, 
             external_lab_yn 
      FROM   batch_status_data 
      WHERE  report_instance_id = cpnmrepid_in 
             AND batch_no = cpvcbatchno_in; 
    nmrepid           NUMBER; 
    nmdummy           NUMBER(1); 
    vccsvtext         VARCHAR2(1000); 
    vcbatchno         VARCHAR2(10); 
    vctesttype        VARCHAR2(10); 
    -- Holds the test type currently being processed 
    vcheatno          VARCHAR2(7); -- Holds the heat currently being process 
    vclegend          VARCHAR2(2); 
    -- Holds the legend applicable for this result 
    blreportsample    BOOLEAN; 
    nmerrorcode       NUMBER := NULL; -- Holds error code 
    vcerrormsg        VARCHAR2(200) := NULL; -- Holds error message 
    vcsampleexistsyn  VARCHAR2(1); 
    vcextlabyn        VARCHAR2(1); 
    cncomma CONSTANT VARCHAR2(1) DEFAULT ','; 
    vcmissingsamples  VARCHAR2(200); 
    vcmissingresults  VARCHAR2(200); 
    vcinvalidresults  VARCHAR2(200); 
    vcunsignedsamples VARCHAR2(200); 
    vcmimetype        VARCHAR2(50) := 'application/ms-excel'; 
    blbsource         BLOB; 
    blbtotblob        BLOB; 
    blbsourcetot      BLOB; 
    nmexportid        NUMBER := pk_master_data.fn_gen_id_seq_nextval; 
    nmrowcount        NUMBER := 0; 
    vcheader          VARCHAR2(1000) := 
'Process Order, Batch Number, Sales Order, Missing Samples, Samples with Missing Results, Samples with OOS Results, Unsigned Samples with results, Spec Name, Alloy, Key Size' 
||Chr(10); 
PRAGMA autonomous_transaction; 
-- Local function to concatonate each coverted text record to a blob holding all 
FUNCTION Fnconcatblob(blrowblob IN BLOB, 
                      bltotblob IN BLOB) 
RETURN BLOB 
IS 
  bloutblob BLOB; 
BEGIN 
    dbms_lob.Createtemporary(bloutblob, TRUE); 

    dbms_lob.Append(bloutblob, bltotblob); 

    dbms_lob.Append(bloutblob, blrowblob); 

    RETURN bloutblob; 
END fnconcatblob; 
BEGIN 
  -- Check whether the data tables have been populated. If not then populate 
  OPEN crchkdataexists(cpnmrepid_in => pnmreportinstanceid_in); 

  FETCH crchkdataexists INTO nmdummy; 

  IF crchkdataexists%NOTFOUND THEN 
    CLOSE crchkdataexists; 

    Batch_status(p_rep_id => pnmreportinstanceid_in, p_run_date => '', 
    p_run_time => '', p_run_by => ''); 
  ELSE 
    CLOSE crchkdataexists; 
  END IF; 

  blbsourcetot := Empty_blob(); 

  -- Loop through the batches 
  FOR crgetbatches_row IN crgetbatches (cpnmrepid_in => pnmreportinstanceid_in 
  ) 
  LOOP 
      -- Initialise the testing status fields  
      vcmissingsamples := NULL; 

      vcmissingresults := NULL; 

      vcinvalidresults := NULL; 

      vcunsignedsamples := NULL; 

      blbsource := Empty_blob(); 

      -- For first record add the header titles 
      IF vcheader IS NOT NULL THEN 
        -- Cast the Varchar2 text line to a blob 
        blbsource := utl_raw.Cast_to_raw(vcheader); 

        -- Concat each converted text line blob into a single blob holding all the objects source  
        blbsourcetot := Fnconcatblob(blbsource, blbsourcetot); 

        blbsource := Empty_blob(); 

        vcheader := NULL; 
      END IF; 

      -- Get the testing status for each batch 
      FOR crgetteststatus_row IN crgetteststatus(cpnmrepid_in => 
      pnmreportinstanceid_in, cpvcbatchno_in => crgetbatches_row.batch_no) 
      LOOP 
          -- Build the test status fields dependant on the legend for the test 
          CASE crgetteststatus_row.legend 
            WHEN '!' THEN 
              -- Sample missing 
              vcmissingsamples := vcmissingsamples 
                                  ||' ' 
                                  ||crgetteststatus_row.test_type; 
            WHEN '*' THEN 
              -- Missing result(s) 
              vcmissingresults := vcmissingresults 
                                  ||' ' 
                                  ||crgetteststatus_row.test_type; 
            WHEN 'x' THEN 
              -- Invalid results 
              vcinvalidresults := vcinvalidresults 
                                  ||' ' 
                                  ||crgetteststatus_row.test_type; 
            WHEN '^' THEN 
              -- Invalid results 
              vcinvalidresults := vcinvalidresults 
                                  ||' ' 
                                  ||crgetteststatus_row.test_type; 
            ELSE 
              -- Unsigned sample 
              vcunsignedsamples := vcunsignedsamples 
                                   ||' ' 
                                   ||crgetteststatus_row.test_type; 
          END CASE; 
      END LOOP; 

      -- Build the remaining CSV export record (cONCATONATE THE TEST STAIST FIELDS FOR EACH STATUS TO THE CSV RECORD) 
      vccsvtext := crgetbatches_row.process_order 
                   ||cncomma 
                   || crgetbatches_row.batch_no 
                   ||cncomma 
                   || crgetbatches_row.sales_order 
                   ||cncomma 
                   || vcmissingsamples 
                   ||cncomma 
                   || vcmissingresults 
                   ||cncomma 
                   || vcinvalidresults 
                   ||cncomma 
                   || vcunsignedsamples 
                   ||cncomma 
                   || crgetbatches_row.spec_code_name 
                   ||cncomma 
                   || crgetbatches_row.alloy_code 
                   ||cncomma 
                   || crgetbatches_row.key_size 
                   ||cncomma 
                   ||Chr(10); 

      -- Cast the Varchar2 text line to a blob 
      blbsource := utl_raw.Cast_to_raw(vccsvtext); 

      -- Concat each converted text line blob into a single blob holding all the objects source  
      blbsourcetot := Fnconcatblob(blbsource, blbsourcetot); 

      -- empty the text line blob ready for the next text line 
      blbsource := Empty_blob(); 

      nmrowcount := nmrowcount + 1; 
  END LOOP; 

  -- Insert into CSV export table 
  INSERT INTO export_csv_data 
              (export_id, 
               report_instance_id, 
               csv_data, 
               generated_by) 
  VALUES      (nmexportid, 
               pnmreportinstanceid_in, 
               blbsourcetot --empty_blob() 
               , 
               USER); 

  -- Commit the data to the export table     
  COMMIT; 

  IF nmrowcount != 0 THEN 
    RETURN nmexportid; 
  ELSE 
    RETURN 0; 
  END IF; 
EXCEPTION 
WHEN OTHERS THEN 
           RETURN 0; 
END fnbatchstatuscsv; 
  -- Procedure to delete CSV data from export CSV table for the given report_instance_id 
  PROCEDURE Prdelexportcsvdata(pnmreportinstanceid_in IN 
  r3_intf_schedad_headers.report_instance_id%TYPE, 
                               pvcgeneratedby_in      IN 
  st_users.user_login%TYPE) 
  IS 
    PRAGMA autonomous_transaction; 
  BEGIN 
      -- 
      -- Delete the data for the given report instance ID  
      DELETE FROM export_csv_data 
      WHERE  report_instance_id = pnmreportinstanceid_in 
             AND generated_by = pvcgeneratedby_in; 

      COMMIT; 
  EXCEPTION 
    WHEN OTHERS THEN 
               -- Record error and re-raise 
               pk_error_log.Prrecorddetailshalt(p_sqlcode_in => SQLCODE, 
               p_sqlerrm_in => Substr(SQLERRM, 1, 200), 
               p_modulename_in => 'pk_sap_interfaces.prDelExportCSVData', 
               p_keydata_in => 'Attempting to delete export_csv_date for ID [' 
                               ||To_char(pnmreportinstanceid_in) 
                               ||'] User [' 
                               ||pvcgeneratedby_in 
                               ||']'); 
  END prdelexportcsvdata; 
END pk_sap_interfaces;
/