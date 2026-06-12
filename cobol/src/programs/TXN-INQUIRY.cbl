      ******************************************************************
      * TXN-INQUIRY.cbl - Fase 6: transaction history of an account.
      *
      * Bridge input (one JSON line on stdin):
      *   {"accountId":1}                      -> last 100 movements
      *   {"accountId":1,"typeFilter":"DEPOSIT"} -> filter by type
      *
      * Movements are returned newest first. Read-only: not audited,
      * only logged.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXN-INQUIRY.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-ACCT-ID              PIC 9(10).
       01  WS-FILTER               PIC X(15).
       01  WS-TYPE-ALL             PIC 9.
       01  WS-ROW-ID               PIC 9(10).
       01  WS-ROW-TYPE             PIC X(15).
       01  WS-ROW-AMT              PIC X(20).
       01  WS-ROW-TS               PIC X(19).
       01  WS-ROW-DESC             PIC X(200).
       01  WS-ROW-RELATED          PIC 9(10).
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
       01  WS-FIRST-ROW            PIC X.
       01  WS-COUNT                PIC 9(4).
       01  WS-COUNT-ED             PIC ZZZ9.
       01  WS-ERR-CODE             PIC X(5).
       01  WS-ERR-CTX              PIC X(80).
       01  WS-SQLCODE-ED           PIC -9(9).
       01  WS-ID-ED                PIC Z(9)9.
       01  WS-REL-ED               PIC Z(9)9.

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
           IF WS-OK = 'Y' PERFORM CHECK-ACCOUNT END-IF
           IF WS-OK = 'Y' PERFORM LIST-TXNS END-IF
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
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'accountId' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-ACCT-ID = FUNCTION NUMVAL(JU-VALUE)
           MOVE 'typeFilter' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-TYPE-ALL
               MOVE FUNCTION UPPER-CASE(JU-VALUE) TO WS-FILTER
           ELSE
               MOVE 1 TO WS-TYPE-ALL
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

       CHECK-ACCOUNT.
           EXEC SQL
               SELECT account_id INTO :WS-ROW-ID
                 FROM accounts
                WHERE account_id = :WS-ACCT-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   PERFORM SET-ACCOUNT-CTX
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
           END-EVALUATE.

       LIST-TXNS.
           EXEC SQL
               DECLARE TXNCUR CURSOR FOR
               SELECT t.transaction_id, t.transaction_type,
                      CAST(t.amount AS VARCHAR),
                      SUBSTR(CAST(t.timestamp AS VARCHAR), 1, 19),
                      COALESCE(t.description, ''),
                      COALESCE(t.related_account_id, 0)
                 FROM transactions t
                WHERE t.account_id = :WS-ACCT-ID
                  AND (:WS-TYPE-ALL = 1
                       OR t.transaction_type =
                          TRIM(TRAILING FROM :WS-FILTER))
                ORDER BY t.transaction_id DESC
                LIMIT 100
           END-EXEC
           EXEC SQL
               OPEN TXNCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           MOVE WS-ACCT-ID TO WS-ID-ED
           DISPLAY '{"status":"OK","accountId":'
                   FUNCTION TRIM(WS-ID-ED)
                   ',"transactions":['
           MOVE 'Y' TO WS-FIRST-ROW
           MOVE 0 TO WS-COUNT
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH TXNCUR
                    INTO :WS-ROW-ID, :WS-ROW-TYPE, :WS-ROW-AMT,
                         :WS-ROW-TS, :WS-ROW-DESC,
                         :WS-ROW-RELATED
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
               CLOSE TXNCUR
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
           MOVE WS-ROW-RELATED TO WS-REL-ED
           DISPLAY '{"transactionId":' FUNCTION TRIM(WS-ID-ED)
                   ',"type":"' FUNCTION TRIM(WS-ROW-TYPE)
                   '","amount":' FUNCTION TRIM(WS-ROW-AMT)
                   ',"timestamp":"' WS-ROW-TS
                   '","description":"'
                   FUNCTION TRIM(WS-ROW-DESC)
                   '","relatedAccountId":'
                   FUNCTION TRIM(WS-REL-ED)
                   '}'.

       LOG-INQUIRY.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'TXN-INQUIRY' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-ACCT-ID TO WS-ID-ED
           MOVE WS-COUNT TO WS-COUNT-ED
           STRING 'history account='
                  FUNCTION TRIM(WS-ID-ED)
                  ' rows=' FUNCTION TRIM(WS-COUNT-ED)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
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
