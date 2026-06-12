      ******************************************************************
      * ACCT-INQUIRY.cbl - Fase 5: account inquiry (consulta).
      *
      * Bridge input (one JSON line on stdin), modes:
      *   {"accountId":7}      -> single account, full detail with
      *                           the owner's name (SQL JOIN)
      *   {}                   -> list all accounts (max 100)
      *   {"customerId":1}     -> list the accounts of one customer
      *   {"statusFilter":"CLOSED"} -> list filtered by status
      *   (customerId and statusFilter can be combined)
      *
      * Read-only: inquiries are not audited, only logged.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-INQUIRY.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-ACCT-ID              PIC 9(10).
       01  WS-CUST-FILT            PIC 9(10).
       01  WS-FILTER               PIC X(10).
       01  WS-ST-ALL               PIC 9.
       01  WS-ROW-ID               PIC 9(10).
       01  WS-ROW-IBAN             PIC X(34).
       01  WS-ROW-CUST             PIC 9(10).
       01  WS-ROW-FIRST            PIC X(50).
       01  WS-ROW-LAST             PIC X(80).
       01  WS-ROW-BAL              PIC X(20).
       01  WS-ROW-TYPE             PIC X(10).
       01  WS-ROW-STATUS           PIC X(10).
       01  WS-ROW-CREATED          PIC X(19).
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
       01  WS-SINGLE               PIC X VALUE 'N'.
       01  WS-FIRST-ROW            PIC X.
       01  WS-COUNT                PIC 9(4).
       01  WS-COUNT-ED             PIC ZZZ9.
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
           IF WS-OK = 'Y'
               IF WS-SINGLE = 'Y'
                   PERFORM GET-ONE
               ELSE
                   PERFORM LIST-ACCOUNTS
               END-IF
           END-IF
           PERFORM FINISH-TRANSACTION
           IF WS-OK NOT = 'Y'
               PERFORM PRINT-ERROR
           END-IF
           STOP RUN.

       GET-JSON.
           MOVE WS-JSON-IN TO JU-BUFFER
           MOVE SPACES TO JU-VALUE
           CALL 'JSON_UTILS' USING JU-PARAMS.

       PARSE-INPUT.
           MOVE 'accountId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 'Y' TO WS-SINGLE
               COMPUTE WS-ACCT-ID = FUNCTION NUMVAL(JU-VALUE)
           END-IF
           MOVE 'customerId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               COMPUTE WS-CUST-FILT = FUNCTION NUMVAL(JU-VALUE)
           ELSE
               MOVE 0 TO WS-CUST-FILT
           END-IF
           MOVE 'statusFilter' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-ST-ALL
               MOVE FUNCTION UPPER-CASE(JU-VALUE) TO WS-FILTER
           ELSE
               MOVE 1 TO WS-ST-ALL
               MOVE SPACES TO WS-FILTER
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

       GET-ONE.
           EXEC SQL
               SELECT a.account_id, a.iban, a.customer_id,
                      c.first_name, c.last_name,
                      CAST(a.balance AS VARCHAR),
                      a.account_type, a.status,
                      SUBSTR(CAST(a.created_at AS VARCHAR), 1, 19)
                 INTO :WS-ROW-ID, :WS-ROW-IBAN, :WS-ROW-CUST,
                      :WS-ROW-FIRST, :WS-ROW-LAST, :WS-ROW-BAL,
                      :WS-ROW-TYPE, :WS-ROW-STATUS,
                      :WS-ROW-CREATED
                 FROM accounts a
                 JOIN customers c
                   ON c.customer_id = a.customer_id
                WHERE a.account_id = :WS-ACCT-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   PERFORM SET-ACCOUNT-CTX
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
               WHEN OTHER
                   PERFORM PRINT-ONE
           END-EVALUATE.

       PRINT-ONE.
           MOVE WS-ROW-ID TO WS-ID-ED
           MOVE WS-ROW-CUST TO WS-CID-ED
           DISPLAY '{"status":"OK","account":{'
                   '"accountId":' FUNCTION TRIM(WS-ID-ED)
                   ',"iban":"' FUNCTION TRIM(WS-ROW-IBAN)
                   '","customerId":' FUNCTION TRIM(WS-CID-ED)
                   ',"customerName":"'
                   FUNCTION TRIM(WS-ROW-FIRST) ' '
                   FUNCTION TRIM(WS-ROW-LAST)
                   '","balance":' FUNCTION TRIM(WS-ROW-BAL)
                   ',"accountType":"' FUNCTION TRIM(WS-ROW-TYPE)
                   '","status":"' FUNCTION TRIM(WS-ROW-STATUS)
                   '","createdAt":"' WS-ROW-CREATED
                   '"}}'
           PERFORM LOG-INQUIRY.

       LIST-ACCOUNTS.
           EXEC SQL
               DECLARE ACCTCUR CURSOR FOR
               SELECT account_id, iban, customer_id,
                      CAST(balance AS VARCHAR),
                      account_type, status
                 FROM accounts
                WHERE (:WS-CUST-FILT = 0
                       OR customer_id = :WS-CUST-FILT)
                  AND (:WS-ST-ALL = 1
                       OR status = TRIM(TRAILING FROM :WS-FILTER))
                ORDER BY account_id
                LIMIT 100
           END-EXEC
           EXEC SQL
               OPEN ACCTCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY '{"status":"OK","accounts":['
           MOVE 'Y' TO WS-FIRST-ROW
           MOVE 0 TO WS-COUNT
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH ACCTCUR
                    INTO :WS-ROW-ID, :WS-ROW-IBAN, :WS-ROW-CUST,
                         :WS-ROW-BAL, :WS-ROW-TYPE,
                         :WS-ROW-STATUS
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               ADD 1 TO WS-COUNT
               PERFORM PRINT-ROW
           END-PERFORM
           EXEC SQL
               CLOSE ACCTCUR
           END-EXEC
           IF WS-OK = 'Y'
               MOVE WS-COUNT TO WS-COUNT-ED
               DISPLAY '],"count":' FUNCTION TRIM(WS-COUNT-ED) '}'
               PERFORM LOG-INQUIRY
           END-IF.

       PRINT-ROW.
           IF WS-FIRST-ROW = 'Y'
               MOVE 'N' TO WS-FIRST-ROW
           ELSE
               DISPLAY ','
           END-IF
           MOVE WS-ROW-ID TO WS-ID-ED
           MOVE WS-ROW-CUST TO WS-CID-ED
           DISPLAY '{"accountId":' FUNCTION TRIM(WS-ID-ED)
                   ',"iban":"' FUNCTION TRIM(WS-ROW-IBAN)
                   '","customerId":' FUNCTION TRIM(WS-CID-ED)
                   ',"balance":' FUNCTION TRIM(WS-ROW-BAL)
                   ',"accountType":"' FUNCTION TRIM(WS-ROW-TYPE)
                   '","status":"' FUNCTION TRIM(WS-ROW-STATUS)
                   '"}'.

       LOG-INQUIRY.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'ACCT-INQUIRY' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           IF WS-SINGLE = 'Y'
               MOVE WS-ACCT-ID TO WS-ID-ED
               STRING 'account inquiry id='
                      FUNCTION TRIM(WS-ID-ED)
                   DELIMITED BY SIZE INTO LOG-MSG
               END-STRING
           ELSE
               MOVE WS-COUNT TO WS-COUNT-ED
               STRING 'account list returned rows='
                      FUNCTION TRIM(WS-COUNT-ED)
                   DELIMITED BY SIZE INTO LOG-MSG
               END-STRING
           END-IF
           CALL 'LOGGER' USING LOG-PARAMS.

       FINISH-TRANSACTION.
           IF WS-CONNECTED = 'Y'
               EXEC SQL COMMIT WORK END-EXEC
               EXEC SQL DISCONNECT ALL END-EXEC
           END-IF.

       SET-ACCOUNT-CTX.
           MOVE WS-ACCT-ID TO WS-ID-ED
           MOVE SPACES TO WS-ERR-CTX
           STRING 'ACCOUNT ' FUNCTION TRIM(WS-ID-ED)
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

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
