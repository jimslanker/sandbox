DROP VIEW STAR.TD_CPAR_ROOT_CAUSE_CODES_BIVW;

CREATE OR REPLACE  VIEW STAR.TD_CPAR_ROOT_CAUSE_CODES_BIVW(ROOT_CAUSE_CODE_ID,
                                                                                                                                                              ROOT_CAUSE_CODE,
                                                                                                                                                              ROOT_CAUSE_TITLE,
                                                                                                                                                              DESCRIPTION,
                                                                                                                                                              ROOT_CAUSE_CATEGORY_ID,
                                                                                                                                                              REC_STATUS,
                                                                                                                                                              EDITION,
                                                                                                                                                              DATE_CREATED,
                                                                                                                                                              CREATED_BY,
                                                                                                                                                              DATE_UPDATED,            
                                                                                                                                                              LAST_UPDATE_BY,          
                                                                                                                                                              ROOT_CAUSE_SEQ )
                                                                                                                                AS SELECT   ROOT_CAUSE_CODE_ID,
                                                                                                                                                              ROOT_CAUSE_CODE,
                                                                                                                                                              ROOT_CAUSE_TITLE,
                                                                                                                                                              DESCRIPTION,
                                                                                                                                                              ROOT_CAUSE_CATEGORY_ID,
                                                                                                                                                              REC_STATUS,
                                                                                                                                                              EDITION,
                                                                                                                                                              DATE_CREATED,
                                                                                                                                                              CREATED_BY,
                                                                                                                                                              DATE_UPDATED,            
                                                                                                                                                              LAST_UPDATE_BY,          
                                                                                                                                                              ROOT_CAUSE_SEQ
                                     FROM    TD_CPAR_ROOT_CAUSE_CODES;
                                                     
DROP PUBLIC SYNONYM TD_CPAR_ROOT_CAUSE_CODES_BIVW;

CREATE OR REPLACE PUBLIC SYNONYM TD_CPAR_ROOT_CAUSE_CODES_BIVW FOR STAR.TD_CPAR_ROOT_CAUSE_CODES_BIVW;

GRANT SELECT ON STAR.TD_CPAR_ROOT_CAUSE_CODES_BIVW TO EXT_TMT_PWRBI;

GRANT SELECT ON STAR.TD_CPAR_ROOT_CAUSE_CODES_BIVW TO EXT_TMT_TABLEAU;

GRANT SELECT ON STAR.TD_CPAR_ROOT_CAUSE_CODES_BIVW TO EXT_TMT_TABLEAU2;