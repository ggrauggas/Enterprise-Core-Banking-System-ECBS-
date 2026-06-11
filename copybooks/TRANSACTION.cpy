      ******************************************************************
      * TRANSACTION.cpy - movement record, mirrors table TRANSACTIONS.
      ******************************************************************
       01  TRANSACTION-REC.
           05 TRN-ID               PIC 9(10).
           05 TRN-ACCOUNT-ID       PIC 9(10).
           05 TRN-TYPE             PIC X(15).
              88 TRN-DEPOSIT       VALUE 'DEPOSIT'.
              88 TRN-WITHDRAWAL    VALUE 'WITHDRAWAL'.
              88 TRN-TRANSFER-IN   VALUE 'TRANSFER_IN'.
              88 TRN-TRANSFER-OUT  VALUE 'TRANSFER_OUT'.
              88 TRN-CARD-PURCHASE VALUE 'CARD_PURCHASE'.
              88 TRN-CARD-REFUND   VALUE 'CARD_REFUND'.
              88 TRN-INTEREST      VALUE 'INTEREST'.
              88 TRN-FEE           VALUE 'FEE'.
              88 TRN-LOAN-PAYMENT  VALUE 'LOAN_PAYMENT'.
              88 TRN-LOAN-DISBURSE VALUE 'LOAN_DISBURSE'.
           05 TRN-AMOUNT           PIC S9(13)V99 COMP-3.
           05 TRN-TIMESTAMP        PIC X(19).
           05 TRN-DESCRIPTION      PIC X(200).
           05 TRN-RELATED-ACCOUNT  PIC 9(10).
