USE [SalesData]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   TRIGGER [dbo].[TRI_ACCOUNT_TRANSACTION] ON [dbo].[ACCOUNT_TRANSACTION]
FOR  INSERT
AS 
BEGIN
				


		DECLARE	@strLocalCurrency	nvarchar(20)
		
		select	@strLocalCurrency = company_desc
		from	company_parameter
		where	company_code  = 'CURRENCY'


		--SELECT * INTO ZZ FROM inserted
		
		-- this for other currency	
		update	account_master_enquiry
		set		acmstenq_debit_amount = acmstenq_debit_amount + case when actrn_fcamount < 0 then actrn_fcamount*-1 else 0 end,
				acmstenq_credit_amount = acmstenq_credit_amount + case when actrn_fcamount < 0 then 0 else actrn_fcamount end,
				acmstenq_cls_amount = acmstenq_cls_amount + actrn_fcamount,
				acmstenq_used = 1
		from	inserted
		where	acmstenq_ac_docno = actrn_ac_docno and
				acmstenq_subledger_docno = isnull(actrn_subledger_docno,actrn_ac_docno) and
				acmstenq_curr_docno	= actrn_curr_docno AND
				acmstenq_curr_docno	<> @strLocalCurrency


		--	this for local currency
		update	account_master_enquiry
		set		acmstenq_debit_amount = acmstenq_debit_amount + case when actrn_amount < 0 then actrn_amount * -1 else 0 end,
				acmstenq_credit_amount = acmstenq_credit_amount + case when actrn_amount < 0 then 0 else actrn_amount end,
				acmstenq_cls_amount = acmstenq_cls_amount + actrn_amount,
				acmstenq_used =  1
		from	inserted
		where	acmstenq_ac_docno = actrn_ac_docno and
				acmstenq_subledger_docno = isnull(actrn_subledger_docno,actrn_ac_docno) and
				acmstenq_curr_docno	= @strLocalCurrency
		
		
		----------------------------------------PDC Amount-------------------------------------------------------------------

		update	account_master_enquiry
		set		acmstenq_PDC_amount = acmstenq_PDC_amount + PDCAmount
		from	(
					SELECT	actrn_ac_docno_cheque, 
							actrn_subledger_docno_cheque, 
							SUM( ACTRN_AMOUNT ) AS PDCAmount
					FROM	inserted
					inner join [dbo].[vw_PDC_Accounts] on
							acmst_docno = actrn_ac_docno					
					GROUP BY actrn_ac_docno_cheque, actrn_subledger_docno_cheque
				)AA
		where	acmstenq_ac_docno = actrn_ac_docno_cheque and
				acmstenq_subledger_docno = isnull(actrn_subledger_docno_cheque,actrn_ac_docno_cheque) and
				acmstenq_curr_docno	= @strLocalCurrency


		update	party_master
		set		partymst_pdc_amt = partymst_pdc_amt + PDCAmount
		from	(
					SELECT	actrn_ac_docno_cheque, 
							actrn_subledger_docno_cheque, 
							SUM( ACTRN_AMOUNT) AS PDCAmount
					FROM	inserted
					inner join [dbo].[vw_PDC_Accounts] on
							acmst_docno = actrn_ac_docno					
					GROUP BY actrn_ac_docno_cheque, actrn_subledger_docno_cheque
				)AA
		where	partymst_doctype	= actrn_ac_docno_cheque and
				partymst_docno		= isnull(actrn_subledger_docno_cheque,actrn_ac_docno_cheque) 
		
		
		-----------------------------------------------------------------------------------------------------------


		UPDATE account_master 
		SET 	acmst_ytddr = acmst_ytddr + ISNULL( sq.Total,0)
		FROM 
			(
				SELECT	actrn_ac_docno, 
						SUM( actrn_amount)	AS total, 
						SUM( actrn_fcamount) as fctotal
				FROM	inserted
				WHERE	actrn_amount < 0 and
						actrn_subledger_docno is null
				GROUP BY actrn_ac_docno
			) AS sq
		where acmst_docno = sq.actrn_ac_docno
		
		UPDATE account_master 
		SET 	acmst_ytdcr = acmst_ytdcr + ISNULL( sq.Total,0)
		FROM 
			(
				SELECT	actrn_ac_docno, 
						SUM( actrn_amount)	AS total, 
						SUM( actrn_fcamount) as fctotal
				FROM	inserted
				WHERE	actrn_amount > 0 and
						actrn_subledger_docno is null
				GROUP BY actrn_ac_docno
			) AS sq
		where acmst_docno = sq.actrn_ac_docno



		UPDATE party_master 
		SET 	partymst_ytddr = partymst_ytddr + ISNULL( sq.Total,0)
		FROM 
			(
				SELECT	actrn_ac_docno, 
						actrn_subledger_docno,
						SUM( actrn_amount)	AS total, 
						SUM( actrn_fcamount) as fctotal
				FROM	inserted
				WHERE	actrn_amount < 0 
				GROUP BY actrn_ac_docno,actrn_subledger_docno
			) AS sq
		where partymst_doctype = actrn_ac_docno and
				partymst_docno = actrn_subledger_docno
		
		
		UPDATE party_master 
		SET 	partymst_ytdcr = partymst_ytdcr + ISNULL( sq.Total,0)
		FROM 
			(
				SELECT	actrn_ac_docno, 
						actrn_subledger_docno,
						SUM( actrn_amount)	AS total, 
						SUM( actrn_fcamount) as fctotal
				FROM	inserted
				WHERE	actrn_amount > 0 
				GROUP BY actrn_ac_docno,actrn_subledger_docno
			) AS sq
		where partymst_doctype = actrn_ac_docno and
				partymst_docno = actrn_subledger_docno


	
				

		UPDATE	ACCOUNT_TRANSACTION
		SET		ACTRN_RECO_DATE = ACCOUNT_TRANSACTION_RECO.ACTRN_RECO_DATE,
				ACTRN_RECO_AMOUNT = ACCOUNT_TRANSACTION_RECO.ACTRN_RECO_AMOUNT,
				ACTRN_RECO_FCAMOUNT = ACCOUNT_TRANSACTION_RECO.ACTRN_RECO_FCAMOUNT
		FROM	ACCOUNT_TRANSACTION_RECO
		WHERE	ACCOUNT_TRANSACTION.[ACTRN_FYCODE] = ACCOUNT_TRANSACTION_RECO.[ACTRN_FYCODE] AND
				ACCOUNT_TRANSACTION.[ACTRN_DOCTYPE] = ACCOUNT_TRANSACTION_RECO.[ACTRN_DOCTYPE] AND
				ACCOUNT_TRANSACTION.[ACTRN_DOCNO] = ACCOUNT_TRANSACTION_RECO.[ACTRN_DOCNO] AND
				ACCOUNT_TRANSACTION.[ACTRN_DOCSRNO] = ACCOUNT_TRANSACTION_RECO.[ACTRN_DOCSRNO] AND
				ACCOUNT_TRANSACTION.[ACTRN_AC_DOCNO] = ACCOUNT_TRANSACTION_RECO.[ACTRN_AC_DOCNO] AND
				ACCOUNT_TRANSACTION.[ACTRN_AMOUNT] = ACCOUNT_TRANSACTION_RECO.[ACTRN_AMOUNT] 						
				

		DELETE  ACCOUNT_TRANSACTION_RECO	FROM	inserted
		WHERE	ACCOUNT_TRANSACTION_RECO.[ACTRN_FYCODE] = inserted.[ACTRN_FYCODE] AND
				ACCOUNT_TRANSACTION_RECO.[ACTRN_DOCTYPE] = inserted.[ACTRN_DOCTYPE] AND
				ACCOUNT_TRANSACTION_RECO.[ACTRN_DOCNO] = inserted.[ACTRN_DOCNO] 
		
		
		

		INSERT INTO ACCOUNT_TRANSACTION_HISTORY
		(
				ACTRN_FYCODE, 
				ACTRN_DOCNO, 
				ACTRN_DOCTYPE, 
				ACTRN_DOCSRNO, 				
				ACTRN_AC_DOCNO, 
				ACTRN_SUBLEDGER_DOCNO, 
				ACTRN_DIVN_DOCNO, 
				ACTRN_DEPT_DOCNO, 
				ACTRN_DOCDATE, 
				ACTRN_VALDATE, 
				ACTRN_NARRATION, 
				ACTRN_AMOUNT, 
				ACTRN_BAL_AMOUNT, 
				ACTRN_FCAMOUNT, 
				ACTRN_BAL_FCAMOUNT, 
				ACTRN_CURR_RATE, 
				ACTRN_RECO_AMOUNT, 
				ACTRN_RECO_REASON, 
				ACTRN_RECO_FCAMOUNT, 
				ACTRN_CURR_DOCNO, 				
				ACTRN_SMAN_DOCNO, 
				ACTRN_COST_DOCNO, 
				ACTRN_JOB_DOCNO, 
				ACTRN_RECO_DATE, 
				ACTRN_PDC_AMOUNT, 
				ACTRN_PDC_FCAMOUNT, 
				ACTRN_CREATED_BY, 
				ACTRN_CREATED_TS,
				ACTRN_HISTORY_TRACKING_BATCH_ID,
				ACTRN_HISTORY_TRACKING_INSDEL_STATUS
		)
		SELECT	ACTRN_FYCODE, 
				ACTRN_DOCNO, 
				ACTRN_DOCTYPE, 
				ACTRN_DOCSRNO, 				
				ACTRN_AC_DOCNO, 
				ACTRN_SUBLEDGER_DOCNO, 
				ACTRN_DIVN_DOCNO, 
				ACTRN_DEPT_DOCNO, 
				ACTRN_DOCDATE, 
				ACTRN_VALDATE, 
				ACTRN_NARRATION, 
				ACTRN_AMOUNT, 
				ACTRN_BAL_AMOUNT, 
				ACTRN_FCAMOUNT, 
				ACTRN_BAL_FCAMOUNT, 
				ACTRN_CURR_RATE, 
				ACTRN_RECO_AMOUNT, 
				ACTRN_RECO_REASON, 
				ACTRN_RECO_FCAMOUNT, 
				ACTRN_CURR_DOCNO, 				
				ACTRN_SMAN_DOCNO, 
				ACTRN_COST_DOCNO, 
				ACTRN_JOB_DOCNO, 
				ACTRN_RECO_DATE, 
				ACTRN_PDC_AMOUNT, 
				ACTRN_PDC_FCAMOUNT, 
				ACTRN_CREATED_BY, 
				ACTRN_CREATED_TS,
				ACTRN_HISTORY_TRACKING_BATCH_ID,
				0
		FROM	inserted






END
