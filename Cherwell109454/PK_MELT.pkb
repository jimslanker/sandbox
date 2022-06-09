CREATE OR REPLACE PACKAGE BODY STAR.pk_melt IS

--
-- Version control data:
--
--   $Revision:   5.25  $
--   $Date:   05 May 2022 13:02:22  $

/*
  File  pk_melt.bdy
  Date  07-Jan-98
  Auth  Joy Williams
  Desc  General Database package for Melting System

  Amended 14/08/2006 : M J Dickson
  Added procedures to maintain Savoie repere numbers.

  Amended 23/11/2006 : M J Dickson
  Amended the Repere number procedures to additional operate on NSN Statuses of A and C in addtion to B and O

  5.1  11-JUN-2009  R R Nault             STCR 4224 added a new function fn_get_melt_method.
  --skipped version numbering to be in sync with PVCS
  5.5  29-APR-2010  A Narayan             STCR 5381 Modified function fn_set_nbt_based_on_heat to modify the decode statement in cursor eb_info_cur
  5.7  24-AUG-2010  Noel Gelineau         Cycle 15 Scheduled Issues - STCR 5433 - added fnGetSpecIdByHeatId
  5.8  05-DEC-2010  Noel Gelineau         Cycle 16 Scheduled Issues - STCR 5483 - added prEmailMFG
       07-DEC-2010  Noel Gelineau         Cycle 16 Scheduled Issues - STCR 5536 - Updated fn_set_nbt_based_on_heat
       17-DEC-2010  Noel Gelineau         Cycle 16 Scheduled Issues - STCR 5587 - Added fnMeltPositionExists
  5.9  16-FEB-2011  Noel Gelineau         2010 Fast Track - STCR 5779 - added prHeatAlloyCheck
  5.10 03-MAR-2011  Noel Gelineau         STCR 5714 - added fnGetOOSChemistryByHeat
  5.11 29-APR-2011  Noel Gelineau         Final Check In
  5.12 21-JUN-2011  G Ford                Cycle 18 Scheduled Issues - STCR 5885 - new procedure fnGetElectrodeNSECount
  5.13 03-OCT-2011  G Ford                Cycle 19 Scheduled Issues - STCR 5767 - modified procedure fnGetElectrodeNSECount to accept eletrode ref ABC1234
  5.14 22-May-2012  A Narayan             Modified for STCR 6240
  5.19 09-AUG-2016  S Chopra              Fast Track - STCR 7086 Change to ensure legacy heat witton records are not included in alloy check
  5,24 14-FEB-2022 Jim Slanker            STCR 7643 - Remove Alloy Code Check with Bought in Material in prHeatAlloyCheck
  */
  PROCEDURE p_create_association (
    p_electrode_ref          IN   VARCHAR2
   ,p_parent_prefix1         IN   VARCHAR2
   ,p_parent_prefix2         IN   VARCHAR2
   ,p_parent_number_string   IN   VARCHAR2
   ,p_parent_melt_ref        IN   VARCHAR2
   ,p_other_casts            IN   VARCHAR2
   ,p_data_source            IN   VARCHAR2
  ) IS
    lc_parent_ref      VARCHAR2 (8) := '';
    lc_parent_prefix   VARCHAR2 (1) := '';
  BEGIN
    IF p_data_source = 'D' THEN
      lc_parent_ref := p_parent_prefix1 || p_parent_number_string;
      lc_parent_prefix := p_parent_prefix2;
    ELSIF p_data_source = 'S' THEN
      lc_parent_ref :=
               p_parent_prefix1 || p_parent_prefix2 || p_parent_number_string;
      lc_parent_prefix := '';
    END IF;
    UPDATE mt_electrode_headers eh
       SET eh.parent_electrode_ref = lc_parent_ref
          ,eh.parent_electrode_prefix = lc_parent_prefix
          ,eh.parent_electrode_melt_ref = p_parent_melt_ref
          ,eh.release_comments =
             SUBSTR (
               'Melted with ' || p_other_casts || ' to form Prime Cast '
               || lc_parent_ref || ' ' || eh.release_comments
              ,1
              ,70
             )
     WHERE eh.electrode_ref = p_electrode_ref;
    COMMIT;
  END p_create_association;

  PROCEDURE p_populate_cast_associations (
    p_parent_prefix1         IN   VARCHAR2
   ,p_parent_prefix2         IN   VARCHAR2
   ,p_parent_number_string   IN   VARCHAR2
   ,p_data_source            IN   VARCHAR2
  ) IS
    CURSOR Get_Root IS
      SELECT eh.electrode_ref, eh.parent_electrode_prefix
        FROM mt_electrode_headers eh
       WHERE eh.parent_electrode_ref =
                                   p_parent_prefix1 || p_parent_number_string
         AND eh.parent_electrode_prefix = p_parent_prefix2
         AND eh.electrode_ref = p_parent_prefix1 || p_parent_number_string;

    CURSOR Get_Next_Level (
      p_prior_electrode   IN   VARCHAR
    ) IS
      SELECT eh.electrode_ref, eh.parent_electrode_melt_ref
        FROM mt_electrode_headers eh
       WHERE eh.parent_electrode_ref = p_prior_electrode;

    CURSOR Get_Rest_of_Tree (
      p_start_with   IN   VARCHAR
    ) IS
      SELECT eh.electrode_ref, eh.parent_electrode_ref
            ,eh.parent_electrode_prefix, eh.parent_electrode_melt_ref, LEVEL
        FROM mt_electrode_headers eh
      CONNECT BY PRIOR electrode_ref = parent_electrode_ref
      START WITH electrode_ref = p_start_with;

    CURSOR Check_Component_Exists (
      p_component_ref   IN   VARCHAR2
    ) IS
      SELECT 'Y'
        FROM SYS.DUAL
       WHERE EXISTS (SELECT 1
                       FROM mt_cast_associations ca
                      WHERE ca.component_electrode_ref = p_component_ref);

    lc_statement          VARCHAR2 (2000);
    ln_cur                INTEGER;
    ln_no_rows            NUMBER (10);
    lc_electrode          VARCHAR2 (8)    := '';
    lc_parent             VARCHAR2 (8)    := '';
    lc_parent_prefix      VARCHAR2 (1)    := '';
    lc_parent_melt        VARCHAR2 (4)    := '';
    ln_level              NUMBER (5)      := '';
    ln_count              NUMBER (5)      := '';
    lc_component_exists   VARCHAR2 (1)    := '';
  --
  BEGIN
    IF p_data_source = 'S' THEN          -- Data entered since Star "Go Live"
      lc_statement :=
        'SELECT ELECTRODE_REF, parent_electrode_ref, parent_electrode_prefix, parent_electrode_melt_ref,'
        || 'level FROM MT_ELECTRODE_HEADERS WHERE parent_electrode_prefix IS NULL connect by prior '
        || 'electrode_ref = parent_electrode_ref start with electrode_ref = :bind_electrode ';
      ln_no_rows := 0;
      ln_cur := DBMS_SQL.open_cursor;                                 -- Open
      DBMS_SQL.parse (ln_cur, lc_statement, DBMS_SQL.V7);            -- Parse
      DBMS_SQL.bind_variable (
        ln_cur
       ,'bind_electrode'
       , p_parent_prefix1 || p_parent_prefix2 || p_parent_number_string
      );                                                               -- Bind
      DBMS_SQL.define_column (ln_cur, 1, lc_electrode, 8);
      -- Define output variables
      DBMS_SQL.define_column (ln_cur, 2, lc_parent, 8);
      DBMS_SQL.define_column (ln_cur, 3, lc_parent_prefix, 1);
      DBMS_SQL.define_column (ln_cur, 4, lc_parent_melt, 4);
      DBMS_SQL.define_column (ln_cur, 5, ln_level);
      ln_no_rows := DBMS_SQL.EXECUTE (ln_cur);                      -- Execute
      ln_count := 0;
      LOOP                                                       -- Fetch Loop
        ln_count := ln_count + 1;
        IF DBMS_SQL.fetch_rows (ln_cur) = 0 THEN
          EXIT;
        END IF;
        DBMS_SQL.COLUMN_VALUE (ln_cur, 1, lc_electrode);
        -- Return in local variables
        DBMS_SQL.COLUMN_VALUE (ln_cur, 2, lc_parent);
        DBMS_SQL.COLUMN_VALUE (ln_cur, 3, lc_parent_prefix);
        DBMS_SQL.COLUMN_VALUE (ln_cur, 4, lc_parent_melt);
        DBMS_SQL.COLUMN_VALUE (ln_cur, 5, ln_level);
        INSERT INTO mt_cast_associations
                    (
                     component_electrode_ref
                    ,resultant_electrode_ref
                    ,resultant_electrode_melt_ref, tree_node_level, order_by
                    ,user_login
                    )
             VALUES (
                     lc_electrode
                    , SUBSTR (lc_parent, 1, 1) || NVL (lc_parent_prefix, '')
                      || SUBSTR (lc_parent, 2)
                    ,lc_parent_melt, ln_level, ln_count
                    ,USER
                    );
      END LOOP;
      DBMS_SQL.close_cursor (ln_cur);
      COMMIT;
    --
    -- For the Legacy Data a standard tree walk will not work, because of circular references.
    --   For Legacy data the second alpha prefix does not form part of the Electrode_ref
    --
    ELSIF p_data_source = 'D' THEN                    -- Legacy DataShare data
      ln_count := 1;
      FOR rec1 IN Get_Root LOOP
        INSERT INTO mt_cast_associations
                    (
                     component_electrode_ref
                    ,resultant_electrode_ref, resultant_electrode_melt_ref
                    ,tree_node_level, order_by, user_login
                    )
             VALUES (
                     p_parent_prefix1 || p_parent_prefix2
                     || p_parent_number_string
                    ,'', 'M1'
                    ,1, ln_count, USER
                    );
        COMMIT;
        FOR rec2 IN Get_Next_Level (rec1.electrode_ref) LOOP
          ln_count := ln_count + 1;
          INSERT INTO mt_cast_associations
                      (
                       component_electrode_ref
                      ,resultant_electrode_ref
                      ,resultant_electrode_melt_ref, tree_node_level
                      ,order_by, user_login
                      )
               VALUES (
                       rec2.electrode_ref
                      , p_parent_prefix1 || p_parent_prefix2
                        || p_parent_number_string
                      ,rec2.parent_electrode_melt_ref, 2
                      ,ln_count, USER
                      );
          COMMIT;
          FOR rec3 IN Get_Rest_of_Tree (rec2.electrode_ref) LOOP
            lc_component_exists := 'N';
            OPEN Check_Component_Exists (rec3.electrode_ref);
            FETCH  Check_Component_Exists
              INTO lc_component_exists;
            CLOSE Check_Component_Exists;
            IF lc_component_exists = 'Y' THEN
              EXIT;
            END IF;
            IF rec3.LEVEL + 2 > 1 THEN
              ln_count := ln_count + 1;
              INSERT INTO mt_cast_associations
                          (
                           component_electrode_ref
                          ,resultant_electrode_ref
                          ,resultant_electrode_melt_ref, tree_node_level
                          ,order_by, user_login
                          )
                   VALUES (
                           rec3.electrode_ref
                          , SUBSTR (rec3.parent_electrode_ref, 1, 1)
                            || rec3.parent_electrode_prefix
                            || SUBSTR (rec3.parent_electrode_ref, 2)
                          ,rec3.parent_electrode_melt_ref, rec3.LEVEL + 2
                          ,ln_count, USER
                          );
              COMMIT;
            END IF;
          END LOOP;
        END LOOP;
      END LOOP;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_SQL.close_cursor (ln_cur);
      RAISE;
  END p_populate_cast_associations;

  PROCEDURE p_empty_cast_associations IS
  BEGIN
    DELETE FROM mt_cast_associations ca
          WHERE ca.user_login = USER;
    COMMIT;
  END p_empty_cast_associations;

  PROCEDURE p_form_release_cast_tree (
    p_electrode_ref   IN   VARCHAR2
   ,p_date_released   IN   DATE
  ) IS
    CURSOR Get_Tree IS
      SELECT eh.electrode_ref, LEVEL
        FROM mt_electrode_headers eh
       WHERE eh.parent_electrode_prefix IS NULL
      CONNECT BY PRIOR eh.electrode_ref = eh.parent_electrode_ref
      START WITH eh.electrode_ref = p_electrode_ref;
  BEGIN
    FOR rec IN Get_Tree LOOP
      IF rec.LEVEL != 1 THEN
        UPDATE mt_electrode_headers eh
           SET eh.date_released = p_date_released
         WHERE eh.electrode_ref = rec.electrode_ref;
        COMMIT;
      END IF;
    END LOOP;
  END p_form_release_cast_tree;

  FUNCTION f_parent_electrode (
    p_electrode_ref   IN   VARCHAR2
  )
    RETURN BOOLEAN IS
    CURSOR Child_Exists IS
      SELECT 'Y'
        FROM SYS.DUAL
       WHERE EXISTS (SELECT 1
                       FROM mt_electrode_headers eh
                      WHERE eh.parent_electrode_ref = p_electrode_ref);

    lc_exists   VARCHAR2 (1) := '';
  BEGIN
    OPEN Child_Exists;
    FETCH  Child_Exists
      INTO lc_exists;
    CLOSE Child_Exists;
    IF lc_exists = 'Y' THEN
      RETURN (TRUE);
    ELSE
      RETURN (FALSE);
    END IF;
  END f_parent_electrode;

  FUNCTION f_parent_electrode_rv2 (
    p_electrode_ref   IN   VARCHAR2
  )
    RETURN VARCHAR2 IS
    CURSOR Child_Exists IS
      SELECT 'Y'
        FROM SYS.DUAL
       WHERE EXISTS (SELECT 1
                       FROM mt_electrode_headers eh
                      WHERE eh.parent_electrode_ref = p_electrode_ref);

    lc_exists   VARCHAR2 (1) := '';
  BEGIN
    OPEN Child_Exists;
    FETCH  Child_Exists
      INTO lc_exists;
    CLOSE Child_Exists;
    RETURN (NVL (lc_exists, 'N') );
  END f_parent_electrode_rv2;

  PROCEDURE pr_update_repere_number (
    p_new_repere_number_in   mt_repere_numbers.repere_number%TYPE
   ,p_heat_number_in         mt_repere_numbers.heat_number%TYPE
  ) IS
  /* This procedure is called when a user either has added a new record to MT_US_HEATS table for Site 26 and has entered an Electrode ID
     or when a record on MT_US_HEATS is updated and part of the update is changing the electrode_id from NULL to a value.
     This procedure
     (a) Updates the repere number table , MT_REPERE_NUMBERS and sets the HEAT_NUMBER and DATE_LINKED_TO_HEAT columns
     (b) Looks for any Non-Std Event Records with the CAST_NUMBER Column = the Repere Number and replaces the CAST_NUMBER value with the HEAT_NUMBER
  */
  BEGIN
    --- Update the Repere Number record
    UPDATE mt_repere_numbers
       SET heat_number = p_heat_number_in
          ,date_linked_to_heat = SYSDATE
     WHERE repere_number = p_new_repere_number_in;
    --- Update the non-stds records
    UPDATE ns_event_lines
       SET repere_number = cast_number
          ,cast_number = p_heat_number_in
     WHERE ns_event_id IN (SELECT ns_event_id
                             FROM ns_event_headers
                            WHERE site = '26'
                              AND rec_status = 'A'
                              AND status IN ('B', 'O' , 'A', 'C') )
       AND cast_number = p_new_repere_number_in;
  END pr_update_repere_number;

  PROCEDURE pr_replace_repere_number (
    p_new_repere_number_in   mt_repere_numbers.repere_number%TYPE
   ,p_old_repere_number_in   mt_repere_numbers.repere_number%TYPE
   ,p_heat_number_in         mt_repere_numbers.heat_number%TYPE
  ) IS
  /* This procedure is called when a user changes the ELECTRODE_ID column on a record in MT_US_HEATS. Doing this change means that
     the previous link between the heat and repere number is no longer valid and is being replaced by a new relationship.
     This procedure ;
     (a) Updates the record for the new repere number to show linked to the heat
     (b) Updates the record for the old repere number to remove the link to the heat
     (c) For any non-stds that were originally for the old repere number , revert the cast_number column back to repere_number
     (d) For any non-stds that are for the new repere number , update the CAST_NUMBER to be the Heat number.
  */
  BEGIN
    --- First remove the links for the old repere number
    pk_melt.pr_remove_repere_number
                           (
      p_old_repere_number_in     => p_old_repere_number_in
     ,p_heat_number_in           => p_heat_number_in
    );
    --- Now put in place the links for the new repere number
    pk_melt.pr_update_repere_number
                            (
      p_new_repere_number_in     => p_new_repere_number_in
     ,p_heat_number_in           => p_heat_number_in
    );
  END pr_replace_repere_number;

  PROCEDURE pr_remove_repere_number (
    p_old_repere_number_in   mt_repere_numbers.repere_number%TYPE
   ,p_heat_number_in         mt_repere_numbers.heat_number%TYPE
  ) IS
  /* This procedure is called when the user has updated a record on MT_US_HEATS and blanked out the ELECTRODE_ID
     This procedure removes all links for the old repere number.
  */
  BEGIN
    --- First undo any past changes for the old repere number.
    UPDATE mt_repere_numbers
       SET heat_number = NULL
          ,date_linked_to_heat = NULL
     WHERE repere_number = p_old_repere_number_in;
    --- Next undo any changes to Non-stds
    UPDATE ns_event_lines
       SET cast_number = repere_number
     WHERE ns_event_id IN (SELECT ns_event_id
                             FROM ns_event_headers
                            WHERE site = '26'
                              AND rec_status = 'A'
                              AND status IN ('B', 'O' , 'A' ,'C') )
       AND repere_number = p_old_repere_number_in;
  END pr_remove_repere_number;

  FUNCTION fn_get_melt_method (
      p_batch_no_in IN VARCHAR2 DEFAULT NULL
     ,p_sales_order_in IN VARCHAR2 DEFAULT NULL
     ,p_sales_order_item_in IN VARCHAR2 DEFAULT NULL
     ,p_heat_no_in IN VARCHAR2 DEFAULT NULL
    )
    RETURN VARCHAR2 IS

  lv_site st_sites.site%TYPE;
  lv_melt_method te_spec_code_header.ingot_num_of_melts%TYPE := NULL;
  lv_process_order_status r3_process_orders.process_order_status%TYPE;

  CURSOR c_get_so_melt_method (p_batch_no VARCHAR2, p_sales_order VARCHAR2, p_sales_order_item VARCHAR2) IS
    SELECT c.plant_no, A.ingot_num_of_melts, d.process_order_status
      FROM te_spec_code_header A, r3_sales_order_items c, r3_process_orders d
     WHERE A.spec_code_id = c.spec_code_id
       AND c.r3_sales_order = d.r3_sales_order
       AND c.r3_sales_order_item = d.r3_sales_order_item
       AND d.r3_process_order = p_batch_no
       AND c.r3_sales_order = p_sales_order
       AND c.r3_sales_order_item = p_sales_order_item;

  CURSOR c_get_heat_melt_method (p_heat_no VARCHAR2) IS
    SELECT A.ingot_num_of_melts
      FROM te_spec_code_header A, r3_sales_order_items c, r3_process_orders d
     WHERE A.spec_code_id = c.spec_code_id
       AND c.r3_sales_order = d.r3_sales_order
       AND c.r3_sales_order_item = d.r3_sales_order_item
       AND d.r3_process_order = p_heat_no
       AND d.process_order_status <> 'E'
       AND c.plant_no <> 11
    ORDER BY d.date_created DESC;

  BEGIN

    IF p_batch_no_in IS NULL THEN
      OPEN c_get_heat_melt_method (p_heat_no_in);
      FETCH c_get_heat_melt_method INTO lv_melt_method;
      CLOSE c_get_heat_melt_method;
    ELSE
      OPEN c_get_so_melt_method (p_batch_no_in, p_sales_order_in, p_sales_order_item_in);
      FETCH c_get_so_melt_method INTO lv_site, lv_melt_method, lv_process_order_status;
      CLOSE c_get_so_melt_method;

      IF NVL(lv_site,0) = 11 THEN
        lv_melt_method := NULL;
        OPEN c_get_heat_melt_method (p_heat_no_in);
        FETCH c_get_heat_melt_method INTO lv_melt_method;
        CLOSE c_get_heat_melt_method;
      ELSIF NVL(lv_process_order_status,'X') = 'E' THEN
        lv_melt_method := NULL;
      END IF;
    END IF;

    RETURN lv_melt_method;

  END fn_get_melt_method;


