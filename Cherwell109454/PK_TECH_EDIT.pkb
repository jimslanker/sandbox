CREATE OR REPLACE PACKAGE BODY STAR.pk_tech_edit
--
-- Version control data:
--
-- $Revision:   5.35  $
-- $Date:   13 May 2022 13:18:04  $
--
/*---------------------------------------------------------------------------------------------------------------------------
||   NAME:       pk_tech_edit                                                                                                
||   PURPOSE:  Repository for datatypes and declarations, procedures and functions utilised within the technical edit module 
||---------------------------------------------------------------------------------------------------------------------------
||  REVISIONS:
||  Ver    Date          Author        Description
|| ------- ----------    ------------- ------------------------------------
||  1.0    26-JAN-2007   S Phillips    1. Created this package.
||  1.1    15-JUL-2007   Todd Farino   2. Added new procedure to copy a to an order spec.
||  1.2    15-AUG-2007   Todd Farino   3. Added new procedure to distribute basis spec limits.
||  1.3    15-JUN-2009   Ray R Nault   1. Add new functions/procedures moving Batch Allocation logic to this database package as part of STCR 4592.
||  1.4    17-JUN-2009   Phil S        Test Piece Tracking update to procedures fncopy_to_order_spec and copy_spec_text
||  1.5    01-MAR-2010   A Narayan     Added pr_copy_approval_header to copy approval header information for issue 5259  JDD2010_C13_2_Fast_Track 
||                                     Removed the insert to te_spec_code_approval table in the function fncopy_to_order_spec as this will be handled by the new procedure
||  1.6    05-MAR-2010   Noel Gelineau 1. STCR 4776 - Updated fncopy_to_order_spec to include new te_spec_code_header.tol_flat_comment column
||                                     2. STCR 4797 - Updated fncopy_to_order_spec and p_distribute_spec_limits to include new te_spec_code_limits.aim_value column
||                                     3. STCR 4839 - Updated fncopy_to_order_spec to include copying of new HT Codes data
||                                     3. STCR 4949 - Updated multiple routines by removing insert statement sequences and audit columns that moved to the table trigger level
||  5.8    21-MAY-2010   S Phillips    Added function fnGetShapeType to returnt he shape type for a given spec ID
||                                     Added procedure prUpdateIngotDiam to update ingot_diamtere_inches for the given spec ID
||                                     Added procedure prGetShapeAndSite to return the shape type and owning site of a given spec ID                                                        
||                       Noel Gelineau Added function fnIsLimitOnSpec to determine if a limit exists given a spec_id, test_type and test_code
||  5.9    25-AUG-2010   Noel Gelineau STCR 5270 - updated pr_copy_approval_header procedure
||                                     STCR 5411 - updated copy_spec_text procedure
||  5.10   26-AUG-2010   Noel Gelineau Added procedure fprGetTestCodeTypeGroup to fetch a type group record
||  5.10   15-SEP-2010   G Ford        5213 - created fnIsOrderLinked
||  5.12   13-DEC-2010   A Narayan     5567 2010 C16 Scheduled Issues
||  5.14   01-MAR-2011   G Ford        Cycle 17 Scheduled Issues - 5685 - Removed the exception WHEN NO_DATA_FOUND from the fnGetSpecOwner function
||  5.15   20-APR-2011   G Ford        2011 Fast Track - STCR 5677. Modifications to pr_batch_allocation_check for returning lib_mess numbers when checking key_size.
||  5.17   23-SEP-2011   G Ford        Cycle 19 Scheduled Issues - STCR 5873 - added fnUpdateStatements 
||  5.20   08-May-2012   A Narayan     Fasttrack Issue 6258
||  5.21   29-JUL-2012   J DAvis       Fasttrack Issue 6295
||  5.22   22-AUG-2012   A narayan     Modified fnGetCustomerAddress and fnRefreshShipToAddress for STCR 6286 and added fnRegionDescLookup
||  5.23   22-AUG-2013   S Phillips    Added function fnIngotChemFailure and procedure prRaiseIngotChemFailEmail - STCR 6363
||         30-May-2014   S Phillips    Added function fnAlloyIsEquiv - STCR 6370, T/E Mini Project.
||
||               --- Jump version listed here to get back into sync with that which will be issued from PVCS ---
||
||  5.28   Dec 2014      S Phillips    STCR 6788, Cycle 32. Add procedure to update IPO Entry table with ingot diameter and/or mold size
                                       from the associated spec record. 
                                       Update spec copy routine to replace eb_mold_size on TE_IPO_ENTRIES with mold_size_id and add new column
                                       to te_spec_code_header
||  5.35  April 2022    Jim Slanker    Update function fnIngotChemFailure to not include test results not released  STCR 7578
||
*/---------------------------------------------------------------------------------------------------------------------------
AS
/*--------------------------------------------------------------------------------
||
|| Function to determine if there are any samples created against this order spec
||
*/--------------------------------------------------------------------------------
  FUNCTION fnSamplesBooked(p_nSpecCodeId_in    IN te_spec_code_header.spec_code_id%TYPE)
  RETURN BOOLEAN IS
/*
||
|| DECLARATIVE SECTION
||
*/
--
-- Local variables
--
vcDummyVar      VARCHAR2(1);        -- Dummy variable for use in SELECT

vcKeyData         st_error_log.key_data%TYPE;

-- Constant to hold procedure/function name for error logging
cModuleName     CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.fnSamplesBooked';

/*
||
|| EXECUTION SECTION
||
*/
BEGIN
--
-- Read for any samples booked against the given spec_code_id
--  
  vcKeyData := 'Spec ID ['||TO_CHAR(p_nSpecCodeId_in)||']';

  SELECT 'Y'
  INTO  vcDummyVar
  FROM te_test_sample_id
  WHERE spec_code_id = p_nSpecCodeId_in;
  
  -- A sample found - return TRUE
  RETURN (TRUE);
  
/*
||
|| EXCEPTION SECTION
||
*/
EXCEPTION
--
-- No samples found
--
  WHEN NO_DATA_FOUND
  THEN
    RETURN (FALSE);
    
--
--  More than one sample found 
--
  WHEN  TOO_MANY_ROWS
  THEN
    RETURN (TRUE);

--
-- Unforeseen exception
--
  WHEN OTHERS
  THEN
    -- Record the exception details and RE-raise
    pk_error_log.prRecordDetailsHalt (p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in     =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleName_in    => cModuleName,        
                                p_KeyData_in        => vcKeyData);
                             
--                             
-- Exit fnSamplesBooked
--
END fnSamplesBooked;


/*-----------------------------------------------------------------------------
||
|| Count ACTIVE attached documents to the given edit
||
*/-----------------------------------------------------------------------------
FUNCTION fnCountAttachedActiveDocs (p_nAppHandleId_in     IN  te_spec_code_header.image_app_handle_id%TYPE)
RETURN PLS_INTEGER IS
/*
||
|| DECLARATIVE SECTION
||
*/
--
-- Local variables
--
nDocCount       PLS_INTEGER;

vcModuleName     st_error_log.module_name%TYPE;
vcKeyData         st_error_log.key_data%TYPE;

-- Constant to hold procedure name for error logging
cModuleName       CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.fnCountAttachedActiveDocs';

/*
||
|| EXECUTION SECTION
||
*/
BEGIN
--
-- Read for the 
--
    nDocCount := 0;
    vcKeyData := 'App Handle ID ['||TO_CHAR(p_nAppHandleId_in)||']';
    
    SELECT  COUNT(*)
    INTO    nDocCount
    FROM    st_doc_app_links
    WHERE   application_handle_id = p_nAppHandleId_in
    AND status = pk_star_constants.vcActiveRecord;
    
    RETURN(nDocCount);
    
/*
||
|| EXCEPTION SECTION
||
*/
EXCEPTION
--
-- No data found - return 0 (nDocCount sert to 0 before lookup)
--
    WHEN NO_DATA_FOUND
    THEN
      -- No attached documents
      nDocCount := 0;
      RETURN(nDocCount);
      
--
-- Unknown error has occurred
--
    WHEN OTHERS
    THEN
      -- Capture exception details and re-raise exception
      pk_error_log.prRecordDetailsHalt(p_SqlCode_in     => SQLCODE
                                 ,p_SqlErrm_in      => SUBSTR(SQLERRM, 1, 200)
                                 ,p_ModuleName_in   => cModuleName
                                 ,p_KeyData_in      => vcKeyData);
    nDocCount := NULL;
    RETURN(nDocCount);
    
--
-- Exit fnCountAttachedActiveDocs
--
END fnCountAttachedActiveDocs;
 
/*-----------------------------------------------------------------------------
||
|| Function to check for uniquness of basis spec name and site (1)
||
*/-----------------------------------------------------------------------------
FUNCTION fnSpecExists (p_vcSpecName_in      IN  te_spec_code_header.spec_code_name%TYPE
                        ,p_vcIssueRef_in     IN te_spec_code_header.issue_ref%TYPE
                       ,p_vcSite_in           IN  st_sites.site%TYPE)
RETURN BOOLEAN IS   
--
-- Local variables
--
lv_count NUMBER;

vcKeyData         st_error_log.key_data%TYPE;

-- Constant to hold procedure name for error logging
cModuleName       CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.fnSpecExists';

/*
||
|| EXECUTION SECTION
||
*/
BEGIN
--
-- Lookup against spec name and site (1)
--
-- #TAF 8/23/2007 Added to the WHERE portion the issue_ref, so it will check if the rev is the same.
    SELECT COUNT(*)
    INTO   lv_count
    FROM   te_spec_code_header
    WHERE  spec_code_name = p_vcSpecName_in
    AND    site = p_vcSite_in
    AND    NVL(issue_ref, 'zNULLz') = NVL(p_vcIssueRef_in, 'zNULLz') 
    AND    spec_code_type = 'B';
    
  IF lv_count > 0 THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;      
/*
||
|| EXCEPTION SECTION
||
*/
EXCEPTION
--
-- Unexpected exception
--
  WHEN OTHERS
  THEN
    -- Capture exception details and re-raise exception
    pk_error_log.prRecordDetailsHalt(p_SqlCode_in     => SQLCODE
                               ,p_SqlErrm_in      => SUBSTR(SQLERRM, 1, 200)
                               ,p_ModuleName_in   => cModuleName
                               ,p_KeyData_in      => vcKeyData);
  
  
--
-- Exit fnSpecExists
--
END fnSpecExists;    

/*-----------------------------------------------------------------------------
||
|| Procedure to remove rows from doc/image attach lInk tables.
|| 
|| We have had circumstances when users have attempted to attach
|| a document to a T/E, but for whatever reason this has failed. However,
|| because the app handle is generated and the link record created
|| BEFORE calling the attachment form, if failure occurs, the data gives the
|| impression that the attachment has been successful. This routine
|| will remove the link records for the given app handle ID when it is 
|| determined these circumstances have occurred.
||
*/-----------------------------------------------------------------------------  
PROCEDURE prRemoveLinkRecord(p_nAppHandleId_in   IN te_spec_code_header.image_app_handle_id%TYPE)
IS
--
-- Local variables
--
vcKeyData         st_error_log.key_data%TYPE;

-- Constant to hold procedure name for error logging
cModuleName       CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.prRemoveLinkRecord';

/*
||
|| EXECUTION SECTION
||
*/
BEGIN
--
-- Delete record witrh the given ap handle
--
  vcKeyData := TO_CHAR(p_nAppHandleId_in);
 
  
  DELETE FROM st_image_app_handles
  WHERE application_handle_id = p_nAppHandleId_in;
  
  COMMIT;

/*
||
|| EXCEPTION SECTION
||
*/
EXCEPTION
--
-- Capture any unforeseen errors
--
  WHEN OTHERS
  THEN
    -- Record error details and RAISE exception
    pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleNAme_in =>  cModuleName,
                                p_KeyData_in    =>  vcKeyData);
--
-- Exit prRemoveLinkRecord
--
END prRemoveLinkRecord;


--
-- Function to determine if user has authority to change order edit
--
FUNCTION fnEditOrderSpec(p_vcUserLogin_in   IN  st_users.user_login%TYPE
                     ,p_vcSite_in       IN  st_sites.site%TYPE)
RETURN BOOLEAN IS
--
-- Local variables
--
vcAccessDeniedData          pk_star_security.access_denied_rec;
bActionAllowed                BOOLEAN;

vcKeyData         st_error_log.key_data%TYPE;

-- Constant to hold procedure name for error logging
cModuleName       CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.fnEditOrderSpec';

/*
||
|| EXECUTION SECTION
||
*/
BEGIN
--
-- See if user has order edit update privileges
--
  pk_star_security.check_authority('SPEC_CODES'
                              ,p_vcUserLogin_in
                              ,NULL
                                 ,'PRE-UPDATE'
                              ,NULL
                                ,p_vcSite_in
                                 ,1
                              ,vcAccessDeniedData
                                ,bActionAllowed
                                );
    RETURN(bActionAllowed);
    
/*
||
|| EXCEPTION SECTION
||
*/
EXCEPTION    
--
-- Capture any unforeseen errors
--
  WHEN OTHERS
  THEN
    -- Record error details and RAISE exception
    pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleNAme_in =>  cModuleName,
                                p_KeyData_in    =>  vcKeyData);
  RETURN(FALSE);                            
--
-- Exit fnEditOrderSpec
--
END fnEditOrderSpec;

/*-----------------------------------------------------------------------------
||
|| Function to return the owning site identifier for the given spec ID
||
*/-----------------------------------------------------------------------------  
FUNCTION fnGetSpecOwner(p_nSpecCodeId_in    IN  te_spec_code_header.spec_code_id%TYPE) RETURN VARCHAR2
IS
--
-- Local variables
--
vcSiteId          st_sites.site%TYPE;
vcKeyData         st_error_log.key_data%TYPE;

-- Constant to hold procedure name for error logging
cModuleName       CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.fnGetSpecOwner';

  CURSOR crGetSite( cpnmSpecCodeId_in IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE ) IS
  SELECT site
  FROM   te_spec_code_header
  WHERE  spec_code_id = cpnmSpecCodeId_in;

/*
||
|| EXECUTION SECTION
||
*/
BEGIN
--
--  Lookup the owning site
--
    vcKeyData := TO_CHAR(p_nSpecCodeId_in);
    
    OPEN crGetSite( cpnmSpecCodeId_in => p_nSpecCodeId_in );
    FETCH crGetSite INTO vcSiteId;
    CLOSE crGetSite;
    
    RETURN(vcSiteId);
    
/*
||
|| EXCEPTION SECTION
||
*/
EXCEPTION
--
-- Unknown error
--
    WHEN OTHERS
    THEN
      -- Record details and re-raise exception
      pk_error_log.prRecordDetailsHalt(p_SqlCode_in      => SQLCODE
                                ,p_SqlErrm_in      => SUBSTR(SQLERRM, 1, 190)
                                ,p_ModuleName_in   => cModuleName
                                ,p_KeyData_in      => vcKeyData);      
              
--
-- Exit fnGetSpecOwner
--
END fnGetSpecOwner;

/*-------------------------------------------------------------------------------------------------------------
||
||  Procedure to automatically create an order spec when data is transferred from STAR.
||
|| NOTE: This procedure is called from the pr_import_data procedure.
|| Author: Todd Farino
*/-------------------------------------------------------------------------------------------------------------  

FUNCTION fncopy_to_order_spec (p_copy_from_spec_id_in IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                              ,p_copy_to_type_in IN TE_SPEC_CODE_HEADER.spec_code_type%TYPE
                            ,p_new_spec_name_in IN TE_SPEC_CODE_HEADER.spec_code_name%TYPE
                            ,p_spec_low_size_in IN TE_SPEC_CODE_HEADER.PR_FILTER_LOW%TYPE
                            ,p_spec_high_size_in IN TE_SPEC_CODE_HEADER.PR_FILTER_HIGH%TYPE
                            ,p_user_site_in IN TE_SPEC_CODE_HEADER.site%TYPE
                            ,p_sales_order_no_in IN R3_SALES_ORDERS.r3_sales_order%TYPE
                            ,p_sales_order_item_in IN R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                            ,p_new_spec_issue_ref IN  TE_SPEC_CODE_HEADER.issue_ref%TYPE DEFAULT NULL
                            ) RETURN NUMBER
   IS
   lv_temp                      VARCHAR2(1);
   cModuleName                  VARCHAR2(100) := 'pk_tech_edit.fncopy_to_order_spec';
   vcKeyData                  VARCHAR2(100);
   vcSiteId                      VARCHAR2(2);
   lv_issue_ref                 TE_SPEC_CODE_HEADER.issue_ref%TYPE;
   lv_amendment_ref                TE_SPEC_CODE_HEADER.amendment_ref%TYPE;
   lv_copy_to_spec_id_out          TE_SPEC_CODE_HEADER.spec_code_id%TYPE;
   lv_spec_type                   TE_SPEC_CODE_HEADER.spec_code_type%TYPE;
   lv_basis_spec_from          TE_SPEC_CODE_HEADER.basis_spec_from%TYPE;
   lv_newImageAppHandleId      PLS_INTEGER;
   lv_doc_id                  ST_DOC_APP_LINKS.doc_id%TYPE;
   lv_other_info              VARCHAR2(1000);
   v_variance_check              NUMBER;                        /*Variance ID to check for copy variance */
   lv_doc_check                  GTT_COPY_SPECS.DOC_ATTACH_YN%TYPE;    
   lv_approvals_check          GTT_COPY_SPECS.APPROVALS_YN%TYPE;
   lv_multi_spec_check          GTT_COPY_SPECS.MULTI_SPEC_YN%TYPE;
   lv_alloy_code                 st_alloys.alloy_code%TYPE;                                -- Read from order line. If null will update to that from spec
   lv_qual_code                  te_spec_code_header.grade_code%TYPE; -- Read from order line. If null will update to that from spec
   lv_key_size                     NUMBER ;              --- Key_Size of order being copied to 
   lv_site                       te_spec_code_header.site%TYPE;
   lv_limit_key_size          NUMBER ;
   lv_site_size_uom           st_sites.default_size_uom%TYPE;
   lv_status                  VARCHAR2(10);
   lv_error                   NUMBER;
   lv_trav_yn                 GTT_COPY_SPECS.traveler_text_yn%TYPE;

  CURSOR get_copy_from_spec_data (p_copy_from_spec_id_in IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE) IS
  SELECT spec_code_name,
  spec_code_desc,
  spec_code_type,
  EDITION,
  issue_ref,
  amendment_ref,
  date_valid_from,
  date_expired,
  alloy_code,
  shape_type,
  qc_code,part_type,
  size_od_width,
  size_thickness,
  unit_of_size,
  LENGTH,
  fixed_length,
  unit_of_length,
  tol_od_width_top,
  tol_od_width_bot,
  tol_od_width_comment,
  tol_thickness_top,
  tol_thickness_bot,
  tol_thickness_comment,
  tol_length_top,
  tol_length_bot,
  tol_length_comment,
  tol_ovality_top,
  tol_ovality_bot,
  tol_ovality_comment,
  tol_straight_top,
  tol_straight_bot,
  tol_straight_comment,
  tol_flat_comment,
  unit_of_weight,
  size_weight,
  tol_weight_top,
  tol_weight_bot,
  tol_weight_comment,
  tol_weight_uom,
  product_type,
  insp_code,
  tech_status,
  copy_indicator,
  ord_to_ord_ok,
  develop_code,
  basis_spec_from,
  ownership,
  grade_code,
  forge_route_grade_code,
  tech_edit_alloy,
  ingot_nom_wt_tonnes,
  ingot_diam_inches,
  ingot_num_of_melts,
  idf_ref,
  origin,enduser,
  rec_status,
  pr_filter_low,
  pr_filter_high,
  ownership_name,
  formulation_no,
  metal_type,
  site,
  image_app_handle_id,
  contract, 
  contract_item, 
  fanblade_type_id,
  piece_id_check_required,          -- 6697
  mold_size_id                           -- 6788
  FROM te_spec_code_header
  WHERE spec_code_id = p_copy_from_spec_id_in;

  CURSOR get_site_size_uom (p_site IN te_spec_code_header.site%TYPE) IS   
  SELECT default_size_uom
  FROM   st_sites
  WHERE  site = p_site;

  CURSOR get_key_size (p_sales_order_no_in IN r3_sales_orders.r3_sales_order%TYPE
                      ,p_sales_order_item_in IN r3_sales_order_items.r3_sales_order_item%TYPE
                      ) IS
  SELECT ROUND(soi.key_size,5), soi.alloy_code, soi.quality_grade_code
  FROM   r3_sales_order_items soi
  WHERE  soi.r3_sales_order = p_sales_order_no_in
  AND    soi.r3_sales_order_item = p_sales_order_item_in ;

  CURSOR get_copy_checks (p_copy_from_spec_id_in IN te_spec_code_header.spec_code_id%TYPE) IS
  SELECT doc_attach_yn
        ,approvals_yn
        ,multi_spec_yn
  FROM   gtt_copy_specs 
  WHERE  spec_code_id = p_copy_from_spec_id_in;

  CURSOR chk_trav_refresh (p_copy_to_spec_id IN te_spec_code_header.spec_code_id%TYPE) IS
  SELECT traveler_text_yn
  FROM gtt_copy_specs 
  WHERE spec_code_id = p_copy_to_spec_id;
  
  copy_from_spec_rec get_copy_from_spec_data%ROWTYPE;

