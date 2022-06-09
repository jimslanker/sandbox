CREATE OR REPLACE PACKAGE STAR.pk_melt IS
--
-- Version control data:
--
-- $Revision:   5.18  $
-- $Date:   05 May 2022 13:02:22  $
-- 
/*    
  File  pk_blend.spc
  Date  07-Jan-98
  Auth  Joy Williams
  Desc  General Database package for Melting System

  5.1  11-JUN-2009  R R Nault            STCR 4224 added a new function fn_get_melt_method.
  5.2  29-JAN-2010  G Ford               STCR 5188 added fn_set_nbt_based_on_heat and the appropriate record structure.
  5.2  09-MAR-2010  G Ford               JDD2010C13_1_Scheduled_Issues: STCR 5070 - added fn_get_swap_reason
  5.3  -- Skipped to make version in sync with the PVCS
  5.4  29-APR-2010  A Narayan            JDD2010C14_3_Fast_Track_Issues : STCR 5381 - Modified the nbt_fields record to  change nbt_bc_weight to VARCHAR2(100)
  5.5  17-JUN-2010  G Ford               Cycle 14 Scheduled Issues - STCR 5198 - added fnGetInputType
  5.5  24-AUG-2010  Noel Gelineau        Cycle 15 Scheduled Issues - STCR 5433 - added fnGetSpecIdByHeatId
  5.7  05-DEC-2010  Noel Gelineau        Cycle 16 Scheduled Issues - STCR 5483 - added prEmailMFG
       17-DEC-2010  Noel Gelineau        Cycle 16 Scheduled Issues - STCR 5587 - Added fnMeltPositionExists
  5.8  16-FEB-2011  Noel Gelineau        2010 Fast Track - STCR 5779 - added prHeatAlloyCheck
  5.9  03-MAR-2011  Noel Gelineau        STCR 5714 - added fnGetOOSChemistryByHeat
  5.10 21-JUN-2011  G Ford               Cycle 18 Scheduled Issues - STCR 5885 - new procedure fnGetElectrodeNSECount
*/
  
  cnPackageName CONSTANT VARCHAR2(50) := 'pk_melt';

  TYPE nbt_fields IS RECORD
  ( nbt_melt_date             DATE
  , nbt_sales_order_num       r3_sales_order_items.r3_sales_order%TYPE
  , nbt_sales_order_item      r3_sales_order_items.r3_sales_order_item%TYPE
  , nbt_mold_size             mt_chm_molds.mold%TYPE
  , nbt_eb_recipe             te_ipo_entries.recipe_no%TYPE
  , nbt_melting_recipe_1      te_ipo_entries.recipe_no_1%TYPE
  , nbt_melting_recipe_2      te_ipo_entries.recipe_no_2%TYPE
  , nbt_customer_name         r3_sales_orders.sap_sold_to_name%TYPE
  , nbt_order_spec_name       te_spec_code_header.spec_code_name%TYPE
  , nbt_alloy_code            te_spec_code_header.alloy_code%TYPE
  , nbt_quality_code          te_spec_code_header.grade_code%TYPE
  , nbt_num_of_mpes           NUMBER
  , nbt_num_of_nses           NUMBER
  , nbt_num_of_samples        NUMBER
  , nbt_num_of_int_cuts       NUMBER
  , nbt_num_of_ext_cuts       NUMBER
  , nbt_num_of_order_devs     NUMBER
  , nbt_electrode_num         mt_us_heats.electrode_id%TYPE
  , nbt_electrode_weight      mt_eb_melts.melt_weight%TYPE
  , nbt_electrode_weight_uom  mt_eb_melts.melt_weight_uom%TYPE
  , nbt_ingot_diameter        te_ipo_entries.var_cast_size%TYPE
  , nbt_bc_weight             VARCHAR2 ( 100 )
  , nbt_bc_weight_uom         mt_eb_melts.bc_weight_uom%TYPE
  , nbt_bc_lot_num            mt_bc_lots.lot_num%TYPE
  , nbt_num_of_electrode_nses NUMBER
  , nbt_linear_density        NUMBER
  ,nbt_tolerance mt_mold_linear_densities.tolerance%TYPE -- STCR 7383 added this column
  );
  
  PROCEDURE p_create_association (
    p_electrode_ref          IN   VARCHAR2
   ,p_parent_prefix1         IN   VARCHAR2
   ,p_parent_prefix2         IN   VARCHAR2
   ,p_parent_number_string   IN   VARCHAR2
   ,p_parent_melt_ref        IN   VARCHAR2
   ,p_other_casts            IN   VARCHAR2
   ,p_data_source            IN   VARCHAR2
  );

  PROCEDURE p_populate_cast_associations (
    p_parent_prefix1         IN   VARCHAR2
   ,p_parent_prefix2         IN   VARCHAR2
   ,p_parent_number_string   IN   VARCHAR2
   ,p_data_source            IN   VARCHAR2
  );

  PROCEDURE p_empty_cast_associations;

  PROCEDURE p_form_release_cast_tree (
    p_electrode_ref   IN   VARCHAR2
   ,p_date_released   IN   DATE
  );

  FUNCTION f_parent_electrode (
    p_electrode_ref   IN   VARCHAR2
  )
    RETURN BOOLEAN;

  FUNCTION f_parent_electrode_rv2 (
    p_electrode_ref   IN   VARCHAR2
  )
    RETURN VARCHAR2;

  -- Assert Purity level for function f_parent_electrode_rv2
  -- Write No Database State, Read No Database State, Read No Package State
  PRAGMA RESTRICT_REFERENCES (f_parent_electrode_rv2, WNDS, WNPS, RNPS);

  /* Three procedures for use at Savoie to manage the pre-heat number reference to an electrode ; The repere number
     These procedures are called from the trigger on MT_US_HEATS table : MTUSH_T1
  */
  PROCEDURE pr_update_repere_number (
    p_new_repere_number_in   mt_repere_numbers.repere_number%TYPE
   ,p_heat_number_in         mt_repere_numbers.heat_number%TYPE
  );

  PROCEDURE pr_replace_repere_number (
    p_new_repere_number_in   mt_repere_numbers.repere_number%TYPE
   ,p_old_repere_number_in   mt_repere_numbers.repere_number%TYPE
   ,p_heat_number_in         mt_repere_numbers.heat_number%TYPE
  );

  PROCEDURE pr_remove_repere_number (
    p_old_repere_number_in   mt_repere_numbers.repere_number%TYPE
   ,p_heat_number_in         mt_repere_numbers.heat_number%TYPE
  );

  FUNCTION fn_get_melt_method (
      p_batch_no_in IN VARCHAR2 DEFAULT NULL
     ,p_sales_order_in IN VARCHAR2 DEFAULT NULL
     ,p_sales_order_item_in IN VARCHAR2 DEFAULT NULL
     ,p_heat_no_in IN VARCHAR2 DEFAULT NULL
    )
    RETURN VARCHAR2;

