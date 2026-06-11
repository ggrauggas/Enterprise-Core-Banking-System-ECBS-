      ******************************************************************
      * CARD.cpy - card record, mirrors table CARDS.
      ******************************************************************
       01  CARD-REC.
           05 CARD-ID              PIC 9(10).
           05 CARD-ACCOUNT-ID      PIC 9(10).
           05 CARD-NUMBER          PIC X(16).
           05 CARD-LIMIT           PIC S9(13)V99 COMP-3.
           05 CARD-AVAILABLE       PIC S9(13)V99 COMP-3.
           05 CARD-STATUS          PIC X(10).
              88 CARD-ACTIVE       VALUE 'ACTIVE'.
              88 CARD-BLOCKED      VALUE 'BLOCKED'.
              88 CARD-CANCELLED    VALUE 'CANCELLED'.