FUNCTION fn_set_nbt_based_on_heat( p_heat_id_in      IN mt_us_heats.heat_id%TYPE
                                 , p_heat_num_in     IN mt_us_heats.heat_num%TYPE
                                 , p_process_type_in IN mt_order_deviations.process_type%TYPE ) RETURN pk_melt.nbt_fields IS

  lv_nbt_fields   pk_melt.nbt_fields                           := NULL;
  lv_spec_code_id te_spec_code_header.spec_code_id%TYPE;
  clMPEHeats      pk_mpe_lookup.ctMPEHeats;

  CURSOR num_nse_cur ( p_heat_num_in IN mt_us_heats.heat_num%TYPE ) IS
  SELECT COUNT ( DISTINCT el.ns_event_id )
  FROM   ns_event_lines   el
       , ns_event_headers eh
       , st_users         su
  WHERE el.ns_event_id  = eh.ns_event_id
   AND   eh.rec_status  = 'A'
   AND   el.cast_number = p_heat_num_in
   AND   su.user_login  = eh.notified_by
   AND   su.home_site   = '20';

  CURSOR rpo_cur ( p_heat_num_in IN mt_us_heats.heat_num%TYPE
                 , p_heat_id_in  IN mt_us_heats.heat_id%TYPE          ) IS
  SELECT rpo.r3_sales_order
       , rpo.r3_sales_order_item
  FROM   r3_process_orders    rpo
       , r3_sales_order_items soi
       , mt_us_heats          ush
  WHERE  rpo.r3_process_order      = p_heat_num_in
  AND    rpo.process_order_status  <> 'E'
  AND    ush.heat_id               = p_heat_id_in
  AND    ush.site                  = soi.plant_no
  AND    rpo.r3_sales_order        = soi.r3_sales_order
  AND    rpo.r3_sales_order_item   = soi.r3_sales_order_item
  ORDER BY rpo.date_created DESC;

  CURSOR melt_date_cur ( p_heat_id_in IN mt_us_heats.heat_id%TYPE ) IS
  SELECT us.melt_date
       , us.electrode_id
  FROM   mt_us_heats us
  WHERE  us.heat_id = p_heat_id_in;

  CURSOR eb_info_cur( p_heat_num_in IN mt_us_heats.heat_num%TYPE ) IS
  SELECT eb.melt_weight
       , eb.melt_weight_uom
       , DECODE ( eb.bc_applicable_yn, 'Y', TO_CHAR ( eb.bc_weight ), 'NA')
       , DECODE ( eb.bc_applicable_yn, 'Y', eb.bc_weight_uom, NULL)
       , DECODE ( eb.bc_applicable_yn, 'Y', bc.lot_num, 'NA')
  FROM   mt_eb_melts eb
       , mt_us_heats us
       , mt_bc_lots  bc
  WHERE  us.heat_num  = p_heat_num_in
  AND    us.heat_id   = eb.heat_id
  AND    eb.bc_lot_id = bc.bc_lot_id (+);

  CURSOR cust_name_cur ( p_sales_order_num_in IN r3_sales_orders.r3_sales_order%TYPE ) IS
  SELECT so.sap_sold_to_name
  FROM   r3_sales_orders so
  WHERE  so.r3_sales_order = p_sales_order_num_in;

  CURSOR spec_code_id_cur ( p_sales_order_num_in  IN r3_sales_orders.r3_sales_order%TYPE
                         ,  p_sales_order_item_in IN r3_sales_order_items.r3_sales_order_item%TYPE  ) IS
  SELECT soi.spec_code_id
  FROM   r3_sales_order_items soi
  WHERE  soi.r3_sales_order      = p_sales_order_num_in
  AND    soi.r3_sales_order_item = p_sales_order_item_in;

  CURSOR spec_header_cur ( p_spec_code_id_in IN te_spec_code_header.spec_code_id%TYPE ) IS
  SELECT sch.spec_code_name
       , sch.alloy_code
       , sch.grade_code
  FROM   te_spec_code_header sch
  WHERE  sch.spec_code_id = p_spec_code_id_in;

  CURSOR ipo_entries_cur ( p_sales_order_num_in  IN r3_sales_orders.r3_sales_order%TYPE
                         , p_sales_order_item_in IN r3_sales_order_items.r3_sales_order_item%TYPE
                         , p_spec_code_id_in     IN te_spec_code_header.spec_code_id%TYPE                  ) IS
  SELECT mcm.mold eb_mold_size
       , ipo.recipe_no
       , ipo.recipe_no_1
       , ipo.recipe_no_2
       , ipo.var_cast_size
  FROM   te_ipo_entries ipo
         ,mt_chm_molds mcm
  WHERE  ipo.sales_order_no   = p_sales_order_num_in
  AND    ipo.sales_order_item = p_sales_order_item_in
  AND    ipo.spec_code_id     = p_spec_code_id_in
  AND    ipo.mold_size_id = mcm.mold_size_id
  AND    ipo.rec_status       <> 'E';

  CURSOR crGetLinearDensity(cptMoldSize_in IN mt_chm_molds.mold%TYPE
                            ,cptAlloyCode_in IN te_spec_code_header.alloy_code%TYPE) IS
   SELECT mmld.linear_density ,mmld.tolerance -- STCR 7383 added tolerance
     FROM MT_MOLD_LINEAR_DENSITIES mmld
          ,MT_CHM_MOLDS mcm
    WHERE mmld.mold_size_id = mcm.mold_size_id
      AND mcm.mold = cptMoldSize_in
      AND mmld.alloy_code = cptAlloyCode_in
      AND mmld.rec_status = 'A'
      AND mcm.rec_status = 'A';

  CURSOR add_samples_cur( p_heat_id_in IN mt_us_heats.heat_id%TYPE ) IS
  SELECT COUNT(*)
  FROM   mt_sampling_requests sr
  WHERE  sr.heat_id = p_heat_id_in;

  CURSOR internal_cuts_cur( p_heat_id_in IN mt_us_heats.heat_id%TYPE ) IS
  SELECT COUNT(*)
  FROM   mt_internal_cuts ic
  WHERE  ic.heat_id = p_heat_id_in;

  CURSOR external_cuts_cur( p_heat_id_in IN mt_us_heats.heat_id%TYPE ) IS
  SELECT COUNT(*)
  FROM   mt_external_cuts ec
  WHERE  ec.heat_id = p_heat_id_in;