--
-- Cursor to retrieve any applicable material characterisitics
--
CURSOR  crGetMatlChars(cpnSpecId    IN  te_spec_matl_chars.spec_code_id %TYPE)
    IS
        SELECT matl_char_id, uom_ref
                    , min_limit, max_limit
        FROM       te_spec_matl_chars
        WHERE   spec_code_id = cpnSpecId
        AND         rec_status = pk_star_constants.vcActiveRecord;        

  lvCopySAPDimYN    st_program_parameters.parameter_value%type;
  lvDimDiameter     r3_sales_order_items.dim_diameter%type;
  lvDimThickness    r3_sales_order_items.dim_thickness%type;
  lvDimWidth        r3_sales_order_items.dim_width%type;
  lvDimUOM          r3_sales_order_items.key_size_uom%type;

  CURSOR cr_get_sales_order_dims (cp_r3_sales_order IN r3_sales_orders.r3_sales_order%TYPE, cp_r3_sales_order_item IN r3_sales_order_items.r3_sales_order_item%TYPE) IS
 		 SELECT dim_diameter, dim_thickness, dim_width, key_size_uom 
  	 FROM r3_sales_order_items 
  	 WHERE r3_sales_order      = cp_r3_sales_order
  	 AND r3_sales_order_item = cp_r3_sales_order_item;
     
--
-- Execution Section
-- 
BEGIN
                                                         
  OPEN get_copy_checks (p_copy_from_spec_id_in => p_copy_from_spec_id_in);
  FETCH get_copy_checks INTO lv_doc_check,lv_approvals_check,lv_multi_spec_check;
  CLOSE get_copy_checks;

  --
  -- Get The Next Sequence Id                                     
  --
  -- No longer needed since moved to the table trigger
  --SELECT spec_code_seq.NEXTVAL
  --INTO   lv_copy_to_spec_id_out
  --FROM   dual;
  
  OPEN get_copy_from_spec_data (p_copy_from_spec_id_in => p_copy_from_spec_id_in);
  FETCH get_copy_from_spec_data INTO copy_from_spec_rec;
  CLOSE get_copy_from_spec_data;

  lv_site               := copy_from_spec_rec.site;
  lv_spec_type := copy_from_spec_rec.spec_code_type;

  -- --------------------------------------------------------------------------------------
  -- Copy SAP sales order dimensional data if parameter value is Y for givin site
  -- --------------------------------------------------------------------------------------
  lvCopySAPDimYN := PK_STAR_PROGRAMS.fn_Get_Parameter('SPEC_CODES'
                                                          ,'COPY_SAP_SALES_ORDER_DIMENSIONAL_DATA'
                                                          ,p_user_site_in);

  IF p_copy_to_type_in = 'O' and nvl(lvCopySAPDimYN,'N') = 'Y' THEN

    OPEN cr_get_sales_order_dims (cp_r3_sales_order => p_sales_order_no_in, cp_r3_sales_order_item => p_sales_order_item_in);
    FETCH cr_get_sales_order_dims INTO lvDimDiameter, lvDimThickness, lvDimWidth, lvDimUOM;
    CLOSE cr_get_sales_order_dims;
    
    copy_from_spec_rec.SIZE_OD_WIDTH := nvl(lvDimDiameter,lvDimWidth);
    copy_from_spec_rec.SIZE_THICKNESS := lvDimThickness;
    copy_from_spec_rec.UNIT_OF_SIZE := lvDimUOM;
    
  END IF;
  -- --------------------------------------------------------------------------------------

  --
  -- If copying to a new basis spec code then reset amendment refs to '1'               
  --
  IF p_copy_to_type_in = 'B' THEN
    lv_issue_ref := p_new_spec_issue_ref;
    lv_amendment_ref := '1' ;
  ELSE
    lv_issue_ref := copy_from_spec_rec.issue_ref;
    lv_amendment_ref := copy_from_spec_rec.amendment_ref;
  END IF;

  --
  -- Set variable v_basis_spec_from                    
  --
  IF copy_from_spec_rec.spec_code_type = 'B' THEN        
    lv_basis_spec_from := p_copy_from_spec_id_in;    -- Set variable to SPEC_CODE_ID being copied FROM
  ELSE
    lv_basis_spec_from :=  copy_from_spec_rec.basis_spec_from;    -- Set variable to same value as Spec being copied FROM   
  END IF;
    
--
-- Capture document attachment link if selected for copy
--
  lv_newImageAppHandleID := NULL;

  IF lv_doc_check = 'Y'
    AND copy_from_spec_rec.image_app_handle_id IS NOT NULL THEN
       --creates new Application handle for new Order Spec
    SELECT st_image_app_id_seq.NEXTVAL
    INTO   lv_newImageAppHandleId
    FROM   DUAL;            
  END IF;    

--
-- Insert record into spec code header                                
--

   INSERT INTO TE_SPEC_CODE_HEADER   
    (SPEC_CODE_NAME,
    SPEC_CODE_DESC,
    SPEC_CODE_TYPE,
    ISSUE_REF,
    AMENDMENT_REF ,
    DATE_VALID_FROM,
    DATE_EXPIRED,
    ALLOY_CODE,
    SHAPE_TYPE,
    QC_CODE,
    PART_TYPE,
    SIZE_OD_WIDTH,
    SIZE_THICKNESS,
    UNIT_OF_SIZE,
    LENGTH,
    FIXED_LENGTH,
    UNIT_OF_LENGTH,
    TOL_OD_WIDTH_TOP,
    TOL_OD_WIDTH_BOT,
    TOL_OD_WIDTH_COMMENT,
    TOL_THICKNESS_TOP,
    TOL_THICKNESS_BOT,
    TOL_THICKNESS_COMMENT,
    TOL_LENGTH_TOP,
    TOL_LENGTH_BOT,
    TOL_LENGTH_COMMENT,
    TOL_OVALITY_TOP,
    TOL_OVALITY_BOT,
    TOL_OVALITY_COMMENT,
    TOL_STRAIGHT_TOP,
    TOL_STRAIGHT_BOT,
    TOL_STRAIGHT_COMMENT,
    TOL_FLAT_COMMENT,
    unit_of_weight,
    size_weight,
    tol_weight_top,
    tol_weight_bot,
    tol_weight_comment,
    tol_weight_uom,
    PRODUCT_TYPE,
    INSP_CODE,
    TECH_STATUS,
    COPY_INDICATOR,
    ORD_TO_ORD_OK,
    DEVELOP_CODE,
    BASIS_SPEC_FROM,
    OWNERSHIP,
    GRADE_CODE,
    FORGE_ROUTE_GRADE_CODE,
    TECH_EDIT_ALLOY,                          
    INGOT_NOM_WT_TONNES,                      
    INGOT_DIAM_INCHES,                        
    INGOT_NUM_OF_MELTS,                       
    IDF_REF,
    ORIGIN,
    ENDUSER,
    PR_FILTER_LOW,
    PR_FILTER_HIGH,
    OWNERSHIP_NAME,
    FORMULATION_NO,
    METAL_TYPE,
    SITE,
    IMAGE_APP_HANDLE_ID,
    CONTRACT
    ,contract_item
    ,fanblade_type_id
    ,piece_id_check_required        -- 6697
    ,mold_size_id                        -- 6788
)
    VALUES
   (p_new_spec_name_in,
    copy_from_spec_rec.SPEC_CODE_DESC,
    p_copy_to_type_in,
    lv_issue_ref,
    copy_from_spec_rec.AMENDMENT_REF,
    copy_from_spec_rec.DATE_VALID_FROM,
    copy_from_spec_rec.DATE_EXPIRED,
    copy_from_spec_rec.ALLOY_CODE,
    copy_from_spec_rec.SHAPE_TYPE,
    copy_from_spec_rec.QC_CODE,
    copy_from_spec_rec.PART_TYPE,
    copy_from_spec_rec.SIZE_OD_WIDTH,
    copy_from_spec_rec.SIZE_THICKNESS,
    copy_from_spec_rec.UNIT_OF_SIZE,
    copy_from_spec_rec.LENGTH,
    copy_from_spec_rec.FIXED_LENGTH,
    copy_from_spec_rec.UNIT_OF_LENGTH,
    copy_from_spec_rec.TOL_OD_WIDTH_TOP,
    copy_from_spec_rec.TOL_OD_WIDTH_BOT,
    copy_from_spec_rec.TOL_OD_WIDTH_COMMENT,
    copy_from_spec_rec.TOL_THICKNESS_TOP,
    copy_from_spec_rec.TOL_THICKNESS_BOT,
    copy_from_spec_rec.TOL_THICKNESS_COMMENT,
    copy_from_spec_rec.TOL_LENGTH_TOP,
    copy_from_spec_rec.TOL_LENGTH_BOT,
    copy_from_spec_rec.TOL_LENGTH_COMMENT,
    copy_from_spec_rec.TOL_OVALITY_TOP,
    copy_from_spec_rec.TOL_OVALITY_BOT,
    copy_from_spec_rec.TOL_OVALITY_COMMENT,
    copy_from_spec_rec.TOL_STRAIGHT_TOP,
    copy_from_spec_rec.TOL_STRAIGHT_BOT,
    copy_from_spec_rec.TOL_STRAIGHT_COMMENT,
    copy_from_spec_rec.TOL_FLAT_COMMENT,
    copy_from_spec_rec.unit_of_weight,
    copy_from_spec_rec.size_weight,
    copy_from_spec_rec.tol_weight_top,
    copy_from_spec_rec.tol_weight_bot,
    copy_from_spec_rec.tol_weight_comment,
    copy_from_spec_rec.tol_weight_uom,
    copy_from_spec_rec.PRODUCT_TYPE,
    copy_from_spec_rec.INSP_CODE,
    copy_from_spec_rec.TECH_STATUS,
    'N',
    'N',
    copy_from_spec_rec.DEVELOP_CODE,
    lv_basis_spec_from,
    copy_from_spec_rec.OWNERSHIP,
    copy_from_spec_rec.GRADE_CODE,
    copy_from_spec_rec.FORGE_ROUTE_GRADE_CODE,
    copy_from_spec_rec.TECH_EDIT_ALLOY,                          
    copy_from_spec_rec.INGOT_NOM_WT_TONNES,                      
    copy_from_spec_rec.INGOT_DIAM_INCHES,                        
    copy_from_spec_rec.INGOT_NUM_OF_MELTS,                     
    copy_from_spec_rec.IDF_REF,
    copy_from_spec_rec.ORIGIN,
    copy_from_spec_rec.ENDUSER,
    P_SPEC_LOW_SIZE_IN,
    P_SPEC_HIGH_SIZE_IN,
    copy_from_spec_rec.OWNERSHIP_NAME,
    copy_from_spec_rec.FORMULATION_NO,
    copy_from_spec_rec.METAL_TYPE,
    copy_from_spec_rec.site,
    lv_newImageAppHandleId,
    copy_from_spec_rec.contract
    ,copy_from_spec_rec.contract_item
    ,copy_from_spec_rec.fanblade_type_id
    ,copy_from_spec_rec.piece_id_check_required            -- 6697
    ,copy_from_spec_rec.mold_size_id                            -- 6788
    ) RETURNING spec_code_id INTO lv_copy_to_spec_id_out;
    

-- STAR Doc Control Insertion 
---Only do this if there are attached documents and the checkbox is checked.
-- If the user does NOT want a copy or if there is nothing to copy then variable lv_newImageAppHandleId will be null
-- Hence we can use this as a check

   IF lv_newImageAppHandleId IS NOT NULL THEN  
         -- INSERT INTO Attach Docs main table.
         lv_other_info := copy_from_spec_rec.spec_code_name||','||copy_from_spec_rec.ownership||','||
                    TO_CHAR(copy_from_spec_rec.date_valid_from,'dd/mm/yyyy');
                    
      INSERT INTO ST_IMAGE_APP_HANDLES
             (application_handle_id, application_area, application_table_name, application_primary_key , application_rec_other_data)
             VALUES (lv_newImageAppHandleId, 'Spec-Codes', 'te_spec_code_header', lv_copy_to_spec_id_out
             , lv_other_info);
             
                -- Adds any linked documents to the new Order Spec
                   INSERT INTO ST_DOC_APP_LINKS
                  (application_handle_id, doc_id, date_linked, time_linked, linked_by, link_comments 
                   , status,EDITION,created_by,time_created,date_created)
                  SELECT lv_newImageAppHandleId,doc_id,date_linked,time_linked
                   ,linked_by,link_comments,status
                   , 1, USER, TO_CHAR(SYSDATE,'HH24:MI:SS'), TRUNC(SYSDATE)
                  FROM ST_DOC_APP_LINKS
                  WHERE application_handle_id = copy_from_spec_rec.image_app_handle_id;
   END IF;  -- End of Insertion of Attached Documents
   
-- For non UK specifications get any variance data from the copied spec.

    IF copy_from_spec_rec.OWNERSHIP NOT IN ('S','W') THEN
        -- Obtain all variance information for copied spec_code ID for Non UK specifications.
            INSERT INTO TE_SPEC_CODE_VARIANCES 
              (SPEC_CODE_ID,VARIANCE_COMMENT,COMMENTS,MPE,
              SITE)
            SELECT lv_copy_to_spec_id_out, variance_comment,comments,mpe,site
            FROM te_spec_code_variances
            WHERE spec_code_id = p_copy_from_spec_id_in
            AND   rec_status = 'A'
            AND   vari_id IS NOT NULL;
    END IF;
        

    --Copy multi Specs from Multi-Spec-Set (TE_MULTI_SPEC_SET) table if they exist.
    IF lv_multi_spec_check = 'Y' THEN
          INSERT INTO te_multi_spec_set
            (spec_id, multi_spec_name, spec_name,alloy_code,rec_status,site, 
            multi_spec_code_id,spec_code_id,EDITION,created_by,time_created,date_created)
          SELECT spec_code_seq.NEXTVAL, p_new_spec_name_in, spec_name,
            alloy_code,'A',p_user_site_in,lv_copy_to_spec_id_out,spec_code_id,
            1, USER, TO_CHAR(SYSDATE,'HH24:MI:SS'), TRUNC(SYSDATE)
          FROM te_multi_spec_set
          WHERE multi_spec_code_id = p_copy_from_spec_id_in;
    END IF;    
    
    -- IPO ENTIRES COPY
    -- Obtain all ipo_entries information for copied spec_code ID.
    INSERT INTO STAR.TE_IPO_ENTRIES 
                 (as_cast_wt, as_cast_wt_tol, as_cast_eb_ln, as_cast_eb_ln_tol, var_cast_size, var_as_cast_wt, var_as_cast_wt_tol, 
                 var_as_cast_ln, var_as_cast_ln_tol, no_cast_heats, var_no_cast_heats, no_pieces, route, aim_gauge, aim_width, aim_ln_t, 
                 aim_ln_b, min_gauge, min_width, min_ln_t, min_ln_b, max_gauge, max_width, max_ln_t, max_ln_b, lsc_roll_gauge, lsc_roll_width, lsc_roll_ln, raw_material, recipe_no, 
                 recipe_no_1, recipe_no_2, revision_history, internal_order_yn, rev_no, condition_comments, 
                 customer, customer_po, rev_comments, sales_order_no, sales_order_item, 
                 ipo_id, spec_code_id, aim_wt, min_wt, max_wt, shape, no_pieces_heat, tht_dim_spec, 
                 date_created, time_created, created_by, rec_status, EDITION, site,shape_form_id, mold_size_id )
    SELECT as_cast_wt, as_cast_wt_tol, as_cast_eb_ln, as_cast_eb_ln_tol, var_cast_size, var_as_cast_wt, var_as_cast_wt_tol, 
                 var_as_cast_ln, var_as_cast_ln_tol, no_cast_heats, var_no_cast_heats, no_pieces, route, aim_gauge, aim_width, aim_ln_t, 
                 aim_ln_b, min_gauge, min_width, min_ln_t, min_ln_b, max_gauge, max_width, max_ln_t, max_ln_b, lsc_roll_gauge, lsc_roll_width, lsc_roll_ln, raw_material, recipe_no, 
                 recipe_no_1, recipe_no_2, revision_history, internal_order_yn, '1', condition_comments, 
                 customer, customer_po, rev_comments, p_sales_order_no_in, p_sales_order_item_in, 
                 te_ipo_entries_id_seq.NEXTVAL, lv_copy_to_spec_id_out, aim_wt, min_wt, max_wt, shape, no_pieces_heat, tht_dim_spec, date_created, 
                 time_created, created_by, rec_status, EDITION, site,shape_form_id, mold_size_id
    FROM   TE_IPO_ENTRIES
    WHERE  spec_code_id = p_copy_from_spec_id_in
    AND    ipo_id IS NOT NULL;

    --
    -- Copy all related text for the SPEC_CODE_HEADER as indicated by the check boxes.
    -- The gtt must be updated to have the newly created spec code id otherwise the copy procedure
    -- will not pick up the correct check box values. Obviously we don't know the new spec code id
    -- until after the insert into te_spec_code_header which done above.
    --
    UPDATE gtt_copy_specs
    SET    spec_code_id = lv_copy_to_spec_id_out
    WHERE  spec_code_id = p_copy_from_spec_id_in;
    
    Pk_Tech_Edit.copy_spec_text(p_copy_from_spec_id_in, lv_copy_to_spec_id_out);

   -- Only do this for copies to order specs.
   IF p_copy_to_type_in = 'O' THEN  
           -- NULL alloy and grade code variables
           lv_alloy_code := NULL;
           lv_qual_code := NULL;
           
      OPEN  get_key_size  (p_sales_order_no_in => p_sales_order_no_in, p_sales_order_item_in => p_sales_order_item_in);    
      FETCH get_key_size INTO lv_key_size, lv_alloy_code, lv_qual_code ;
      --- Get the key size from the order line record.
      --- Note that this field will always in mm.
      IF get_key_size%NOTFOUND THEN
            CLOSE get_key_size;
         lv_copy_to_spec_id_out := 1.1;
         RETURN (lv_copy_to_spec_id_out);
      END IF;
   
      CLOSE get_key_size ;
      
      -- If the alloy and grade against the order line are currently NULL default them to values from the spec
      IF lv_alloy_code IS NULL
      THEN
          -- Default to spec value
          lv_alloy_code := copy_from_spec_rec.alloy_code;
      END IF;
      
      IF lv_qual_code IS NULL
      THEN
          -- Default to spec value
          lv_qual_code := copy_from_spec_rec.grade_code;
      END IF;
   
      OPEN  get_site_size_uom(p_site => copy_from_spec_rec.site);
      FETCH get_site_size_uom INTO lv_site_size_uom;
   
      IF get_site_size_uom%NOTFOUND THEN
         CLOSE get_site_size_uom;
         lv_copy_to_spec_id_out := 1.2;
         RETURN (lv_copy_to_spec_id_out);
      END IF;  
      CLOSE get_site_size_uom;
      IF lv_site_size_uom <> 'mm' THEN
         --- Need to convert
         P_CONV_UOM (PC_UOM_FROM => 'mm'
                    ,PC_UOM_TO   => lv_site_size_uom
                    ,PN_VAL_IN   => lv_key_size
                    ,PN_VAL_OUT  => lv_limit_key_size
                    ,PC_STAT     => lv_status
                    ,PN_ERRNO    => lv_error
                    );
         lv_limit_key_size := ROUND(lv_limit_key_size,5);
      ELSE
            lv_limit_key_size := lv_key_size;
      END IF;
   
      IF lv_error = 146 THEN
           lv_copy_to_spec_id_out := 1.3;
        RETURN (lv_copy_to_spec_id_out);
      END IF;
   END IF;
   
   -- Loop through all the limit records
   -- Do this for basis to basis spec and order to order spec copies
    IF p_copy_to_type_in IN ('O', 'B') THEN
      INSERT INTO te_spec_code_limits
                   (SPEC_CODE_ID,TEST_TYPE,TEST_CODE,MIN_VALUE,MIN_VALUE_UOM,MAX_VALUE,
                   AIM_VALUE,SIZE_BAND_LOW_VAL,SIZE_BAND_HIGH_VAL,CONF_LIMIT_LOW,
                CONF_LIMIT_HIGH,COMMENTS,EDITION,DECIMALS,REPORT_RESULT_YN,CERT_RESULT_YN) 
            -- STCR 6169 MAX_VALUE_UOM,AIM_VALUE,SIZE_BAND_LOW_VAL,SIZE_BAND_HIGH_VAL,CONF_LIMIT_LOW,                         
      SELECT lv_copy_to_spec_id_out,test_type,test_code,
                min_value,min_value_uom,max_value,
                aim_value,size_band_low_val,size_band_high_val,
                conf_limit_low,conf_limit_high,comments,
                1,decimals,report_result_yn,cert_result_yn
              -- STCR 6169 max_value_uom,aim_value,size_band_low_val,size_band_high_val,                
      FROM   te_spec_code_limits
      WHERE  spec_code_id = p_copy_from_spec_id_in
      AND    NVL(size_band_high_val,9999999999) >= DECODE(p_copy_to_type_in, 'O', lv_limit_key_size, NVL(size_band_high_val,9999999999))
      AND    NVL(size_band_low_val,-9999999999) <= DECODE(p_copy_to_type_in, 'O', lv_limit_key_size, NVL(size_band_low_val,-9999999999));
    END IF;    
  
   -- Get the Manufacturing Solutions for From Spec
  INSERT INTO TE_MANUFACTURING_SOLUTIONS
              (SPEC_CODE_ID,INGOT_TYPE_ID,PROCESS_ROUTE_ID,PREFERENCE
            ,COMMENTS,DATE_CREATED,TIME_CREATED,CREATED_BY,EDITION)
  SELECT lv_copy_to_spec_id_out,man.ingot_type_id,man.process_route_id,
            man.preference,man.comments,SYSDATE,
            TO_CHAR(SYSDATE,'hh24:mi:ss'),USER,1
   FROM   te_manufacturing_solutions man,te_process_route_headers pro,            
         te_ingot_types ing
  WHERE  man.ingot_type_id = ing.ingot_type_id            
  AND    man.process_route_id = pro.process_route_id      
  AND    pro.status = 'A'                                 
  AND    ing.status = 'A'                                 
  AND    spec_code_id = p_copy_from_spec_id_in 
  AND    pro.product_final_size BETWEEN p_spec_low_size_in AND p_spec_high_size_in;


