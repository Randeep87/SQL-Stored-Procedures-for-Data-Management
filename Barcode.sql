USE [FACTSALTARAF]
GO
/****** Object:  StoredProcedure [dbo].[usp_BarcodeGenerate]    Script Date: 2/4/2025 9:41:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





ALTER  procedure [dbo].[usp_BarcodeGenerate]

/*-------------------------------------------------------------------------------------------------------
Author		: Randeep
Date		: 3-5-2018
Purpose		: Barcode Generation
----------------------------------------------------------------------------------------------------------
Notes		: 
----------------------------------------------------------------------------------------------------------
Revision History:
----------------------------------------------------------------------------------------------------------

[usp_BarcodeGenerate] 'SL0304','PUR','<FACTS><PARAMETERS><COLUMN1>PUR</COLUMN1><COLUMN2>5</COLUMN2></PARAMETERS></FACTS>',''


*/
	@strFycode				nvarchar(6),
	@strDocType				nvarchar(3),
	@strXmlDocDetails		nvarchar(max),
	@strLoginID				nvarchar(20)

AS


	DECLARE 	@idoc INT

	exec sp_xml_preparedocument @idoc output , @strXmlDocDetails


	SELECT	stptrn_stock_docno				AS [STOCK CODE],
			stptrn_piece_docno				AS [PIECE CODE],
			stptrn_stock_docno + '.' + 
			stptrn_piece_docno				as [BARCODE],
			prm_docno						as [PRODUCT CODE],
			prm_description					AS [PRODUCT NAME],
			pd3_code						AS [COLOR CODE],
			pd3_desc						AS [COLOR DESCRIPTION],
			pd4_code						AS [SIZE CODE],
			stk_grp4_desc					AS [SIZE DESCRIPTION],
			pdp_price						AS [PRICE]
	FROM	stock_piece_transaction	a
	INNER JOIN
				(
					select	COLUMN1	AS DocType,
							COLUMN2	as DocNo
					from openxml( @idoc , 'FACTS/PARAMETERS',2)
					with (
 							COLUMN1			Nvarchar(50),
							COLUMN2			Nvarchar(50)
						 )	
				)bb ON
				stptrn_fycode = @strFycode and
				stptrn_doctype = DocType and
				stptrn_docno = DocNo
	INNER JOIN stock_master ON
			stkmst_docno = stptrn_stock_docno
	INNER JOIN product_master on
			prm_docno = stkmst_product_docno
	INNER JOIN product_details_grp3 on
			pd3_docno = prm_docno and
			pd3_code = stkmst_grp3			
	INNER JOIN product_details_grp4 on
			pd4_docno = prm_docno and
			pd4_code = stkmst_grp4			
	LEFT OUTER JOIN product_details_price on
			pdp_docno = prm_docno and
			pdp_price_type = 'GBPW'
	INNER JOIN stk_grp4 on
			stk_grp4_docno = pd4_code
	ORDER BY stptrn_stock_docno,prm_docno, pd3_code,pd4_code,stptrn_piece_docno
		