BEGIN

  OPEN rpo_cur( p_heat_num_in => p_heat_num_in
              , p_heat_id_in  => p_heat_id_in   );
  FETCH rpo_cur INTO lv_nbt_fields.nbt_sales_order_num, lv_nbt_fields.nbt_sales_order_item;
  CLOSE rpo_cur;

  IF lv_nbt_fields.nbt_sales_order_num IS NOT NULL
    AND lv_nbt_fields.nbt_sales_order_item IS NOT NULL THEN
    OPEN cust_name_cur( p_sales_order_num_in => lv_nbt_fields.nbt_sales_order_num );
    FETCH cust_name_cur INTO lv_nbt_fields.nbt_customer_name;
    CLOSE cust_name_cur;

    OPEN spec_code_id_cur( p_sales_order_num_in => lv_nbt_fields.nbt_sales_order_num
                         , p_sales_order_item_in => lv_nbt_fields.nbt_sales_order_item
                         );
    FETCH spec_code_id_cur INTO lv_spec_code_id;

    IF spec_code_id_cur%FOUND THEN

      OPEN spec_header_cur( p_spec_code_id_in => lv_spec_code_id );
      FETCH spec_header_cur INTO lv_nbt_fields.nbt_order_spec_name
                               , lv_nbt_fields.nbt_alloy_code
                               , lv_nbt_fields.nbt_quality_code;
      CLOSE spec_header_cur;

      OPEN ipo_entries_cur( p_sales_order_num_in => lv_nbt_fields.nbt_sales_order_num
                          , p_sales_order_item_in => lv_nbt_fields.nbt_sales_order_item
                          , p_spec_code_id_in => lv_spec_code_id
                          );
      FETCH ipo_entries_cur INTO lv_nbt_fields.nbt_mold_size
                               , lv_nbt_fields.nbt_eb_recipe
                               , lv_nbt_fields.nbt_melting_recipe_1
                               , lv_nbt_fields.nbt_melting_recipe_2
                               , lv_nbt_fields.nbt_ingot_diameter;
      CLOSE ipo_entries_cur;

    END IF;

    CLOSE spec_code_id_cur;

  END IF;

  OPEN  melt_date_cur( p_heat_id_in => p_heat_id_in );
  FETCH melt_date_cur INTO lv_nbt_fields.nbt_melt_date, lv_nbt_fields.nbt_electrode_num;
  CLOSE melt_date_cur;

  IF lv_nbt_fields.nbt_electrode_num IS NOT NULL THEN

    OPEN eb_info_cur( p_heat_num_in => lv_nbt_fields.nbt_electrode_num );
    FETCH eb_info_cur INTO lv_nbt_fields.nbt_electrode_weight
                         , lv_nbt_fields.nbt_electrode_weight_uom
                         , lv_nbt_fields.nbt_bc_weight
                         , lv_nbt_fields.nbt_bc_weight_uom
                         , lv_nbt_fields.nbt_bc_lot_num;
    CLOSE eb_info_cur;

  END IF;

