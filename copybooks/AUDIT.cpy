      ******************************************************************
      * AUDIT.cpy - audit event record, mirrors table AUDIT_LOGS.
      ******************************************************************
       01  AUDIT-REC.
           05 AUD-USERNAME         PIC X(50).
           05 AUD-EVENT-TIME       PIC X(19).
           05 AUD-OPERATION        PIC X(30).
           05 AUD-ENTITY-TYPE      PIC X(30).
           05 AUD-ENTITY-ID        PIC 9(10).
           05 AUD-OLD-VALUE        PIC X(500).
           05 AUD-NEW-VALUE        PIC X(500).