FUNCTION fn_set_nbt_based_on_heat( p_heat_id_in IN MT_US_HEATS.heat_id%TYPE
                                 , p_heat_num_in IN MT_US_HEATS.heat_num%TYPE
                                 , p_process_type_in IN MT_ORDER_DEVIATIONS.process_type%TYPE
                                 ) RETURN Pk_Melt.nbt_fields;

FUNCTION fn_get_swap_reason( p_swap_reason_id_in IN MT_SWAP_REASONS.swap_reason_id%TYPE ) RETURN MT_SWAP_REASONS.swap_reason_name%TYPE;

FUNCTION fnGetInputType( pnmInputTypeId_in IN RM_INPUT_TYPES.input_type_id%TYPE ) RETURN RM_INPUT_TYPES.input_type%TYPE;

FUNCTION fnGetSpecIdByHeatId(pnmHeatId_In IN mt_us_heats.heat_id%TYPE)
                             RETURN r3_sales_order_items.spec_code_id%TYPE;

FUNCTION fnGetOrderDevCount(pnmHeatId_in      IN mt_order_deviations.heat_id%TYPE,
                            pnmCutPieceId_in  IN mt_order_deviations.cut_piece_id%TYPE,
                            pvcProcessType_in IN mt_order_deviations.process_type%TYPE)
                            RETURN number;