-- STCR 6612 start

  OPEN num_nse_cur( p_heat_num_in => lv_nbt_fields.nbt_electrode_num );
  FETCH num_nse_cur INTO lv_nbt_fields.nbt_num_of_electrode_nses;
  CLOSE num_nse_cur;

-- STCR 6612 End

  OPEN num_nse_cur( p_heat_num_in => p_heat_num_in );
  FETCH num_nse_cur INTO lv_nbt_fields.nbt_num_of_nses;
  CLOSE num_nse_cur;

  lv_nbt_fields.nbt_num_of_order_devs := fnGetOrderDevCount(pnmHeatId_in      => p_heat_id_in,
                                                            pnmCutPieceId_in  => NULL,
                                                            pvcProcessType_in => p_process_type_in);

  pk_mpe_lookup.prGetMPEHeats(pvcHeatNo_in    => p_heat_num_in,
                              pclMPEHeats_out => clMPEHeats);

  lv_nbt_fields.nbt_num_of_mpes := clMPEHeats.COUNT;

  OPEN  add_samples_cur ( p_heat_id_in =>  p_heat_id_in );
  FETCH add_samples_cur INTO lv_nbt_fields.nbt_num_of_samples;
  CLOSE add_samples_cur;

  OPEN  internal_cuts_cur ( p_heat_id_in =>  p_heat_id_in );
  FETCH internal_cuts_cur INTO lv_nbt_fields.nbt_num_of_int_cuts;
  CLOSE internal_cuts_cur;

  OPEN  external_cuts_cur ( p_heat_id_in =>  p_heat_id_in );
  FETCH external_cuts_cur INTO lv_nbt_fields.nbt_num_of_ext_cuts;
  CLOSE external_cuts_cur;
  OPEN crGetLinearDensity(cptMoldSize_in => UPPER(lv_nbt_fields.nbt_mold_size)
                          ,cptAlloyCode_in => lv_nbt_fields.nbt_alloy_code);
  FETCH crGetLinearDensity INTO lv_nbt_fields.nbt_linear_density,lv_nbt_fields.nbt_tolerance; -- STCR 7383 added  nbt_tolerance
  CLOSE crGetLinearDensity;

  RETURN lv_nbt_fields;

END fn_set_nbt_based_on_heat;