--
-- Copy document version to spec links
--
        INSERT INTO dc_doc_basis_spec_linkage
        (spec_code_id
        ,doc_version_id
        ,rec_status
        ,date_created
        ,time_created
        ,created_by
        ,EDITION
        ,date_updated
        ,time_updated
        ,last_update_by
        ,date_expired
        ,date_reactivated
        ,doc_short_name
        ,report_yn
        ,ndt_proc_yn
        ,qc_alloy_comments
        )
        SELECT lv_copy_to_spec_id_out,
                doc_version_id,
                'A',
                SYSDATE,
                TO_CHAR(SYSDATE,'hh24:mi:ss'),
                USER,
                1,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                doc_short_name,
                report_yn,
                ndt_proc_yn,
                qc_alloy_comments
      FROM dc_doc_basis_spec_linkage
      WHERE spec_code_id = p_copy_from_spec_id_in
      AND    rec_status = 'A';
---
--- Copy Over Bom (ZPPV) details
---
    INSERT INTO TE_MAN_SOL_BOMS
            (SPEC_CODE_ID
             ,INGOT_TYPE_ID
         ,PROCESS_ROUTE_ID
         ,BOM_DETAIL
             ,PREFERENCE
         ,COMMENTS
            )
    SELECT lv_copy_to_spec_id_out
         ,bom.ingot_type_id
         ,bom.process_route_id
             ,bom.bom_detail
             ,bom.preference
             ,bom.comments
    FROM te_man_sol_boms bom,te_process_route_headers pro,
    te_ingot_types ing
    WHERE bom.ingot_type_id = ing.ingot_type_id
    AND bom.process_route_id = pro.process_route_id
    AND pro.status = 'A'
    AND ing.status = 'A'
    AND spec_code_id = p_copy_from_spec_id_in
    AND pro.product_final_size BETWEEN p_spec_low_size_in AND p_spec_high_size_in;

--    debug_rec('BOMS inserted');
---
--- Copy over Tech edit data : Process Outlines
---
      INSERT INTO TE_SPEC_PROUTL_LINKS
          ( SPEC_CODE_ID
           ,PROCESS_OUTLINE_ID
           ,LINK_STILL_VALID
           ,DATE_CREATED
           ,TIME_CREATED
           ,CREATED_BY
           ,EDITION
           ,LINKAGE_COMMENT
          )
      SELECT lv_copy_to_spec_id_out
          ,process_outline_id
          ,link_still_valid
          ,SYSDATE
          ,TO_CHAR(SYSDATE,'hh24:mi:ss')
          ,USER
          ,1
          ,linkage_comment
       FROM te_spec_proutl_links
       WHERE spec_code_id = p_copy_from_spec_id_in
       AND link_still_valid = 'Y';

--    debug_rec('Process outlines inserted');
---
--- Copy over Tech edit data : Conversion Route Modification Text
---
      INSERT INTO TE_SPEC_CODE_ROUTE_MOD_TEXT
          ( SPEC_CODE_ID
           ,ROUTE_MOD_TEXT
           ,DATE_CREATED
           ,TIME_CREATED
           ,CREATED_BY
           ,EDITION
          )
      SELECT lv_copy_to_spec_id_out
          ,route_mod_text
          ,SYSDATE
          ,TO_CHAR(SYSDATE,'hh24:mi:ss')
          ,USER
          ,1
      FROM   te_spec_code_route_mod_text
      WHERE  spec_code_id = p_copy_from_spec_id_in;

--    debug_rec('Conversion route text inserted');

---
--- Copy over HT Codes data
---
      INSERT INTO TE_SPEC_CODE_HT_CODES
          ( SPEC_CODE_ID
           ,TEST_TYPE
           ,HT_CODE
          )
      SELECT lv_copy_to_spec_id_out
            ,TEST_TYPE
            ,HT_CODE
        FROM TE_SPEC_CODE_HT_CODES
       WHERE SPEC_CODE_ID = p_copy_from_spec_id_in
         AND REC_STATUS = 'A';
--
-- Ensure any material charatceristics applied are copied to the new spec
    FOR crGetMatlChars_row IN crGetMatlChars(p_copy_from_spec_id_in )
    LOOP   
        -- INSERT  record
        INSERT INTO te_spec_matl_chars
            (spec_code_id, matl_char_id, uom_ref, rec_status
            , min_limit, max_limit
            )
        VALUES
            (lv_copy_to_spec_id_out, crGetMatlChars_row.matl_char_id
            , crGetMatlChars_row.uom_ref, pk_star_constants.vcactiverecord
            ,crGetMatlChars_row.min_limit, crGetMatlChars_row.max_limit
            );
    END LOOP;

/* If copying to an Order Type Specification Code then set up links  */
 
    IF p_copy_to_type_in = 'O' THEN

    UPDATE STAR.r3_sales_order_items
  SET   spec_code_id = lv_copy_to_spec_id_out,
        item_status  = 'L',
        alloy_code = lv_alloy_code,
        quality_grade_code = lv_qual_code
    WHERE r3_sales_order = p_sales_order_no_in 
    AND   r3_sales_order_item = p_sales_order_item_in;

    END IF;

    -- Add traveler data if required
    lv_trav_yn := 'N';
    OPEN chk_trav_refresh (lv_copy_to_spec_id_out);
    FETCH chk_trav_refresh INTO lv_trav_yn;
    CLOSE chk_trav_refresh;
    --debug_rec('p_copy_from_spec_id_in - '||p_copy_from_spec_id_in||' lv_copy_to_spec_id_out '||lv_copy_to_spec_id_out||' p_copy_to_type_in '||p_copy_to_type_in);
    IF lv_trav_yn = 'Y' THEN
     pk_test_piece_tracking.p_copy_spec_tech_edit(p_copy_from_spec_id_in,
                                                  lv_copy_to_spec_id_out,
                                                  p_copy_to_type_in);
    END IF;
    
    RETURN(lv_copy_to_spec_id_out);

EXCEPTION
  WHEN OTHERS
    THEN
      -- Record details and re-raise exception
        pk_error_log.prRecordDetailsHalt (p_SqlCode_in         =>  SQLCODE,
                                 p_SqlErrm_in        =>  SUBSTR(SQLERRM, 1, 190),
                                  p_ModuleName_in  => cModuleName,  
                                  p_KeyData_in        => vcKeyData);

END fncopy_to_order_spec;          

PROCEDURE copy_spec_text(p_copy_from_spec_id_in IN  te_spec_code_header.spec_code_id%TYPE
                        ,p_copy_to_spec_id_in IN  te_spec_code_header.spec_code_id%TYPE
                        ,p_delete_records IN BOOLEAN DEFAULT FALSE) IS
                        
  lv_spec_code_type te_spec_code_header.spec_code_type%TYPE;

  CURSOR get_copy_checks (p_copy_to_spec_id IN te_spec_code_header.spec_code_id%TYPE) IS
  SELECT traveler_text_yn
        ,chem_text_yn
        ,comp_text_yn
        ,mech_text_yn
        ,metl_text_yn
        ,rel_text_yn
        ,gen_text_yn
        ,man_text_yn
        ,spec_text_yn
        ,test_text_yn
        ,trep_text_yn
        ,note_text_yn
        ,lab_text_yn
        ,approval_text_yn
        ,approval_te_text_yn
        ,approval_met_text_yn
        ,approval_lab_text_yn
        ,approval_ce_text_yn
        ,approval_us_text_yn
        ,approval_ht_text_yn
  FROM   gtt_copy_specs 
  WHERE  spec_code_id = p_copy_to_spec_id;

  copy_checks_rec get_copy_checks%ROWTYPE;
  
BEGIN
  OPEN get_copy_checks (p_copy_to_spec_id => p_copy_to_spec_id_in);
  FETCH get_copy_checks INTO copy_checks_rec;
  CLOSE get_copy_checks;   
  
  ---
  --- Copy Over Chemistry Statements if selected        
  ---
  IF copy_checks_rec.chem_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_chem_statements_txt'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_other_columns => ',chem_id'
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    
    
  ---
  --- Copy Over Compliance Statements if selected        
  ---
  IF copy_checks_rec.comp_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_comp_statements_txt'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_other_columns => ',comp_id'
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Mechanical Statements if selected        
  ---
  IF copy_checks_rec.mech_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_mech_statements_txt'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_other_columns => ',mech_id'
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Metallurgical Statements if selected        
  ---
  IF copy_checks_rec.metl_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_metl_statements_txt'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_other_columns => ',metl_id'
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Release Statements if selected        
  ---
  IF copy_checks_rec.rel_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_rel_statements_txt'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_other_columns => ',rel_id'
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over General Text if selected        
  ---
  IF copy_checks_rec.gen_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_gen_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Manufacturing Text if selected        
  ---
  IF copy_checks_rec.man_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_man_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Special Text if selected        
  ---
  IF copy_checks_rec.spec_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_spe_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Testing Text if selected        
  ---
  IF copy_checks_rec.test_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_tst_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_other_columns => ',ht_code'
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over lab Text if selected        
  ---
  IF copy_checks_rec.lab_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_lab_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Test Report Text if selected        
  ---
  IF copy_checks_rec.trep_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_rpt_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Note Text if selected        
  ---
  IF copy_checks_rec.note_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_tech_notes'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Tech-Edit Approval Text if selected        
  ---
  IF copy_checks_rec.approval_te_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_approval_te_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Metallurgy Approval Text if selected        
  ---
  IF copy_checks_rec.approval_met_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_approval_met_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Laboratory Approval Text if selected        
  ---
  IF copy_checks_rec.approval_lab_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_approval_lab_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Certification Approval Text if selected        
  ---
  IF copy_checks_rec.approval_ce_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_approval_ce_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Ultrasonic Approval Text if selected        
  ---
  IF copy_checks_rec.approval_us_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_approval_us_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;    

  ---
  --- Copy Over Heat Treatment Approval Text if selected        
  ---
  IF copy_checks_rec.approval_ht_text_yn = 'Y' THEN
    Pk_Tech_Edit.pr_copy_stmt_text (p_table_name => 'te_spec_code_approval_ht_text'
                                   ,p_order_spec_id => p_copy_to_spec_id_in
                                   ,p_basis_spec_id => p_copy_from_spec_id_in
                                   ,p_delete_records => p_delete_records
                                   );
  END IF;  
  ---
  --- Copy Over ALL Approval Header Information if selected        
  ---
  IF copy_checks_rec.approval_text_yn = 'Y' THEN
    Pk_Tech_Edit. pr_copy_approval_header (p_order_spec_id_in  => p_copy_to_spec_id_in
                                                                ,p_basis_spec_id_in => p_copy_from_spec_id_in
                                                                ,p_delete_records_in => p_delete_records);
  END IF;    
END copy_spec_text; 



PROCEDURE temp_checks_yn(p_copy_from_spec_id_in IN te_spec_code_header.spec_code_id%TYPE
                          ,p_attachment_link_in IN VARCHAR2
                         ,p_multi_spec_sets_in IN VARCHAR2
                         ,p_approval_in IN VARCHAR2
                         ,p_t_traveler_text_in IN VARCHAR2
                         ,p_chem_text_in IN VARCHAR2
                         ,p_comp_text_in IN VARCHAR2
                         ,p_gen_text_in IN VARCHAR2
                         ,p_man_text_in IN VARCHAR2
                         ,p_spe_text_in IN VARCHAR2
                         ,p_tst_text_in IN VARCHAR2
                         ,p_tr_text_in IN VARCHAR2
                         ,p_note_in IN VARCHAR2
                         ,p_approval_text_in IN VARCHAR2) IS
                         
                         
                         
BEGIN


IF p_copy_from_spec_id_in IS NOT NULL THEN
     INSERT INTO TE_COPY_SPECS_TEMP
                   (spec_code_id,doc_attach_yn,multi_spec_yn,approvals_yn,traveler_text_yn,chem_text_yn,
                 comp_text_yn,gen_text_yn,man_text_yn,spec_text_yn,test_text_yn,
                 trep_text_yn,note_text_yn,approval_text_yn)
     VALUES
                (p_copy_from_spec_id_in
                  ,p_attachment_link_in 
                 ,p_multi_spec_sets_in 
                 ,p_approval_in 
                 ,p_t_traveler_text_in 
                 ,p_chem_text_in 
                 ,p_comp_text_in 
                 ,p_gen_text_in 
                 ,p_man_text_in 
                 ,p_spe_text_in 
                 ,p_tst_text_in 
                 ,p_tr_text_in 
                 ,p_note_in 
                 ,p_approval_text_in);
END IF;                 
COMMIT;
END temp_checks_yn;                 


PROCEDURE p_distribute_spec_limits (p_basis_spec_id_in IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                                     ,p_order_spec_id_in IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                                   ,p_site_in IN TE_SPEC_CODE_HEADER.site%TYPE
                                   ,p_key_size_in IN r3_sales_order_items.key_size%TYPE
                                   ,p_distribution_type_in IN VARCHAR2 DEFAULT 'U'
                                   ) IS

  CURSOR upd_limits_cur IS
  SELECT scla.test_code
        ,scla.test_type
        ,scla.size_band_low_val
        ,scla.size_band_high_val
        ,scla.min_value
        ,scla.min_value_uom
        ,scla.max_value
        -- STCR 6169 ,scla.max_value_uom
        ,scla.aim_value
        ,scla.report_result_yn
        ,scla.cert_result_yn
        ,scla.conf_limit_low
        ,scla.conf_limit_high
        ,scla.comments
        ,scla.decimals
  FROM   te_spec_code_limits scla
        ,te_spec_code_limits sclb
  WHERE  scla.spec_code_id = p_basis_spec_id_in
  AND    sclb.spec_code_id = p_order_spec_id_in
  AND    scla.test_code = sclb.test_code
  AND    scla.test_type = sclb.test_type
  AND    NVL(scla.size_band_low_val, -9999) = NVL(sclb.size_band_low_val, -9999)
  AND    NVL(scla.size_band_high_val, -9999) = NVL(sclb.size_band_high_val, -9999)
  AND    (NVL(scla.conf_limit_low, -9999) != NVL(sclb.conf_limit_low, -9999)
          OR NVL(scla.conf_limit_high, -9999) != NVL(sclb.conf_limit_high, -9999)
          OR NVL(scla.min_value, -9999) != NVL(sclb.min_value, -9999)
         -- STCR 6169  OR NVL(scla.max_value, -9999) != NVL(sclb.max_value, -9999)
         );
/*
  CURSOR limits_cur (p_spec_code_id IN TE_SPEC_CODE_LIMITS.spec_code_id%TYPE) IS
  SELECT test_code
        ,test_type
        ,size_band_low_val
        ,size_band_high_val
        ,min_value,min_value_uom
        ,max_value,max_value_uom
        ,report_result_yn
        ,cert_result_yn
        ,conf_limit_low
        ,conf_limit_high
        ,comments
        ,decimals
  FROM   te_spec_code_limits
  WHERE  spec_code_id = p_spec_code_id;
*/
BEGIN
  IF p_distribution_type_in = 'U' THEN
    FOR upd_limits_rec IN upd_limits_cur LOOP
      UPDATE te_spec_code_limits
      SET    min_value = upd_limits_rec.min_value
            ,min_value_uom = upd_limits_rec.min_value_uom
            ,max_value = upd_limits_rec.max_value
           -- STCR 6169 ,max_value_uom = upd_limits_rec.max_value_uom
            ,aim_value = upd_limits_rec.aim_value
            ,conf_limit_low = upd_limits_rec.conf_limit_low
            ,conf_limit_high = upd_limits_rec.conf_limit_high
            ,comments = upd_limits_rec.comments
            ,report_result_yn = upd_limits_rec.report_result_yn
            ,cert_result_yn = upd_limits_rec.cert_result_yn
            ,decimals  = upd_limits_rec.decimals
            ,size_band_low_val = upd_limits_rec.size_band_low_val
            ,size_band_high_val = upd_limits_rec.size_band_high_val
      WHERE  spec_code_id = p_order_spec_id_in
      AND    test_code = upd_limits_rec.test_code
      AND    test_type = upd_limits_rec.test_type
      AND    NVL(size_band_low_val, -9999) = NVL(upd_limits_rec.size_band_low_val, -9999)
      AND    NVL(size_band_high_val, -9999) = NVL(upd_limits_rec.size_band_high_val, -9999);
    END LOOP;
  ELSE
    DELETE FROM te_spec_code_limits
    WHERE SPEC_CODE_ID = p_order_spec_id_in;
  END IF;

  INSERT INTO TE_SPEC_CODE_LIMITS
    (spec_code_id
    ,test_code
    ,test_type
    ,size_band_low_val
    ,size_band_high_val
    ,min_value
    ,min_value_uom
    ,max_value
   -- STCR 6169 ,max_value_uom
    ,aim_value
    ,conf_limit_low
    ,conf_limit_high
    ,comments
    ,report_result_yn
    ,cert_result_yn
    ,decimals)
  SELECT p_order_spec_id_in
        ,test_code
        ,test_type
        ,size_band_low_val
        ,size_band_high_val
        ,min_value
        ,min_value_uom
        ,max_value
       -- STCR 6169 ,max_value_uom
        ,aim_value
        ,conf_limit_low
        ,conf_limit_high
        ,comments
        ,report_result_yn
        ,cert_result_yn
        ,decimals
  FROM   te_spec_code_limits
  WHERE  spec_code_id = p_basis_spec_id_in
  AND    (test_code, test_type, NVL(size_band_low_val, -9999), NVL(size_band_high_val, 9999)) IN
         (SELECT scla.test_code
                ,scla.test_type
                ,NVL(scla.size_band_low_val, -9999)
                ,NVL(scla.size_band_high_val, 9999)
          FROM   te_spec_code_limits scla
          WHERE  scla.spec_code_id = p_basis_spec_id_in
          AND    p_key_size_in BETWEEN NVL(size_band_low_val, p_key_size_in - 1) AND NVL(size_band_high_val, p_key_size_in + 1) -- 1.4
          MINUS
          SELECT sclb.test_code
                ,sclb.test_type
                ,NVL(sclb.size_band_low_val, -9999)
                ,NVL(sclb.size_band_high_val, 9999)
          FROM   te_spec_code_limits sclb
          WHERE  sclb.spec_code_id = p_order_spec_id_in
          AND    p_key_size_in BETWEEN NVL(size_band_low_val, p_key_size_in - 1) AND NVL(size_band_high_val, p_key_size_in + 1) -- 1.4
         );

