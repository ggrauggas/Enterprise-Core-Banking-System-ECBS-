      ******************************************************************
      * ACCOUNT.cpy - account record, mirrors table ACCOUNTS.
      ******************************************************************
       01  ACCOUNT-REC.
           05 ACC-ID               PIC 9(10).
           05 ACC-IBAN             PIC X(34).
           05 ACC-CUSTOMER-ID      PIC 9(10).
           05 ACC-BALANCE          PIC S9(13)V99 COMP-3.
           05 ACC-TYPE             PIC X(10).
              88 ACC-CHECKING      VALUE 'CHECKING'.
              88 ACC-SAVINGS       VALUE 'SAVINGS'.
           05 ACC-STATUS           PIC X(10).
              88 ACC-ACTIVE        VALUE 'ACTIVE'.
              88 ACC-CLOSED        VALUE 'CLOSED'.
           05 ACC-CREATED-AT       PIC X(19).
