CREATE OR REPLACE TRIGGER STAR.NSPCDI_BI_CR BEFORE INSERT
ON STAR.NS_PIECE_DISPOSITIONS REFERENCING OLD AS OLD NEW AS NEW FOR EACH ROW
BEGIN
  :NEW.CREATED_BY := USER;
  :NEW.DATE_CREATED := CURRENT_TIMESTAMP;
  :NEW.REC_STATUS := 'A';
  :NEW.NS_PIECE_DISP_ID := NSPCDI_ID_SEQ.NEXTVAL;
  IF :NEW.EDITION IS NULL THEN 
    :NEW.EDITION := 1;
  END IF;
  
  -- Assign DISPOSITION_DATE if assigned -- STCR 7587
  IF :NEW.disposition_id is not null THEN   -- STCR 7587
    :NEW.disposition_date := SYSDATE;       -- STCR 7587
  END IF;                                   -- STCR 7587
  
END;
/
