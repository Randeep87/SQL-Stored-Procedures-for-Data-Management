USE [FACTSALTARAF]
GO
/****** Object:  StoredProcedure [dbo].[usp_BR_NegativeStock]    Script Date: 2/4/2025 9:44:01 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*-------------------------------------------------------------------------------------------------------
Author		: Randeep
Date		: 31-10-2019
Purpose		: To check the Business rule violation of Negative stock
----------------------------------------------------------------------------------------------------------
Notes		: 
----------------------------------------------------------------------------------------------------------
Revision History:
----------------------------------------------------------------------------------------------------------


	exec [usp_BR_NegativeStock] 'CFY','SI',
			'<FACTS><PARAMETERS>
				<COLUMN1>SI</COLUMN1>
				<COLUMN2>1940</COLUMN2>
			</PARAMETERS></FACTS>','',''

*/

ALTER PROCEDURE [dbo].[usp_BR_NegativeStock]
			@strFyCode						NVARCHAR( 6),
			@strDocType						NVARCHAR( 6),
			@strXmlDocDetails				NVARCHAR( MAX),
			@strLoginID						NVARCHAR( 20),
			@strUniqueKey					NVARCHAR( 50)
AS
	DECLARE	@idoc							INT,
			@strTableName					NVARCHAR( 100),
			@strDetailsTableName			NVARCHAR( 100),
			@strColPrefix					NVARCHAR( 50),
			@strDetColPrefix				NVARCHAR( 50),
			@sqlString						NVARCHAR( 4000),
			@ConsiderPendingSO				INT	= 0 ,
			@ConsiderPendingDO				INT	= 0,
			@ConsiderPendingSAL				INT	= 0,
			@SourceDoctype					nvarchar(250)
			
	EXEC sp_xml_preparedocument @idoc OUTPUT, @strXmlDocDetails

	CREATE TABLE  #tmp_PossibleDocumentsBRNS
	(
			tmp_fycode						NVARCHAR( 6),	
			tmp_doctype						NVARCHAR( 6),
			tmp_docno						NVARCHAR( 20),
			tmp_caption						NVARCHAR( 100),
			PRIMARY KEY (tmp_fycode, tmp_doctype, tmp_docno)
	) 

	CREATE TABLE  #tmp_PossibleDocumentsWithStockBRNS
	(
			tmp_Fycode						NVARCHAR( 20),
			tmp_doctype						NVARCHAR( 20),
			tmp_docno						NVARCHAR( 20),
			tmp_stock_doctype				NVARCHAR( 20),
			tmp_stock_Docno					NVARCHAR( 20),
			tmp_Batch_docno					NVARCHAR( 20),
			tmp_Location_docno				NVARCHAR( 20),
			tmp_docDate						Date,
			tmp_Qty							NUMERIC(18,3),
			tmp_CurrentStock				NUMERIC(18,3),
			tmp_StockAsOnDocDate			NUMERIC(18,3),
			tmp_SONQty						NUMERIC(18,3),
			tmp_DOQty						NUMERIC(18,3),
			tmp_SalQty						NUMERIC(18,3),
			tmp_PONQty						NUMERIC(18,3),
			tmp_PartNumber					NVARCHAR(50)	
			PRIMARY KEY (tmp_stock_doctype, tmp_stock_Docno, tmp_Location_docno)
	) 

	INSERT INTO #tmp_PossibleDocumentsBRNS
	SELECT	@strFyCode,
			doctype,
			docno,
			caption 
	FROM	dbo.fn_ParseXMLDocDetails(@strXmlDocDetails)

	SELECT	@strColPrefix			= dm_header_column_prefix,
			@strDetColPrefix		= dm_det_column_prefix,
			@strTableName			= dm_header_table_name,
			@strDetailsTableName	= dm_det_table_name,
			@SourceDoctype			= dm_source_doctype
	FROM	document_master
	WHERE	dm_docno				= @strDocType

	IF @strDetColPrefix = 'TSFDET' 
	BEGIN
	SET		@sqlString ='
	INSERT INTO	#tmp_PossibleDocumentsWithStockBRNS
	(
			tmp_Fycode,	
			tmp_doctype,	
			tmp_docno,	
			tmp_stock_doctype,
			tmp_stock_docno,
			tmp_Location_docno,
			tmp_docDate,
			tmp_Qty,
			tmp_CurrentStock,
			tmp_SONQty,
			tmp_DOQty,
			tmp_SALQty,
			tmp_PONQty,
			tmp_PartNumber
	)
	SELECT	
			MAX( TMP_FYCODE),
			MAX( TMP_DOCTYPE),
			MAX( TMP_DOCNO),
			'		+ @strDetColPrefix	+ '_STOCK_DOCTYPE,
			'		+ @strDetColPrefix	+ '_STOCK_DOCNO,
			'		+ @strDetColPrefix	+ '_LOCATION_FM_DOCNO,
			DATEADD( d, 1, MAX('	+ @strColPrefix		+ '_DOCDATE)),
			SUM('	+ @strDetColPrefix	+ '_QTY),
			SUM(stkloc_clsqty),
			SUM(stkloc_sonqty),
			SUM(stkloc_doqty),
			SUM(stkloc_salqty),
			sum(stkloc_ponqty),
			max(stkmst_supplier_design_no)
	FROM	' + @strDetailsTableName	+'
	INNER JOIN ' + @strTableName + ' ON
			' + @strDetColPrefix + '_FYCODE		=  '+ @strColPrefix +'_FYCODE AND
			' + @strDetColPrefix + '_DOCTYPE	=  '+ @strColPrefix +'_DOCTYPE AND
			' + @strDetColPrefix + '_DOCNO		=  '+ @strColPrefix +'_DOCNO 
	INNER JOIN #tmp_PossibleDocumentsBRNS ON
			' + @strDetColPrefix + '_FYCODE		=  TMP_FYCODE AND
			' + @strDetColPrefix + '_DOCTYPE	=  TMP_DOCTYPE AND
			' + @strDetColPrefix + '_DOCNO		=  TMP_DOCNO
	OUTER APPLY (SELECT 
						stkloc_doctype,
						stkloc_docno,	
						stkloc_loc_docno,
						stkloc_clsqty,
						stkloc_SONqty,
						stkloc_DOQty,
						stkloc_SALQty,
						stkloc_ponqty,
						stkmst_supplier_design_no
				FROM	stock_location_master
				inner join stock_master on 
						stkloc_doctype	= stkmst_doctype AND
						stkloc_docno	= stkmst_docno  
				WHERE	stkloc_doctype		= ' + @strDetColPrefix	+ '_STOCK_DOCTYPE  AND
						stkloc_docno		= ' + @strDetColPrefix	+ '_STOCK_DOCNO  AND
						stkloc_loc_docno	= ' + @strDetColPrefix	+ '_LOCATION_FM_DOCNO )aa 
	GROUP BY ' + @strDetColPrefix +'_STOCK_DOCTYPE,
			' + @strDetColPrefix +'_STOCK_DOCNO,
			' + @strDetColPrefix +'_LOCATION_FM_DOCNO'
	END
	ELSE 
		IF @SourceDoctype = 'SO'
		BEGIN
	SET		@sqlString ='
	INSERT INTO	#tmp_PossibleDocumentsWithStockBRNS
	(
			tmp_Fycode,	
			tmp_doctype,	
			tmp_docno,	
			tmp_stock_doctype,
			tmp_stock_docno,
			tmp_Location_docno,
			tmp_docDate,
			tmp_Qty,
			tmp_CurrentStock,
			tmp_SONQty,
			tmp_DOQty,
			tmp_SALQty,
			tmp_PONQty,
			tmp_PartNumber

	)
	SELECT	
			MAX( TMP_FYCODE),
			MAX( TMP_DOCTYPE),
			MAX( TMP_DOCNO),
			'		+ @strDetColPrefix	+ '_STOCK_DOCTYPE,
			'		+ @strDetColPrefix	+ '_STOCK_DOCNO,
			max('		+ @strDetColPrefix	+ '_LOCATION_DOCNO),
			DATEADD( d, 1, MAX('	+ @strColPrefix		+ '_DOCDATE)),
			SUM('	+ @strDetColPrefix	+ '_QTY),
			SUM(stkloc_clsqty),
			SUM(stkloc_sonqty),
			SUM(stkloc_doqty),
			SUM(stkloc_salqty),
			SUM(stkloc_ponqty),
			max(STKMST_SUPPLIER_DESIGN_NO)
	FROM	' + @strDetailsTableName	+'
	INNER JOIN ' + @strTableName + ' ON
			' + @strDetColPrefix + '_FYCODE		=  '+ @strColPrefix +'_FYCODE AND
			' + @strDetColPrefix + '_DOCTYPE	=  '+ @strColPrefix +'_DOCTYPE AND
			' + @strDetColPrefix + '_DOCNO		=  '+ @strColPrefix +'_DOCNO 
	INNER JOIN #tmp_PossibleDocumentsBRNS ON
			' + @strDetColPrefix + '_FYCODE		=  TMP_FYCODE AND
			' + @strDetColPrefix + '_DOCTYPE	=  TMP_DOCTYPE AND
			' + @strDetColPrefix + '_DOCNO		=  TMP_DOCNO
	OUTER APPLY (SELECT 
						stkloc_doctype,
						stkloc_docno,	
						stkloc_loc_docno,
						stkloc_clsqty,
						stkloc_SONqty,
						stkloc_DOQty,
						stkloc_SALQty,
						stkloc_ponqty,
						STKMST_SUPPLIER_DESIGN_NO
				FROM	stock_location_master
				inner join stock_master on 
						stkloc_docno = stkmst_docno  
						--stkmst_sttype  IN (''STOCK'')
				WHERE	stkloc_doctype		= ' + @strDetColPrefix	+ '_STOCK_DOCTYPE  AND
						stkloc_docno		= ' + @strDetColPrefix	+ '_STOCK_DOCNO  
						--stkloc_loc_docno	= ' + @strDetColPrefix	+ '_LOCATION_DOCNO 
						)aa 
	GROUP BY ' + @strDetColPrefix +'_STOCK_DOCTYPE,
			' + @strDetColPrefix +'_STOCK_DOCNO
			--' + @strDetColPrefix +'_LOCATION_DOCNO'
