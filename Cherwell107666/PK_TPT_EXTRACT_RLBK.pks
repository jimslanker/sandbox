CREATE OR REPLACE PACKAGE STAR.pk_tpt_extract AS
/*
  --
  -- $Revision:   5.6  $
  -- $Date:   Jan 21 2016 19:13:00  $
  --
   NAME:       PK_TPT_EXTRACT
   PURPOSE:   Repository for procedure / functions used to extract TPT and sample data. First utilised to satisfy STCR 6966.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        24/09/2015      sphillips       1. Created this package.
   
*/
--
-- Procedure to extract the long / medium order requirement 
PROCEDURE prGetOrderRequirement (pvcSite_in    IN   st_sites.site%TYPE,
                                                 pvcCreateType_in   IN  ex_tpt_order_requirement.creation_indicator%TYPE);
                                                 
--
-- Procedure to delete the order requirement rows from the extract table for the given site
PROCEDURE prDelOrdReqData (pvcSite_in    IN   st_sites.site%TYPE,
                                         pnmRowsDeleted_out     OUT    PLS_INTEGER);                                                
                                                 
--
-- Procedure to extract batch tracking data
PROCEDURE prGetBatchTrackData   (pvcSite_in    IN   st_sites.site%TYPE,
                                                 pvcCreateType_in   IN  ex_tpt_order_requirement.creation_indicator%TYPE); 
                                                 
--
-- Procedure to delete the batch tracking data rows from the extract table for the given site.
PROCEDURE prDelBatchTrackData (pvcSite_in  IN   st_sites.site%TYPE,
                                               pnmRowsDeleted_out  OUT  PLS_INTEGER);                                      
                                                 
--                                                 
-- Report to user extract complete and number or rows processed
FUNCTION fnGetExtractRowCount (pvcSite_in  IN   st_sites.site%TYPE,
                                                 pnmJobId_in   IN    ex_tpt_control.job_id%TYPE)
RETURN PLS_INTEGER;                                                  
                                                                                                                                              
--
-- Function to indicate if selected extract job is currently running
FUNCTION fnExtractRunning(pnmJobId_in   IN  ex_tpt_control.job_id%TYPE,
                                       pvcSite_in     IN   st_sites.site%TYPE)
RETURN BOOLEAN;                                                                         

--
-- Procedure to run order requirement extract for site 24 as a scheduled job
PROCEDURE prGetOrderRequirement24;

--
-- Procedure to batch tracking data extract for site 24 as a scheduled job
PROCEDURE prRunBatchTrackSiteData;

--
-- End package spec PK_TPT_EXTRACT
END pk_tpt_extract;
/