FUNCTION fn_get_swap_reason( p_swap_reason_id_in IN MT_SWAP_REASONS.swap_reason_id%TYPE )
                             RETURN MT_SWAP_REASONS.swap_reason_name%TYPE IS

  lv_swap_reason_name MT_SWAP_REASONS.swap_reason_name%TYPE;

  CURSOR get_reason_name( p_swap_reason_id_in IN MT_SWAP_REASONS.swap_reason_id%TYPE ) IS
  SELECT swap_reason_name
  FROM   mt_swap_reasons
  WHERE  swap_reason_id = p_swap_reason_id_in;

BEGIN
  OPEN get_reason_name( p_swap_reason_id_in => p_swap_reason_id_in );
  FETCH get_reason_name INTO lv_swap_reason_name;
  CLOSE get_reason_name;

  RETURN lv_swap_reason_name;
END;


FUNCTION fnGetInputType( pnmInputTypeId_in IN RM_INPUT_TYPES.input_type_id%TYPE ) RETURN RM_INPUT_TYPES.input_type%TYPE IS

  vcInputType RM_INPUT_TYPES.input_type%TYPE;

  CURSOR crGetInputType( cpInputTypeId_in IN RM_INPUT_TYPES.input_type_id%TYPE ) IS
  SELECT input_type
  FROM   rm_input_types
  WHERE  input_type_id = cpInputTypeId_in;

BEGIN
  OPEN crGetInputType( cpInputTypeId_in => pnmInputTypeId_in );
  FETCH crGetInputType INTO vcInputType;
  CLOSE crGetInputType;

  RETURN vcInputType;
END fnGetInputType;


FUNCTION fnGetSpecIdByHeatId(pnmHeatId_in IN mt_us_heats.heat_id%TYPE)
                             RETURN r3_sales_order_items.spec_code_id%TYPE IS

  CURSOR crHeat (cpnmHeatId_in mt_us_heats.heat_id%TYPE) IS
  SELECT soi.spec_code_id
    FROM mt_us_heats h,
         r3_process_orders po,
         r3_sales_order_items soi
   WHERE h.heat_id = cpnmHeatId_in
     AND h.site = soi.plant_no
     AND h.heat_num = po.r3_process_order
     AND po.process_order_status <> 'E'
     AND po.r3_sales_order = soi.r3_sales_order
     AND po.r3_sales_order_item = soi.r3_sales_order_item
ORDER BY po.date_created desc;

  nmSpecCodeId r3_sales_order_items.spec_code_id%TYPE;

BEGIN
    OPEN crHeat(cpnmHeatId_in => pnmHeatId_in);
    FETCH crHeat INTO nmSpecCodeId;
    CLOSE crHeat;
    RETURN nmSpecCodeId;
END fnGetSpecIdByHeatId;


FUNCTION fnGetOrderDevCount(pnmHeatId_in      IN mt_order_deviations.heat_id%TYPE,
                            pnmCutPieceId_in  IN mt_order_deviations.cut_piece_id%TYPE,
                            pvcProcessType_in IN mt_order_deviations.process_type%TYPE)
                            RETURN number IS

  CURSOR crOrderDevCount (cpnmHeatId_in      IN mt_order_deviations.heat_id%TYPE,
                          cpnmCutPieceId_in  IN mt_order_deviations.cut_piece_id%TYPE,
                          cpvcProcessType_in IN mt_order_deviations.process_type%TYPE) IS
  SELECT COUNT(*)
    FROM mt_order_deviations
   WHERE heat_id = cpnmheatId_in
     AND NVL(cut_piece_id, 0) = NVL(cpnmCutPieceId_in, NVL(cut_piece_id, 0))
     AND process_type = NVL(cpvcProcessType_in, process_type)
     AND rec_status = pk_star_constants.vcActiveRecord;

  nmOrderDevCount number;

BEGIN
  OPEN crOrderDevCount(cpnmHeatId_in      => pnmHeatId_in,
                       cpnmCutPieceId_in  => pnmCutPieceId_in,
                       cpvcProcessType_in => pvcProcessType_in);
  FETCH crOrderDevCount INTO nmOrderDevCount;
  CLOSE crOrderDevCount;
  RETURN nmOrderDevCount;
END fnGetOrderDevCount;


PROCEDURE prEmailMFG(pnmMeltId_in         IN  mt_eb_melts.melt_id%TYPE,
                     pvcOutcomeStatus_out OUT pk_email.pv_outcome_status%TYPE) IS

  CURSOR crHeat(cpnmMeltId_in mt_eb_melts.melt_id%TYPE) IS
    SELECT b.site, b.heat_num
      FROM mt_eb_melts A,
           mt_us_heats b
     WHERE A.melt_id = cpnmMeltId_in
       AND A.heat_id = b.heat_id;

  vcSite           mt_us_heats.site%TYPE;
  vcHeatNum        mt_us_heats.heat_num%TYPE;
  vcOutcomeMessage pk_email.pv_outcome_message%TYPE;
  vcMessageText    st_email_queue_headers.message_text%TYPE;
  vcSubject        st_email_queue_headers.subject%TYPE;
  clEmailParams    pk_star_programs.text_parameters;

BEGIN
  OPEN crHeat(cpnmMeltId_in => pnmMeltId_in);
  FETCH crHeat INTO vcSite, vcHeatNum;
  CLOSE crHeat;

  clEmailParams := pk_star_programs.text_parameters();
  pk_star_programs.pr_add_text_parameters(p_text_parameters => clEmailParams,
                                          p_parameter       => vcHeatNum);

  vcSubject := pk_star_programs.fn_get_module_text(p_module_name => 'PK_MELT',
                                                   p_text_key    => 'VAR_RELEASE_EMAIL_SUBJECT',
                                                   p_parameters  => clEmailParams);

  vcMessageText := pk_star_programs.fn_get_module_text(p_module_name => 'PK_MELT',
                                                       p_text_key    => 'VAR_RELEASE_EMAIL_TEXT',
                                                       p_parameters  => clEmailParams);

  pk_email.pr_email_an_event (p_event_id_in              => 136,
                              p_additional_recipients_in => pk_collection_types.user_login_list_t(),
                              p_message_text_in          => vcMessageText,
                              p_subject_in               => vcSubject,
                              p_event_specific_data_in   => 'Program: EB Melt VAR Release',
                              p_outcome_status_out       => pvcOutcomeStatus_out,
                              p_outcome_message_out      => vcOutcomeMessage);

END prEmailMFG;


FUNCTION fnMeltPositionExists(pnmHeatID_in   IN mt_positions.heat_id%TYPE,
                              pvcPosition_in IN mt_positions.position%TYPE)
                              RETURN BOOLEAN IS

  CURSOR crMeltPosition(cpnmHeatID_in   IN mt_positions.heat_id%TYPE,
                        cpvcPosition_in IN mt_positions.position%TYPE) IS
    SELECT position
      FROM mt_positions
     WHERE heat_id = cpnmHeatID_in
       AND position = cpvcPosition_in;

  vcPosition   mt_positions.position%TYPE;

BEGIN

  OPEN crMeltPosition(cpnmHeatID_in   => pnmHeatID_in,
                      cpvcPosition_in => pvcPosition_in);
  FETCH crMeltPosition INTO vcPosition;
  CLOSE crMeltPosition;
  IF vcPosition IS NULL THEN
    RETURN FALSE;
  ELSE
    RETURN TRUE;
  END IF;

END fnMeltPositionExists;


PROCEDURE prHeatAlloyCheck(pvcHeatNum_in     IN varchar2,
                           pvcAlloyCode_in   IN st_alloys.alloy_code%TYPE,
                           pvcCheckSource_in IN varchar2) IS

  CURSOR crHeatUS(cpvcHeatNum_in   IN varchar2,
                  cpvcAlloyCode_in IN varchar2) IS
    SELECT alloy_code,
           'US'
      FROM mt_us_heats
     WHERE heat_num = cpvcHeatNum_in
       AND alloy_code != cpvcAlloyCode_in;

  CURSOR crHeatUK(cpvcElectrodeRef_in IN varchar2,
                  cpvcAlloyCode_in    IN varchar2) IS
    SELECT alloy_code,
           'UK'
      FROM mt_electrode_headers
     WHERE electrode_ref = cpvcElectrodeRef_in
       AND alloy_code != cpvcAlloyCode_in
       AND electrode_ref NOT IN (SELECT electrode_ref
                                 FROM   mt_electrode_headers
                                 WHERE  electrode_ref = cpvcElectrodeRef_in
                                 AND    TRUNC(date_created) = '08-JAN-1999'
                                 AND    created_by = 'STAR');


  --CURSOR crHeatBM(cpvcHeatNo_in    IN varchar2,     --Commented out by STCR 7643
  --                cpvcAlloyCode_in IN varchar2) IS
  --  SELECT alloy_code,
  --         'BM'
  --    FROM st_bought_in_material
  --   WHERE heat_no = cpvcHeatNo_in
  --     AND alloy_code != cpvcAlloyCode_in;

  vcAlloyCode  varchar2(8);
  vcHeatSource varchar2(50);

