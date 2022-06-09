DROP TRIGGER STAR.RSAIMP_BIUD_R;

CREATE OR REPLACE TRIGGER STAR.RSAIMP_BIUD_R BEFORE DELETE OR INSERT OR UPDATE
ON STAR.R3_SHED_ADH_IMPORTS REFERENCING OLD AS OLD NEW AS NEW FOR EACH ROW
DECLARE
  lv_pk VARCHAR2(100);
  lv_table_name VARCHAR2(100);
  lv_aud_ent VARCHAR2(100);
  lv_aud_ent_key VARCHAR2(100);
  lv_update_bool BOOLEAN := FALSE;
  -- END auto generated declaration. This line used by auto generator to ensure no duplication of variable declarations.
BEGIN
  lv_pk := TO_CHAR(:OLD.RSAIMP_ID);
  lv_table_name := 'R3_SHED_ADH_IMPORTS';
  lv_aud_ent := NULL;
  lv_aud_ent_key := NULL;
  -- END auto generated variables. This line used by auto generator to ensure no duplication of variables.
IF INSERTING THEN
  null; -- in case there is nothing to do on inserting
  :NEW.DATE_CREATED := SYSDATE;
  :NEW.TIME_CREATED := TO_CHAR(SYSDATE,'HH24:MI:SS');
  :NEW.EDITION := 1;
  :NEW.REC_STATUS := 'A';
  IF (:NEW.CREATED_BY IS NULL) THEN
    :NEW.CREATED_BY := USER;
  END IF;

 -- :NEW.site := sys_context('sec_admin','user_home_site');-- Commented out as solution for STCR 7632

  -- new record so get a new pk value
  IF :NEW.rsaimp_id IS NULL THEN
    SELECT rsaimp_id_seq.nextval INTO :NEW.rsaimp_id FROM sys.dual;
  END IF;
END IF;
IF UPDATING THEN
  -- Lock down primary keys from being updated.
  IF TO_CHAR(:OLD.RSAIMP_ID)
     <> TO_CHAR(:NEW.RSAIMP_ID) THEN
    pk_star_programs.p_raise_star_error(pn_mess_no_in => 903);
  END IF;
  IF NVL(:NEW.REC_STATUS,'zzNULLzz') != NVL(:OLD.REC_STATUS,'zzNULLzz') THEN
    P_WRITE_AUDIT(p_audit_table => lv_table_name
                  ,p_audit_column => 'REC_STATUS'
                  ,p_row_identity => lv_pk
                  ,p_before_image => :OLD.REC_STATUS
                  ,p_after_image => :NEW.REC_STATUS
                  ,p_audited_entity => lv_aud_ent
                  ,p_audited_entity_key => lv_aud_ent_key
                  );
    lv_update_bool := TRUE;
  END IF;
  IF :NEW.REC_STATUS = 'E' AND :OLD.REC_STATUS = 'A' THEN
    :NEW.DATE_EXPIRED := SYSDATE;
  END IF;
  IF :NEW.REC_STATUS = 'A' AND :OLD.REC_STATUS = 'E' THEN
    :NEW.DATE_REACTIVATED := SYSDATE;
  END IF;
  IF NVL(:NEW.RSAIMP_ID, -999999) != NVL(:OLD.RSAIMP_ID, -999999) THEN
    P_WRITE_AUDIT(p_audit_table => lv_table_name
                  ,p_audit_column => 'RSAIMP_ID'
                  ,p_row_identity => lv_pk
                  ,p_before_image => :OLD.RSAIMP_ID
                  ,p_after_image => :NEW.RSAIMP_ID
                  ,p_audited_entity => lv_aud_ent
                  ,p_audited_entity_key => lv_aud_ent_key
                  );
    lv_update_bool := TRUE;
  END IF;
  IF NVL(:NEW.USER_LOGIN,'zzNULLzz') != NVL(:OLD.USER_LOGIN,'zzNULLzz') THEN
    P_WRITE_AUDIT(p_audit_table => lv_table_name
                  ,p_audit_column => 'USER_LOGIN'
                  ,p_row_identity => lv_pk
                  ,p_before_image => :OLD.USER_LOGIN
                  ,p_after_image => :NEW.USER_LOGIN
                  ,p_audited_entity => lv_aud_ent
                  ,p_audited_entity_key => lv_aud_ent_key
                  );
    lv_update_bool := TRUE;
  END IF;
  IF NVL(:NEW.SITE,'zzNULLzz') != NVL(:OLD.SITE,'zzNULLzz') THEN
    P_WRITE_AUDIT(p_audit_table => lv_table_name
                  ,p_audit_column => 'SITE'
                  ,p_row_identity => lv_pk
                  ,p_before_image => :OLD.SITE
                  ,p_after_image => :NEW.SITE
                  ,p_audited_entity => lv_aud_ent
                  ,p_audited_entity_key => lv_aud_ent_key
                  );
    lv_update_bool := TRUE;
  END IF;
  IF NVL(:NEW.DATE_EXPIRED, TO_DATE('01-JAN-0001', 'DD-MON-YYYY')) != NVL(:OLD.DATE_EXPIRED, TO_DATE('01-JAN-0001', 'DD-MON-YYYY')) THEN
    P_WRITE_AUDIT(p_audit_table => lv_table_name
                  ,p_audit_column => 'DATE_EXPIRED'
                  ,p_row_identity => lv_pk
                  ,p_before_image => TO_CHAR(:OLD.DATE_EXPIRED,'DD-MON-YYYY')
                  ,p_after_image => TO_CHAR(:NEW.DATE_EXPIRED,'DD-MON-YYYY')
                  ,p_audited_entity => lv_aud_ent
                  ,p_audited_entity_key => lv_aud_ent_key
                  );
    lv_update_bool := TRUE;
  END IF;
  IF NVL(:NEW.DATE_REACTIVATED, TO_DATE('01-JAN-0001', 'DD-MON-YYYY')) != NVL(:OLD.DATE_REACTIVATED, TO_DATE('01-JAN-0001', 'DD-MON-YYYY')) THEN
    P_WRITE_AUDIT(p_audit_table => lv_table_name
                  ,p_audit_column => 'DATE_REACTIVATED'
                  ,p_row_identity => lv_pk
                  ,p_before_image => TO_CHAR(:OLD.DATE_REACTIVATED,'DD-MON-YYYY')
                  ,p_after_image => TO_CHAR(:NEW.DATE_REACTIVATED,'DD-MON-YYYY')
                  ,p_audited_entity => lv_aud_ent
                  ,p_audited_entity_key => lv_aud_ent_key
                  );
    lv_update_bool := TRUE;
  END IF;
END IF;
  IF lv_update_bool = TRUE THEN
    NULL; -- in case there are no audit columns
    :NEW.DATE_UPDATED := SYSDATE;
    :NEW.TIME_UPDATED := TO_CHAR(SYSDATE,'HH24:MI:SS');
    :NEW.LAST_UPDATE_BY := USER;
    :NEW.EDITION := :OLD.EDITION + 1;
  END IF;
IF DELETING THEN
  P_WRITE_AUDIT(p_audit_table => lv_table_name
               ,p_audit_column => '(RECORD)'
               ,p_row_identity => lv_pk
               ,p_before_image => '*DELETED*'
               ,p_after_image => '*DELETED*'
               ,p_audited_entity => lv_aud_ent
               ,p_audited_entity_key => lv_aud_ent_key
               );
END IF;
END;
/
