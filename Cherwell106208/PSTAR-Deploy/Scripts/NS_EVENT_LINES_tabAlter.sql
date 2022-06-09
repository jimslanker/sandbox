-------------------------------------------------------------------------------
-- Filename: NS_EVENT_LINES_tabAlter.sql                                     --
-- Author: Jim Slanker                                                       --
-- Date: Sept 7th 2021                                                       --
-- Increase size of column TEST_NUMBER to 40 Characters for STCR 7570        --
-- Existing size is 6 bytes
-------------------------------------------------------------------------------
PROMPT >>Alter Table NS_EVENT_LINES

ALTER table  STAR.NS_EVENT_LINES
 MODIFY TEST_NUMBER   VARCHAR2(40);