BEGIN

  IF pvcCheckSource_in != 'US' THEN
    OPEN crHeatUS(cpvcHeatNum_in   => pvcHeatNum_in,
                  cpvcAlloyCode_in => pvcAlloyCode_in);
    FETCH crHeatUS INTO vcAlloyCode, vcHeatSource;
    CLOSE crHeatUS;
  END IF;

  IF vcAlloyCode IS NULL AND pvcCheckSource_in != 'UK' THEN
    OPEN crHeatUK(cpvcElectrodeRef_in => pvcHeatNum_in,
                  cpvcAlloyCode_in    => pvcAlloyCode_in);
    FETCH crHeatUK INTO vcAlloyCode, vcHeatSource;
    CLOSE crHeatUK;
  END IF;

  --IF vcAlloyCode IS NULL AND pvcCheckSource_in != 'BM' THEN  --Commented out by STCR 7643
  --  OPEN crHeatBM(cpvcHeatNo_in    => pvcHeatNum_in,
  --                cpvcAlloyCode_in => pvcAlloyCode_in);
  --  FETCH crHeatBM INTO vcAlloyCode, vcHeatSource;
  --  CLOSE crHeatBM;
  --END IF;

  IF vcAlloyCode IS NOT NULL THEN
    IF vcHeatSource = 'US' THEN
      vcHeatSource := pk_star_programs.fn_get_module_text('MT_0201_US_HEATS', 'PROGRAM_TITLE');
    ELSIF vcHeatSource = 'UK' THEN
      vcHeatSource := pk_star_programs.fn_get_module_text('MT_ELECT_HDR', 'PROGRAM_TITLE');
    --ELSIF vcHeatSource = 'BM' THEN                                                                  --Commented out by STCR 7643
    --  vcHeatSource := pk_star_programs.fn_get_module_text('ST_BOUGHT_IN_MATERIAL', 'PROGRAM_TITLE');--Commented out by STCR 7643
    END IF;
    pk_star_programs.p_raise_star_error(1215, pvcHeatNum_in, pvcAlloyCode_in, vcAlloyCode, vcHeatSource);
  END IF;

END prHeatAlloyCheck;

FUNCTION fnGetOOSChemistryByHeat(pvcProcessOrderNo_in IN te_test_sample_id.process_order_no%TYPE,
                                 pvcSalesOrder_in     IN r3_sales_order_items.r3_sales_order%TYPE,
                                 pvcSalesOrderItem_in IN r3_sales_order_items.r3_sales_order_item%TYPE)
                                 RETURN varchar2 IS
  TYPE ref_cur IS REF CURSOR;
  crTestResults    ref_cur;
  vcTestResultsSQL varchar2(1000) :=
     'select c.sample_id, '
   ||       'c.piece_id, '
   ||       'd.test_code, '
   ||       'd.act_result '
   ||  'from r3_sales_order_items a, '
   ||       'r3_process_orders b, '
   ||       'te_test_sample_id c, '
   ||       'te_test_results d '
   || 'where a.r3_sales_order = :cpvcSalesOrder_in '
   ||   'and a.r3_sales_order_item = :cpvcSalesOrderItem_in '
   ||   'and a.r3_sales_order = b.r3_sales_order '
   ||   'and a.r3_sales_order_item = b.r3_sales_order_item '
   ||   'and b.r3_process_order = :cpvcProcessOrderNo_in '
   ||   'and b.r3_process_order = c.process_order_no '
   ||   'and a.spec_code_id = c.spec_code_id '
   ||   'and c.sample_id = d.sample_id '
   ||   'and c.valid_sample_yn = ''Y'' '
   ||   'and nvl(d.valid_result, ''N'') = ''Y'' '
   ||   'and nvl(c.sign_off_status, ''N'') = ''A'' ';
  vcCountSQL       varchar2(1000);
  rcLoadLimits     pk_test_result_rounding.load_limits_rec;
  rcSampleResult   pk_test_result_rounding.sample_result_rec;
  vcOOSResults     varchar2(3000);
  vcHighLow        varchar2(5);
  nmSampleId       te_test_sample_id.sample_id%TYPE;
  vcPieceId        te_test_sample_id.piece_id%TYPE;
  vcTestCode       te_test_results.test_code%TYPE;
  vcActResult      te_test_results.act_result%TYPE;

BEGIN

  vcCountSQL := vcTestResultsSQL || 'and pk_test_results.fn_is_number_yn(c.piece_id) = ''N''';
  OPEN crTestResults FOR vcCountSQL USING pvcSalesOrder_in, pvcSalesOrderItem_in, pvcProcessOrderNo_in;
  FETCH crTestResults INTO nmSampleId, vcPieceId, vcTestCode, vcActResult;
  CLOSE crTestResults;
  IF nmSampleId IS NOT NULL THEN -- There is at least one piece_id that is NOT numeric
    vcTestResultsSQL := vcTestResultsSQL || 'order by c.piece_id, d.test_code';
  ELSE
    vcTestResultsSQL := vcTestResultsSQL || 'order by to_number(c.piece_id), d.test_code';
  END IF;

  OPEN crTestResults FOR vcTestResultsSQL USING pvcSalesOrder_in, pvcSalesOrderItem_in, pvcProcessOrderNo_in;
  LOOP
    FETCH crTestResults INTO nmSampleId, vcPieceId, vcTestCode, vcActResult;
    exit WHEN crTestResults%NOTFOUND;

    rcSampleResult := NULL;
    rcLoadLimits := NULL;
    rcSampleResult.sample_id := nmSampleId;
    rcSampleResult.test_code := vcTestCode;
    pk_test_result_rounding.pr_populate_result_recs(p_sample_result_rec => rcSampleResult,
                                                    p_load_limits_rec   => rcLoadLimits);
    rcSampleResult.ack_result := NULL;
    pk_test_result_rounding.pr_check_limits(p_sample_result_rec => rcSampleResult,
                                            p_load_limits_rec   => rcLoadLimits);
    IF rcSampleResult.pass_limit = 'N' THEN
      IF vcOOSResults IS NOT NULL THEN
        vcOOSResults := vcOOSResults || CHR(10);
      END IF;
      IF rcSampleResult.rnd_oos_flag = 'GREATER' THEN
        vcHighLow := 'High ';
      ELSIF rcSampleResult.rnd_oos_flag = 'LESS' THEN
        vcHighLow := 'Low ';
      ELSE
        vcHighLow := NULL;
      END IF;
      vcOOSResults := vcOOSResults || vcPieceId || ', ' || vcHighLow || vcTestCode || ', ' || vcActResult;
    END IF;
  END LOOP;
  CLOSE crTestResults;
  RETURN vcOOSResults;
END fnGetOOSChemistryByHeat;


PROCEDURE fnGetElectrodeNSECount( pvcElectrodeRef_in IN MT_ELECTRODE_HEADERS.electrode_ref%TYPE
                                , pnmNSECount_out OUT NUMBER
                                , pvcEventString_out OUT VARCHAR2
                                ) IS
--Modified this function for STCR 7379 to get the cast number using the function
--We are getting the cast number from the process orders as per the change in STCR 7379
  CURSOR crGetNSCounts( cpvcElectrodeRef_in IN MT_ELECTRODE_HEADERS.electrode_ref%TYPE ) IS
  SELECT DISTINCT neh.ns_event_id
  FROM   ns_event_lines nel, ns_event_headers neh
  WHERE  nel.ns_event_id = neh.ns_event_id
  AND    neh.rec_status = 'A'
  AND    nel.cast_number = pk_melt_api.fnGetParentElectrode(pElectrodeRef_in => pvcElectrodeRef_in);
