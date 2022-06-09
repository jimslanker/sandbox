CREATE OR REPLACE TRIGGER STAR.NSPCDI_BUD_R BEFORE DELETE OR UPDATE
ON STAR.NS_PIECE_DISPOSITIONS REFERENCING OLD AS OLD NEW AS NEW FOR EACH ROW
DECLARE
  vcPK VARCHAR2(100) := TO_CHAR(:OLD.NS_PIECE_DISP_ID);
  vcTableName VARCHAR2(100) := 'NS_PIECE_DISPOSITIONS';
  vcAudEnt VARCHAR2(100);
  vcAudEntKey VARCHAR2(100);
  blUpdate BOOLEAN := FALSE;
BEGIN
IF UPDATING THEN
  -- Lock down primary keys from being updated.
  IF TO_CHAR(:OLD.NS_PIECE_DISP_ID) != TO_CHAR(:NEW.NS_PIECE_DISP_ID) THEN
    pk_star_programs.p_raise_star_error( pn_mess_no_in => 903 );
  END IF;
  IF NVL(:NEW.REC_STATUS,'zzNULLzz') != NVL(:OLD.REC_STATUS,'zzNULLzz') THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'REC_STATUS'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.REC_STATUS
                  ,p_after_image  => :NEW.REC_STATUS
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.NS_EVENT_ID,-999999) != NVL(:OLD.NS_EVENT_ID,-999999) THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'NS_EVENT_ID'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.NS_EVENT_ID
                  ,p_after_image  => :NEW.NS_EVENT_ID
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.LINE_NUMBER,-999999) != NVL(:OLD.LINE_NUMBER,-999999) THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'LINE_NUMBER'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.LINE_NUMBER
                  ,p_after_image  => :NEW.LINE_NUMBER
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.NS_PIECE_DISP_ID,-999999) != NVL(:OLD.NS_PIECE_DISP_ID,-999999) THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'NS_PIECE_DISP_ID'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.NS_PIECE_DISP_ID
                  ,p_after_image  => :NEW.NS_PIECE_DISP_ID
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.DISPOSITION_TYPE,'zzNULLzz') != NVL(:OLD.DISPOSITION_TYPE,'zzNULLzz') THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'DISPOSITION_TYPE'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.DISPOSITION_TYPE
                  ,p_after_image  => :NEW.DISPOSITION_TYPE
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.PIECE_ID,'zzNULLzz') != NVL(:OLD.PIECE_ID,'zzNULLzz') THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'PIECE_ID'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.PIECE_ID
                  ,p_after_image  => :NEW.PIECE_ID
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.PIECE_COUNT,-999999) != NVL(:OLD.PIECE_COUNT,-999999) THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'PIECE_COUNT'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.PIECE_COUNT
                  ,p_after_image  => :NEW.PIECE_COUNT
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.PIECE_WEIGHT,-999999) != NVL(:OLD.PIECE_WEIGHT,-999999) THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'PIECE_WEIGHT'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.PIECE_WEIGHT
                  ,p_after_image  => :NEW.PIECE_WEIGHT
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.WT_UOM,'zzNULLzz') != NVL(:OLD.WT_UOM,'zzNULLzz') THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'WT_UOM'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.WT_UOM
                  ,p_after_image  => :NEW.WT_UOM
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.DISP_REASON_ID,-999999) != NVL(:OLD.DISP_REASON_ID,-999999) THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'DISP_REASON_ID'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.DISP_REASON_ID
                  ,p_after_image  => :NEW.DISP_REASON_ID
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.DISPOSITION_ID,-999999) != NVL(:OLD.DISPOSITION_ID,-999999) THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'DISPOSITION_ID'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.DISPOSITION_ID
                  ,p_after_image  => :NEW.DISPOSITION_ID
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF NVL(:NEW.COMMENTS,'zzNULLzz') != NVL(:OLD.COMMENTS,'zzNULLzz') THEN
    P_WRITE_AUDIT( p_audit_table  => vcTableName
                  ,p_audit_column => 'COMMENTS'
                  ,p_row_identity => vcPK
                  ,p_before_image => :OLD.COMMENTS
                  ,p_after_image  => :NEW.COMMENTS
                  ,p_audited_entity     => vcAudEnt
                  ,p_audited_entity_key => vcAudEntKey
                  );
    blUpdate := TRUE;
  END IF;
  IF blUpdate THEN
    NULL; -- in case there are no audit columns
    :NEW.DATE_UPDATED := CURRENT_TIMESTAMP;
    :NEW.EDITION := :OLD.EDITION + 1;
    :NEW.LAST_UPDATE_BY := USER;
  END IF;
END IF;
IF DELETING THEN
  P_WRITE_AUDIT(p_audit_table => vcTableName
               ,p_audit_column => '(RECORD)'
               ,p_row_identity => vcPK
               ,p_before_image => '*DELETED*'
               ,p_after_image => '*DELETED*'
               ,p_audited_entity => vcAudEnt
               ,p_audited_entity_key => vcAudEntKey
               );
END IF;
END;
/