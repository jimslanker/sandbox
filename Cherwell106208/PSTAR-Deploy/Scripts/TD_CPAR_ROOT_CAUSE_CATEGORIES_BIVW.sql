DROP VIEW STAR.TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW;

CREATE OR REPLACE  VIEW STAR.TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW(ROOT_CAUSE_CATEGORY_ID,
                                                                                                                                                                          ROOT_CAUSE_CATEGORY,
                                                                                                                                                                          DESCRIPTION,
                                                                                                                                                                          REC_STATUS,
                                                                                                                                                                          EDITION,
                                                                                                                                                                          DATE_CREATED,
                                                                                                                                                                          CREATED_BY,
                                                                                                                                                                          DATE_UPDATED,
                                                                                                                                                                          LAST_UPDATE_BY)
                                                                                                                                AS SELECT   ROOT_CAUSE_CATEGORY_ID,
                                                                                                                                                           ROOT_CAUSE_CATEGORY,
                                                                                                                                                           DESCRIPTION,
                                                                                                                                                           REC_STATUS,
                                                                                                                                                           EDITION,
                                                                                                                                                           DATE_CREATED,
                                                                                                                                                           CREATED_BY,
                                                                                                                                                           DATE_UPDATED,
                                                                                                                                                           LAST_UPDATE_BY
                                     FROM    TD_CPAR_ROOT_CAUSE_CATEGORIES;
                                                     
DROP PUBLIC SYNONYM TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW;

CREATE OR REPLACE PUBLIC SYNONYM TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW FOR STAR.TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW;

GRANT SELECT ON STAR.TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW TO EXT_TMT_PWRBI;

GRANT SELECT ON STAR.TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW TO EXT_TMT_TABLEAU;

GRANT SELECT ON STAR.TD_CPAR_ROOT_CAUSE_CATEGORIES_BIVW TO EXT_TMT_TABLEAU2;