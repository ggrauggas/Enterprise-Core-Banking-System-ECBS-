      ******************************************************************
      * LOAN-INQUIRY.cbl - Fase 8: loan inquiry (seguimiento).
      *
      * Bridge input (one JSON line on stdin), modes:
      *   {"loanId":1}        -> single loan with the holder's name
      *   {}                  -> list all loans (max 100)
      *   {"customerId":3}    -> loans of one customer
      *   {"statusFilter":"REQUESTED"} -> filter by status
      *   (customerId and statusFilter can be combined)
      *
      * Read-only: inquiries are not audited, only logged.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-INQUIRY.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-LOAN-ID              PIC 9(10).
       01  WS-CUST-FILT            PIC 9(10).
       01  WS-FILTER               PIC X(10).
       01  WS-ST-ALL               PIC 9.
       01  WS-ROW-ID               PIC 9(10).
       01  WS-ROW-CUST             PIC 9(10).
       01  WS-ROW-FIRST            PIC X(50).
       01  WS-ROW-LAST             PIC X(80).
       01  WS-ROW-AMT              PIC X(20).
       01  WS-ROW-RATE             PIC X(20).
       01  WS-ROW-MONTHS           PIC 9(4).
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
       01  WS-MONTHS-ED            PIC ZZZ9.
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
                   PERFORM LIST-LOANS
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
           MOVE 'loanId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 'Y' TO WS-SINGLE
               COMPUTE WS-LOAN-ID = FUNCTION NUMVAL(JU-VALUE)
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
               SELECT l.loan_id, l.customer_id,
                      c.first_name, c.last_name,
                      CAST(l.amount AS VARCHAR),
                      CAST(l.interest_rate AS VARCHAR),
                      l.duration_months, l.status,
                      SUBSTR(CAST(l.created_at AS VARCHAR), 1, 19)
                 INTO :WS-ROW-ID, :WS-ROW-CUST, :WS-ROW-FIRST,
                      :WS-ROW-LAST, :WS-ROW-AMT, :WS-ROW-RATE,
                      :WS-ROW-MONTHS, :WS-ROW-STATUS,
                      :WS-ROW-CREATED
                 FROM loans l
                 JOIN customers c
                   ON c.customer_id = l.customer_id
                WHERE l.loan_id = :WS-LOAN-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   PERFORM SET-LOAN-CTX
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
               WHEN OTHER
                   PERFORM PRINT-ONE
           END-EVALUATE.

       PRINT-ONE.
           MOVE WS-ROW-ID TO WS-ID-ED
           MOVE WS-ROW-CUST TO WS-CID-ED
           MOVE WS-ROW-MONTHS TO WS-MONTHS-ED
           DISPLAY '{"status":"OK","loan":{'
                   '"loanId":' FUNCTION TRIM(WS-ID-ED)
                   ',"customerId":' FUNCTION TRIM(WS-CID-ED)
                   ',"customerName":"'
                   FUNCTION TRIM(WS-ROW-FIRST) ' '
                   FUNCTION TRIM(WS-ROW-LAST)
                   '","amount":' FUNCTION TRIM(WS-ROW-AMT)
                   ',"interestRate":' FUNCTION TRIM(WS-ROW-RATE)
                   ',"durationMonths":'
                   FUNCTION TRIM(WS-MONTHS-ED)
                   ',"loanStatus":"'
                   FUNCTION TRIM(WS-ROW-STATUS)
                   '","createdAt":"' WS-ROW-CREATED
                   '"}}'
           PERFORM LOG-INQUIRY.

       LIST-LOANS.
           EXEC SQL
               DECLARE LOANCUR CURSOR FOR
               SELECT loan_id, customer_id,
                      CAST(amount AS VARCHAR),
                      CAST(interest_rate AS VARCHAR),
                      duration_months, status
                 FROM loans
                WHERE (:WS-CUST-FILT = 0
                       OR customer_id = :WS-CUST-FILT)
                  AND (:WS-ST-ALL = 1
                       OR status = TRIM(TRAILING FROM :WS-FILTER))
                ORDER BY loan_id
                LIMIT 100
           END-EXEC
           EXEC SQL
               OPEN LOANCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY '{"status":"OK","loans":['
           MOVE 'Y' TO WS-FIRST-ROW
           MOVE 0 TO WS-COUNT
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH LOANCUR
                    INTO :WS-ROW-ID, :WS-ROW-CUST, :WS-ROW-AMT,
                         :WS-ROW-RATE, :WS-ROW-MONTHS,
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
               CLOSE LOANCUR
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
           MOVE WS-ROW-MONTHS TO WS-MONTHS-ED
           DISPLAY '{"loanId":' FUNCTION TRIM(WS-ID-ED)
                   ',"customerId":' FUNCTION TRIM(WS-CID-ED)
                   ',"amount":' FUNCTION TRIM(WS-ROW-AMT)
                   ',"interestRate":' FUNCTION TRIM(WS-ROW-RATE)
                   ',"durationMonths":'
                   FUNCTION TRIM(WS-MONTHS-ED)
                   ',"loanStatus":"'
                   FUNCTION TRIM(WS-ROW-STATUS)
                   '"}'.

       LOG-INQUIRY.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'LOAN-INQUIRY' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           IF WS-SINGLE = 'Y'
               MOVE WS-LOAN-ID TO WS-ID-ED
               STRING 'loan inquiry id='
                      FUNCTION TRIM(WS-ID-ED)
                   DELIMITED BY SIZE INTO LOG-MSG
               END-STRING
           ELSE
               MOVE WS-COUNT TO WS-COUNT-ED
               STRING 'loan list returned rows='
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

       SET-LOAN-CTX.
           MOVE WS-LOAN-ID TO WS-ID-ED
           MOVE SPACES TO WS-ERR-CTX
           STRING 'LOAN ' FUNCTION TRIM(WS-ID-ED)
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
