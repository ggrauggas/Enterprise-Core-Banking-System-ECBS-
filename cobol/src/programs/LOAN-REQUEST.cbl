      ******************************************************************
      * LOAN-REQUEST.cbl - Fase 8: loan application (solicitud).
      *
      * Bridge input (one JSON line on stdin):
      *   {"customerId":1,"amount":15000,"interestRate":4.75,
      *    "durationMonths":48,"user":"advisor1"}
      *
      * Rules: the customer must exist and be ACTIVE, amount > 0,
      * rate >= 0, months 1-600. The loan is created in REQUESTED
      * state; approval/rejection are separate operations. The
      * response includes the French-method monthly payment so the
      * applicant knows the quota upfront. Audited.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-REQUEST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-CUST-ID              PIC 9(10).
       01  WS-LOAN-ID              PIC 9(10).
       01  WS-AMOUNT               PIC S9(13)V99 COMP-3.
       01  WS-RATE                 PIC S9(3)V9(4) COMP-3.
       01  WS-MONTHS               PIC 9(4).
       01  WS-CUST-STATUS          PIC X(10).
       01  WS-AMT-TXT              PIC X(20).
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
       01  WS-RATE-ED              PIC ZZ9.99.
       01  WS-MONTHS-ED            PIC ZZZ9.
       01  WS-PMT-TXT              PIC X(20).

      * framework module parameter blocks
       01  JU-PARAMS.
           05 JU-BUFFER            PIC X(2000).
           05 JU-KEY               PIC X(32).
           05 JU-VALUE             PIC X(256).
           05 JU-FOUND             PIC X.
           05 JU-RC                PIC X(2).
       01  MU-PARAMS.
           05 MU-OPERATION         PIC X(12).
           05 MU-AMOUNT-1          PIC S9(13)V99 COMP-3.
           05 MU-AMOUNT-2          PIC S9(13)V99 COMP-3.
           05 MU-RATE              PIC S9(3)V9(4) COMP-3.
           05 MU-MONTHS            PIC 9(4).
           05 MU-RESULT            PIC S9(13)V99 COMP-3.
           05 MU-FORMATTED         PIC X(20).
           05 MU-STATUS            PIC X(2).
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
           IF WS-OK = 'Y' PERFORM INSERT-LOAN END-IF
           IF WS-OK = 'Y' PERFORM COMPUTE-PAYMENT END-IF
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
           MOVE 'amount' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'amount' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-AMOUNT = FUNCTION NUMVAL(JU-VALUE)
           MOVE 'interestRate' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'interestRate' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-RATE = FUNCTION NUMVAL(JU-VALUE)
           MOVE 'durationMonths' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'durationMonths' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-MONTHS = FUNCTION NUMVAL(JU-VALUE)
           EVALUATE TRUE
               WHEN WS-AMOUNT <= 0
                   MOVE 'E018' TO WS-ERR-CODE
                   MOVE 'AMOUNT MUST BE POSITIVE' TO WS-ERR-CTX
                   MOVE 'N' TO WS-OK
               WHEN WS-RATE < 0
                   MOVE 'E018' TO WS-ERR-CODE
                   MOVE 'RATE MUST NOT BE NEGATIVE' TO WS-ERR-CTX
                   MOVE 'N' TO WS-OK
               WHEN WS-MONTHS = 0 OR WS-MONTHS > 600
                   MOVE 'E018' TO WS-ERR-CODE
                   MOVE 'MONTHS MUST BE 1-600' TO WS-ERR-CTX
                   MOVE 'N' TO WS-OK
           END-EVALUATE
           IF WS-OK NOT = 'Y'
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

       INSERT-LOAN.
           EXEC SQL
               INSERT INTO loans
                      (customer_id, amount, interest_rate,
                       duration_months, status)
               VALUES (:WS-CUST-ID, :WS-AMOUNT, :WS-RATE,
                       :WS-MONTHS, 'REQUESTED')
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               SELECT currval('loans_loan_id_seq'),
                      CAST(:WS-AMOUNT AS VARCHAR)
                 INTO :WS-LOAN-ID, :WS-AMT-TXT
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       COMPUTE-PAYMENT.
           IF WS-RATE = 0
               COMPUTE MU-RESULT ROUNDED = WS-AMOUNT / WS-MONTHS
           ELSE
               MOVE 'FRENCH-PMT' TO MU-OPERATION
               MOVE WS-AMOUNT TO MU-AMOUNT-1
               MOVE WS-RATE TO MU-RATE
               MOVE WS-MONTHS TO MU-MONTHS
               CALL 'MONEY_UTILS' USING MU-PARAMS
           END-IF
           MOVE 'FORMAT' TO MU-OPERATION
           MOVE MU-RESULT TO MU-AMOUNT-1
           CALL 'MONEY_UTILS' USING MU-PARAMS
           MOVE MU-FORMATTED TO WS-PMT-TXT.

       WRITE-AUDIT.
           MOVE WS-CUST-ID TO WS-CID-ED
           MOVE WS-RATE TO WS-RATE-ED
           MOVE WS-MONTHS TO WS-MONTHS-ED
           MOVE SPACES TO WS-AUD-NEW
           STRING '{"customerId":' FUNCTION TRIM(WS-CID-ED)
                  ',"amount":' FUNCTION TRIM(WS-AMT-TXT)
                  ',"interestRate":' FUNCTION TRIM(WS-RATE-ED)
                  ',"durationMonths":'
                  FUNCTION TRIM(WS-MONTHS-ED)
                  ',"monthlyPayment":' FUNCTION TRIM(WS-PMT-TXT)
                  ',"status":"REQUESTED"}'
               DELIMITED BY SIZE INTO WS-AUD-NEW
           END-STRING
           EXEC SQL
               INSERT INTO audit_logs
                      (username, operation, entity_type,
                       entity_id, old_value, new_value)
               VALUES (TRIM(TRAILING FROM :WS-AUD-USER),
                       'REQUEST', 'LOAN', :WS-LOAN-ID, NULL,
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
           MOVE 'LOAN-REQUEST' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-LOAN-ID TO WS-ID-ED
           STRING 'loan requested id=' FUNCTION TRIM(WS-ID-ED)
                  ' amount=' FUNCTION TRIM(WS-AMT-TXT)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
           CALL 'LOGGER' USING LOG-PARAMS
           MOVE WS-RATE TO WS-RATE-ED
           MOVE WS-MONTHS TO WS-MONTHS-ED
           DISPLAY '{"status":"OK","loanId":'
                   FUNCTION TRIM(WS-ID-ED)
                   ',"loanStatus":"REQUESTED"'
                   ',"amount":' FUNCTION TRIM(WS-AMT-TXT)
                   ',"interestRate":' FUNCTION TRIM(WS-RATE-ED)
                   ',"durationMonths":'
                   FUNCTION TRIM(WS-MONTHS-ED)
                   ',"monthlyPayment":'
                   FUNCTION TRIM(WS-PMT-TXT) '}'.

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
