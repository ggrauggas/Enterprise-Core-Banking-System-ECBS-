      ******************************************************************
      * ACCT-OPEN.cbl - Fase 5: account opening (apertura).
      *
      * Bridge input (one JSON line on stdin):
      *   {"customerId":1,"accountType":"CHECKING","user":"operator1"}
      *
      * Rules: the owner must exist and be ACTIVE, the type must be
      * CHECKING or SAVINGS, accounts always open with balance 0
      * (funding happens through the Fase 6 transaction engine).
      * The IBAN is generated from the new account id: BBAN
      * 2100 0418 00 + id(10) with ISO 13616 check digits computed
      * by IBAN_UTILS. The opening is written to audit_logs.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-OPEN.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-CUST-ID              PIC 9(10).
       01  WS-ACCT-ID              PIC 9(10).
       01  WS-ACCT-TYPE            PIC X(10).
       01  WS-IBAN                 PIC X(34).
       01  WS-CUST-STATUS          PIC X(10).
       01  WS-AUD-USER             PIC X(50).
       01  WS-AUD-NEW              PIC X(500).
       01  WS-DB-CONN              PIC X(64).
       01  WS-DB-USER              PIC X(32).
       01  WS-DB-PASS              PIC X(32).

      * environment and control fields
       01  WS-ENV-HOST             PIC X(32) VALUE SPACES.
       01  WS-ENV-PORT             PIC X(6)  VALUE SPACES.
       01  WS-ENV-DB               PIC X(32) VALUE SPACES.
       01  WS-JSON-IN              PIC X(2000).
       01  WS-OK                   PIC X VALUE 'Y'.
       01  WS-CONNECTED            PIC X VALUE 'N'.
       01  WS-ERR-CODE             PIC X(5).
       01  WS-ERR-CTX              PIC X(80).
       01  WS-SQLCODE-ED           PIC -9(9).
       01  WS-ID-ED                PIC Z(9)9.
       01  WS-CID-ED               PIC Z(9)9.

      * framework module parameter blocks
       01  JU-PARAMS.
           05 JU-BUFFER            PIC X(2000).
           05 JU-KEY               PIC X(32).
           05 JU-VALUE             PIC X(256).
           05 JU-FOUND             PIC X.
           05 JU-RC                PIC X(2).
       01  IB-PARAMS.
           05 IB-OPERATION         PIC X(10).
           05 IB-COUNTRY           PIC X(2).
           05 IB-BBAN              PIC X(30).
           05 IB-BBAN-LEN          PIC 9(2).
           05 IB-IBAN              PIC X(34).
           05 IB-RC                PIC X(2).
       01  EH-PARAMS.
           05 EH-ERROR-CODE        PIC X(5).
           05 EH-CONTEXT           PIC X(80).
           05 EH-SEVERITY          PIC X.
           05 EH-MESSAGE           PIC X(120).
       01  LOG-PARAMS.
           05 LOG-LEVEL            PIC X(5).
           05 LOG-COMPONENT        PIC X(12).
           05 LOG-MSG              PIC X(200).

       PROCEDURE DIVISION.
       MAIN-PARA.
           ACCEPT WS-JSON-IN
           PERFORM PARSE-INPUT
           IF WS-OK = 'Y' PERFORM DB-CONNECT END-IF
           IF WS-OK = 'Y' PERFORM CHECK-CUSTOMER END-IF
           IF WS-OK = 'Y' PERFORM BUILD-IBAN END-IF
           IF WS-OK = 'Y' PERFORM INSERT-ACCOUNT END-IF
           IF WS-OK = 'Y' PERFORM WRITE-AUDIT END-IF
           PERFORM FINISH-TRANSACTION
           IF WS-OK = 'Y'
               PERFORM PRINT-OK
           ELSE
               PERFORM PRINT-ERROR
           END-IF
           STOP RUN.

       GET-JSON.
           MOVE WS-JSON-IN TO JU-BUFFER
           MOVE SPACES TO JU-VALUE
           CALL 'JSON_UTILS' USING JU-PARAMS.

       PARSE-INPUT.
           MOVE 'customerId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'customerId' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-CUST-ID = FUNCTION NUMVAL(JU-VALUE)
           MOVE 'accountType' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'accountType' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE FUNCTION UPPER-CASE(JU-VALUE) TO WS-ACCT-TYPE
           IF WS-ACCT-TYPE NOT = 'CHECKING'
                   AND WS-ACCT-TYPE NOT = 'SAVINGS'
               MOVE 'E015' TO WS-ERR-CODE
               MOVE SPACES TO WS-ERR-CTX
               STRING 'TYPE ' FUNCTION TRIM(WS-ACCT-TYPE)
                   DELIMITED BY SIZE INTO WS-ERR-CTX
               END-STRING
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'user' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE JU-VALUE TO WS-AUD-USER
           ELSE
               MOVE 'SYSTEM' TO WS-AUD-USER
           END-IF.

       DB-CONNECT.
           ACCEPT WS-ENV-HOST FROM ENVIRONMENT 'ECBS_DB_HOST'
           ACCEPT WS-ENV-PORT FROM ENVIRONMENT 'ECBS_DB_PORT'
           ACCEPT WS-ENV-DB   FROM ENVIRONMENT 'ECBS_DB_NAME'
           ACCEPT WS-DB-USER  FROM ENVIRONMENT 'ECBS_DB_USER'
           ACCEPT WS-DB-PASS  FROM ENVIRONMENT 'ECBS_DB_PASSWORD'
           IF WS-ENV-HOST = SPACES MOVE 'postgres' TO WS-ENV-HOST
           END-IF
           IF WS-ENV-PORT = SPACES MOVE '5432' TO WS-ENV-PORT
           END-IF
           IF WS-ENV-DB = SPACES MOVE 'ecbs' TO WS-ENV-DB
           END-IF
           MOVE SPACES TO WS-DB-CONN
           STRING FUNCTION TRIM(WS-ENV-DB) '@'
                  FUNCTION TRIM(WS-ENV-HOST) ':'
                  FUNCTION TRIM(WS-ENV-PORT)
               DELIMITED BY SIZE INTO WS-DB-CONN
           END-STRING
           EXEC SQL
               CONNECT :WS-DB-USER IDENTIFIED BY :WS-DB-PASS
                       USING :WS-DB-CONN
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 'N' TO WS-OK
               MOVE 'E010' TO WS-ERR-CODE
               MOVE 'DB CONNECT FAILED' TO WS-ERR-CTX
           ELSE
               MOVE 'Y' TO WS-CONNECTED
           END-IF.

       CHECK-CUSTOMER.
           EXEC SQL
               SELECT status INTO :WS-CUST-STATUS
                 FROM customers
                WHERE customer_id = :WS-CUST-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   PERFORM SET-CUSTOMER-CTX
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
               WHEN WS-CUST-STATUS NOT = 'ACTIVE'
                   MOVE 'E017' TO WS-ERR-CODE
                   PERFORM SET-CUSTOMER-CTX
                   MOVE 'N' TO WS-OK
           END-EVALUATE.

      * the id is taken from the sequence BEFORE the insert so the
      * IBAN can embed it (BBAN = entity 2100, office 0418, dc 00,
      * account number = id zero-padded to 10 digits)
       BUILD-IBAN.
           EXEC SQL
               SELECT nextval('accounts_account_id_seq')
                 INTO :WS-ACCT-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO IB-BBAN
           STRING '21000418' '00' WS-ACCT-ID
               DELIMITED BY SIZE INTO IB-BBAN
           END-STRING
           MOVE 20 TO IB-BBAN-LEN
           MOVE 'ES' TO IB-COUNTRY
           MOVE 'BUILD' TO IB-OPERATION
           CALL 'IBAN_UTILS' USING IB-PARAMS
           IF IB-RC NOT = '00'
               MOVE 'E010' TO WS-ERR-CODE
               MOVE 'IBAN GENERATION FAILED' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE IB-IBAN TO WS-IBAN.

       INSERT-ACCOUNT.
           EXEC SQL
               INSERT INTO accounts
                      (account_id, iban, customer_id, balance,
                       account_type, status)
               VALUES (:WS-ACCT-ID,
                       TRIM(TRAILING FROM :WS-IBAN),
                       :WS-CUST-ID, 0,
                       TRIM(TRAILING FROM :WS-ACCT-TYPE),
                       'ACTIVE')
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       WRITE-AUDIT.
           MOVE WS-CUST-ID TO WS-CID-ED
           MOVE SPACES TO WS-AUD-NEW
           STRING '{"iban":"' FUNCTION TRIM(WS-IBAN)
                  '","customerId":' FUNCTION TRIM(WS-CID-ED)
                  ',"accountType":"' FUNCTION TRIM(WS-ACCT-TYPE)
                  '","balance":"0.00","status":"ACTIVE"}'
               DELIMITED BY SIZE INTO WS-AUD-NEW
           END-STRING
           EXEC SQL
               INSERT INTO audit_logs
                      (username, operation, entity_type,
                       entity_id, old_value, new_value)
               VALUES (TRIM(TRAILING FROM :WS-AUD-USER),
                       'CREATE', 'ACCOUNT', :WS-ACCT-ID, NULL,
                       CAST(TRIM(TRAILING FROM :WS-AUD-NEW)
                            AS JSONB))
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       FINISH-TRANSACTION.
           IF WS-CONNECTED = 'Y'
               IF WS-OK = 'Y'
                   EXEC SQL COMMIT WORK END-EXEC
               ELSE
                   EXEC SQL ROLLBACK WORK END-EXEC
               END-IF
               EXEC SQL DISCONNECT ALL END-EXEC
           END-IF.

       SET-CUSTOMER-CTX.
           MOVE WS-CUST-ID TO WS-ID-ED
           MOVE SPACES TO WS-ERR-CTX
           STRING 'CUSTOMER ' FUNCTION TRIM(WS-ID-ED)
               DELIMITED BY SIZE INTO WS-ERR-CTX
           END-STRING.

       SQL-ERROR-PARA.
           MOVE 'N' TO WS-OK
           MOVE 'E010' TO WS-ERR-CODE
           MOVE SQLCODE TO WS-SQLCODE-ED
           MOVE SPACES TO WS-ERR-CTX
           STRING 'SQLCODE ' WS-SQLCODE-ED ' ' SQLERRMC(1:40)
               DELIMITED BY SIZE INTO WS-ERR-CTX
           END-STRING.

       PRINT-OK.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'ACCT-OPEN' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-ACCT-ID TO WS-ID-ED
           STRING 'account opened id='
                  FUNCTION TRIM(WS-ID-ED)
                  ' iban=' FUNCTION TRIM(WS-IBAN)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
           CALL 'LOGGER' USING LOG-PARAMS
           DISPLAY '{"status":"OK","accountId":'
                   FUNCTION TRIM(WS-ID-ED)
                   ',"iban":"' FUNCTION TRIM(WS-IBAN)
                   '","accountType":"' FUNCTION TRIM(WS-ACCT-TYPE)
                   '","balance":0.00}'.

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