PROCEDURE prEmailMFG(pnmMeltId_in         IN  mt_eb_melts.melt_id%TYPE,
                     pvcOutcomeStatus_out OUT pk_email.pv_outcome_status%TYPE);

FUNCTION fnMeltPositionExists(pnmHeatID_in   IN mt_positions.heat_id%TYPE,
                              pvcPosition_in IN mt_positions.position%TYPE)
                              RETURN BOOLEAN;

PROCEDURE prHeatAlloyCheck(pvcHeatNum_in     IN varchar2,
                           pvcAlloyCode_in   IN st_alloys.alloy_code%TYPE,
                           pvcCheckSource_in IN varchar2);

FUNCTION fnGetOOSChemistryByHeat(pvcProcessOrderNo_in IN te_test_sample_id.process_order_no%TYPE,
                                 pvcSalesOrder_in     IN r3_sales_order_items.r3_sales_order%TYPE,
                                 pvcSalesOrderItem_in IN r3_sales_order_items.r3_sales_order_item%TYPE)
                                 RETURN varchar2;

PROCEDURE fnGetElectrodeNSECount( pvcElectrodeRef_in IN MT_ELECTRODE_HEADERS.electrode_ref%TYPE
                                , pnmNSECount_out OUT NUMBER
                                , pvcEventString_out OUT VARCHAR2
                                );

FUNCTION fnchkMeltProfilePropExist(pnmMeltProfileId_in IN     mt_melt_profile_properties.melt_profile_id%TYPE
                                  ,pvcQualityCode_in   IN     mt_melt_profile_properties.quality_code%TYPE
                                  ,pvcAlloyCode_in     IN     mt_melt_profile_properties.alloy_code%TYPE
                                  ,pnnRecipeId_in      IN     mt_recipes.recipe_id%TYPE DEFAULT NULL) RETURN BOOLEAN;                                  
                                  
-- STCR 6588
PROCEDURE prCreateDefaultSamples ( ptMeltID_in         IN mt_sample_locations.melt_id%TYPE,
                                   ptQualityCode_in    IN te_grade_codes.grade_code%TYPE );

--STCR 6772
--Passing spec code id and ingot ref to update mt us heats for the heat
PROCEDURE prUpdateHeat(ptSpecCodeId_in         IN r3_sales_order_items.spec_code_id%TYPE,
                        ptR3IngotRef_in    IN r3_process_orders.r3_ingot_ref%TYPE );                                   
                   
-- STCR 6917               
PROCEDURE prUnpairBumperAndRings ( ptPairingID_in IN mt_bumper_ring_pairings.pairing_id%TYPE );
PROCEDURE prGetNSEs(pElectrodeRef_in IN mt_electrode_headers.electrode_ref%TYPE
                    ,pStatus_in IN ns_event_headers.status%TYPE
                    ,pNSEList_out OUT VARCHAR2);
                    

-----------------------------------------------------------------------STCR7663
-- f n G e t M e l t S i t e                                FUNCTION --STCR7663
-----------------------------------------------------------------------STCR7663
-- Return Melt Site based on query the following tables in this order--STCR7663
-- MT_US_HEATS                                                       --STCR7663
-- BL_INGOTS                                                         --STCR7663
-- ST_BOUGHT_IN_MATERIAL                                             --STCR7663
-----------------------------------------------------------------------STCR7663
FUNCTION fnGetMeltSite(pHeatNo_in IN  VARCHAR2)
                                 RETURN varchar2;                    
                        
END PK_MELT;
/