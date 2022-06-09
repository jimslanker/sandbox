CREATE OR REPLACE VIEW STAR.CP_BATCHES_VIEW
(
   SITE,
   BATCH,
   SALES_ORDER,
   SALES_ITEM,
   KEY_SIZE,
   ALLOY_CODE,
   ALLOY_NAME,
   DELIVERY_CONDITION,
   PRODUCT_DESCRIPTION,
   INGOT_LENGTH,
   INGOT_LENGTH_COMMENT,
   INGOT_FINISHED_WT,
   SAP_SOLD_TO_NAME,
   CUSTOMER_PO_REF,
   CUSTOMER_PO_DATE,
   HEAT,
   MELT_DATE,
   MELT_METHOD,
   MELT_SITE,
   PROCESS_ORDER_STATUS
)
AS
   SELECT b.plant_no "SITE",
          A.r3_batch_number "BATCH",
          -- STCR 6867 Start
          --          SUBSTR ( b.r3_sales_order, 1, 15 ) "SALES_ORDER",
          --          SUBSTR ( b.r3_sales_order_item, 1, 15 ) "SALES_ITEM",
          b.r3_sales_order "SALES_ORDER",
          b.r3_sales_order_item "SALES_ITEM",
          -- STCR 6867 End
          b.key_size_entered || ' ' || b.key_size_uom "KEY_SIZE",
          A.alloy_code "ALLOY_CODE",
          d.alloy_name "ALLOY_NAME",
          E.product_type_desc "DELIVERY_CONDITION",
          (CASE b.plant_no
              WHEN 11
              THEN
                 SUBSTR (
                       DECODE (
                          c.shape_type,
                          'MCHTUB',    DECODE (
                                          c.SIZE_OD_WIDTH,
                                          '', '',
                                             c.SIZE_OD_WIDTH
                                          || DECODE (UPPER (b.key_size_uom),
                                                     'IN', '"',
                                                     b.key_size_uom)
                                          || ' X ')
                                    || CASE b.primary_dim
                                          WHEN 'T'
                                          THEN
                                             CASE
                                                WHEN b.key_size_entered < 1
                                                THEN
                                                   TO_CHAR (
                                                      b.key_size_entered,
                                                      '0.900')
                                                ELSE
                                                   TO_CHAR (
                                                      b.key_size_entered)
                                             END
                                          ELSE
                                             TO_CHAR (b.key_size_entered)
                                       END,
                             CASE b.primary_dim
                                WHEN 'T'
                                THEN
                                   CASE
                                      WHEN b.key_size_entered < 1
                                      THEN
                                         TO_CHAR (b.key_size_entered,
                                                  '0.900')
                                      ELSE
                                         TO_CHAR (b.key_size_entered)
                                   END
                                ELSE
                                      TO_CHAR (b.key_size_entered)
                             END
                          || CASE c.shape_type
                                WHEN 'BIL-RE'
                                THEN
                                   DECODE (c.SIZE_OD_WIDTH,
                                           '', '',
                                           ' X ' || c.SIZE_OD_WIDTH)
                                WHEN 'BAR-RE'
                                THEN
                                   DECODE (c.SIZE_OD_WIDTH,
                                           '', '',
                                           ' X ' || c.SIZE_OD_WIDTH)
                                ELSE
                                   ''
                             END)
                    || DECODE (UPPER (b.key_size_uom),
                               'IN', '"',
                               b.key_size_uom)
                    || ' '
                    || c.grade_code
                    || ' '
                    || f.shape_type_desc,
                    1,
                    100)
              WHEN 13
              THEN
                 SUBSTR (
                       TO_CHAR (b.key_size_entered)
                    || DECODE (UPPER (b.key_size_uom),
                               'IN', '"',
                               b.key_size_uom)
                    || ' '
                    || c.grade_code
                    || ' '
                    || (SELECT melt_profile_desc
                          FROM te_melt_profiles
                         WHERE melt_profile_ref = c.ingot_num_of_melts)
                    || ' '
                    || f.shape_type_desc,
                    1,
                    100)
              WHEN 20
              THEN
                 pk_certification.fnGetProdDesc (c.spec_code_id)
              WHEN 22
              THEN
                 DECODE (
                    c.ingot_diam_inches,
                    NULL, SUBSTR (
                                c.grade_code
                             || ' '
                             || c.ingot_num_of_melts
                             || ' '
                             || f.shape_type_desc,
                             1,
                             100),
                    SUBSTR (
                          TO_CHAR (c.ingot_diam_inches)
                       || '" '
                       || c.grade_code
                       || ' '
                       || c.ingot_num_of_melts
                       || ' '
                       || f.shape_type_desc,
                       1,
                       100))
              WHEN 23
              THEN
                 pk_certification.fnGetProdDesc (c.spec_code_id)
              WHEN 24
              THEN
                 DECODE (
                    NVL (c.size_thickness, 0),
                    0, SUBSTR (
                             TO_CHAR (c.size_od_width)
                          || DECODE (UPPER (c.unit_of_size),
                                     'IN', '"',
                                     c.unit_of_size)
                          || ' Dia. x '
                          || c.LENGTH
                          || ' '
                          || DECODE (UPPER (c.unit_of_length),
                                     'IN', '"',
                                     c.unit_of_length)
                          || ' '
                          || c.grade_code
                          || ' '
                          || f.shape_type_desc,
                          1,
                          100),
                    SUBSTR (
                          TO_CHAR (c.size_thickness)
                       || DECODE (UPPER (c.unit_of_size),
                                  'IN', '"',
                                  c.unit_of_size)
                       || ' x '
                       || TO_CHAR (c.size_od_width)
                       || DECODE (UPPER (c.unit_of_size),
                                  'IN', '"',
                                  c.unit_of_size)
                       || ' x '
                       || c.LENGTH
                       || ' '
                       || DECODE (UPPER (c.unit_of_length),
                                  'IN', '"',
                                  c.unit_of_length)
                       || ' '
                       || c.grade_code
                       || ' '
                       || f.shape_type_desc,
                       1,
                       100))
              WHEN 26
              THEN
                 c.machining_instructions  -- STCR 6774  c.tol_ovality_comment
              WHEN 32
              THEN
                 SUBSTR (
                       CASE b.primary_dim
                          WHEN 'T'
                          THEN
                             (CASE
                                 WHEN b.key_size_entered < 1
                                 THEN
                                    TO_CHAR (b.key_size_entered, '0.900')
                                 ELSE
                                    TO_CHAR (b.key_size_entered)
                              END)
                          ELSE
                             TO_CHAR (b.key_size_entered)
                       END
                    || CASE c.shape_type
                          WHEN 'BIL-RE'
                          THEN
                             DECODE (c.SIZE_OD_WIDTH,
                                     '', '',
                                     ' X ' || c.SIZE_OD_WIDTH)
                          WHEN 'BAR-RE'
                          THEN
                             DECODE (c.SIZE_OD_WIDTH,
                                     '', '',
                                     ' X ' || c.SIZE_OD_WIDTH)
                          ELSE
                             ''
                       END
                    || DECODE (UPPER (b.key_size_uom),
                               'IN', '"',
                               b.key_size_uom)
                    || ' '
                    || c.grade_code
                    || ' '
                    || f.shape_type_desc,
                    1,
                    100)
              WHEN 40
              THEN
                 SUBSTR ( decode(substr(to_char(c.size_od_width),1,1),'.','0' || to_char(c.size_od_width), to_char(c.size_od_width))
                  || '-' || c.unit_of_size || ' OD x ' || 
                  decode(substr(to_char(c.size_thickness),1,1),'.','0' || to_char(c.size_thickness), to_char(c.size_thickness))
                   || '-' || c.unit_of_size || ' WT ' || 
                   f.shape_type_desc
                    , 1, 100)
              WHEN 41
              THEN
                 SUBSTR ( decode(substr(to_char(c.size_od_width),1,1),'.','0' || to_char(c.size_od_width), to_char(c.size_od_width))
                  || '-' || c.unit_of_size || ' OD x ' || 
                  decode(substr(to_char(c.size_thickness),1,1),'.','0' || to_char(c.size_thickness), to_char(c.size_thickness))
                   || '-' || c.unit_of_size || ' WT ' || 
                   f.shape_type_desc
                    , 1, 100)
              ELSE
                 NULL
           END)
             "PRODUCT_DESCRIPTION",
          G.ingot_length "INGOT_LENGTH",
          G.ingot_length_comment "INGOT_LENGTH_COMMENT",
          G.finished_wt "INGOT_FINISHED_WT",
          h.sap_sold_to_name "SAP_SOLD_TO_NAME",
          h.customer_po_ref "CUSTOMER_PO_REF",
          h.customer_po_date "CUSTOMER_PO_DATE",
          A.r3_ingot_ref "HEAT",
          G.melt_date "MELT_DATE",
          NULL "MELT_METHOD",
          G.heat_source "MELT_SITE",
          A.process_order_status "PROCESS_ORDER_STATUS"
     FROM r3_process_orders A,
          r3_sales_order_items b,
          te_spec_code_header c,
          st_alloys d,
          te_product_type E,
          te_shape_type f,
          mt_us_heats G,
          r3_sales_orders h
    WHERE     A.r3_sales_order = b.r3_sales_order
          AND A.r3_sales_order_item = b.r3_sales_order_item
          AND A.r3_sales_order = h.r3_sales_order
          AND c.spec_code_id = b.spec_code_id
          AND d.alloy_code = A.alloy_code
          AND E.product_type(+) = c.product_type
          AND f.shape_type = c.shape_type
          AND f.site = c.site
          AND G.heat_num(+) = A.r3_ingot_ref;


--CREATE OR REPLACE PUBLIC SYNONYM CP_BATCHES_VIEW FOR CP_BATCHES_VIEW
--/

--GRANT SELECT ON CP_BATCHES_VIEW TO STAR_USER
--/
