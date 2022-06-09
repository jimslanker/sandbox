-------------------------------------------------------------------------------
-- Filename: NS_PIECE_DISPOSITIONS_tabAlter.sql                              --
-- Author: Jim Slanker                                                       --
-- Date: Sept 7th 2021                                                       --
-- Add column DISPOSITION_DATE                                               --
-------------------------------------------------------------------------------
PROMPT >>Alter Table NS_PIECE_DISPOSITIONS

ALTER table  STAR.NS_PIECE_DISPOSITIONS
 ADD DISPOSITION_DATE   TIMESTAMP(6);
