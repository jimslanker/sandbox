CREATE OR REPLACE PACKAGE BODY STAR.PK_STAR_WEBSERVICES AS 
--
-- Version control data:
--
-- $Revision:   1.3  $
-- $Date:   18 Oct 2021 19:07:22  $
--
-------------------------------------------------------------------------------
-- Updated Oct 4th 2021 by Jim Slanker for STCR 7634
--         Add 1 minute delay to prRunSTARInterface for move to
--         SAP Stand by Database. to give time for replication
--         from SAP PRD Database.
-------------------------------------------------------------------------------
PROCEDURE prFetchConcRef(pBatchNum_in IN ns_submittal_details.batch_no%TYPE
                         ,pDeliveryNum_in IN cp_cert_headers.delivery_number%TYPE
                         ,pConcRef_out OUT VARCHAR2
                         ,pSAPpieceIds_out OUT VARCHAR2
                         ,pMeltMethod_out OUT VARCHAR2) IS
                         
CURSOR crGetConcessions(cpBatchNum_in IN ns_submittal_details.batch_no%TYPE
                        ,cpDeliveryNum_in IN cp_cert_headers.delivery_number%TYPE) IS
SELECT nssuhr.customer_reference 
  FROM ns_submittal_headers nssuhr
       ,cp_cert_submittals cpcesu
       ,cp_cert_headers cpcehr
 WHERE cpcehr.batch_number = cpBatchNum_in
   AND cpcehr.delivery_number = cpDeliveryNum_in
   AND cpcehr.cert_id = cpcesu.cert_id
   AND cpcehr.latest_yn = 'Y'
   AND NVL(cpcesu.report_yn,'N') = 'Y'
   AND nssuhr.submittal_header_id = cpcesu.submittal_header_id
   AND nssuhr.rec_status = 'A'; 

CURSOR crGetSAPpieceIds(cpBatchNum_in IN ns_submittal_details.batch_no%TYPE
                        ,cpDeliveryNum_in IN cp_cert_headers.delivery_number%TYPE) IS
SELECT value 
  FROM cp_cert_delivery_item_chars cpdeit
       ,cp_cert_sap_delivery_items cpsadi
       ,cp_cert_headers cpcehr
WHERE cpcehr.batch_number = cpBatchNum_in
  AND cpcehr.delivery_number = cpDeliveryNum_in
  AND cpcehr.cert_id = cpsadi.cert_id
  AND cpcehr.latest_yn = 'Y'
  AND cpsadi.cert_delivery_item_id = cpdeit.cert_delivery_item_id
  AND cpdeit.characteristic = 'MM4_METAL_ID'
  AND NVL(cpdeit.include_yn,'N') = 'Y'
  AND cpcehr.rec_status = 'A'
  AND cpsadi.rec_status = 'A'
  AND cpdeit.rec_status = 'A';

CURSOR crGetMeltMethod(cpBatchNum_in IN ns_submittal_details.batch_no%TYPE
                        ,cpDeliveryNum_in IN cp_cert_headers.delivery_number%TYPE) IS
SELECT cpceoi.melt_method 
  FROM cp_cert_other_info cpceoi
       ,cp_cert_headers cpcehr
 WHERE cpcehr.batch_number = cpBatchNum_in
   AND cpcehr.delivery_number = cpDeliveryNum_in
   AND cpcehr.cert_id = cpceoi.cert_id
   AND cpcehr.latest_yn = 'Y'
   AND cpceoi.rec_status = 'A'
   AND cpcehr.rec_status = 'A';
      
   lvCustomerReference VARCHAR2(200);
   lvSAPPieceIds VARCHAR2(200);
   lvMeltMethod VARCHAR2(100);
   
BEGIN
lvCustomerReference := '';
FOR rcGetConcessions IN crGetConcessions(cpBatchNum_in => pBatchNum_in
                                         ,cpDeliveryNum_in => pDeliveryNum_in) LOOP
IF lvCustomerReference IS NULL THEN
   lvCustomerReference := rcGetConcessions.customer_reference;
ELSE
   lvCustomerReference := lvCustomerReference||','||rcGetConcessions.customer_reference;
END IF;
END LOOP;
   pConcRef_out := lvCustomerReference;

FOR rcGetSAPpieceIds IN crGetSAPpieceIds(cpBatchNum_in => pBatchNum_in
                                         ,cpDeliveryNum_in => pDeliveryNum_in) LOOP
IF lvSAPPieceIds IS NULL THEN
   lvSAPPieceIds := rcGetSAPpieceIds.value;
ELSE
   lvSAPPieceIds := lvSAPPieceIds||','||rcGetSAPpieceIds.value;
END IF;
END LOOP;

pSAPpieceIds_out := lvSAPPieceIds;

OPEN crGetMeltMethod(cpBatchNum_in => pBatchNum_in
                      ,cpDeliveryNum_in => pDeliveryNum_in);
FETCH crGetMeltMethod INTO lvMeltMethod;
CLOSE crGetMeltMethod;
                     
pMeltMethod_out :=  lvMeltMethod;                     
                      
                      
END prFetchConcRef; 
PROCEDURE prRunSTARInterface(pStartDate IN VARCHAR2 DEFAULT NULL 
                             ,pEndDate   IN VARCHAR2 DEFAULT NULL) IS

BEGIN

-------------------------------------------------------------------------------
-- Delay 1 minute to allow time for SAP Standby to be replicated from SAP PRD--
-- STCR 7634                                                                 --
-------------------------------------------------------------------------------
DEBUG_REC('>>Temp >> About to call DBMS_SESSION.SLEEP for 60 Seconds <<');
DBMS_SESSION.SLEEP(60);                                          --STCR 7634
DEBUG_REC('>>Temp >> After to call DBMS_SESSION.SLEEP for 60 Seconds <<');



-------------------------------------------------------------------------------
--Run the interface program in STAR  This is called via Web Service from SAP --
-------------------------------------------------------------------------------

pk_sap_interfaces.pr_get_import_data(p_start_date => pStartDate 
                                     ,p_end_date => pEndDate);

END;
END;
/