/*
  -- Delete existing limit records
  DELETE FROM TE_SPEC_CODE_LIMITS WHERE
               SPEC_CODE_ID = p_order_spec_id_in;

  FOR limits_rec IN limits_cur (p_spec_code_id => p_basis_spec_id_in) LOOP
    IF p_key_size_in BETWEEN NVL(limits_rec.size_band_low_val,0)    
      AND NVL(limits_rec.size_band_high_val,99999) THEN
      INSERT INTO TE_SPEC_CODE_LIMITS (
         spec_code_id
        ,test_code
        ,test_type
        ,limit_ref
        ,size_band_low_val
        ,size_band_high_val
        ,min_value
        ,min_value_uom
        ,max_value
        ,max_value_uom
        ,conf_limit_low
        ,conf_limit_high
        ,comments
        ,report_result_yn
        ,cert_result_yn
        ,decimals
        )
      VALUES (
         p_order_spec_id_in
        ,limits_rec.test_code
        ,limits_rec.test_type
        ,limit_ref_seq.nextval
        ,limits_rec.size_band_low_val
        ,limits_rec.size_band_high_val
        ,limits_rec.min_value
        ,limits_rec.min_value_uom
        ,limits_rec.max_value
        ,limits_rec.max_value_uom
        ,limits_rec.conf_limit_low
        ,limits_rec.conf_limit_high
        ,limits_rec.comments
        ,limits_rec.report_result_yn
        ,limits_rec.cert_result_yn
        ,limits_rec.decimals
      );

      END IF;
  END LOOP;*/
END p_distribute_spec_limits ;    

-- STCR 6956 Start

PROCEDURE pr_copy_stmt_text ( p_table_name     IN VARCHAR2
                            , p_order_spec_id  IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                            , p_basis_spec_id  IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                            , p_other_columns  IN VARCHAR2                               DEFAULT NULL -- ex: ,ht_code,ht_comment  Must be comma separated with a starting comma
                            , p_delete_records IN BOOLEAN                                DEFAULT TRUE                             ) IS
BEGIN 

IF p_delete_records THEN


  CASE LOWER ( p_table_name )
  
  WHEN 'te_chem_statements_txt' THEN
  
    DELETE FROM te_chem_statements_txt
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );


  WHEN 'te_comp_statements_txt' THEN
  
    DELETE FROM te_comp_statements_txt
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );

  WHEN 'te_mech_statements_txt' THEN
  
    DELETE FROM te_mech_statements_txt
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );  

  WHEN 'te_metl_statements_txt' THEN
  
    DELETE FROM te_metl_statements_txt
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );       

  WHEN 'te_rel_statements_txt' THEN
  
    DELETE FROM te_rel_statements_txt
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );  

  WHEN 'te_spec_code_gen_text' THEN
  
    DELETE FROM te_spec_code_gen_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id ); 
    
  WHEN 'te_spec_code_man_text' THEN
  
    DELETE FROM te_spec_code_man_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );  
    
  WHEN 'te_spec_code_spe_text' THEN
  
    DELETE FROM te_spec_code_spe_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );        

  WHEN 'te_spec_code_tst_text' THEN
  
    DELETE FROM te_spec_code_tst_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id ); 
    
  WHEN 'te_spec_code_lab_text' THEN
  
    DELETE FROM te_spec_code_lab_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id ); 
    
  WHEN 'te_spec_code_rpt_text' THEN
  
    DELETE FROM te_spec_code_rpt_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );  
    
  WHEN 'te_spec_code_tech_notes' THEN
  
    DELETE FROM te_spec_code_tech_notes
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );  
    
  WHEN 'te_spec_code_approval_te_text' THEN
  
    DELETE FROM te_spec_code_approval_te_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id ); 
    
  WHEN 'te_spec_code_approval_met_text' THEN
  
    DELETE FROM te_spec_code_approval_met_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );     
    
  WHEN 'te_spec_code_approval_ce_text' THEN
  
    DELETE FROM te_spec_code_approval_ce_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );  

  WHEN 'te_spec_code_approval_us_text' THEN
  
    DELETE FROM te_spec_code_approval_us_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );   

  WHEN 'te_spec_code_approval_ht_text' THEN
  
    DELETE FROM te_spec_code_approval_ht_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );    
    
  WHEN 'te_spec_code_approval_lab_text' THEN
  
    DELETE FROM te_spec_code_approval_lab_text
    WHERE spec_code_id = TO_CHAR ( p_order_spec_id );                           
 
  ELSE
 
    NULL;
     
  END CASE;   
  
  COMMIT;        

END IF;
/*
  IF p_delete_records THEN
    EXECUTE IMMEDIATE 'DELETE ' || p_table_name
                    ||' WHERE spec_code_id = ' || TO_CHAR(p_order_spec_id);
  END IF;
*/
  EXECUTE IMMEDIATE 'INSERT INTO '                    || p_table_name
                  ||' (spec_code_id,line_number,text' || NVL ( p_other_columns, ' ') || ')'
                  ||' SELECT '                        || TO_CHAR ( p_order_spec_id)  || ',line_number,NVL(text,''.'')' || NVL(p_other_columns, ' ')
                  ||' from '                          || p_table_name
                  ||' where  spec_code_id = '         || TO_CHAR ( p_basis_spec_id )
                  ||' AND   rec_status = ''A''';

EXCEPTION

  WHEN OTHERS THEN

    pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                 , p_SqlErrm_in    => SQLERRM
                                 , p_ModuleName_in => 'pk_tech_edit.pr_copy_stmt_text'  
                                 , p_KeyData_in    => p_table_name || ',' || TO_CHAR ( p_order_spec_id ) || ',' || TO_CHAR ( p_basis_spec_id )   );
END pr_copy_stmt_text;


FUNCTION fndistribute_statements ( p_statement_id_in    IN te_compliance_statements.comp_id%TYPE
                                 , p_copy_to_type_in    IN te_spec_code_header.spec_code_type%TYPE
                                 , p_new_statement_desc IN te_compliance_statements.description%TYPE
                                 , p_spec_code_type     IN te_spec_code_header.spec_code_type%TYPE                        ) RETURN NUMBER IS
BEGIN
  CASE p_copy_to_type_in
    WHEN 'CO' THEN
      UPDATE te_comp_statements_txt
      SET    text = p_new_statement_desc
      WHERE  spec_code_id IN (SELECT spec_code_id
                              FROM   te_spec_code_header b
                              WHERE  spec_code_type LIKE p_spec_code_type
                              AND    rec_status = 'A'
                             )
      AND    rec_status = 'A'
      AND    comp_id = p_statement_id_in;
    WHEN 'CH' THEN
      UPDATE te_chem_statements_txt
      SET    text = p_new_statement_desc
      WHERE  spec_code_id IN (SELECT spec_code_id
                              FROM   te_spec_code_header b
                              WHERE  spec_code_type LIKE p_spec_code_type
                              AND    rec_status = 'A'
                             )
      AND    rec_status = 'A'
      AND    chem_id = p_statement_id_in;
    WHEN 'RE' THEN
      UPDATE te_rel_statements_txt
      SET    text = p_new_statement_desc
      WHERE  spec_code_id IN (SELECT spec_code_id
                              FROM   te_spec_code_header b
                              WHERE  spec_code_type LIKE p_spec_code_type
                              AND    rec_status = 'A'
                             )
      AND    rec_status = 'A'
      AND    rel_id = p_statement_id_in;
    WHEN 'MT' THEN
      UPDATE te_metl_statements_txt
      SET    text = p_new_statement_desc
      WHERE  spec_code_id IN (SELECT spec_code_id
                              FROM   te_spec_code_header b
                              WHERE  spec_code_type LIKE p_spec_code_type
                              AND    rec_status = 'A'
                             )
      AND    rec_status = 'A'
      AND    metl_id = p_statement_id_in;
    WHEN 'MC' THEN
      UPDATE te_mech_statements_txt
      SET    text = p_new_statement_desc
      WHERE  spec_code_id IN (SELECT spec_code_id
                              FROM   te_spec_code_header b
                              WHERE  spec_code_type LIKE p_spec_code_type
                              AND    rec_status = 'A'
                             )
      AND    rec_status = 'A'
      AND    mech_id = p_statement_id_in;
    ELSE
      RETURN 0;
  END CASE;
  
  RETURN SQL%ROWCOUNT;

  EXCEPTION
    WHEN OTHERS THEN
      Pk_Error_Log.prRecordDetails(p_SqlCode_in => SQLCODE
                                  ,p_SqlErrm_in => SQLERRM
                                  ,p_ModuleName_in => 'Pk_Tech_Edit.fndistribute_statements'  
                                  ,p_KeyData_in => TO_CHAR(p_statement_id_in) || ',' || p_copy_to_type_in || ',' || p_spec_code_type
                                  );
END fndistribute_statements;                                                                   


FUNCTION fn_mask_limits( p_limit IN NUMBER
                       , p_decimals IN NUMBER
                       ) RETURN VARCHAR2 IS

    lv_decimal_mask VARCHAR2( 20 ) := 'FM999990.';
    lv_actual_decimals NUMBER := 0;
    lv_return_val VARCHAR2( 200 );
    lv_decimal_position NUMBER;
    lv_decimals NUMBER;
    
BEGIN
  lv_decimal_position := INSTR( TO_CHAR( p_limit ), '.' );
    
  IF lv_decimal_position >= 1 THEN
    lv_actual_decimals := LENGTH( SUBSTR( TO_CHAR( p_limit )
                                        , lv_decimal_position + 1
                                        , LENGTH ( TO_CHAR( p_limit ) )
                                        ) );
  END IF;
    
  IF lv_actual_decimals > NVL( p_decimals, lv_actual_decimals + 1 ) THEN
    lv_decimals := lv_actual_decimals;
  ELSE
    lv_decimals := p_decimals;
  END IF;

  IF NVL( lv_decimals, 0 ) > 0
    AND p_limit IS NOT NULL THEN
        
    FOR i IN 1..ROUND( lv_decimals ) LOOP
      lv_decimal_mask := lv_decimal_mask || '0';
    END LOOP;
        
    lv_return_val := TO_CHAR( p_limit, lv_decimal_mask );
  ELSIF NVL( lv_decimals, 0 ) = 0
    AND lv_decimal_position = 1 THEN
    lv_return_val := '0' || p_limit;
  ELSE
    lv_return_val := p_limit;
  END IF;
    
  RETURN lv_return_val;
END fn_mask_limits;


PROCEDURE pr_basis_spec_linkage( p_table_data IN OUT Pk_Tech_Edit.spec_linkage_tab
                               , p_spec_code_id IN DC_DOC_BASIS_SPEC_LINKAGE.spec_code_id%TYPE
                               , p_rec_status IN DC_DOC_BASIS_SPEC_LINKAGE.rec_status%TYPE
                               , p_op_type IN VARCHAR2
                               ) IS

  TYPE t_spec_code_id IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.spec_code_id%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_doc_version_id IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.doc_version_id%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_report_yn IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.report_yn%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_qc_alloy_comments IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.qc_alloy_comments%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_rec_status IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.rec_status%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_date_created IS TABLE OF DATE INDEX BY BINARY_INTEGER;
  TYPE t_time_created IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.time_created%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_created_by IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.created_by%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_date_updated IS TABLE OF DATE INDEX BY BINARY_INTEGER;
  TYPE t_time_updated IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.time_updated%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_last_update_by IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.last_update_by%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_edition IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.EDITION%TYPE INDEX BY BINARY_INTEGER;
  TYPE clNdbYN IS TABLE OF DC_DOC_BASIS_SPEC_LINKAGE.ndt_proc_yn%TYPE INDEX BY BINARY_INTEGER;
  
  lv_spec_code_id t_spec_code_id;
  lv_doc_version_id t_doc_version_id;
  lv_report_yn t_report_yn;
  rcNdbProcYN clNdbYN;
  lv_qc_alloy_comments t_qc_alloy_comments;
  lv_rec_status t_rec_status;
  lv_date_created t_date_created;
  lv_time_created t_time_created;
  lv_created_by t_created_by;
  lv_date_updated t_date_updated;
  lv_time_updated t_time_updated;
  lv_last_update_by t_last_update_by;
  lv_edition t_edition;
   cModuleName            VARCHAR2(100) := 'pk_tech_edit.pr_basis_spec_linkage';
   vcKeyData                  VARCHAR2(100);        
  CURSOR spec_link_cur( p_spec_code_id IN DC_DOC_BASIS_SPEC_LINKAGE.spec_code_id%TYPE ) IS
  SELECT sl.spec_code_id
       , sl.doc_version_id
       , sl.report_yn
       , sl.qc_alloy_comments
       , sl.rec_status
       , dh.doc_origin nbt_doc_origin
       , dh.doc_short_name nbt_doc_short_name
       , sl.date_created
       , sl.time_created
       , sl.created_by
       , sl.date_updated
       , sl.time_updated
       , sl.last_update_by
       , sl.EDITION
       , sl.ndt_proc_yn
  FROM   dc_doc_basis_spec_linkage sl
       , dc_document_versions dv
       , dc_document_headers dh
  WHERE  sl.spec_code_id = p_spec_code_id
  AND    sl.doc_version_id = dv.doc_version_id
  AND    dv.doc_id = dh.doc_id
  AND    sl.rec_status LIKE p_rec_status
  ORDER BY dh.doc_origin DESC, dh.doc_short_name;
  
BEGIN
vcKeyData := 'Spec Code Id : '||p_spec_code_id;
  IF p_op_type = 'Q' THEN
    OPEN spec_link_cur( p_spec_code_id => p_spec_code_id );
    FETCH spec_link_cur BULK COLLECT INTO p_table_data;
    CLOSE spec_link_cur;
  ELSIF p_op_type IN ( 'I', 'U' ) THEN
    FOR i IN p_table_data.FIRST..p_table_data.LAST LOOP
      lv_spec_code_id( i ) := p_table_data( i ).spec_code_id;
      lv_doc_version_id( i ) := p_table_data( i ).doc_version_id;
      lv_report_yn( i ) := p_table_data( i ).report_yn;
      lv_qc_alloy_comments( i ) := p_table_data( i ).qc_alloy_comments;
      lv_rec_status( i ) := p_table_data( i ).rec_status;
      lv_date_created( i ) := p_table_data( i ).date_created;
      lv_time_created( i ) := p_table_data( i ).time_created;
      lv_created_by( i ) := p_table_data( i ).created_by;
      lv_date_updated( i ) := p_table_data( i ).date_updated;
      lv_time_updated( i ) := p_table_data( i ).time_updated;
      lv_last_update_by( i ) := p_table_data( i ).last_update_by;
      lv_edition( i ) := p_table_data( i ).EDITION;
      rcNdbProcYN( i ) := p_table_data( i ).ndt_proc_yn;
    END LOOP;
  
    IF p_op_type = 'I' THEN
      FORALL i IN 1..p_table_data.COUNT
        INSERT INTO dc_doc_basis_spec_linkage
        ( spec_code_id
        , doc_version_id
        , rec_status
        , report_yn
        , ndt_proc_yn
        , qc_alloy_comments
        , date_created
        , time_created
        , created_by
        , EDITION
        )
        VALUES
        ( p_spec_code_id
        , lv_doc_version_id( i )
        , 'A'
        , lv_report_yn( i )
        , rcNdbProcYN( i )
        , lv_qc_alloy_comments( i )
        , NULL
        , NULL
        , NULL
        , NULL
        );
    ELSE
      FORALL i IN 1..p_table_data.COUNT
        UPDATE dc_doc_basis_spec_linkage
        SET    rec_status = lv_rec_status( i )
             , qc_alloy_comments = lv_qc_alloy_comments( i )
             , report_yn = lv_report_yn( i )
             , ndt_proc_yn =  rcNdbProcYN( i )
        WHERE  spec_code_id = lv_spec_code_id( i )
        AND    doc_version_id = lv_doc_version_id( i );
    END IF;
  ELSE
    NULL; -- Currently neither delete nor lock need to do anything
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    pk_error_log.prRecordDetailsHalt(p_SqlCode_in      => SQLCODE
                                                     ,p_SqlErrm_in      => SUBSTR(SQLERRM, 1, 190)
                                                     ,p_ModuleName_in   => cModuleName
                                                     ,p_KeyData_in      => vcKeyData);  
END pr_basis_spec_linkage;
/*-----------------------------------------------------------------------------
||
|| Function to determine if there are any basis spec created with the same name
||
*/-----------------------------------------------------------------------------

FUNCTION fn_get_heat_no (p_batch_no_in IN VARCHAR2) RETURN VARCHAR2 IS

    lv_heat_number VARCHAR2(7);
    lv_hyphen_position NUMBER;
    
BEGIN
    -- If the batch number has hyphens then it has been padded. These more often than not won't exist
    -- as part of the heat number so we need to remove them. If they are part of the heat number
    -- then the user can add them back in.
    lv_heat_number := SUBSTR(p_batch_no_in,1,7);
    lv_hyphen_position := INSTR(lv_heat_number, '-');
    
    IF lv_hyphen_position > 1 THEN
      lv_heat_number := SUBSTR(lv_heat_number, 1, lv_hyphen_position - 1);
    END IF;

    RETURN lv_heat_number;
END;

PROCEDURE pr_get_heat_info (p_heat_no_in IN VARCHAR2
                           ,p_alloy_code_out OUT VARCHAR2
                           ,p_heat_id_out OUT VARCHAR2) IS


   
 CURSOR c1 IS   
   SELECT alloy_code, heat_id 
   FROM   mt_us_heats
   WHERE  heat_num = p_heat_no_in;
  
 CURSOR c2 IS
   SELECT b.alloy_code, NULL heat_id
   FROM   bl_ingots a, bl_idfs b
   WHERE  a.idf_ref = b.idf_ref
   AND    SUBSTR (a.ingot_ref, 1, 7) = p_heat_no_in;
   
 CURSOR c3 IS
   SELECT alloy_code, NULL heat_id 
   FROM   st_bought_in_material
   WHERE  heat_no = p_heat_no_in;   
       
BEGIN

  OPEN  c1;
  FETCH c1 INTO p_alloy_code_out, p_heat_id_out;
  CLOSE c1;
  
  IF p_alloy_code_out IS NULL THEN
    OPEN  c2;
    FETCH c2 INTO p_alloy_code_out, p_heat_id_out;
    CLOSE c2;  
  END IF;

  IF p_alloy_code_out IS NULL THEN
    OPEN  c3;
    FETCH c3 INTO p_alloy_code_out, p_heat_id_out;
    CLOSE c3;  
  END IF;
  
END;

PROCEDURE pr_batch_allocation_check(p_check_type_in IN VARCHAR2
                                   ,p_batch_no_in IN VARCHAR2
                                   ,p_heat_no_in IN VARCHAR2
                                   ,p_sales_order_in IN VARCHAR2
                                   ,p_sales_order_item_in IN VARCHAR2
                                   ,p_key_size_in IN NUMBER
                                   ,p_spec_code_id_in IN NUMBER
                                   ,p_check_product IN BOOLEAN DEFAULT TRUE 
                                   ,p_table_outcomes OUT Pk_Tech_Edit.ctOutcomes) IS
                                   
/*
|| p_check_type = 'ALLOY'
|| Check to see if this process order is already linked
|| to another sales order item. If so check alloy against spec is
|| the same as alloy for THIS order item (if already linked).
||
// p_check_type = 'KEY_SIZE'
|| Also check that if the batch has been allocated to an order with a different
|| key size allocation is denied. If it has previously been allocated to an order
|| with the same size then warn the user.
||
// p_check_type = 'LIMITS'
|| If batch has previous allocations check results for tests booked are within
|| limits of the spec we are allocating the material to.
||
*/

