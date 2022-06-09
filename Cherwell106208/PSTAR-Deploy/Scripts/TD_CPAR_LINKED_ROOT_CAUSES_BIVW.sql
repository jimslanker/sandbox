DROP VIEW STAR.TD_CPAR_LINKED_ROOT_CAUSES_BIVW;

CREATE OR REPLACE  VIEW STAR.TD_CPAR_LINKED_ROOT_CAUSES_BIVW(LINKED_ROOT_CAUSE_ID,
                                                                                                                                                                  ROOT_CAUSE_CODE_ID,
                                                                                                                                                                  CPAR_ID,
                                                                                                                                                                  REC_STATUS,
                                                                                                                                                                  EDITION,
                                                                                                                                                                  DATE_CREATED,
                                                                                                                                                                  CREATED_BY,
                                                                                                                                                                  DATE_UPDATED,
                                                                                                                                                                  LAST_UPDATE_BY)
                                                                                                                                AS SELECT   LINKED_ROOT_CAUSE_ID,
                                                                                                                                                           ROOT_CAUSE_CODE_ID,
                                                                                                                                                           CPAR_ID,
                                                                                                                                                           REC_STATUS,
                                                                                                                                                           EDITION,
                                                                                                                                                           DATE_CREATED,
                                                                                                                                                           CREATED_BY,
                                                                                                                                                           DATE_UPDATED,
                                                                                                                                                           LAST_UPDATE_BY
                                     FROM    TD_CPAR_LINKED_ROOT_CAUSES
                                 WHERE    rec_status = 'A'
                                          OR ( rec_status = 'E'
                                                     AND date_updated > (SYSDATE - 7));
                                                     
DROP PUBLIC SYNONYM TD_CPAR_LINKED_ROOT_CAUSES_BIVW;

CREATE OR REPLACE PUBLIC SYNONYM TD_CPAR_LINKED_ROOT_CAUSES_BIVW FOR STAR.TD_CPAR_LINKED_ROOT_CAUSES_BIVW;

GRANT SELECT ON STAR.TD_CPAR_LINKED_ROOT_CAUSES_BIVW TO EXT_TMT_PWRBI;

GRANT SELECT ON STAR.TD_CPAR_LINKED_ROOT_CAUSES_BIVW TO EXT_TMT_TABLEAU;

GRANT SELECT ON STAR.TD_CPAR_LINKED_ROOT_CAUSES_BIVW TO EXT_TMT_TABLEAU2;