END
		ELSE
		BEGIN

		SET		@sqlString ='
	INSERT INTO	#tmp_PossibleDocumentsWithStockBRNS
	(
			tmp_Fycode,	
			tmp_doctype,	
			tmp_docno,	
			tmp_stock_doctype,
			tmp_stock_docno,
			tmp_Location_docno,
			tmp_docDate,
			tmp_Qty,
			tmp_CurrentStock,
			tmp_SONQty,
			tmp_DOQty,
			tmp_SALQty,
			tmp_PONQty,
			tmp_PartNumber
	)
	SELECT	
			MAX( TMP_FYCODE),
			MAX( TMP_DOCTYPE),
			MAX( TMP_DOCNO),
			'		+ @strDetColPrefix	+ '_STOCK_DOCTYPE,
			'		+ @strDetColPrefix	+ '_STOCK_DOCNO,
			'		+ @strDetColPrefix	+ '_LOCATION_DOCNO,
			DATEADD( d, 1, MAX('	+ @strColPrefix		+ '_DOCDATE)),
			SUM('	+ @strDetColPrefix	+ '_QTY),
			SUM(stkloc_clsqty),
			SUM(stkloc_sonqty),
			SUM(stkloc_doqty),
			SUM(stkloc_salqty),
			SUM(stkloc_ponqty),
			max(stkmst_supplier_design_no)
	FROM	' + @strDetailsTableName	+'
	INNER JOIN ' + @strTableName + ' ON
			' + @strDetColPrefix + '_FYCODE		=  '+ @strColPrefix +'_FYCODE AND
			' + @strDetColPrefix + '_DOCTYPE	=  '+ @strColPrefix +'_DOCTYPE AND
			' + @strDetColPrefix + '_DOCNO		=  '+ @strColPrefix +'_DOCNO 
	INNER JOIN #tmp_PossibleDocumentsBRNS ON
			' + @strDetColPrefix + '_FYCODE		=  TMP_FYCODE AND
			' + @strDetColPrefix + '_DOCTYPE	=  TMP_DOCTYPE AND
			' + @strDetColPrefix + '_DOCNO		=  TMP_DOCNO
	OUTER APPLY (SELECT 
						stkloc_doctype,
						stkloc_docno,	
						stkloc_loc_docno,
						stkloc_clsqty,
						stkloc_SONqty,
						stkloc_DOQty,
						stkloc_SALQty,
						stkloc_ponqty,
						stkmst_supplier_design_no
				FROM	stock_location_master
				inner join stock_master on 
						stkloc_doctype	= stkmst_doctype AND
						stkloc_docno	= stkmst_docno  
						--stkmst_sttype  IN (''STOCK'')
				WHERE	stkloc_doctype		= ' + @strDetColPrefix	+ '_STOCK_DOCTYPE  AND
						stkloc_docno		= ' + @strDetColPrefix	+ '_STOCK_DOCNO  AND
						stkloc_loc_docno	= ' + @strDetColPrefix	+ '_LOCATION_DOCNO )aa 
	GROUP BY ' + @strDetColPrefix +'_STOCK_DOCTYPE,
			' + @strDetColPrefix +'_STOCK_DOCNO,
			' + @strDetColPrefix +'_LOCATION_DOCNO'

 END
 
	PRINT @sqlString 
	EXEC(	@sqlString)

	SET		@sqlString ='	UPDATE	cc
							SET		tmp_StockAsOnDocDate			= aa.clsQty
							FROM	#tmp_PossibleDocumentsWithStockBRNS cc
							OUTER APPLY (SELECT sttrn_stock_doctype,
												sttrn_stock_docno,
												sttrn_location_docno,
												SUM( sttrn_qty) clsQty
										FROM	stock_transaction
										WHERE	sttrn_stock_doctype		= tmp_stock_doctype		AND
												sttrn_stock_docno		= tmp_stock_docNo		AND
												sttrn_location_docno	= tmp_Location_docno	AND
												sttrn_docdate			< tmp_docDate			
										GROUP BY  sttrn_stock_doctype,
												sttrn_stock_docno,
												sttrn_location_docno) aa
							'
	PRINT @sqlString 
	EXEC(	@sqlString)


	/* Commented Below Update as per Demolan procedure*/
	--UPDATE	#tmp_PossibleDocumentsWithStockBRNS
	--SET		tmp_CurrentStock = (ISNULL( tmp_CurrentStock,0) + isnull(tmp_PONQty,0))
	--							- (ISNULL(tmp_SONQty,0) 
	--							) - (ISNULL(tmp_DOQty,0))
								

--	SET		tmp_CurrentStock =  ISNULL( tmp_CurrentStock,0) 
								
		--select * from #tmp_PossibleDocumentsWithStockBRNS						 

	SELECT	tmp_doctype						AS doctype,
			tmp_docno 						AS docno,
			0								AS docsrno,
			'Negative Stock'				AS br_desc,
			tmp_stock_Docno 				AS stock_code,
			Null							AS stock_Desc,
			ISNULL(tmp_CurrentStock,0)		AS stock_balance,
			0,
			0,
			tmp_PartNumber
	FROM	#tmp_PossibleDocumentsWithStockBRNS
	WHERE	tmp_CurrentStock < 0 AND
			tmp_Location_docno <> '14'
	         
	 
 
