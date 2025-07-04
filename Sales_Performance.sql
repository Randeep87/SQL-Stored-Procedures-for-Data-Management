USE [FACTSALTARAF]
GO
/****** Object:  StoredProcedure [dbo].[usp_DB_LR_SalesmanPerformance]     
Author: Randeep
Date  : 14/10/2020

*/


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--[usp_DB_LR_SalesmanPerformance] 'randeep.a'


ALTER PROCEDURE [dbo].[usp_DB_LR_SalesmanPerformance]
	@strLoginID			NVARCHAR(20) = NULL
AS 
			SELECT	rmd_text_col2															AS [Salesman],
					rmd_num_col1															AS [Yearly Target], 
					rmd_num_col2															AS [YTD Target], 
					rmd_num_col3															AS [YTD Achieved], 
					rmd_num_col4															AS [Variance],
					rmd_num_col5															AS [YTD Score %],
					rmd_num_col6															AS [Yearly Score %],
					ROUND((rmd_num_col1 - rmd_num_col3)/(365 - DATENAME(DY,GETDATE())),0)	AS [Daily Target],
					ROW_NUMBER() OVER(ORDER BY  rmd_num_col5 DESC)							AS [SortOrder]
			FROM	reminder_details
			WHERE  rmd_reminder_docno	= 'usp_DB_LR_SYNC_SalesmanPerformance' 

			UNION 

			SELECT	'**Total'																	AS	[Salesman],
					SUM(rmd_num_col1)															AS	[Yearly Target], 
					SUM(rmd_num_col2)															AS	[YTD Target], 
					SUM(rmd_num_col3)															AS	[YTD Achieved], 
					SUM(rmd_num_col4)															AS	[Variance],
					ROUND((SUM(rmd_num_col3)/SUM(rmd_num_col2))*100,0) 							AS	[YTD Score %],
					ROUND((SUM(rmd_num_col3)/SUM(rmd_num_col1))*100,0) 							AS	[Yearly Score %],
					ROUND((SUM(rmd_num_col1 - rmd_num_col3))/(365 - DATENAME(DY,GETDATE())),0) 	AS [Daily Target],
					COUNT(*) + 1																AS	[SortOrder]
			FROM	reminder_details
			WHERE  rmd_reminder_docno	= 'usp_DB_LR_SYNC_SalesmanPerformance' 

			UNION 

			SELECT	'**MaxScore'								AS	[Salesman],
					0											AS	[Yearly Target], 
					0											AS	[YTD Target], 
					0											AS	[YTD Achieved], 
					0											AS	[Variance],
					100									 		AS	[YTD Score %],
					100									 		AS	[Yearly Score %],
					0											AS [Daily Target],
					COUNT(*) + 2								AS	[SortOrder]
			FROM	reminder_details
			WHERE  rmd_reminder_docno	= 'usp_DB_LR_SYNC_SalesmanPerformance' 
	

			UNION
			
			SELECT	'**MinScore'								AS	[Salesman],
					0											AS	[Yearly Target], 
					0											AS	[YTD Target], 
					0											AS	[YTD Achieved], 
					0											AS	[Variance],
					0									 		AS	[YTD Score %],
					0									 		AS	[Yearly Score %],
					0											AS [Daily Target],
					COUNT(*) + 3								AS	[SortOrder]
			FROM	reminder_details
			WHERE  rmd_reminder_docno	= 'usp_DB_LR_SYNC_SalesmanPerformance' 
			ORDER BY [SortOrder] ASC