BEGIN
  pnmNSECount_out := 0;
  --For the count return the count of all NSEs of the cast and component electrodes
  FOR frGetNSCounts IN crGetNSCounts( cpvcElectrodeRef_in => pvcElectrodeRef_in ) LOOP
    pvcEventString_out := pvcEventString_out || TO_CHAR( frGetNSCounts.ns_event_id ) || ',';
    pnmNSECount_out := pnmNSECount_out + 1;
  END LOOP;

  pvcEventString_out := RTRIM( pvcEventString_out, ',' );
END fnGetElectrodeNSECount;

FUNCTION fnchkMeltProfilePropExist(pnmMeltProfileId_in IN     mt_melt_profile_properties.melt_profile_id%TYPE
                                  ,pvcQualityCode_in   IN     mt_melt_profile_properties.quality_code%TYPE
                                  ,pvcAlloyCode_in     IN     mt_melt_profile_properties.alloy_code%TYPE
                                  ,pnnRecipeId_in      IN     mt_recipes.recipe_id%TYPE DEFAULT NULL) RETURN BOOLEAN IS

  CURSOR crGetPropertiesRecipe IS
  SELECT alloy_code,
         quality_code
  FROM   mt_melt_profile_properties
  WHERE  mtmepp_id IN (SELECT mtmepp_id
                       FROM   mt_recipe_profiles
                       WHERE  recipe_id = pnnRecipeId_in
                       AND    rec_status = 'A');

  CURSOR crGetPropertiesProfile IS
  SELECT alloy_code,
         quality_code
  FROM   mt_melt_profile_properties
  WHERE  melt_profile_id = pnmMeltProfileId_in
  AND    rec_status = 'A';


  vcAlloyFailYN     VARCHAR2(1)  := 'Y';
  vcQualityFailYN   VARCHAR2(1)  := 'Y';
  vcAlloyExistYN    VARCHAR2(1)  := 'N';
  vcQualityExistYN  VARCHAR2(1)  := 'N';

BEGIN

  --If a recipe has been supplied make use of relevant cursor
  IF pnnRecipeId_in IS NOT NULL THEN

    FOR frGetProperties IN crGetPropertiesRecipe LOOP
      -- match the alloc code to the property value
      IF frGetProperties.alloy_code IS NOT NULL THEN
        vcAlloyExistYN := 'Y';
        IF frGetProperties.alloy_code = pvcAlloyCode_in THEN
          vcAlloyFailYN := 'N';
        END IF;
      END IF;

      -- Match the grade code to the property value
      IF frGetProperties.quality_code IS NOT NULL THEN
        vcQualityExistYN := 'Y';
        IF frGetProperties.quality_code = pvcQualityCode_in THEN
          vcQualityFailYN := 'N';
        END IF;
      END IF;

      -- Match the grade code to the property value
      IF frGetProperties.quality_code IS NOT NULL THEN
        vcQualityExistYN := 'Y';
        IF frGetProperties.quality_code = pvcQualityCode_in THEN
          vcQualityFailYN := 'N';
        END IF;
      END IF;
    END LOOP;

  ELSE

    FOR frGetProperties IN crGetPropertiesProfile LOOP
      -- match the alloc code to the property value
      IF frGetProperties.alloy_code IS NOT NULL THEN
        vcAlloyExistYN := 'Y';
        IF frGetProperties.alloy_code = pvcAlloyCode_in THEN
          vcAlloyFailYN := 'N';
        END IF;
      END IF;

      -- Match the grade code to the property value
      IF frGetProperties.quality_code IS NOT NULL THEN
        vcQualityExistYN := 'Y';
        IF frGetProperties.quality_code = pvcQualityCode_in THEN
          vcQualityFailYN := 'N';
        END IF;
      END IF;
    END LOOP;

  END IF;

  -- Check whether either code doesn't exist in the profile properties
  -- If either code fails then return false
  IF vcAlloyExistYN = 'Y' AND
     vcAlloyFailYN = 'Y' THEN

    RETURN FALSE;
  END IF;

  IF vcQualityExistYN = 'Y' AND
     vcQualityFailYN = 'Y' THEN

    RETURN FALSE;
  ELSE
    RETURN TRUE;
  END IF;

END fnchkMeltProfilePropExist;

PROCEDURE prCreateDefaultSamples ( ptMeltID_in         IN mt_sample_locations.melt_id%TYPE,
                                   ptQualityCode_in    IN te_grade_codes.grade_code%TYPE ) IS

-- This procedure creates a default set of sample locations based on master data
-- It will expire any existing records that are not default and refresh any existing defaults


CURSOR crCreateDefaultSampLocs ( cptQualityCode_in IN te_grade_codes.grade_code%TYPE ) IS
SELECT NAME sample_name,
       sort_id,
       LOCATION
FROM mt_default_sample_locs
WHERE quality_code = cptQualityCode_in
AND   rec_status   = 'A';

CURSOR crChkSampleLocExists ( cptSampleName_in IN mt_sample_locations.sample_name%TYPE,
                              cptMeltId_in     IN mt_sample_locations.melt_id%TYPE )    IS
SELECT sample_location_id
FROM mt_sample_locations
WHERE sample_name = cptSampleName_in
AND   melt_id     = cptMeltId_in;

ltSampleLocationID mt_sample_locations.sample_location_id%TYPE;
vcErrLoc           VARCHAR2 ( 4 );

BEGIN

  vcErrLoc := '0000';

  -- Firstly expire all non default records for that melt_id and quality code
  UPDATE mt_sample_locations locs
  SET rec_status = 'E'
  WHERE sample_location_id IN ( SELECT msl.sample_location_id
                                FROM   mt_sample_locations msl,
                                       mt_eb_melts            mel
                                WHERE  msl.melt_id  = ptMeltID_in
                                AND   mel.melt_id   = msl.melt_id
                                AND   sample_name NOT IN ( SELECT NAME
                                                           FROM mt_default_sample_locs
                                                           WHERE quality_code = ptQualityCode_in ));

                                                                                -- Create sample location for the melt based on the master data
  vcErrLoc := '0100';

  FOR cfCreateDefaultSampLocs IN crCreateDefaultSampLocs ( cptQualityCode_in => ptQualityCode_in ) LOOP

    OPEN crChkSampleLocExists ( cptSampleName_in => cfCreateDefaultSampLocs.sample_name,
                                cptMeltId_in     => ptMeltID_in);
    FETCH crChkSampleLocExists INTO ltSampleLocationID;

    IF crChkSampleLocExists%NOTFOUND THEN

      INSERT INTO mt_sample_locations ( sample_location_id,
                                        melt_id,
                                        sort_id,
                                        sample_name,
                                        LOCATION )
       VALUES  ( NULL,                                              -- sample_location_id
                 ptMeltID_in,                                       -- melt_id
                 cfCreateDefaultSampLocs.sort_id,                   -- sort_id
                 cfCreateDefaultSampLocs.sample_name,               -- sample_name
                 cfcreatedefaultsamplocs.LOCATION );                -- location

    ELSE

      UPDATE mt_sample_locations
      SET sort_id     = cfCreateDefaultSampLocs.sort_id,
          LOCATION    = cfCreateDefaultSampLocs.LOCATION,
          rec_status  = 'A'
      WHERE sample_location_id = ltSampleLocationID;

    END IF;

    CLOSE crChkSampleLocExists;

  END LOOP;

  vcErrLoc := '9999';

EXCEPTION

  WHEN OTHERS THEN

    pk_error_log.prRecordDetailsHalt ( p_SqlCode_in    => SQLCODE,
                                       p_SqlErrm_in    => SQLERRM,
                                       p_ModuleName_in => 'pk_melt.prCreateDefaultSamples',
                                       p_KeyData_in    =>  'Melt ID: '      || ptMeltID_in
                                                       || ' Quality Code: ' || ptQualityCode_in
                                                       || '; Debug position IS ' || vcErrLoc);

END prCreateDefaultSamples;
PROCEDURE prUpdateHeat(ptSpecCodeId_in         IN r3_sales_order_items.spec_code_id%TYPE,
                        ptR3IngotRef_in    IN r3_process_orders.r3_ingot_ref%TYPE ) IS