lv_current_alloy     VARCHAR2(18);                           -- Holds the alloy code from the CURRENT spec
lv_key_size          NUMBER := NULL;                         -- Holds the key size ''   ''    ''    ''      ''    ''
lv_cast_no           R3_PROCESS_ORDERS.r3_ingot_ref%TYPE;    -- Holds the cast number
lv_batch_no          R3_PROCESS_ORDERS.r3_batch_number%TYPE; -- Holds the batch number
lv_errcode           NUMBER;                                 -- Holds generated error code 
lv_errmess           VARCHAR2(100);                          -- Holds generated error message text
lr_sample_result_rec Pk_Test_Result_Rounding.sample_result_rec;
lr_load_limits_rec   Pk_Test_Result_Rounding.load_limits_rec;
i                    INTEGER := 1;
vcErrorLoc           VARCHAR2(10);

-- Cursor to get the current alloy from the spec
CURSOR current_alloy IS
    SELECT     b.alloy_code
    FROM       r3_sales_order_items A,
              te_spec_code_header b
    WHERE     A.r3_sales_order = p_sales_order_in
    AND        A.r3_sales_order_item = p_sales_order_item_in
    AND        A.spec_code_id = b.spec_code_id;

-- Cursor to get alloy code from other orders material is linked to
CURSOR other_order_alloys IS
    SELECT     c.alloy_code
    FROM    r3_process_orders A,
            r3_sales_order_items b,
            te_spec_code_header c        
    WHERE     A.r3_process_order = p_batch_no_in
    AND     A.process_order_status != 'E'
    AND        A.r3_sales_order = b.r3_sales_order
    AND        A.r3_sales_order_item = b.r3_sales_order_item
    AND        b.spec_code_id = c.spec_code_id;

-- Cursor to get the test requirement and limits of the spec we are allocating to
  CURSOR    get_tests_and_limits IS
    SELECT     test_type, test_code,
            min_value, max_value,
            conf_limit_low, conf_limit_high
    FROM    te_spec_code_limits
    WHERE     spec_code_id = p_spec_code_id_in;

  CURSOR crPreviousResultsProd(cpBatchNo_in IN R3_PROCESS_ORDERS.r3_batch_number%TYPE 
                              ,cpTestType_in IN TE_TEST_SAMPLE_ID.test_type%TYPE
                              ,cpTestCode_in IN TE_TEST_RESULTS.test_code%TYPE) IS
  SELECT ts.sample_id
       , tr.test_code
  FROM   te_test_sample_id ts
       , te_test_results tr
  WHERE  ts.process_order_no = cpBatchNo_in
  AND    ts.test_type = cpTestType_in
  AND    tr.sample_id = ts.sample_id
  AND    tr.test_code = cpTestCode_in
  AND    tr.material_release_yn = 'Y'; --STCR 7578 only select test results that are released                                               
 

  CURSOR crPreviousResultsChem(cpBatchNo_in IN R3_PROCESS_ORDERS.r3_batch_number%TYPE
                              ,cpHeatNo_in IN R3_PROCESS_ORDERS.r3_ingot_ref%TYPE
                              ,cpTestType_in IN TE_TEST_SAMPLE_ID.test_type%TYPE
                              ,cpTestCode_in IN TE_TEST_RESULTS.test_code%TYPE) IS
  SELECT ts.sample_id
       , tr.test_code
  FROM   te_test_sample_id ts
       , te_test_results tr
       , te_test_codes tc
  WHERE  ts.cast_no = cpHeatNo_in
  AND    ts.test_type = cpTestType_in
  AND    tr.sample_id = ts.sample_id
  AND    tr.test_code = cpTestCode_in
  AND    tr.test_code = tc.test_code 
  AND    tc.status    = 'A'
  AND    tc.test_material = 'I'
  AND    ts.process_order_no <> cpBatchNo_in
  AND    tr.material_release_yn = 'Y' --STCR 7578 only select test results that are released  
  UNION ALL
  SELECT ts.sample_id
       , tr.test_code
  FROM   te_test_sample_id ts
       , te_test_results tr
  WHERE  ts.cast_no = cpHeatNo_in
  AND    ts.test_type = cpTestType_in
  AND    tr.sample_id = ts.sample_id
  AND    tr.test_code = cpTestCode_in
  AND    ts.process_order_no = cpBatchNo_in
  AND    tr.material_release_yn = 'Y'; --STCR 7578 only select test results that are released  ;

BEGIN

  p_table_outcomes(i).status  := 'S';
  p_table_outcomes(i).message := 'Success';

  vcErrorLoc            := '0000';

  CASE p_check_type_in
  WHEN 'ALLOY' THEN
  --
  -- Get the current alloy
  --
    OPEN current_alloy;
    FETCH current_alloy INTO lv_current_alloy;
 
    vcErrorLoc := '0010';

    IF current_alloy%NOTFOUND
    THEN     
        NULL;            -- 1st time process order enetered
        CLOSE current_alloy;
    ELSE
        CLOSE current_alloy;
        
        vcErrorLoc := '0020';

        -- Check for any other sales order items material allocated to
        -- and ensure that they are of the same alloy
        FOR other_order_alloys_rec IN other_order_alloys LOOP
            IF other_order_alloys_rec.alloy_code != lv_current_alloy THEN
              p_table_outcomes(i).status  := 'W';
              p_table_outcomes(i).message := 'Warning';
              i := i + 1;            
            END IF;
        END LOOP;
    END IF;

  vcErrorLoc := '0030';
  
  WHEN 'LIMITS' THEN
  --
  -- If this batch is already allocated to another spec,
  -- collate the test requirement from the spec we are now allocating to
  -- and if we have a sample for that test previously booked, check it is
  -- within the limits of this new spec.
  -- 
    FOR get_tests_and_limits_row IN get_tests_and_limits LOOP
      IF pk_test_results.ingot_or_product_chemistry(get_tests_and_limits_row.test_code) THEN -- Chemistry
        FOR frPreviousResults IN crPreviousResultsChem(cpBatchNo_in  => p_batch_no_in
                                                      ,cpHeatNo_in   => p_heat_no_in
                                                      ,cpTestType_in => get_tests_and_limits_row.test_type
                                                      ,cpTestCode_in => get_tests_and_limits_row.test_code) LOOP

          lr_load_limits_rec             := NULL;
          lr_sample_result_rec           := NULL;
          lr_sample_result_rec.sample_id := frPreviousResults.sample_id;
          lr_sample_result_rec.test_code := frPreviousResults.test_code;
            
          vcErrorLoc := '0040';
          
          Pk_Test_Result_Rounding.pr_populate_result_recs(p_sample_result_rec => lr_sample_result_rec
                                                         ,p_load_limits_rec => lr_load_limits_rec);
            
          vcErrorLoc := '0050';
          
          lr_load_limits_rec.spec_code_id := p_spec_code_id_in;

          vcErrorLoc := '0060'; 

          -- Need to recheck if it is a multi-spec that it is being reallocated to as the check would have
          -- been done on the original spec id which is wrong for the reallocation.
          Pk_Test_Results.pr_get_multi_spec_info(p_spec_code_id => lr_load_limits_rec.spec_code_id
                                                ,p_multi_spec_code_id => lr_load_limits_rec.multi_spec_code_id
                                                ,p_multi_spec_name => lr_load_limits_rec.multi_spec_name);

          vcErrorLoc := '0070';

          lr_sample_result_rec.ack_result := NULL;
            
          -- The following two lines ensure the limit checking will be done against the current
          -- spec only. This is essentially for UK sites to behave as US sites do.
          lr_load_limits_rec.uk_limit_check := 'N';
          lr_load_limits_rec.check_tight_specs := 'N';
            
          vcErrorLoc := '0080';
          
          Pk_Test_Result_Rounding.pr_check_limits(p_sample_result_rec => lr_sample_result_rec
                                                 ,p_load_limits_rec => lr_load_limits_rec);
            
          vcErrorLoc := '0090';
          
          IF lr_sample_result_rec.pass_limit = 'N' THEN
            -- Failed test. Continue with allocation ?
            
            p_table_outcomes(i).status  := 'F';
            p_table_outcomes(i).message := get_tests_and_limits_row.test_code;
            i := i + 1;            
            
          END IF;
        END LOOP;
        
        vcErrorLoc := '0100';
        
      ELSE--IF p_check_product THEN -- Product
      
        FOR frPreviousResults IN crPreviousResultsProd(cpBatchNo_in  => p_batch_no_in
                                                      ,cpTestType_in => get_tests_and_limits_row.test_type
                                                      ,cpTestCode_in => get_tests_and_limits_row.test_code) LOOP
          vcErrorLoc := '0110';                                                      
          lr_load_limits_rec             := NULL;
          lr_sample_result_rec           := NULL;
          lr_sample_result_rec.sample_id := frPreviousResults.sample_id;
          lr_sample_result_rec.test_code := frPreviousResults.test_code;
            
          vcErrorLoc := '0120';
          
          Pk_Test_Result_Rounding.pr_populate_result_recs(p_sample_result_rec => lr_sample_result_rec
                                                       ,p_load_limits_rec => lr_load_limits_rec);
          vcErrorLoc := '0130';
          
          lr_load_limits_rec.spec_code_id := p_spec_code_id_in;

          -- Need to recheck if it is a multi-spec that it is being reallocated to as the check would have
          -- been done on the original spec id which is wrong for the reallocation.
          Pk_Test_Results.pr_get_multi_spec_info(p_spec_code_id => lr_load_limits_rec.spec_code_id
                                                ,p_multi_spec_code_id => lr_load_limits_rec.multi_spec_code_id
                                                ,p_multi_spec_name => lr_load_limits_rec.multi_spec_name);

          lr_sample_result_rec.ack_result := NULL;
            
          -- The following two lines ensure the limit checking will be done against the current
          -- spec only. This is essentially for UK sites to behave as US sites do.
          lr_load_limits_rec.uk_limit_check := 'N';
          lr_load_limits_rec.check_tight_specs := 'N';
            
          vcErrorLoc := '0140';
          
          Pk_Test_Result_Rounding.pr_check_limits(p_sample_result_rec => lr_sample_result_rec
                                                 ,p_load_limits_rec => lr_load_limits_rec);
            
          IF lr_sample_result_rec.pass_limit = 'N' THEN
            -- Failed test. Continue with allocation ?
            lr_sample_result_rec.pass_limit := 'Y';            
            p_table_outcomes(i).status  := 'F';
            p_table_outcomes(i).message := get_tests_and_limits_row.test_code;
            i := i + 1;            
                        
          END IF;        -- END IF on failed test 
        END LOOP;
      END IF;
    END LOOP;        -- End LOOP for get test requirement from the allocating to spec
  END CASE;
  
  vcErrorLoc := '9999';
  
EXCEPTION
    WHEN OTHERS THEN
      Pk_Error_Log.prRecordDetails(p_SqlCode_in    => SQLCODE
                                  ,p_SqlErrm_in    => SQLERRM
                                  ,p_ModuleName_in => 'Pk_Tech_Edit.pr_batch_allocation_check'  
                                  ,p_KeyData_in    => 'Errorloc = '||vcErrorLoc|| '. Batch = '||p_batch_no_in || ',' ||' Spec = '|| TO_CHAR(p_spec_code_id_in));

END pr_batch_allocation_check;

PROCEDURE pr_copy_approval_header ( p_order_spec_id_in  IN te_spec_code_header.spec_code_id%TYPE
                                  , p_basis_spec_id_in  IN te_spec_code_header.spec_code_id%TYPE
                                  , p_delete_records_in IN BOOLEAN DEFAULT TRUE) IS

/*Procedure to copy the approval header information from the basis spec to the order spec*/               
                                           
CURSOR get_spec_code_apprvl ( p_basis_specid_in IN  te_spec_code_header.spec_code_id%TYPE ) IS
SELECT spec_code_approval_id
      ,timet_grade                              
      ,approved_sizes             
      ,comments                   
      ,melt_variance
      ,sonic_req_yn
FROM  te_spec_code_approval
WHERE spec_code_id = p_basis_specid_in
AND   rec_status   = pk_star_constants.vcActiveRecord;  

     
CURSOR crGetApprovals ( cpnmSpecId_in  IN te_spec_code_approval.spec_code_id%TYPE ) IS
SELECT tech_edit_approval_name, 
       metallurgy_approval_name,
       lab_approval_name, 
       certification_approval_name, 
       us_approval_name,
       ht_approval_name,
       tech_edit_approval_date, 
       metallurgy_approval_date,
       lab_approval_date, 
       certification_approval_date, 
       us_approval_date,
       ht_approval_date
FROM  te_spec_code_approval
WHERE spec_code_id = cpnmSpecId_in
AND   rec_status   = pk_star_constants.vcActiveRecord;

CURSOR crGetSubGradeMeltVar(cptSpecCodeApprovalId_in te_spec_code_approval.spec_code_approval_id%TYPE) IS
SELECT subgrade_id            
       ,melt_variance_comment  
  FROM  TE_SPEC_APP_SUB_GRADES
 WHERE spec_code_approval_id = cptSpecCodeApprovalId_in
   AND rec_status = 'A';
   
tSpecCodeApprovalId te_spec_code_approval.spec_code_approval_id%TYPE;    
recApprovals  crGetApprovals%ROWTYPE;       

BEGIN

  -- Get any existing approvals for the order spec (STCR 6430)
  OPEN  crGetApprovals(cpnmSpecId_in => p_order_spec_id_in);
  FETCH crGetApprovals INTO recApprovals;
  CLOSE crGetApprovals;

  --Delete the record if specified
  IF p_delete_records_in THEN
    DELETE FROM te_spec_code_approval
    WHERE  spec_code_id = TO_CHAR ( p_order_spec_id_in );
  END IF;

--Copy approval header information
  FOR  get_spec_code_apprvl_rec IN get_spec_code_apprvl ( p_basis_specid_in => p_basis_spec_id_in ) LOOP

    INSERT INTO te_spec_code_approval ( spec_code_id
                                      , timet_grade               
                                      , approved_sizes             
                                      , comments
                                      , tech_edit_approval_name                 -- Start STCR 6430
                                      , metallurgy_approval_name            
                                      , lab_approval_name                
                                      , certification_approval_name
                                      , us_approval_name
                                      , ht_approval_name
                                      , tech_edit_approval_date
                                      , metallurgy_approval_date
                                      , lab_approval_date
                                      , certification_approval_date
                                      , us_approval_date                        -- End STCR 6430     
                                      , ht_approval_date              
                                      , melt_variance
                                      , sonic_req_yn  )
                              VALUES ( p_order_spec_id_in
                                     , get_spec_code_apprvl_rec.timet_grade
                                     , get_spec_code_apprvl_rec.approved_sizes
                                     , get_spec_code_apprvl_rec.comments
                                     , recApprovals.tech_edit_approval_name     -- Start STCR 63430
                                     , recApprovals.metallurgy_approval_name
                                     , recApprovals.lab_approval_name
                                     , recApprovals.certification_approval_name
                                     , recApprovals.us_approval_name
                                     , recApprovals.ht_approval_name
                                     , recApprovals.tech_edit_approval_date
                                     , recApprovals.metallurgy_approval_date
                                     , recApprovals.lab_approval_date
                                     , recApprovals.certification_approval_date
                                     , recApprovals.us_approval_date            -- End STCR 6430 
                                     , recApprovals.ht_approval_date
                                     , get_spec_code_apprvl_rec.melt_variance
                                     , get_spec_code_apprvl_rec.sonic_req_yn )
    RETURNING spec_code_approval_id INTO tSpecCodeApprovalId;                                     
  --Now insert the sub grade ids into the sub grade table --STCR 6264
    FOR rcGetSubGradeMeltVar IN crGetSubGradeMeltVar(cptSpecCodeApprovalId_in =>  get_spec_code_apprvl_rec.spec_code_approval_id) LOOP
        INSERT INTO te_spec_app_sub_grades(SPEC_CODE_APPROVAL_ID
                                           ,SUBGRADE_ID
                                           ,MELT_VARIANCE_COMMENT)
                                    VALUES( tSpecCodeApprovalId
                                            ,rcGetSubGradeMeltVar.subgrade_id
                                            ,rcGetSubGradeMeltVar.melt_variance_comment);
    END LOOP;                           
  END LOOP;
EXCEPTION
  
  WHEN OTHERS THEN
    pk_error_log.prRecordDetails ( p_SqlCode_in    => SQLCODE
                                 , p_SqlErrm_in    => SQLERRM
                                 , p_ModuleName_in => 'pk_tech_edit.pr_copy_approval_header'  
                                 , p_KeyData_in    => TO_CHAR ( p_order_spec_id_in ) || ',' || TO_CHAR ( p_basis_spec_id_in ) );
                                 
END pr_copy_approval_header;


FUNCTION fn_sales_order_va ( p_r3_sales_order_in      IN r3_sales_order_items.r3_sales_order%TYPE
                           , p_r3_sales_order_item_in IN r3_sales_order_items.r3_sales_order_item%TYPE
                           , p_spec_code_id_in        IN te_spec_code_header.spec_code_id%TYPE                 ) RETURN VARCHAR2 IS
                           
lv_batch_count NUMBER  := 0;
lv_sample_count NUMBER := 0;
  
  CURSOR batch_check( p_r3_sales_order_in IN R3_SALES_ORDER_ITEMS.r3_sales_order%TYPE
                    , p_r3_sales_order_item_in IN R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                    , p_spec_code_id_in IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                    ) IS
  SELECT COUNT( batch_number ), NVL( SUM( sample_cnt ), 0 )
  FROM
  ( SELECT DISTINCT( r3_process_order ) batch_number, COUNT( sample_id ) sample_cnt
    FROM   r3_sales_order_items soi
         , r3_process_orders po
         , te_test_sample_id tsi
    WHERE  po.r3_sales_order = p_r3_sales_order_in
    AND    po.r3_sales_order_item = p_r3_sales_order_item_in
    AND    po.process_order_status != 'E'
    AND    soi.r3_sales_order = po.r3_sales_order
    AND    soi.r3_sales_order_item = po.r3_sales_order_item
    AND    soi.spec_code_id = p_spec_code_id_in
    AND    po.r3_process_order = tsi.process_order_no(+)
    AND    tsi.spec_code_id(+) = p_spec_code_id_in
    GROUP BY r3_process_order
  );
  
BEGIN
  OPEN batch_check( p_r3_sales_order_in => p_r3_sales_order_in
                  , p_r3_sales_order_item_in => p_r3_sales_order_item_in
                  , p_spec_code_id_in => p_spec_code_id_in
                  );
  FETCH batch_check INTO lv_batch_count, lv_sample_count;
  CLOSE batch_check;
  
  IF lv_sample_count > 0 THEN
    RETURN 'VA_GREEN_RECORD';
  ELSIF lv_batch_count > 0 THEN
    RETURN 'VA_AMBER_RECORD';
  ELSE
    RETURN 'VA_NORMAL_RECORD';
  END IF;
END fn_sales_order_va;


FUNCTION fn_flag_batch_fr_ord_pattern( p_batch_number_in IN R3_PROCESS_ORDERS.r3_batch_number%TYPE ) RETURN BOOLEAN IS
  
  lv_count NUMBER;
  
  CURSOR get_ns_control_flag( p_batch_number_in IN R3_PROCESS_ORDERS.r3_batch_number%TYPE ) IS
  SELECT COUNT(*)
  FROM   r3_sales_order_items soi
       , lab_tests_view ltv
       , st_order_patterns op
  WHERE  soi.r3_sales_order = ltv.sales_order
  AND    soi.r3_sales_order_item = ltv.sales_order_item
  AND    ltv.batch_number = p_batch_number_in
  AND    soi.order_pattern_id = op.order_pattern_id
  AND    op.ns_control_yn = 'Y';
  
BEGIN
  OPEN get_ns_control_flag( p_batch_number_in => p_batch_number_in );
  FETCH get_ns_control_flag INTO lv_count;
  CLOSE get_ns_control_flag;
  
  IF lv_count > 0 THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END fn_flag_batch_fr_ord_pattern;


