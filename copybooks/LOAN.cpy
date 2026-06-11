      ******************************************************************
      * LOAN.cpy - loan record, mirrors table LOANS.
      ******************************************************************
       01  LOAN-REC.
           05 LOAN-ID              PIC 9(10).
           05 LOAN-CUSTOMER-ID     PIC 9(10).
           05 LOAN-AMOUNT          PIC S9(13)V99 COMP-3.
           05 LOAN-RATE            PIC S9(3)V99 COMP-3.
           05 LOAN-MONTHS          PIC 9(4).
           05 LOAN-STATUS          PIC X(10).
              88 LOAN-REQUESTED    VALUE 'REQUESTED'.
              88 LOAN-APPROVED     VALUE 'APPROVED'.
              88 LOAN-REJECTED     VALUE 'REJECTED'.
              88 LOAN-ACTIVE       VALUE 'ACTIVE'.
              88 LOAN-PAID         VALUE 'PAID'.
              88 LOAN-DEFAULTED    VALUE 'DEFAULTED'.