CURSOR crGetGradeAlloy(cptSpecCodeId_in IN r3_sales_order_items.spec_code_id%TYPE) IS
SELECT G.sub_grade
       ,soi.quality_grade_code
  FROM r3_sales_order_items soi
       ,te_spec_code_header s
       ,te_subgrades G
 WHERE  soi.spec_code_id = cptSpecCodeId_in
   AND    soi.spec_code_id = s.spec_code_id
   AND s.formulation_no = G.formulation_no;
   tSubGrade  te_subgrades.sub_grade%TYPE;
   tQualityGradeCode  r3_sales_order_items.quality_grade_code%TYPE;
BEGIN
OPEN crGetGradeAlloy(cptSpecCodeId_in => ptSpecCodeId_in);
FETCH crGetGradeAlloy INTO tSubGrade
                           ,tQualityGradeCode;
CLOSE crGetGradeAlloy;
--Site 23  & 24 may not have entry in mt us heats in which case this update will not modify any records
UPDATE mt_us_heats
   SET sub_grade_code = tSubGrade
       ,quality_grade_code = tQualityGradeCode
 WHERE heat_num = ptR3IngotRef_in;

END prUpdateHeat;

-- STCR 6917
PROCEDURE prUnpairBumperAndRings ( ptPairingID_in IN mt_bumper_ring_pairings.pairing_id%TYPE ) IS

vcProcedureName VARCHAR2(50) := 'prUnpairBumperAndRings';

BEGIN

  pk_debug.prWriteDebugRec ( ptModuleName_in =>  cnPackageName,
                             vcDebugText_in  => 'Start '|| vcProcedureName || ' ptPairingID_in = '  || ptPairingID_in );

  UPDATE mt_bumper_ring_pairings
  SET date_unpaired = SYSDATE
  WHERE pairing_id = ptPairingID_in;

  pk_debug.prWriteDebugRec ( ptModuleName_in =>  cnPackageName,
                             vcDebugText_in  => 'End '|| vcProcedureName || ' ptPairingID_in = '  || ptPairingID_in );

EXCEPTION

  WHEN OTHERS THEN

     pk_error_log.prRecordDetailsHalt( p_SqlCode_in    => SQLCODE
                                     , p_SqlErrm_in    => SUBSTR( SQLERRM, 1, 100 )
                                     , p_ModuleName_in => 'pk_melt.prUnpairBumperAndRings'
                                     , p_KeyData_in    => 'ptPairingID_in: ' || TO_CHAR ( ptPairingID_in ) );

END prUnpairBumperAndRings;
PROCEDURE prGetNSEs(pElectrodeRef_in IN mt_electrode_headers.electrode_ref%TYPE
                    ,pStatus_in IN ns_event_headers.status%TYPE
                    ,pNSEList_out OUT VARCHAR2) IS
CURSOR crGetCastNSEs(cpElectrodeRef_in IN mt_electrode_headers.electrode_ref%TYPE
                     ,cpStatus_in IN ns_event_headers.status%TYPE) IS
SELECT neh.ns_event_id
  FROM ns_event_lines nel
       ,ns_event_headers neh
 WHERE nel.ns_event_id = neh.ns_event_id
   AND neh.rec_status = 'A'
   AND nel.cast_number = cpElectrodeRef_in
   AND neh.status = cpStatus_in;
CURSOR crGetComponentNSEs(cpElectrodeRef_in IN mt_electrode_headers.electrode_ref%TYPE
                          ,cpStatus_in IN ns_event_headers.status%TYPE) IS
SELECT neh.ns_event_id
  FROM ns_event_lines nel
       ,ns_event_headers neh
 WHERE nel.ns_event_id = neh.ns_event_id
   AND neh.rec_status = 'A'
   AND nel.process_order = cpElectrodeRef_in
   AND neh.status = cpStatus_in;
   lvNSEList VARCHAR2(1000) := '';
BEGIN
--First check if this is a cast or component electrode STCR 7379
IF pk_melt_api.fnIsComponentElectrode(pElectrodeRef_in => pElectrodeRef_in) THEN --Component electrode
   FOR rcGetComponentNSEs IN crGetComponentNSEs(cpElectrodeRef_in => pElectrodeRef_in
                                                ,cpStatus_in => pStatus_in) LOOP
       lvNSEList := lvNSEList||TO_CHAR(rcGetComponentNSEs.ns_event_id)||',';
   END LOOP;
ELSE --parent electrode so use cast number in non std lines
   FOR rcGetCastNSEs IN crGetCastNSEs(cpElectrodeRef_in => pElectrodeRef_in
                                      ,cpStatus_in => pStatus_in) LOOP
       lvNSEList := lvNSEList||TO_CHAR(rcGetCastNSEs.ns_event_id)||',';
   END LOOP;
END IF;
IF lvNSEList IS NOT NULL THEN
   lvNSEList := RTRIM(lvNSEList,',');
END IF;
pNSEList_out := lvNSEList;
END;



-----------------------------------------------------------------------STCR7663
-- f n G e t M e l t S i t e                                FUNCTION --STCR7663
-----------------------------------------------------------------------STCR7663
-- Return Melt Site based on query the following tables in this order--STCR7663
-- MT_US_HEATS                                                       --STCR7663
-- BL_INGOTS                                                         --STCR7663
-- ST_BOUGHT_IN_MATERIAL                                             --STCR7663
-----------------------------------------------------------------------STCR7663
FUNCTION fnGetMeltSite(pHeatNo_in IN  VARCHAR2)
                       RETURN varchar2 is

----------------------------------
-- V A R I A B L E S            --
----------------------------------
--
lvHeatSource        VARCHAR2(2);
numeric_error    EXCEPTION; 
 
---------------------------------
-- C U R S O R S               --
---------------------------------

-------------------------------------------------------------------------------
-- C U R S O R   c r G e t U S _ S o u r c e                    MT_US_HEATS  --
-------------------------------------------------------------------------------
CURSOR crGetUS_Source IS
select heat_source 
  from mt_us_heats 
  where heat_num = pHeatNo_in
    and rec_status = 'A';
  
-------------------------------------------------------------------------------
-- C U R S O R   c r G e t B L _ S o u r c e                      BL_INGOTS  --
-------------------------------------------------------------------------------
CURSOR crGetBL_Source IS  
--BL_INGOTS
select '23' heat_source from bl_ingots where SUBSTR (ingot_ref, 1, 7) = pHeatNo_in;

-------------------------------------------------------------------------------
-- C U R S O R   c r G e t B o u g h t S o u r c e    ST_BOUGHT_IN_MATERIAL  --
-------------------------------------------------------------------------------
CURSOR crGetBoughtSource IS
select site heat_source from st_bought_in_material 
 where heat_no = pHeatNo_in
   and rec_status = 'A';

-------------------------------------------------------------------------------
-- B E G I N                                                                 --
-------------------------------------------------------------------------------
--
BEGIN
  lvHeatSource := NULL;
  
  -----------------------------------------------------------------------------
  -- First Check if Heat Source is in MT_US_HEATS                            --
  -----------------------------------------------------------------------------
  OPEN crGetUS_Source;
  FETCH crGetUS_Source INTO lvHeatSource;
  CLOSE crGetUS_Source;  
  
  IF lvHeatSource is NULL THEN
     -----------------------------------------------------------------------------
     --Next Check if Heat Source is in BL_INGOTS                                --
     -----------------------------------------------------------------------------
     OPEN crGetBL_Source;
     FETCH crGetBL_Source INTO lvHeatSource;
     CLOSE crGetBL_Source;  
  END IF;
 
  
  IF lvHeatSource is NULL THEN
     -----------------------------------------------------------------------------
     --Next Check if Heat Source is in ST_BOUGHT_IN_MATERIAL                    --
     -----------------------------------------------------------------------------
     OPEN crGetBoughtSource;
     FETCH crGetBoughtSource INTO lvHeatSource;
     CLOSE crGetBoughtSource;  
  END IF;
 
  RETURN lvHeatSource;
  
EXCEPTION
 
WHEN others THEN
  RETURN NULL;

END fnGetMeltSite;

END pk_melt;
/