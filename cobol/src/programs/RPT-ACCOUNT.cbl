      ******************************************************************
      * RPT-ACCOUNT.cbl - Fase 11: account statement report.
      *
      * Bridge input (one JSON line on stdin):
      *   {"accountId":1}              -> last 50 movements
      *   {"accountId":1,"limit":200}  -> up to 200 movements
      *
      * Returns the account statement as JSON (header + holder +
      * movements newest first + totals) and exports it to
      * ECBS_REPORT_DIR as statement_<id>.csv and statement_<id>.pdf
      * (PDF via the reusable PDF-WRITER module). Read-only.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPT-ACCOUNT.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CSV-FILE ASSIGN TO WS-CSV-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-CSV-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  CSV-FILE.
       01  CSV-REC                 PIC X(300).

       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-ACC-ID               PIC 9(10).
       01  WS-LIMIT                PIC 9(4).
       01  WS-IBAN                 PIC X(34).
       01  WS-FIRST                PIC X(50).
       01  WS-LAST                 PIC X(80).
       01  WS-A-BAL                PIC X(20).
       01  WS-A-TYPE               PIC X(10).
       01  WS-A-STATUS             PIC X(10).
       01  WS-INFLOW               PIC X(24).
       01  WS-OUTFLOW              PIC X(24).
       01  WS-MVCOUNT              PIC 9(9).
       01  WS-T-ID                 PIC 9(10).
       01  WS-T-TYPE               PIC X(15).
       01  WS-T-AMT                PIC X(20).
       01  WS-T-TS                 PIC X(19).
       01  WS-T-DESC               PIC X(200).
       01  WS-DB-CONN              PIC X(64).
       01  WS-DB-USER              PIC X(32).
       01  WS-DB-PASS              PIC X(32).

      * export / buffering
       01  WS-REPORT-DIR           PIC X(80) VALUE SPACES.
       01  WS-CSV-PATH             PIC X(120).
       01  WS-PDF-PATH             PIC X(120).
       01  WS-CSV-FS               PIC X(2).
       01  WS-TS-NOW               PIC X(19).
       01  WS-DIR                  PIC X(3).
       01  WS-SIGN                 PIC X.
       01  WS-MV-CNT               PIC 9(4) VALUE 0.
       01  WS-MV-MAX               PIC 9(4).
       01  WS-K                    PIC 9(4).
       01  WS-MV-TAB.
           05 WS-MV-CSV            OCCURS 200 PIC X(300).
       01  WS-ID-ED                PIC Z(9)9.
       01  WS-NZ                   PIC Z(8)9.
       01  WS-IDFILE               PIC X(16).

      * environment and control fields
       01  WS-ENV-HOST             PIC X(32) VALUE SPACES.
       01  WS-ENV-PORT             PIC X(6)  VALUE SPACES.
       01  WS-ENV-DB               PIC X(32) VALUE SPACES.
       01  WS-JSON-IN              PIC X(2000).
       01  WS-OK                   PIC X VALUE 'Y'.
       01  WS-CONNECTED            PIC X VALUE 'N'.
       01  WS-FIRST-ROW            PIC X.
       01  WS-ERR-CODE             PIC X(5).
       01  WS-ERR-CTX              PIC X(80).
       01  WS-SQLCODE-ED           PIC -9(9).

      * framework module parameter blocks
       01  JU-PARAMS.
           05 JU-BUFFER            PIC X(2000).
           05 JU-KEY               PIC X(32).
           05 JU-VALUE             PIC X(256).
           05 JU-FOUND             PIC X.
           05 JU-RC                PIC X(2).
       01  DU-PARAMS.
           05 DU-OPERATION         PIC X(12).
           05 DU-DATE-1            PIC X(10).
           05 DU-DATE-2            PIC X(10).
           05 DU-NUMBER            PIC S9(5).
           05 DU-RESULT-DATE       PIC X(10).
           05 DU-RESULT-NUM        PIC S9(9).
           05 DU-RESULT-TS         PIC X(19).
           05 DU-STATUS            PIC X(2).
       01  EH-PARAMS.
           05 EH-ERROR-CODE        PIC X(5).
           05 EH-CONTEXT           PIC X(80).
           05 EH-SEVERITY          PIC X.
           05 EH-MESSAGE           PIC X(120).
       01  LOG-PARAMS.
           05 LOG-LEVEL            PIC X(5).
           05 LOG-COMPONENT        PIC X(12).
           05 LOG-MSG              PIC X(200).
       01  PW-PARAMS.
           05 PW-FILEPATH          PIC X(120).
           05 PW-TITLE             PIC X(80).
           05 PW-LINE-CNT          PIC 9(4).
           05 PW-LINE              OCCURS 200 PIC X(100).
           05 PW-RC                PIC X(2).

       PROCEDURE DIVISION.
       MAIN-PARA.
           ACCEPT WS-JSON-IN
           PERFORM PARSE-INPUT
           IF WS-OK = 'Y' PERFORM DB-CONNECT END-IF
           IF WS-OK = 'Y' PERFORM FETCH-ACCOUNT END-IF
           IF WS-OK = 'Y' PERFORM FETCH-TOTALS END-IF
           IF WS-OK = 'Y' PERFORM PRINT-REPORT END-IF
           IF WS-OK = 'Y' PERFORM EXPORT-FILES END-IF
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
           COMPUTE WS-ACC-ID = FUNCTION NUMVAL(JU-VALUE)
           MOVE 'limit' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               COMPUTE WS-LIMIT = FUNCTION NUMVAL(JU-VALUE)
           ELSE
               MOVE 50 TO WS-LIMIT
           END-IF
           IF WS-LIMIT = 0 OR WS-LIMIT > 200
               MOVE 200 TO WS-LIMIT
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

       FETCH-ACCOUNT.
           EXEC SQL
               SELECT a.iban, c.first_name, c.last_name,
                      CAST(a.balance AS VARCHAR),
                      a.account_type, a.status
                 INTO :WS-IBAN, :WS-FIRST, :WS-LAST,
                      :WS-A-BAL, :WS-A-TYPE, :WS-A-STATUS
                 FROM accounts a
                 JOIN customers c
                   ON c.customer_id = a.customer_id
                WHERE a.account_id = :WS-ACC-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   MOVE WS-ACC-ID TO WS-ID-ED
                   MOVE SPACES TO WS-ERR-CTX
                   STRING 'ACCOUNT ' FUNCTION TRIM(WS-ID-ED)
                       DELIMITED BY SIZE INTO WS-ERR-CTX
                   END-STRING
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
           END-EVALUATE.

       FETCH-TOTALS.
           EXEC SQL
               SELECT
                 CAST(COALESCE(SUM(CASE WHEN transaction_type IN
                   ('DEPOSIT','TRANSFER_IN','INTEREST',
                    'CARD_REFUND','LOAN_DISBURSE')
                   THEN amount ELSE 0 END),0) AS VARCHAR),
                 CAST(COALESCE(SUM(CASE WHEN transaction_type IN
                   ('WITHDRAWAL','TRANSFER_OUT','CARD_PURCHASE',
                    'FEE','LOAN_PAYMENT')
                   THEN amount ELSE 0 END),0) AS VARCHAR),
                 COUNT(*)
                 INTO :WS-INFLOW, :WS-OUTFLOW, :WS-MVCOUNT
                 FROM transactions
                WHERE account_id = :WS-ACC-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

      * single pass over the movements: emit JSON, buffer CSV rows
      * and append PDF body lines
       PRINT-REPORT.
           MOVE WS-ACC-ID TO WS-ID-ED
           DISPLAY '{"status":"OK","report":"ACCOUNT"'
                   ',"account":{"accountId":'
                   FUNCTION TRIM(WS-ID-ED)
                   ',"iban":"' FUNCTION TRIM(WS-IBAN)
                   '","holder":"' FUNCTION TRIM(WS-FIRST) ' '
                   FUNCTION TRIM(WS-LAST)
                   '","balance":' FUNCTION TRIM(WS-A-BAL)
                   ',"accountType":"' FUNCTION TRIM(WS-A-TYPE)
                   '","status":"' FUNCTION TRIM(WS-A-STATUS)
                   '"}'
           PERFORM PREPARE-PDF-HEADER
           DISPLAY ',"movements":['
           EXEC SQL
               DECLARE RTCUR CURSOR FOR
               SELECT transaction_id, transaction_type,
                      CAST(amount AS VARCHAR),
                      SUBSTR(CAST(timestamp AS VARCHAR), 1, 19),
                      COALESCE(description, '')
                 FROM transactions
                WHERE account_id = :WS-ACC-ID
                ORDER BY transaction_id DESC
                LIMIT :WS-LIMIT
           END-EXEC
           EXEC SQL OPEN RTCUR END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           MOVE 'Y' TO WS-FIRST-ROW
           MOVE 0 TO WS-MV-CNT
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH RTCUR
                    INTO :WS-T-ID, :WS-T-TYPE, :WS-T-AMT,
                         :WS-T-TS, :WS-T-DESC
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               PERFORM CLASSIFY-MOVEMENT
               PERFORM EMIT-MOVEMENT-JSON
               PERFORM BUFFER-MOVEMENT
           END-PERFORM
           EXEC SQL CLOSE RTCUR END-EXEC
           IF WS-OK = 'Y'
               DISPLAY ']'
               DISPLAY ',"totals":{"inflow":'
                       FUNCTION TRIM(WS-INFLOW)
                       ',"outflow":' FUNCTION TRIM(WS-OUTFLOW)
               MOVE WS-MVCOUNT TO WS-NZ
               DISPLAY ',"movementCount":' FUNCTION TRIM(WS-NZ)
                       '}'
               MOVE WS-ACC-ID TO WS-ID-ED
               DISPLAY ',"files":["statement_'
                       FUNCTION TRIM(WS-ID-ED) '.csv","statement_'
                       FUNCTION TRIM(WS-ID-ED) '.pdf"]}'
               PERFORM LOG-REPORT
           END-IF.

       CLASSIFY-MOVEMENT.
           EVALUATE FUNCTION TRIM(WS-T-TYPE)
               WHEN 'DEPOSIT'
               WHEN 'TRANSFER_IN'
               WHEN 'INTEREST'
               WHEN 'CARD_REFUND'
               WHEN 'LOAN_DISBURSE'
                   MOVE 'IN' TO WS-DIR
                   MOVE '+' TO WS-SIGN
               WHEN OTHER
                   MOVE 'OUT' TO WS-DIR
                   MOVE '-' TO WS-SIGN
           END-EVALUATE.

       EMIT-MOVEMENT-JSON.
           IF WS-FIRST-ROW = 'Y'
               MOVE 'N' TO WS-FIRST-ROW
           ELSE
               DISPLAY ','
           END-IF
           MOVE WS-T-ID TO WS-ID-ED
           DISPLAY '{"transactionId":' FUNCTION TRIM(WS-ID-ED)
                   ',"type":"' FUNCTION TRIM(WS-T-TYPE)
                   '","amount":' FUNCTION TRIM(WS-T-AMT)
                   ',"direction":"' FUNCTION TRIM(WS-DIR)
                   '","timestamp":"' WS-T-TS
                   '","description":"' FUNCTION TRIM(WS-T-DESC)
                   '"}'.

      * buffers a CSV row and (capped) a PDF body line
       BUFFER-MOVEMENT.
           ADD 1 TO WS-MV-CNT
           MOVE WS-T-ID TO WS-ID-ED
           MOVE SPACES TO WS-MV-CSV(WS-MV-CNT)
           STRING FUNCTION TRIM(WS-ID-ED) ','
                  WS-T-TS ','
                  FUNCTION TRIM(WS-T-TYPE) ','
                  FUNCTION TRIM(WS-T-AMT) ','
                  FUNCTION TRIM(WS-DIR) ',"'
                  FUNCTION TRIM(WS-T-DESC) '"'
               DELIMITED BY SIZE INTO WS-MV-CSV(WS-MV-CNT)
           END-STRING
           IF PW-LINE-CNT < 55
               ADD 1 TO PW-LINE-CNT
               MOVE SPACES TO PW-LINE(PW-LINE-CNT)
               STRING WS-T-TS ' '
                      WS-T-TYPE(1:14) ' '
                      WS-SIGN FUNCTION TRIM(WS-T-AMT) '  '
                      WS-T-DESC(1:28)
                   DELIMITED BY SIZE INTO PW-LINE(PW-LINE-CNT)
               END-STRING
           END-IF.

       PREPARE-PDF-HEADER.
           MOVE 'CURRENT-TS' TO DU-OPERATION
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-RESULT-TS TO WS-TS-NOW
           MOVE 0 TO PW-LINE-CNT
           ADD 1 TO PW-LINE-CNT
           MOVE SPACES TO PW-LINE(PW-LINE-CNT)
           STRING 'Account : ' FUNCTION TRIM(WS-IBAN)
               DELIMITED BY SIZE INTO PW-LINE(PW-LINE-CNT)
           END-STRING
           ADD 1 TO PW-LINE-CNT
           MOVE SPACES TO PW-LINE(PW-LINE-CNT)
           STRING 'Holder  : ' FUNCTION TRIM(WS-FIRST) ' '
                  FUNCTION TRIM(WS-LAST)
               DELIMITED BY SIZE INTO PW-LINE(PW-LINE-CNT)
           END-STRING
           ADD 1 TO PW-LINE-CNT
           MOVE SPACES TO PW-LINE(PW-LINE-CNT)
           STRING 'Balance : ' FUNCTION TRIM(WS-A-BAL)
                  ' ' FUNCTION TRIM(WS-A-TYPE)
                  ' (' FUNCTION TRIM(WS-A-STATUS) ')'
               DELIMITED BY SIZE INTO PW-LINE(PW-LINE-CNT)
           END-STRING
           ADD 1 TO PW-LINE-CNT
           MOVE SPACES TO PW-LINE(PW-LINE-CNT)
           STRING 'Printed : ' WS-TS-NOW
               DELIMITED BY SIZE INTO PW-LINE(PW-LINE-CNT)
           END-STRING
           ADD 1 TO PW-LINE-CNT
           MOVE 'DATE/TIME           TYPE           AMOUNT'
             TO PW-LINE(PW-LINE-CNT)
           ADD 1 TO PW-LINE-CNT
           MOVE '------------------------------------------'
             TO PW-LINE(PW-LINE-CNT).

       EXPORT-FILES.
           ACCEPT WS-REPORT-DIR FROM ENVIRONMENT 'ECBS_REPORT_DIR'
           IF WS-REPORT-DIR = SPACES
               MOVE '/opt/ecbs/reports' TO WS-REPORT-DIR
           END-IF
           MOVE WS-ACC-ID TO WS-ID-ED
           MOVE SPACES TO WS-IDFILE
           STRING 'statement_' FUNCTION TRIM(WS-ID-ED)
               DELIMITED BY SIZE INTO WS-IDFILE
           END-STRING
           MOVE SPACES TO WS-CSV-PATH
           STRING FUNCTION TRIM(WS-REPORT-DIR) '/'
                  FUNCTION TRIM(WS-IDFILE) '.csv'
               DELIMITED BY SIZE INTO WS-CSV-PATH
           END-STRING
           MOVE SPACES TO WS-PDF-PATH
           STRING FUNCTION TRIM(WS-REPORT-DIR) '/'
                  FUNCTION TRIM(WS-IDFILE) '.pdf'
               DELIMITED BY SIZE INTO WS-PDF-PATH
           END-STRING
           PERFORM WRITE-CSV
           PERFORM WRITE-PDF.

       WRITE-CSV.
           OPEN OUTPUT CSV-FILE
           MOVE SPACES TO CSV-REC
           STRING 'transaction_id,timestamp,type,amount,'
                  'direction,description'
               DELIMITED BY SIZE INTO CSV-REC
           END-STRING
           WRITE CSV-REC
           MOVE WS-MV-CNT TO WS-MV-MAX
           PERFORM VARYING WS-K FROM 1 BY 1
                   UNTIL WS-K > WS-MV-MAX
               MOVE WS-MV-CSV(WS-K) TO CSV-REC
               WRITE CSV-REC
           END-PERFORM
           CLOSE CSV-FILE.

       WRITE-PDF.
           MOVE WS-PDF-PATH TO PW-FILEPATH
           MOVE SPACES TO PW-TITLE
           MOVE WS-ACC-ID TO WS-ID-ED
           STRING 'ECBS - ACCOUNT STATEMENT ' FUNCTION TRIM(WS-IBAN)
               DELIMITED BY SIZE INTO PW-TITLE
           END-STRING
           CALL 'PDF-WRITER' USING PW-PARAMS.

       LOG-REPORT.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'RPT-ACCT' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-ACC-ID TO WS-ID-ED
           STRING 'account statement id='
                  FUNCTION TRIM(WS-ID-ED)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
           CALL 'LOGGER' USING LOG-PARAMS.

       FINISH-TRANSACTION.
           IF WS-CONNECTED = 'Y'
               EXEC SQL COMMIT WORK END-EXEC
               EXEC SQL DISCONNECT ALL END-EXEC
           END-IF.

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