PROCEDURE pr_r3_soi_post_query( p_spec_code_id_in IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE
                              , p_order_pattern_id_in IN ST_ORDER_PATTERNS.order_pattern_id%TYPE
                              , p_spec_code_name_out OUT TE_SPEC_CODE_HEADER.spec_code_name%TYPE
                              , p_order_pattern_ref_out OUT ST_ORDER_PATTERNS.order_pattern_ref%TYPE
                              ) IS
  
  CURSOR get_spec_code_name( p_spec_code_id_in IN TE_SPEC_CODE_HEADER.spec_code_id%TYPE ) IS
  SELECT spec_code_name
  FROM   te_spec_code_header
  WHERE  spec_code_id = p_spec_code_id_in;
  
  CURSOR get_order_pattern_ref( p_order_pattern_id_in IN ST_ORDER_PATTERNS.order_pattern_id%TYPE ) IS
  SELECT order_pattern_ref
  FROM   st_order_patterns
  WHERE  order_pattern_id = p_order_pattern_id_in;
  
BEGIN
  OPEN get_spec_code_name ( p_spec_code_id_in => p_spec_code_id_in );
  FETCH get_spec_code_name INTO p_spec_code_name_out;
  
  IF get_spec_code_name%NOTFOUND THEN
    p_spec_code_name_out := '<NONE>';
  END IF;
  
  CLOSE get_spec_code_name;
  
  OPEN get_order_pattern_ref( p_order_pattern_id_in => p_order_pattern_id_in );
  FETCH get_order_pattern_ref INTO p_order_pattern_ref_out;
  CLOSE get_order_pattern_ref;

END pr_r3_soi_post_query;

/*---------------------------------------------------------------------------------------------
||
|| Function to return the shape type against the incoming spec ID
||
*/---------------------------------------------------------------------------------------------
FUNCTION fnGetShapeType(pnmSpecId_in      IN te_spec_code_header.spec_code_id%TYPE)
RETURN VARCHAR2 IS
--
-- Data declarations
--
vcShapeType          te_spec_code_header.shape_type%TYPE;

vcKeyData               st_error_log.key_data%TYPE;

-- Constant to hold procedure/function name for error logging
cnModuleName        CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.fnGetShapeType';


--
-- Execution section
--
BEGIN  
--
-- Get the shape type
--
    SELECT   shape_type
    INTO        vcShapeType
    FROM      te_spec_code_header
    WHERE   spec_code_id = pnmSpecId_in;
    
    RETURN  (vcShapeType);

--
-- Exceptions
--
EXCEPTION

    WHEN NO_DATA_FOUND
    THEN
        vcKeyData := 'Spec ID ['||TO_CHAR(pnmSpecId_in)||']';
        pk_error_log.prRecordDetailsHalt (p_SqlCode_in   =>  SQLCODE,
                                                          p_SqlErrm_in     =>  SUBSTR(SQLERRM, 1, 200),
                                                          p_ModuleName_in    => cnModuleName,        
                                                          p_KeyData_in        => vcKeyData);
                                                          
        RETURN ('*****');       
      
--      
    WHEN OTHERS
    THEN
        vcKeyData := 'Spec ID ['||TO_CHAR(pnmSpecId_in)||']';
        pk_error_log.prRecordDetailsHalt (p_SqlCode_in   =>  SQLCODE,
                                                          p_SqlErrm_in     =>  SUBSTR(SQLERRM, 1, 200),
                                                          p_ModuleName_in    => cnModuleName,        
                                                          p_KeyData_in        => vcKeyData);
                                                          
        RETURN ('*****');                                                            
 
--
-- Exit fnGetShapeType
--
END fnGetShapeType;

/*---------------------------------------------------------------------------------------------
||
|| Procedure to update ingot_diam_inches column on te_spec_code_header with
|| the incoming figure
||
*/---------------------------------------------------------------------------------------------
PROCEDURE prUpdateIngotDiam(pnmSpecId_in IN te_spec_code_header.spec_code_id%TYPE
                                               ,pnmIngotDiam_in  IN Te_spec_code_header.ingot_diam_inches%TYPE)
IS
--
-- Declarative section
--
vcKeyData               st_error_log.key_data%TYPE;

-- Constant to hold procedure/function name for error logging
cnModuleName        CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.fnGetShapeType';

--
-- Execution section
--
BEGIN

    UPDATE te_spec_code_header
    SET ingot_diam_inches = pnmIngotDiam_in
    WHERE spec_code_id = pnmSpecId_in;

--
-- Exceptions
--
EXCEPTION

    WHEN NO_DATA_FOUND
    THEN
        vcKeyData := 'Spec ID ['||TO_CHAR(pnmSpecId_in)||']';
        pk_error_log.prRecordDetailsHalt (p_SqlCode_in   =>  SQLCODE,
                                                          p_SqlErrm_in     =>  SUBSTR(SQLERRM, 1, 200),
                                                          p_ModuleName_in    => cnModuleName,        
                                                          p_KeyData_in        => vcKeyData);
--      
    WHEN OTHERS
    THEN
        vcKeyData := 'Spec ID ['||TO_CHAR(pnmSpecId_in)||']';
        pk_error_log.prRecordDetailsHalt (p_SqlCode_in   =>  SQLCODE,
                                                          p_SqlErrm_in     =>  SUBSTR(SQLERRM, 1, 200),
                                                          p_ModuleName_in    => cnModuleName,        
                                                          p_KeyData_in        => vcKeyData);
                                                          
--
-- Exit  prUpdateIngotDiam
--
END  prUpdateIngotDiam;


/*---------------------------------------------------------------------------------------------
||
|| Procedure to get the shape type and site ownership for the given spec ID
||
*/---------------------------------------------------------------------------------------------
PROCEDURE prGetShapeAndSite (pnmSpecCodeId_in   IN            te_spec_code_header.spec_code_id%TYPE
                                                 ,pvcShapeType_out   OUT         te_spec_code_header.shape_type%TYPE
                                                 ,pvcOwningSite_out   OUT         te_spec_code_header.site%TYPE)
IS
--
-- Declarative section
--
vcKeyData               st_error_log.key_data%TYPE;

-- Constant to hold procedure/function name for error logging
cnModuleName        CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.fnGetShapeAndSite';

--
-- Cursors
--
CURSOR crGetShapeAndSite (cpnmSpecId_in  te_spec_code_header.spec_code_id%TYPE)
 IS
 SELECT shape_type, site
 FROM te_spec_code_header
 WHERE spec_code_id = cpnmSpecId_in;
 
rcShapeAndSite  crGetShapeAndSite%ROWTYPE;

-- Exceptions
exSpecNotFound      EXCEPTION;

--
-- Execution section
--
BEGIN
--
-- Get shape and site for the given spec
--
    OPEN crGetShapeAndSite (cpnmSpecId_in => pnmSpecCodeId_in);
    FETCH crGetShapeAndSite INTO rcShapeAndSite ;
    
    -- Found ?
    IF crGetShapeAndSite%NOTFOUND
    THEN
        RAISE   exSpecNotFound;
    END IF;
    
    -- Found. Close the cursor and return the data
    CLOSE crGetShapeAndSite;
    
    pvcShapeType_out := rcShapeAndSite.shape_type;
    pvcOwningSite_out := rcShapeAndSite.site;

--
-- Exceptions
--
EXCEPTION

-- Spec not found
WHEN exSpecNotFound
THEN
    -- Ensure cursor is closed
    CLOSE crGetShapeAndSite;
        
    -- Write error to log and return '**' to from to process
    vcKeyData := 'Unable to find Spec ID ['||TO_CHAR(pnmSpecCodeId_in)||']';
    pk_error_log.prRecordDetailS(p_SqlCode_in   =>  SQLCODE,
                                              p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                              p_ModuleName_in => cnModuleName,        
                                              p_KeyData_in   => vcKeyData); 
        
    pvcShapeType_out := '**';                                         
                       
 -- OTHERS
 WHEN OTHERS                                                
  THEN
    -- Ensure cursor is closed
    IF crGetShapeAndSite%ISOPEN 
    THEN
        -- Close it
        CLOSE crGetShapeAndSite;
    END IF;
    
    -- Write error to log and return '**' to from to process
    vcKeyData := 'Unable to find Spec ID ['||TO_CHAR(pnmSpecCodeId_in)||']';
    pk_error_log.prRecordDetails(p_SqlCode_in   =>  SQLCODE,
                                              p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                              p_ModuleName_in => cnModuleName,        
                                               p_KeyData_in   => vcKeyData); 
        
    pvcShapeType_out := '**'; 

END prGetShapeAndSite;
                                                  

FUNCTION fnIsLimitOnSpec(pnmSpecCodeId_in IN te_spec_code_limits.spec_code_id%TYPE
                        ,pvcTestType_in   IN te_spec_code_limits.test_type%TYPE
                        ,pvcTestCode_in   IN te_spec_code_limits.test_code%TYPE) RETURN BOOLEAN IS

  CURSOR crGetSpecLimit(cpnmSpecCodeId_in IN te_spec_code_limits.spec_code_id%TYPE
                       ,cpvcTestType_in   IN te_spec_code_limits.test_type%TYPE
                       ,cpvcTestCode_in   IN te_spec_code_limits.test_code%TYPE) IS
    SELECT limit_ref
      FROM te_spec_code_limits
     WHERE spec_code_id = cpnmSpecCodeId_in
       AND test_type = cpvcTestType_in
       AND test_code = cpvcTestCode_in;
 
  nmLimitRef te_spec_code_limits.limit_ref%TYPE;

BEGIN
  OPEN crGetSpecLimit(cpnmSpecCodeId_in => pnmSpecCodeId_in
                     ,cpvcTestType_in   => pvcTestType_in
                     ,cpvcTestCode_in   => pvcTestCode_in);
  FETCH crGetSpecLimit INTO nmLimitRef;
  CLOSE crGetSpecLimit;
  
  IF nmLimitRef IS NULL THEN
    RETURN FALSE;
  ELSE
    RETURN TRUE;
  END IF;
    
END fnIsLimitOnSpec;


PROCEDURE prGetTestCodeTypeGroup(pnmTestCodeTypeGroupId_in IN  te_test_code_type_groups.test_code_type_group_id%TYPE,
                                 prcTestCodeTypeGroup_out  OUT rtTestCodeTypeGroup) IS

  vcKeyData         st_error_log.key_data%TYPE := pnmTestCodeTypeGroupId_in;

  -- Constant to hold procedure name for error logging
  cModuleName       CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.prGetTestCodeTypeGroup';


  CURSOR crGetTestCodeTypeGroup(cpnmTestCodeTypeGroupId_in IN te_test_code_type_groups.test_code_type_group_id%TYPE) IS
    SELECT test_code
      FROM te_test_code_type_groups
     WHERE test_code_type_group_id = cpnmTestCodeTypeGroupId_in;

BEGIN
  OPEN crGetTestCodeTypeGroup(cpnmTestCodeTypeGroupId_in => pnmTestCodeTypeGroupId_in);
  FETCH crGetTestCodeTypeGroup INTO prcTestCodeTypeGroup_out;
  CLOSE crGetTestCodeTypeGroup;
EXCEPTION
  WHEN OTHERS THEN
    -- Record error details and RAISE exception
    pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleNAme_in =>  cModuleName,
                                p_KeyData_in    =>  vcKeyData);
  RAISE;
END prGetTestCodeTypeGroup;


PROCEDURE prGetLimitProfileTestCodes (pnmLimitProfileId_in         IN  te_limit_profile_test_codes.limit_profile_id%TYPE,
                                      pclLimitProfileTestCodes_out OUT ctLimitProfileTestCodes) IS

  CURSOR crLimitProfileTestCodes(cpnmLimitProfileId_in IN te_limit_profile_test_codes.limit_profile_id%TYPE) IS
    SELECT test_code_type_group_id
      FROM te_limit_profile_test_codes
     WHERE limit_profile_id = cpnmLimitProfileId_in
  ORDER BY limit_profile_test_code_id;
  
  clLimitProfileTestCodes ctLimitProfileTestCodes;
  nmLoopCount             NUMBER := 1;

BEGIN
  FOR frLimitProfileTestCodes IN crLimitProfileTestCodes(cpnmLimitProfileId_in => pnmLimitProfileId_in) LOOP
    clLimitProfileTestCodes(nmLoopCount).nmTestCodeTypeGroupId := frLimitProfileTestCodes.test_code_type_group_id;
    nmLoopCount := nmLoopcount + 1;
  END LOOP;
  pclLimitProfileTestCodes_out := clLimitProfileTestCodes;
END prGetLimitProfileTestCodes;


PROCEDURE prGetTestCode (pvcTestCode_in  IN  te_test_codes.test_code%TYPE,
                         prcTestCode_out OUT rtTestCode) IS

  vcKeyData         st_error_log.key_data%TYPE := pvcTestCode_in;

  -- Constant to hold procedure name for error logging
  cModuleName       CONSTANT st_error_log.module_name%TYPE DEFAULT 'pk_tech_edit.prGetTestCode';


  CURSOR crGetTestCode(cpvcTestCode_in IN te_test_codes.test_code%TYPE) IS
    SELECT min_value_uom
           -- STCR 6169 ,max_value_uom
      FROM te_test_codes
     WHERE test_code = cpvcTestCode_in;

BEGIN
  OPEN crGetTestCode(cpvcTestCode_in => pvcTestCode_in);
  FETCH crGetTestCode INTO prcTestCode_out;
  CLOSE crGetTestCode;
EXCEPTION
  WHEN OTHERS THEN
    -- Record error details and RAISE exception
    pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleNAme_in =>  cModuleName,
                                p_KeyData_in    =>  vcKeyData);

    RAISE;
END prGetTestCode;


FUNCTION fnIsOrderLinked( pvcSalesOrder_in IN R3_SALES_ORDER_ITEMS.r3_sales_order%TYPE
                        , pvcSalesOrderItem_in IN R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                        ) RETURN NUMBER IS
  
  vcIsLinkedYN VARCHAR2( 1 ) := 'N';
  
    CURSOR crIsOrderLinked( cpSalesOrder_in IN R3_SALES_ORDER_ITEMS.r3_sales_order%TYPE
                          , cpSalesOrderItem_in IN R3_SALES_ORDER_ITEMS.r3_sales_order_item%TYPE
                          ) IS
  SELECT 'Y'
  FROM   r3_sales_order_items
  WHERE  r3_sales_order = cpSalesOrder_in
  AND    r3_sales_order_item = cpSalesOrderItem_in
  AND    spec_code_id IS NOT NULL;

BEGIN
    OPEN crIsOrderLinked( cpSalesOrder_in => pvcSalesOrder_in
                        , cpSalesOrderItem_in => pvcSalesOrderItem_in
                        );
    FETCH    crIsOrderLinked INTO vcIsLinkedYN;
  CLOSE crIsOrderLinked;
  
  IF vcIsLinkedYN = 'Y' THEN
    RETURN 0;
  ELSE
    RETURN 1165;
  END IF;
END fnIsOrderLinked;

/*--------------------------------------------------------------------------------------------
||
|| Fumction to return fanblade type for the given ID
||
*/--------------------------------------------------------------------------------------------
FUNCTION fnGetFanbladeType (pnFanbladeTypeId_in    IN       te_fanblade_types.fanblade_type_id%TYPE)
   RETURN VARCHAR2
IS
--
-- Local variables
--
vcFanbladeType      te_fanblade_types.fanblade_type%TYPE;

--
-- Execution section
--
BEGIN
--
-- Lookup the danblade type for the given ID
--
    SELECT fanblade_type
    INTO    vcFanbladeType
    FROM    te_fanblade_types
    WHERE   fanblade_type_id = pnFanbladeTypeId_in;

    RETURN(vcFanbladeType);
    
--
-- EXCEPTIONS
--
EXCEPTION
    -- Not found
    WHEN NO_DATA_FOUND
    THEN
        -- Log and report (1)
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleName_in =>  'pk_tech_edit.fnGetFanbladeType',
                                p_KeyData_in    => 'NO_DATA_FOUND reading for fanblade type ID ['||TO_CHAR(pnFanbladeTypeId_in)||']');        
        
    -- Unexpected exception
    WHEN OTHERS
    THEN
       -- Trap details and return
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleName_in =>  'pk_tech_edit.fnGetFanbladeType',
                                p_KeyData_in    =>  'WHEN OTHERS reading for fanblade type ID ['||TO_CHAR(pnFanbladeTypeId_in)||']');
   
-- End fnGetFanbladeType
END fnGetFanbladeType;

/*--------------------------------------------------------------------------------------------
||
|| Function to check that the fanbalde types of two given specifications are the same
||
|| If a fanblade type is assigned to BOTH specs the they need to match. If assigned
|| to only one then cross allocation is allowed.
||
*/--------------------------------------------------------------------------------------------
FUNCTION fnSameFanbladeTypes (pnFromSpecCodeId_in   IN   te_spec_code_header.spec_code_id%TYPE
                                                  ,pnToSpecCodeId_in   IN   te_spec_code_header.spec_code_id%TYPE)
  RETURN BOOLEAN
IS  
--
-- Local variables
vcFromTypeId      te_fanblade_types.fanblade_type_id%TYPE;
vcToTypeId          te_fanblade_types.fanblade_type_id%TYPE;

nSpecCodeID         te_spec_code_header.spec_code_id%TYPE;

--
-- Cursors
CURSOR crGetFanblade (cpSpecId_in   IN   te_spec_code_header.spec_code_id%TYPE)
IS
    SELECT  fanblade_type_id
    FROM    te_spec_code_header
    WHERE   spec_code_id = cpSpecId_in;
    
--
-- Exceptions
exNoSpec            EXCEPTION;

--
-- Execution section
--
BEGIN
--
-- Initailaise both the TO and from ID variables
    vcFromTypeId := NULL;
    vcToTypeId := NULL;
    
--
-- Get the FROM ID
    OPEN crGetFanblade (pnFromSpecCodeId_in);
    FETCH crGetFanblade INTO vcFromTypeId;
    IF crGetFanblade%NOTFOUND
    THEN
        -- Couldn't find spec header 
        CLOSE crGetFanblade;
        nSpecCodeId := pnFromSpecCodeId_in;
        RAISE exNoSpec;    
    ELSE
        CLOSE crGetFanblade;
    END IF;
    
--
-- Get the TO ID
    OPEN crGetFanblade (pnToSpecCodeId_in);
    FETCH crGetFanblade INTO vcToTypeId;
    IF crGetFanblade%NOTFOUND
    THEN
        -- Couldn't find spec header 
        CLOSE crGetFanblade;
        nSpecCodeId := pnToSpecCodeId_in;        
        RAISE exNoSpec;    
    ELSE
        CLOSE crGetFanblade;
    END IF;
    
--
-- Now check the two fan blade ID types for compatability
    IF vcFromTypeId IS NOT NULL
        AND vcToTypeId IS NOT NULL
   THEN
        -- Both specs have a fanblade assigned so ensure they are the same
        IF vcFromTypeId != vcToTypeId
        THEN
            -- Incompatible fan blade types
            RETURN(FALSE);
        ELSE
            -- Both the same
            RETURN(TRUE);
        END IF;
    ELSE
        -- At least one of the spec does not have a fanblade defined so allocation can go ahead
        RETURN(TRUE);
    END IF;     

--
-- EXCEPTIONS
--
EXCEPTION
    WHEN    exNoSpec
    THEN
        -- Handle and report (1)
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleName_in =>  'pk_tech_edit.fnSameFanbladeTypes',
                                p_KeyData_in    => 'exNoSpec: Spec ID ['||TO_CHAR(nSpecCodeId)||']');      
        
    -- Unexpected exception
    WHEN OTHERS
    THEN
       -- Trap details and return
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                p_ModuleName_in =>  'pk_tech_edit.fnSameFanbladeTypes',
                                p_KeyData_in    =>  'WHEN OTHERS checking for same fanblade types. To Spec ['||TO_CHAR(pnToSpecCodeId_in)||
                                                                ']  From Spec ['||TO_CHAR(pnFromSpecCodeId_in)||']');       
    
 -- End fnSameFanbladeTypes
END fnSameFanbladeTypes;
  
/*--------------------------------------------------------------------------------------------
||
|| Function to determine if the fanbalde types for previous allocations of this
|| material  are the same as that being allocated to
||
*/--------------------------------------------------------------------------------------------
FUNCTION fnPrevFanbladeTypesOk ( pnFanbladeTypeId_in   IN   te_fanblade_types.fanblade_type_id%TYPE
                                                    ,pnBatchFirstEight_in   IN  VARCHAR2)
  RETURN BOOLEAN
