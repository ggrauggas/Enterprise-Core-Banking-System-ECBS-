      ******************************************************************
      * RPT-BANK.cbl - Fase 11: bank-wide totals report.
      *
      * Bridge input: {} (no parameters)
      *
      * Aggregates the headline figures of the bank (customers,
      * accounts, total deposits, loans, cards) and returns them as
      * JSON. It also exports the report to two files in
      * ECBS_REPORT_DIR: bank_report.csv and bank_report.pdf (the
      * PDF is produced by the reusable PDF-WRITER module).
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPT-BANK.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CSV-FILE ASSIGN TO WS-CSV-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-CSV-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  CSV-FILE.
       01  CSV-REC                 PIC X(200).

       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-N-CUST               PIC 9(9).
       01  WS-N-ACTIVE             PIC 9(9).
       01  WS-N-ACCT               PIC 9(9).
       01  WS-DEPOSITS             PIC X(24).
       01  WS-N-LOANS              PIC 9(9).
       01  WS-LOAN-AMT             PIC X(24).
       01  WS-N-CARDS              PIC 9(9).
       01  WS-DB-CONN              PIC X(64).
       01  WS-DB-USER              PIC X(32).
       01  WS-DB-PASS              PIC X(32).

      * export handling
       01  WS-REPORT-DIR           PIC X(80) VALUE SPACES.
       01  WS-CSV-PATH             PIC X(120).
       01  WS-PDF-PATH             PIC X(120).
       01  WS-CSV-FS               PIC X(2).
       01  WS-TS                   PIC X(19).
       01  WS-NZ                   PIC Z(8)9.
       01  WS-METRIC               PIC X(20).
       01  WS-LABEL                PIC X(22).
       01  WS-VAL                  PIC X(24).

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

      * framework module parameter blocks
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
           PERFORM DB-CONNECT
           IF WS-OK = 'Y' PERFORM FETCH-TOTALS END-IF
           IF WS-OK = 'Y' PERFORM PRINT-JSON END-IF
           IF WS-OK = 'Y' PERFORM EXPORT-FILES END-IF
           PERFORM FINISH-TRANSACTION
           IF WS-OK NOT = 'Y'
               PERFORM PRINT-ERROR
           END-IF
           STOP RUN.

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

      * ocesql does not parse scalar subqueries in the select list,
      * so the totals are gathered with simple separate statements
       FETCH-TOTALS.
           EXEC SQL
               SELECT COUNT(*) INTO :WS-N-CUST FROM customers
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT COUNT(*) INTO :WS-N-ACTIVE
                 FROM customers WHERE status = 'ACTIVE'
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT COUNT(*) INTO :WS-N-ACCT
                 FROM accounts WHERE status = 'ACTIVE'
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT CAST(COALESCE(SUM(balance),0) AS VARCHAR)
                 INTO :WS-DEPOSITS
                 FROM accounts WHERE status = 'ACTIVE'
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT COUNT(*) INTO :WS-N-LOANS
                 FROM loans WHERE status = 'ACTIVE'
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT CAST(COALESCE(SUM(amount),0) AS VARCHAR)
                 INTO :WS-LOAN-AMT
                 FROM loans WHERE status = 'ACTIVE'
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT COUNT(*) INTO :WS-N-CARDS
                 FROM cards WHERE status = 'ACTIVE'
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       PRINT-JSON.
           DISPLAY '{"status":"OK","report":"BANK"'
           MOVE WS-N-CUST TO WS-NZ
           DISPLAY ',"totalCustomers":' FUNCTION TRIM(WS-NZ)
           MOVE WS-N-ACTIVE TO WS-NZ
           DISPLAY ',"activeCustomers":' FUNCTION TRIM(WS-NZ)
           MOVE WS-N-ACCT TO WS-NZ
           DISPLAY ',"totalAccounts":' FUNCTION TRIM(WS-NZ)
           DISPLAY ',"totalDeposits":' FUNCTION TRIM(WS-DEPOSITS)
           MOVE WS-N-LOANS TO WS-NZ
           DISPLAY ',"activeLoans":' FUNCTION TRIM(WS-NZ)
           DISPLAY ',"totalLoanAmount":'
                   FUNCTION TRIM(WS-LOAN-AMT)
           MOVE WS-N-CARDS TO WS-NZ
           DISPLAY ',"activeCards":' FUNCTION TRIM(WS-NZ)
                   ',"files":["bank_report.csv","bank_report.pdf"]}'
           PERFORM LOG-REPORT.

       LOG-REPORT.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'RPT-BANK' TO LOG-COMPONENT
           MOVE 'bank report generated' TO LOG-MSG
           CALL 'LOGGER' USING LOG-PARAMS.

       EXPORT-FILES.
           ACCEPT WS-REPORT-DIR FROM ENVIRONMENT 'ECBS_REPORT_DIR'
           IF WS-REPORT-DIR = SPACES
               MOVE '/opt/ecbs/reports' TO WS-REPORT-DIR
           END-IF
           MOVE SPACES TO WS-CSV-PATH
           STRING FUNCTION TRIM(WS-REPORT-DIR) '/bank_report.csv'
               DELIMITED BY SIZE INTO WS-CSV-PATH
           END-STRING
           MOVE SPACES TO WS-PDF-PATH
           STRING FUNCTION TRIM(WS-REPORT-DIR) '/bank_report.pdf'
               DELIMITED BY SIZE INTO WS-PDF-PATH
           END-STRING
           MOVE 'CURRENT-TS' TO DU-OPERATION
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-RESULT-TS TO WS-TS
      *    one pass building both the CSV file and the PDF lines
           MOVE WS-PDF-PATH TO PW-FILEPATH
           MOVE 'ECBS - BANK TOTALS REPORT' TO PW-TITLE
           MOVE 0 TO PW-LINE-CNT
           ADD 1 TO PW-LINE-CNT
           MOVE SPACES TO PW-LINE(PW-LINE-CNT)
           STRING 'Generated: ' WS-TS
               DELIMITED BY SIZE INTO PW-LINE(PW-LINE-CNT)
           END-STRING
           ADD 1 TO PW-LINE-CNT
           MOVE '------------------------------------'
             TO PW-LINE(PW-LINE-CNT)
           OPEN OUTPUT CSV-FILE
           MOVE 'metric,value' TO CSV-REC
           WRITE CSV-REC
           MOVE 'total_customers' TO WS-METRIC
           MOVE 'Total customers     :' TO WS-LABEL
           MOVE WS-N-CUST TO WS-NZ
           MOVE FUNCTION TRIM(WS-NZ) TO WS-VAL
           PERFORM EMIT-ROW
           MOVE 'active_customers' TO WS-METRIC
           MOVE 'Active customers    :' TO WS-LABEL
           MOVE WS-N-ACTIVE TO WS-NZ
           MOVE FUNCTION TRIM(WS-NZ) TO WS-VAL
           PERFORM EMIT-ROW
           MOVE 'total_accounts' TO WS-METRIC
           MOVE 'Total accounts      :' TO WS-LABEL
           MOVE WS-N-ACCT TO WS-NZ
           MOVE FUNCTION TRIM(WS-NZ) TO WS-VAL
           PERFORM EMIT-ROW
           MOVE 'total_deposits' TO WS-METRIC
           MOVE 'Total deposits      :' TO WS-LABEL
           MOVE FUNCTION TRIM(WS-DEPOSITS) TO WS-VAL
           PERFORM EMIT-ROW
           MOVE 'active_loans' TO WS-METRIC
           MOVE 'Active loans        :' TO WS-LABEL
           MOVE WS-N-LOANS TO WS-NZ
           MOVE FUNCTION TRIM(WS-NZ) TO WS-VAL
           PERFORM EMIT-ROW
           MOVE 'total_loan_amount' TO WS-METRIC
           MOVE 'Total loan amount   :' TO WS-LABEL
           MOVE FUNCTION TRIM(WS-LOAN-AMT) TO WS-VAL
           PERFORM EMIT-ROW
           MOVE 'active_cards' TO WS-METRIC
           MOVE 'Active cards        :' TO WS-LABEL
           MOVE WS-N-CARDS TO WS-NZ
           MOVE FUNCTION TRIM(WS-NZ) TO WS-VAL
           PERFORM EMIT-ROW
           CLOSE CSV-FILE
           CALL 'PDF-WRITER' USING PW-PARAMS.

      * writes one CSV data row and appends the matching PDF line
       EMIT-ROW.
           MOVE SPACES TO CSV-REC
           STRING FUNCTION TRIM(WS-METRIC) ','
                  FUNCTION TRIM(WS-VAL)
               DELIMITED BY SIZE INTO CSV-REC
           END-STRING
           WRITE CSV-REC
           ADD 1 TO PW-LINE-CNT
           MOVE SPACES TO PW-LINE(PW-LINE-CNT)
           STRING WS-LABEL ' ' FUNCTION TRIM(WS-VAL)
               DELIMITED BY SIZE INTO PW-LINE(PW-LINE-CNT)
           END-STRING.

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
