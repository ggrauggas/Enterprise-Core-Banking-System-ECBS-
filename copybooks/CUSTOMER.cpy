      ******************************************************************
      * CUSTOMER.cpy - customer record, mirrors table CUSTOMERS.
      ******************************************************************
       01  CUSTOMER-REC.
           05 CUST-ID              PIC 9(10).
           05 CUST-FIRST-NAME      PIC X(50).
           05 CUST-LAST-NAME       PIC X(80).
           05 CUST-BIRTH-DATE      PIC X(10).
           05 CUST-EMAIL           PIC X(120).
           05 CUST-PHONE           PIC X(20).
           05 CUST-STATUS          PIC X(10).
              88 CUST-ACTIVE       VALUE 'ACTIVE'.
              88 CUST-INACTIVE     VALUE 'INACTIVE'.
              88 CUST-DELETED      VALUE 'DELETED'.