IS
--
-- Local variables
vcBatchSearchString     VARCHAR2(9);    -- Incoming batch first 8 concatoneted with '%'

--
-- Cursors
CURSOR crPrevAllocations (cpBatchno_in   IN      VARCHAR2)
IS
    SELECT sch.fanblade_type_id
    FROM    te_spec_code_header sch,
                r3_sales_order_items soi,
                r3_process_orders po
    WHERE    po.r3_process_order LIKE (cpBatchNo_in)
    AND         soi.r3_sales_order = po.r3_sales_order
    AND         soi.r3_sales_order_item = po.r3_sales_order_item
    AND         sch.spec_code_id = soi.spec_code_id;            

--
-- Exceptions
exFanbladeMismatch      EXCEPTION;

--
-- Execution section
--
BEGIN
--
--  Build the batch no search string
    vcBatchSearchString := pnBatchFirstEight_in||'%';

--
-- Read for previous allocations
    FOR    crPrevAllocations_row IN crPrevAllocations (vcBatchSearchString)
    LOOP
        -- Check that the fanblade type is the same if assigned
        IF crPrevAllocations_row.fanblade_type_id IS NOT NULL
        THEN
            -- Ensure fanblade types are the same
            IF crPrevAllocations_row.fanblade_type_id !=  pnFanbladeTypeId_in
            THEN
                -- Different !
                RAISE exFanbladeMismatch;
            END IF;
        END IF;
    
    END LOOP;
     
     -- Previous types are compatable
     RETURN(TRUE);
     
--
-- EXCEPTIONS
--
EXCEPTION
--
-- Fanblade mismatch
    WHEN    exFanbladeMismatch
    THEN
        RETURN(FALSE);
        
    WHEN OTHERS
    THEN
        -- Report and handle (1) the error
        NULL;     
         
-- End fnPrevFanbladeTypesOk
END fnPrevFanbladeTypesOk;    

/*--------------------------------------------------------------------------------------------
||
|| Function to return the asigned fanblade type for the given order spec ID
||
*/--------------------------------------------------------------------------------------------
FUNCTION fnGetAssignedFanblade (pnSpecCodeId_in     IN      te_spec_code_header.spec_code_id%TYPE)
    RETURN NUMBER
IS
--
-- Local variables
nFanbladeTypeId         te_spec_code_header.fanblade_type_id%TYPE;

--
-- Execution logic
--
BEGIN
    SELECT  fanblade_type_id
    INTO      nFanbladeTypeId
    FROM    te_spec_code_header
    WHERE   spec_code_id = pnSpecCodeId_in;
    
    RETURN(nFanbladeTypeId);
    
--
-- Exceptions
--
EXCEPTION

    WHEN NO_DATA_FOUND
    THEN
        -- Report and handle (1)
        RETURN(NULL);
        
    WHEN OTHERS
    THEN
        -- Report and handle (1)
        RETURN(NULL);

-- End fnGetAssignedFanblade
END fnGetAssignedFanblade;           


FUNCTION fnUpdateStatements( pnStatementId_in IN TE_COMPLIANCE_STATEMENTS.comp_id%TYPE
                           , pvcCopyType_in IN VARCHAR2
                           , pvcNewStatementDesc_in IN TE_COMPLIANCE_STATEMENTS.description%TYPE
                           ) RETURN NUMBER IS
BEGIN
  CASE pvcCopyType_in
    WHEN 'CO' THEN
      UPDATE te_comp_statements_txt
      SET    text = pvcNewStatementDesc_in
      WHERE  spec_code_id IN ( SELECT spec_code_id
                               FROM   gtt_upd_spec_statements
                             )
      AND    rec_status = 'A'
      AND    comp_id = pnStatementId_in;
    WHEN 'CH' THEN
      UPDATE te_chem_statements_txt
      SET    text = pvcNewStatementDesc_in
      WHERE  spec_code_id IN ( SELECT spec_code_id
                               FROM   gtt_upd_spec_statements
                             )
      AND    rec_status = 'A'
      AND    chem_id = pnStatementId_in;
    WHEN 'RE' THEN
      UPDATE te_rel_statements_txt
      SET    text = pvcNewStatementDesc_in
      WHERE  spec_code_id IN ( SELECT spec_code_id
                               FROM   gtt_upd_spec_statements
                             )
      AND    rec_status = 'A'
      AND    rel_id = pnStatementId_in;
    WHEN 'MT' THEN
      UPDATE te_metl_statements_txt
      SET    text = pvcNewStatementDesc_in
      WHERE  spec_code_id IN ( SELECT spec_code_id
                               FROM   gtt_upd_spec_statements
                             )
      AND    rec_status = 'A'
      AND    metl_id = pnStatementId_in;
    WHEN 'MC' THEN
      UPDATE te_mech_statements_txt
      SET    text = pvcNewStatementDesc_in
      WHERE  spec_code_id IN ( SELECT spec_code_id
                               FROM   gtt_upd_spec_statements
                             )
      AND    rec_status = 'A'
      AND    mech_id = pnStatementId_in;
    ELSE
      RETURN 0;
  END CASE;
  
  RETURN SQL%ROWCOUNT;

  EXCEPTION
    WHEN OTHERS THEN
      Pk_Error_Log.prRecordDetails(p_SqlCode_in => SQLCODE
                                  ,p_SqlErrm_in => SQLERRM
                                  ,p_ModuleName_in => 'Pk_Tech_Edit.fnUpdateStatements'  
                                  ,p_KeyData_in => TO_CHAR( pnStatementId_in ) || ',' || pvcCopyType_in
                                  );
END fnUpdateStatements;


/*--------------------------------------------------------------------------------------------
||
|| Procedure to copy an material characteristics
||
*/--------------------------------------------------------------------------------------------                           
PROCEDURE prCopyMatlChars(pnFromSpecId_in    IN    te_spec_code_header.spec_code_id%TYPE
                                              ,pnToSpecId_in   IN     te_spec_code_header.spec_code_id%TYPE)
IS
--
-- Local declarations
--
CURSOR crGetMatlChars(cpnSpecId IN  te_spec_code_header.spec_code_id%TYPE)
    IS
        SELECT matl_char_id, uom_ref
                         ,min_limit, max_limit
        FROM    te_spec_matl_chars
        WHERE   spec_code_id = cpnSpecId
        AND         rec_status = pk_star_constants.vcActiveRecord;
--
-- Execution Section
BEGIN
        FOR     crGetMatlChars_row IN crGetMatlChars(pnFromSpecId_in)
    LOOP
        -- Insert the row against the new destination spec 
        INSERT INTO te_spec_matl_chars
            (spec_code_id
            ,matl_char_id
            ,uom_ref
            ,min_limit
            ,max_limit
            )           -- Other NOT NULL values assigned in BI trigger
        VALUES
            (pnToSpecId_in 
            ,crGetMatlChars_row.matl_char_id
            ,crGetMatlChars_row.uom_ref
            ,crGetMatlChars_row.min_limit
            ,crGetMatlChars_row.max_limit
            );
    END LOOP;
    
--
-- END prCopyMatlChars
END prCopyMatlChars;                              

-- STCR 6942 
FUNCTION fnGetCustomerAddress ( pvcSalesOrder_in   IN     r3_sales_orders.r3_sales_order%TYPE
                              , pvcCustType_in     IN     VARCHAR2
                              , pvcCustCountry_out    OUT VARCHAR2
                              , pvcCustStreet_out     OUT VARCHAR2
                              , pvcCustCity_out       OUT VARCHAR2
                              , pvcCustRegion_out     OUT VARCHAR2
                              , pvcCustPostCode_out   OUT VARCHAR2
                              , pvcCustName_out       OUT VARCHAR2
                              , pvcCustName2_out      OUT VARCHAR2
                              , pvcCustName3_out      OUT VARCHAR2 ) RETURN BOOLEAN IS

CURSOR crGetAddress ( cpvcsalesorder_in IN r3_sales_orders.r3_sales_order%TYPE
                    , cpvcCustType_in   IN VARCHAR2                                 ) IS
    SELECT TRIM ( kn.name1 ) NAME
          ,TRIM ( kn.name2 ) NAME2
          ,TRIM ( kn.name3 ) NAME2
          ,TRIM ( kn.stras ) street 
          ,TRIM ( kn.ort01 ) city
          ,TRIM ( kn.regio ) region
          ,TRIM ( kn.pstlz ) postcode
          ,TRIM ( kn.land1 ) country
    FROM   r3_kna1         kn
         , r3_sales_orders so
    WHERE  kn.mandt          = '010'
    AND    kn.kunnr          = DECODE ( cpvcCustType_in, 'SHIP', so.sap_customer_ref, so.sap_sold_to_ref )
    AND    so.r3_sales_order = cpvcSalesOrder_in;

BEGIN
  
  OPEN crGetAddress ( cpvcSalesOrder_in => pvcSalesOrder_in 
                    , cpvcCustType_in   => pvcCustType_in   );
                    
  FETCH crGetAddress INTO pvcCustName_out
                        , pvcCustName2_out
                        , pvcCustName3_out
                        , pvcCustStreet_out
                        , pvcCustCity_out
                        , pvcCustRegion_out
                        , pvcCustPostCode_out
                        , pvcCustCountry_out;
                         
  IF crGetAddress%NOTFOUND THEN
  
    CLOSE crGetAddress;
    RETURN FALSE;
    
  ELSE
  
    CLOSE crGetAddress;
    RETURN TRUE;
    
  END IF;
   
EXCEPTION

  WHEN OTHERS THEN

     pk_error_log.prRecordDetailsHalt ( p_SqlCode_in    => SQLCODE
                                      , p_SqlErrm_in    => SUBSTR( SQLERRM, 1, 100 )
                                      , p_ModuleName_in => 'pk_tech_edit.fnGetCustomerAddress' 
                                      , p_KeyData_in    => 'pvcSalesOrder_in: ' || TO_CHAR( pvcSalesOrder_in ) ||
                                                           ',pvcCustType_in: '  || TO_CHAR ( pvcCustType_in ) );  

END fnGetCustomerAddress;

FUNCTION fnRefreshShipToAddress ( pvcsalesorder_in IN r3_sales_orders.r3_sales_order%TYPE ) RETURN BOOLEAN IS

   vcStreet       r3_sales_orders.ship_to_street%TYPE;
   vcCity         r3_sales_orders.ship_to_city%TYPE;
   vcRegion       r3_sales_orders.ship_to_region%TYPE;
   vcPostCode     r3_sales_orders.ship_to_post_code%TYPE;
   vcName         r3_sales_orders.ship_to_name%TYPE;
   vcName2        r3_sales_orders.ship_to_name%TYPE;
   vcName3        r3_sales_orders.ship_to_name%TYPE;
   vcCountry      r3_sales_orders.ship_to_country%TYPE;
   blAddressFound BOOLEAN;

BEGIN

  blAddressFound := pk_tech_edit.fnGetCustomerAddress ( pvcSalesOrder_in    => pvcSalesOrder_in
                                                       ,pvcCustType_in      => 'SHIP'
                                                       ,pvcCustCountry_out  => vcCountry
                                                       ,pvcCustStreet_out   => vcStreet
                                                       ,pvcCustCity_out     => vcCity
                                                       ,pvcCustRegion_out   => vcRegion
                                                       ,pvcCustPostCode_out => vcPostCode
                                                       ,pvcCustName_out     => vcName
                                                       ,pvcCustName2_out    => vcName2
                                                       ,pvcCustName3_out    => vcName3 );
                          
  IF blAddressFound THEN
  
    UPDATE r3_sales_orders
      SET ship_to_country      = vcCountry
         ,ship_to_street       = vcStreet
         ,ship_to_city         = vcCity
         ,ship_to_region       = vcRegion
         ,ship_to_post_code    = vcPostCode
         ,ship_to_name         = vcName
         ,ship_to_name2        = vcName2
         ,ship_to_name3        = vcName3
         ,date_ship_to_fetched = SYSDATE
      WHERE r3_sales_order = pvcSalesOrder_in;

      RETURN TRUE;
      
  ELSE
    
      RETURN FALSE;
    
  END IF;

EXCEPTION

  WHEN OTHERS THEN

     pk_error_log.prRecordDetailsHalt ( p_SqlCode_in    => SQLCODE
                                      , p_SqlErrm_in    => SUBSTR( SQLERRM, 1, 100 )
                                      , p_ModuleName_in => 'pk_tech_edit.fnRefreshShipToAddress' 
                                      , p_KeyData_in    => 'pvcsalesorder_in: ' || TO_CHAR( pvcsalesorder_in ) );    
  
END fnRefreshShipToAddress;

FUNCTION fnRegionDescLookup ( pvcMandt_IN  IN VARCHAR2,
                              pvcRegio_IN  IN VARCHAR2,
                              pvcSpras_IN  IN VARCHAR2,
                              pvcLand1_IN  IN VARCHAR2 ) RETURN VARCHAR2 IS
                                
CURSOR crGetDesc ( cpvcMandt_IN IN VARCHAR2,
                   cpvcRegio_IN IN VARCHAR2,
                   cpvcSpras_IN IN VARCHAR2,
                   cpvcLand1_IN IN VARCHAR2 ) IS
SELECT TRIM ( bezei ) Description
  FROM  r3_t005u
 WHERE  mandt = cpvcMandt_IN
   AND  bland = cpvcRegio_IN
   AND  spras = cpvcSpras_IN
   AND  land1 = cpvcLand1_IN;
     
   vcRegioDesc VARCHAR2(20);

BEGIN

  OPEN crGetDesc ( cpvcMandt_IN => pvcMandt_IN,
                   cpvcRegio_IN => pvcRegio_IN,
                   cpvcSpras_IN => pvcSpras_IN,
                   cpvcLand1_IN => pvcLand1_IN );
                   
  FETCH  crGetDesc INTO vcRegioDesc;
  CLOSE  crGetDesc;
  
  RETURN vcRegioDesc;

END fnRegionDescLookup;

  FUNCTION fnShapeTypeLookup(pnmShapeFormId_in IN te_ipo_shape_forms.shape_form_id%TYPE) RETURN VARCHAR2 IS

    vcShapeForm te_ipo_shape_forms.shape_form%TYPE;

    CURSOR crGetShape(cpnmShapeFormId_in IN te_ipo_shape_forms.shape_form_id%TYPE) IS
    SELECT  shape_form
    FROM te_ipo_shape_forms
    WHERE shape_form_id = cpnmShapeFormId_in;
  
  BEGIN
    OPEN crGetShape(cpnmShapeFormId_in => pnmShapeFormId_in);
    FETCH crGetShape INTO vcShapeForm;
    CLOSE crGetShape;

    RETURN vcShapeForm;

  END fnShapeTypeLookup;

  FUNCTION fnDimSpecLookup(pvcDimSpec_in IN te_dim_spec.dim_spec%TYPE,
                           pvcSite_in    IN te_dim_spec.site%TYPE) RETURN VARCHAR2 IS

    vcSpecNo te_dim_spec.spec_no%TYPE;

    CURSOR crGetDesc(cpvcDimSpec_in IN te_dim_spec.dim_spec%TYPE,
                     cpvcSite_in   IN te_dim_spec.site%TYPE) IS
    SELECT spec_no
    FROM te_dim_spec
    WHERE site = cpvcSite_in
    AND dim_spec = cpvcDimSpec_in;

  BEGIN
    OPEN crGetDesc(cpvcDimSpec_in => pvcDimSpec_in,
                   cpvcSite_in    => pvcSite_in);
    FETCH crGetDesc INTO vcSpecNo;
    CLOSE crGetDesc;

    RETURN vcSpecNo;
  END fnDimSpecLookup;

---------------------------------
FUNCTION fnIsAlloyForSpec (pnmSpecCodeID_IN IN te_spec_code_header.spec_code_id%TYPE,
                           pvcAlloyCode_IN  IN te_spec_code_header.alloy_code%TYPE) 
                                        RETURN BOOLEAN AS

vcDummy VARCHAR2(1);

CURSOR crGetSpecAlloy (cpnmSpecCodeID_IN IN te_spec_code_header.spec_code_id%TYPE,
                       cpvcAlloyCode_IN  IN te_spec_code_header.alloy_code%TYPE) IS
SELECT 'x'
  FROM te_spec_code_header te 
 WHERE te.spec_code_id = cpnmSpecCodeID_IN
   AND te.alloy_code   = cpvcAlloyCode_IN;

BEGIN


  OPEN crGetSpecAlloy ( cpnmSpecCodeID_IN => pnmSpecCodeID_IN,
                        cpvcAlloyCode_IN  => pvcAlloyCode_IN);
  FETCH crGetSpecAlloy INTO vcDummy;
  
  IF crGetSpecAlloy%FOUND THEN
  
     CLOSE crGetSpecAlloy;
     RETURN TRUE;
  
  ELSE
  
     CLOSE crGetSpecAlloy;
     RETURN FALSE;
  
  END IF;
  
  
END fnIsAlloyForSpec;    

/*------------------------------------------------------------------------------------------
||
|| Function to determine if there is an ingot result failure
||
*/------------------------------------------------------------------------------------------
FUNCTION fnIngotChemFailure (pnmSpecCodeId_in   IN   te_spec_code_header.spec_code_id%TYPE
                                            ,pvcHeatNo_in   IN   r3_process_orders.r3_ingot_ref%TYPE)
RETURN BOOLEAN IS
--
-- Declarations
blEndLoop         BOOLEAN;        -- Flags occurrence of OOS result so stop processsing test requirement checks
blResultOos       BOOLEAN;        -- Return value TRUE if we have a result OOS, else FALSE

-- Variables to hold oder / material details required for E-mail
vcBatchNo     r3_process_orders.r3_process_order%TYPE;
vcHeatNo      r3_process_orders.r3_ingot_ref%TYPE;
vcSalesOrder   r3_sales_order_items.r3_sales_order%TYPE;
vcSalesOrderItem    r3_sales_order_items.r3_sales_order_item%TYPE;

--
-- Get the ingot test requirement from the order spec
CURSOR crGetChemTestReq(pnmSpecId_in    IN  te_spec_code_limits.spec_code_id%TYPE)
IS
    SELECT  scl.test_code, scl.min_value, scl.max_value
    FROM    te_spec_code_limits scl,
                te_test_codes tc
    WHERE   scl.spec_code_id = pnmSpecId_in
    AND       tc.status = pk_star_constants.vcActiveRecord
    AND       tc.test_code = scl.test_code
    AND       tc.test_category = 'C'
    AND       tc.test_material = 'I';
    
rcChemTestReq       crGetChemTestReq%ROWTYPE;

--
-- Get the corresponding results against the heat 
CURSOR  crGetIngotResult (pvcCastNo_in  IN  te_test_sample_id.cast_no%TYPE
                                    ,pvcTestCode_in IN  te_test_results.test_code%TYPE)
IS
    SELECT  ts.process_order_no, ts.sample_id, tr.test_code, tr.act_result
                    ,pk_test_result_rounding.fnE29RoundToSpec (pnmSpecCodeId_in    => pnmSpecCodeId_in
                                                                                ,pvcTestCode_in     =>  tr.test_code
                                                                                ,pnmActResult_in  =>    tr.act_result) rnd_result
    FROM    te_test_sample_id ts,
            te_test_results tr
    WHERE   ts.cast_no = pvcCastNo_in
    AND     tr.sample_id = ts.sample_id
    AND     tr.rec_status = pk_star_constants.vcActiveRecord
    AND     tr.test_code = pvcTestCode_in
    AND     tr.material_release_yn = 'Y'; --STCR 7578 only select test results that are released                                               

--
-- Get the test requirement and check if corresponding results in spec
--
BEGIN
    -- Set relevant BOOLEAN flags
    blEndLoop := FALSE;
    blResultOos := FALSE;
    
    --
    -- Loop through the Ingot test requirement for the given Spec ID. A Cursor FOR .... LOOP is not
    -- used as we need to exit the loop as soon as we find a corresponding result OOS.
    OPEN    crGetChemTestReq(pnmSpecId_in  =>  pnmSpecCodeId_in);
    WHILE   NOT blEndLoop
    LOOP
        -- Fetch the test requirement rows from the order spec
        FETCH   crGetChemTestReq INTO rcChemTestReq;
        IF  crGetChemTestReq%NOTFOUND
        THEN
            -- End of test requirement so stop processing
            blEndLoop := TRUE;    
        ELSE
            -- Loop through the results for this test code and check if OOS
            FOR cfGetIngotResult IN crGetIngotResult(pvcCastNo_in =>  pvcHeatNo_in
                                                                    ,pvcTestCode_in =>  rcChemTestReq.test_code)
            LOOP
                -- Check against spec limits if rounded result is a number
                IF pk_test_results.is_number(cfGetIngotResult.rnd_result)
                THEN 
                    -- Is result OOS ?
                    IF pk_test_results.failed_test (p_min_value  => rcChemTestReq.min_value
                                                            ,p_max_value => rcChemTestReq.max_value
                                                            ,p_act_result  =>  cfGetIngotResult.rnd_result)
                    THEN
                        -- Flag OOS result
                        blResultOos := TRUE;
                        -- Stop processing test requirements as we have one result OOS
                        blEndLoop := TRUE;
                    END IF;
                 END IF;                                                    
                
            -- END LOOP on results against the heat
            END LOOP;
        
        -- End If on End of requirement data
        END IF;                                                               
    
    -- END LOOP on test requirement from Spec
    END LOOP;
    
    -- Close the test requirement cursor
    CLOSE   crGetChemTestReq;
    
    -- Return 
    RETURN(blResultOos);

--
-- EXCEPTIONS
--
EXCEPTION
    WHEN OTHERS
    THEN
        -- Record error and re-raise
       pk_error_log.prRecordDetailsHalt(p_SqlCode_in   =>  SQLCODE,
                                                   p_SqlErrm_in   =>  SUBSTR(SQLERRM, 1, 200),
                                                   p_ModuleName_in =>  'pk_tech_edit.fnIngotChemFailure',
                                                   p_KeyData_in    =>  'Checking FOR OOS results whilst allocating heat '
                                                                                ||pvcHeatNo_in||' TO ORDER Spec ID '||TO_CHAR(pnmSpecCodeId_in)||' AT '
                                                                                ||TO_CHAR(SYSDATE, 'DD-MON-YYYY 24HH:MI:SS'));              
                                                                                

--
-- End fnIngotChemFailure
END fnIngotChemFailure;

/*------------------------------------------------------------------------------------------
||
|| Procedure to raise STAR WATCH E-mail for OOS chemistry result on batch allocation
||
*/------------------------------------------------------------------------------------------
PROCEDURE prRaiseIngotChemFailEmail(pvcBatchNo_in   IN   r3_process_orders.r3_process_order%TYPE
                                                    ,pvcHeatNo_in    IN   r3_process_orders.r3_ingot_ref%TYPE
                                                    ,pvcSalesOrder_in  IN  r3_sales_order_items.r3_sales_order%TYPE
                                                    ,pvcSalesOrderItem_in   IN    r3_sales_order_items.r3_sales_order_item%TYPE
                                                    ,pnmSpecCodeId_in    IN     te_spec_code_header.spec_code_id%TYPE )
IS
--
-- Email variables
vcOutcomeStatus          pk_email.pv_outcome_status%TYPE;
vcOutcomeMessage        pk_email.pv_outcome_message%TYPE;

clRecipients                   pk_collection_types.user_login_list_t := pk_collection_types.user_login_list_t ();

-- rtTextParameters         pk_star_programs.text_parameters := pk_star_programs.text_parameters ();
clEmailParameters          pk_star_programs.text_parameters := pk_star_programs.text_parameters ();

vcEmailSubject              st_email_queue_headers.subject%TYPE;
vcEmailMessage           st_email_queue_headers.MESSAGE_TEXT%TYPE;

--
vcShapeType             te_spec_code_header.shape_type%TYPE;          


-- 
-- Build the E-mail and add to queue
--
BEGIN
    -- Get the shape type
    vcShapeType  :=  pk_tech_edit.fnGetShapeType(pnmSpecId_in  =>  pnmSpecCodeId_in);
    
    -- Build the subject line
    vcEmailSubject := pk_star_programs.fn_get_module_text(p_module_name =>  'PK_TECH_EDIT'
                                                                                ,p_text_key =>  'SUBJECT_ALLOC_RESULT_FAILURE');

    --                                                                                
    -- Add each item that will be used in the message text to the collection used when building the message
    Pk_Star_Programs.pr_add_text_parameters (p_text_parameters => clEmailParameters, p_parameter => pvcBatchNo_in);              -- Batch No
    Pk_Star_Programs.pr_add_text_parameters (p_text_parameters => clEmailParameters, p_parameter => pvcHeatNo_in);                -- Heat No
    Pk_Star_Programs.pr_add_text_parameters (p_text_parameters => clEmailParameters, p_parameter => pvcSalesOrder_in);             -- Order No
    Pk_Star_Programs.pr_add_text_parameters (p_text_parameters => clEmailParameters, p_parameter => pvcSalesOrderItem_in);     -- Line (Item) No
    Pk_Star_Programs.pr_add_text_parameters (p_text_parameters => clEmailParameters, p_parameter => vcShapeType);                -- Shape Type
    
    -- Now build the message text 
    vcEmailMessage := pk_star_programs.fn_get_module_text(p_module_name =>  'PK_TECH_EDIT'
                                                                                 ,p_text_key =>  'MESSAGE_ALLOC_RESULT_FAILURE'
                                                                                 ,p_parameters  =>  clEmailParameters);
                                                                                 
    -- Now queue the E-mail for sending
    pk_email.pr_email_an_event(p_event_id_in   =>  149
                                         ,p_additional_recipients_in  =>    clRecipients
                                         ,p_message_text_in  =>  vcEmailMessage
                                         ,p_subject_in  =>  vcEmailSubject
                                         ,p_event_specific_data_in  =>  'PACKAGE: pk_tech_edit.prRaiseIngotChemFailEmail'
                                         ,p_outcome_status_out  =>  vcOutcomeStatus
                                         ,p_outcome_message_out =>  vcOutcomeMessage);
                                                                       
    
--
-- End prRaiseIngotChemFailEmail
END prRaiseIngotChemFailEmail;                                                        
PROCEDURE prRenumSpecText(ptSpecCodeId_in  IN r3_sales_order_items.spec_code_id%TYPE
                          ,pnmTableId   IN NUMBER) IS
/**************************************************************************************************************************************************
--  PURPOSE:
    Procedure to renumber spec text for the spec and text table passed thru.
    Numbering will be in increments of 10. Table id's are:

           1) Manufacturing text
           2) General text
           3) Special text
           4) Testing text
           5) Test report text
           6) Technical notepad
           7) Tech EDIT otepad
           8) Ultrasonic notepad
           9) Certfication notepad
           10) metallurgy notepad
           11) Lab notepad
           12) Chemistry Statements
           13) Compliance Statements
           14) Test Travelers Text
           15) Test Traveler SAMPLE Text
           16) Mechanical Statsments
           17) Metalurgical Statements
           18) RELEASE Statements
           19) lab_text
           20) Heat Treatment Text
***************************************************************************************************************************************************/
nmLine    NUMBER    := 0;
vcTableName VARCHAR2(100);
TYPE rfCursor IS REF CURSOR;
rfCurTxt rfCursor;
vcQuery VARCHAR2(2000);
ltSeqNo te_spec_code_man_text.seq_no%TYPE;
ltLineNumber te_spec_code_man_text.line_number%TYPE;
BEGIN
SELECT DECODE(pnmTableId
              ,1,'te_spec_code_man_text'
              ,2,'te_spec_code_gen_text'
              ,3,'te_spec_code_spe_text'
              ,4,'te_spec_code_tst_text'
              ,5,'te_spec_code_rpt_text'
              ,6,'te_spec_code_tech_notes'
              ,7,'te_spec_code_approval_te_text'
              ,8,'te_spec_code_approval_us_text'
              ,9,'te_spec_code_approval_ce_text'
              ,10,'te_spec_code_approval_met_text'
              ,11,'te_spec_code_approval_lab_text'
              ,12,'te_chem_statements_txt'
              ,13,'te_comp_statements_txt'
              ,14,'te_test_traveler_txt'
              ,15,'te_test_traveler_samp_txt'
              ,16,'te_mech_statements_txt'
              ,17,'te_metl_statements_txt'
              ,18,'te_rel_statements_txt'
              ,19,'te_spec_code_lab_text'
              ,20,'te_spec_code_approval_ht_text'
              ,'invalid table')             
INTO vcTableName
FROM DUAL;                      
vcQuery:= 'SELECT SEQ_NO,LINE_NUMBER FROM '||vcTableName||' WHERE spec_code_id = '||ptSpecCodeId_in||' ORDER BY line_number FOR UPDATE OF line_number';
OPEN rfCurTxt FOR vcQuery;
LOOP
FETCH rfCurTxt INTO ltSeqNo
                    ,ltLineNumber;
nmLine := nmLine+10;
EXIT WHEN rfCurTxt%NOTFOUND;
IF pnmTableId = 1 THEN
   UPDATE  te_spec_code_man_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 2 THEN
   UPDATE  te_spec_code_gen_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 3 THEN
   UPDATE  te_spec_code_spe_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 4 THEN
   UPDATE  te_spec_code_tst_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 5 THEN
   UPDATE  te_spec_code_rpt_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 6 THEN
   UPDATE  te_spec_code_tech_notes
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 7 THEN
   UPDATE  te_spec_code_approval_te_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 8 THEN
   UPDATE  te_spec_code_approval_us_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 9 THEN
   UPDATE  te_spec_code_approval_ce_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 10 THEN
   UPDATE  te_spec_code_approval_met_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 11 THEN
   UPDATE  te_spec_code_approval_lab_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 12 THEN
   UPDATE  te_chem_statements_txt
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 13 THEN
   UPDATE  te_comp_statements_txt
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 14 THEN
   UPDATE  te_test_traveler_txt
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 15 THEN
   UPDATE  te_test_traveler_samp_txt
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 16 THEN
   UPDATE  te_mech_statements_txt
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 17 THEN
   UPDATE  te_metl_statements_txt
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 18 THEN
   UPDATE  te_rel_statements_txt
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo;
ELSIF pnmTableId = 19 THEN
   UPDATE  te_spec_code_lab_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo; 
ELSIF pnmTableId = 20 THEN
   UPDATE  te_spec_code_approval_ht_text
      SET  line_number = nmLine
    WHERE  seq_no = ltSeqNo; 
END IF;                                                         
END LOOP;
END prRenumSpecText;

--
-- Function to determine if two alloys are set as equivalent
FUNCTION fnAlloyIsEquiv(ptSOIAlloyCode_in       IN      st_alloys.alloy_code%TYPE
                                 ,ptSpecAlloyCode_in     IN      st_alloys.alloy_code%TYPE)
RETURN BOOLEAN IS
--
-- Declarations
CURSOR crCheckEquivalent (cpSoiAlloy_in     IN      st_alloys.alloy_code%TYPE
                                    ,cpSpecAlloy_in     IN      st_alloys.alloy_code%TYPE)
IS
    SELECT 'Y'
    FROM    st_alloy_equivalents
    WHERE    primary_alloy_code =  cpSpecAlloy_in
    AND       equivalent_alloy_code =  cpSoiAlloy_in
    AND       rec_status = pk_star_constants.vcActiveRecord;
    
vcFoundYN       VARCHAR2(1);
blAlloysEquiv     BOOLEAN;                            

--
-- Perform the lookup
BEGIN
    -- Initialise
    vcFoundYN := NULL;
    blAlloysEquiv := NULL;
    
    -- Are alloys equivalent ?
    OPEN    crCheckEquivalent(cpSoiAlloy_in =>  ptSOIAlloyCode_in
                                        ,cpSpecAlloy_in => ptSpecAlloyCode_in);
    FETCH   crCheckEquivalent
        INTO    vcFoundYN;
        
    IF  vcFoundYN = 'Y'
    THEN
        -- Equivalent alloys
        blAlloysEquiv := TRUE;
        CLOSE   crCheckEquivalent;
    ELSE
        -- Not equivalent
        blAlloysEquiv := FALSE;
        CLOSE   crCheckEquivalent;
    END IF;
    
    -- Return
    RETURN(blAlloysEquiv);
    
--
-- Exceptions
EXCEPTION

  WHEN OTHERS
  THEN
    -- Record the exception details and RE-raise
    pk_error_log.prRecordDetailsHalt (p_SqlCode_in   =>  SQLCODE,
                                                p_SqlErrm_in     =>  SUBSTR(SQLERRM, 1, 200),
                                                p_ModuleName_in    => 'pk_tech_edit.fnAlloyIsEquiv',        
                                                p_KeyData_in        => 'WHEN OTHERS: SOI Alloy ['||ptSOIAlloyCode_in||
                                                                                '] Spec Alloy ['||ptSpecAlloyCode_in||']');

--
-- End fnAlloyIsEquiv    
END fnAlloyIsEquiv;    

--
-- Procedure to date stamp header recoRd when one of the specs child tables has been updated or inserted into         
PROCEDURE prDateStampHeader(ptSpecCodeId_in    IN   te_spec_code_header.spec_code_id%TYPE)
IS

BEGIN
    --
    -- Update last updated date  against the header record
    UPDATE  te_spec_code_header
    SET     date_updated = SYSDATE,
              time_updated = TO_CHAR(SYSDATE, 'HH24:MI:SS')
    WHERE   spec_code_id = ptSpecCodeId_in;

--
-- Exceptions
EXCEPTION
    WHEN OTHERS
    THEN
        -- Record the exception details and RE-raise
        pk_error_log.prRecordDetailsHalt (p_SqlCode_in   =>  SQLCODE,
                                                    p_SqlErrm_in     =>  SUBSTR(SQLERRM, 1, 200),
                                                    p_ModuleName_in    => 'pk_tech_edit.prDateStampHeader',        
                                                    p_KeyData_in        => 'WHEN OTHERS: Spec ID ['||TO_CHAR(ptSpecCodeId_in)||']');                          
       

--
-- End prDateStampHeader
END prDateStampHeader;


--
-- Procedure to set (update) IPO mold size column from corresponding value in TE (STCR 6848)   
PROCEDURE prSetIPOMoldSize(pnmSpecId_in     IN  te_spec_code_header.spec_code_id%TYPE
                                          ,pnmMoldSizeId_in    IN  te_spec_code_header.mold_size_id%TYPE)  
IS                                          
--
-- Cursor to read for the IPO record for the incoming spec ID
CURSOR crCheckIPOEntry(cpnmSpecID_in    IN  te_ipo_entries.spec_code_id%TYPE)
IS
    SELECT  'Y'
    FROM    te_ipo_entries
    WHERE   spec_code_id = cpnmSpecID_in;
    
-- Variables
vcExistYN       VARCHAR2(1);

--
-- Update the IPO record for this spec (if one is present)
BEGIN
    -- Check that we have an existing IPO record
    OPEN    crCheckIPOEntry(cpnmSpecID_in  =>  pnmSpecId_in);
    FETCH   crCheckIPOEntry
        INTO    vcExistYN;
        
    IF crCheckIPOEntry%FOUND
    THEN    
        -- Update the mold ID
        UPDATE  te_ipo_entries
        SET mold_size_id = pnmMoldSizeId_in
        WHERE spec_code_id = pnmSpecId_in;
    END IF;
    
    CLOSE   crCheckIPOEntry;    
     
--
-- End prSetIPOMoldSize
END prSetIPOMoldSize;                                             

--
-- Procedure to set (update) IPO ingot diameter column from corresponding value in TE (STCR 6848)                                            
PROCEDURE prSetIPOIngotDiam(pnmSpecId_in     IN  te_spec_code_header.spec_code_id%TYPE
                                          ,pnmIngotDiam_in     IN  te_spec_code_header.ingot_diam_inches%TYPE)
IS                                          
--
-- Cursor to read for the IPO record for the incoming spec ID
CURSOR crCheckIPOEntry(cpnmSpecID_in    IN  te_ipo_entries.spec_code_id%TYPE)
IS
    SELECT  'Y'
    FROM    te_ipo_entries
    WHERE   spec_code_id = cpnmSpecID_in;
    
-- Variables
vcExistYN       VARCHAR2(1);                                           

--
-- Update the IPO record for this spec (if one is present)
BEGIN
    -- Check that we have an existing IPO record
    OPEN    crCheckIPOEntry(cpnmSpecID_in  =>  pnmSpecId_in);
    FETCH   crCheckIPOEntry
        INTO    vcExistYN;
        
    IF crCheckIPOEntry%FOUND
    THEN    
        -- Update the ingot diameter
        UPDATE  te_ipo_entries
        SET var_cast_size = pnmIngotDiam_in
        WHERE  spec_code_id = pnmSpecId_in;
    END IF;

    CLOSE   crCheckIPOEntry;    
     
--
-- End prSetIPOIngotDiam
END prSetIPOIngotDiam;
                                             
/*                              
--
-- Procedure to set (update) IPO mold size columns from corresponding values in TE
PROCEDURE prSetIPOMoldSizes(pnmSpecId_in     IN  te_spec_code_header.spec_code_id%TYPE
                                          ,pnmMoldSizeId_in    IN  te_spec_code_header.mold_size_id%TYPE
                                          ,pnmIngotDiam_in     IN  te_spec_code_header.ingot_diam_inches%TYPE
                                          ,pblUpdateToNULL_in   IN  BOOLEAN DEFAULT FALSE)              -- STCR 6848
IS                                          
--
-- Cursor to read for the IPO record for the incoming spec ID
CURSOR crCheckIPOEntry(cpnmSpecID_in    IN  te_ipo_entries.spec_code_id%TYPE)
IS
    SELECT  'Y'
    FROM    te_ipo_entries
    WHERE   spec_code_id = cpnmSpecID_in;
    
-- Variables
vcExistYN       VARCHAR2(1);

--
-- Update the IPO record for this spec (if one is present)
BEGIN
    -- Check that we have an existing IPO record
    OPEN    crCheckIPOEntry(cpnmSpecID_in  =>  pnmSpecId_in);
    FETCH   crCheckIPOEntry
        INTO    vcExistYN;
        
    IF crCheckIPOEntry%FOUND
    THEN    
        -- Update mold_size_id if value passed in
        IF pnmMoldSizeId_in IS NOT NULL
        THEN 
            UPDATE  te_ipo_entries
            SET mold_size_id = pnmMoldSizeId_in
            WHERE spec_code_id = pnmSpecId_in;
        -- Check that mold size has not been NULL'd by the user (STCR 6848)
        ELSIF pblUpdateToNULL_in
        THEN
            UPDATE  te_ipo_entries
            SET mold_size_id = NULL
            WHERE spec_code_id = pnmSpecId_in;                           
        END IF;
        
        -- Update ingot diam if value passed in
        IF pnmIngotDiam_in IS NOT NULL
        THEN
            UPDATE  te_ipo_entries
            SET var_cast_size = pnmIngotDiam_in
            WHERE  spec_code_id = pnmSpecId_in;
        -- Check that ingot diameter has not been NULL'd by the user (STCR 6848)
        ELSIF pblUpdateToNULL_in
        THEN
            UPDATE  te_ipo_entries
            SET var_cast_size = NULL
            WHERE spec_code_id = pnmSpecId_in;            
        END IF; 
       
    END IF; 
    
    CLOSE   crCheckIPOEntry;    
    
--
-- End prSetIPOMoldSizes  
END prSetIPOMoldSizes;
*/
                                          
--
-- Procedure to get (return) IPO mold sizes from the corresponding T/E record
PROCEDURE prGetIPOMoldSizes(pnmSpecId_in     IN  te_spec_code_header.spec_code_id%TYPE
                                          ,pnmMoldSizeId_out   OUT  te_spec_code_header.mold_size_id%TYPE
                                          ,pnmIngotDiam_out    OUT  te_spec_code_header.ingot_diam_inches%TYPE)
IS                                          
--
-- Cursor to get the T/E record
CURSOR crGetMoldData (cpnmSpecID_in IN  te_spec_code_header.spec_code_id%TYPE)
IS
    SELECT  ingot_diam_inches, mold_size_id
    FROM    te_spec_code_header
    WHERE   spec_code_id = cpnmSpecID_in;

-- Variables

--
-- Get the mold size data from T/|E
BEGIN
    OPEN    crGetMoldData (cpnmSpecID_in =>  pnmSpecId_in);
    FETCH   crGetMoldData
        INTO    pnmIngotDiam_out, pnmMoldSizeId_out;
    CLOSE   crGetMoldData;     

--
-- End prGetIPOMoldSizes  
END prGetIPOMoldSizes;                                                            

--
-- END PACKAGE BODY
--
END pk_tech_edit;
/
