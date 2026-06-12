      ******************************************************************
      * LOAN-SIMULATE.cbl - Fase 8: French method loan simulator
      * with full amortization schedule (calendario de pagos).
      *
      * Bridge input (one JSON line on stdin), two modes:
      *   {"amount":12000,"interestRate":5.5,"durationMonths":60}
      *       -> free simulation, no database access
      *   {"loanId":1}
      *       -> simulate a stored loan (reads its terms from DB)
      *
      * The constant payment comes from MONEY_UTILS FRENCH-PMT
      * (A = P*i*f/(f-1), f=(1+i)^n). Each schedule row splits the
      * payment into interest (pending * rate/1200, rounded) and
      * principal; the last row settles the remaining balance so
      * the loan closes at exactly 0.00. Read-only: not audited.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-SIMULATE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-LOAN-ID              PIC 9(10).
       01  WS-AMT-TXT              PIC X(20).
       01  WS-RATE-TXT             PIC X(20).
       01  WS-MONTHS-DB            PIC 9(4).
       01  WS-DB-CONN              PIC X(64).
       01  WS-DB-USER              PIC X(32).
       01  WS-DB-PASS              PIC X(32).

      * simulation working fields (packed decimal money)
       01  WS-AMOUNT               PIC S9(13)V99 COMP-3.
       01  WS-RATE                 PIC S9(3)V9(4) COMP-3.
       01  WS-MONTHS               PIC 9(4).
       01  WS-PMT                  PIC S9(13)V99 COMP-3.
       01  WS-PENDING              PIC S9(13)V99 COMP-3.
       01  WS-INT-M                PIC S9(13)V99 COMP-3.
       01  WS-PRIN-M               PIC S9(13)V99 COMP-3.
       01  WS-PAY-M                PIC S9(13)V99 COMP-3.
       01  WS-TOT-PAID             PIC S9(13)V99 COMP-3.
       01  WS-TOT-INT              PIC S9(13)V99 COMP-3.
       01  WS-M                    PIC 9(4).
       01  WS-TODAY                PIC X(10).
       01  WS-RATE-ED              PIC ZZ9.99.
       01  WS-MONTHS-ED            PIC ZZZ9.
       01  WS-M-ED                 PIC ZZZ9.
       01  WS-ID-ED                PIC Z(9)9.

      * environment and control fields
       01  WS-ENV-HOST             PIC X(32) VALUE SPACES.
       01  WS-ENV-PORT             PIC X(6)  VALUE SPACES.
       01  WS-ENV-DB               PIC X(32) VALUE SPACES.
       01  WS-JSON-IN              PIC X(2000).
       01  WS-OK                   PIC X VALUE 'Y'.
       01  WS-CONNECTED            PIC X VALUE 'N'.
       01  WS-DB-MODE              PIC X VALUE 'N'.
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
       01  MU-PARAMS.
           05 MU-OPERATION         PIC X(12).
           05 MU-AMOUNT-1          PIC S9(13)V99 COMP-3.
           05 MU-AMOUNT-2          PIC S9(13)V99 COMP-3.
           05 MU-RATE              PIC S9(3)V9(4) COMP-3.
           05 MU-MONTHS            PIC 9(4).
           05 MU-RESULT            PIC S9(13)V99 COMP-3.
           05 MU-FORMATTED         PIC X(20).
           05 MU-STATUS            PIC X(2).
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

       PROCEDURE DIVISION.
       MAIN-PARA.
           ACCEPT WS-JSON-IN
           PERFORM PARSE-INPUT
           IF WS-OK = 'Y' AND WS-DB-MODE = 'Y'
               PERFORM DB-CONNECT
               IF WS-OK = 'Y' PERFORM FETCH-LOAN END-IF
           END-IF
           IF WS-OK = 'Y' PERFORM VALIDATE-TERMS END-IF
           IF WS-OK = 'Y' PERFORM COMPUTE-PAYMENT END-IF
           IF WS-OK = 'Y' PERFORM PRINT-SIMULATION END-IF
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
               MOVE 'Y' TO WS-DB-MODE
               COMPUTE WS-LOAN-ID = FUNCTION NUMVAL(JU-VALUE)
               EXIT PARAGRAPH
           END-IF
           MOVE 'amount' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'amount (or loanId)' TO WS-ERR-CTX
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
           COMPUTE WS-MONTHS = FUNCTION NUMVAL(JU-VALUE).

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

       FETCH-LOAN.
           EXEC SQL
               SELECT CAST(amount AS VARCHAR),
                      CAST(interest_rate AS VARCHAR),
                      duration_months
                 INTO :WS-AMT-TXT, :WS-RATE-TXT, :WS-MONTHS-DB
                 FROM loans
                WHERE loan_id = :WS-LOAN-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   PERFORM SET-LOAN-CTX
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
               WHEN OTHER
                   COMPUTE WS-AMOUNT =
                       FUNCTION NUMVAL(WS-AMT-TXT)
                   COMPUTE WS-RATE =
                       FUNCTION NUMVAL(WS-RATE-TXT)
                   MOVE WS-MONTHS-DB TO WS-MONTHS
           END-EVALUATE.

       VALIDATE-TERMS.
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
           END-EVALUATE.

       COMPUTE-PAYMENT.
           IF WS-RATE = 0
      *        zero-interest edge case: plain division, the French
      *        formula would divide by f-1 = 0
               COMPUTE WS-PMT ROUNDED = WS-AMOUNT / WS-MONTHS
           ELSE
               MOVE 'FRENCH-PMT' TO MU-OPERATION
               MOVE WS-AMOUNT TO MU-AMOUNT-1
               MOVE WS-RATE TO MU-RATE
               MOVE WS-MONTHS TO MU-MONTHS
               CALL 'MONEY_UTILS' USING MU-PARAMS
               IF MU-STATUS NOT = '00'
                   MOVE 'E010' TO WS-ERR-CODE
                   MOVE 'PAYMENT CALCULATION FAILED' TO WS-ERR-CTX
                   MOVE 'N' TO WS-OK
                   EXIT PARAGRAPH
               END-IF
               MOVE MU-RESULT TO WS-PMT
           END-IF.

       FORMAT-MONEY.
           MOVE 'FORMAT' TO MU-OPERATION
           CALL 'MONEY_UTILS' USING MU-PARAMS.

       PRINT-SIMULATION.
           MOVE 'CURRENT-TS' TO DU-OPERATION
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-RESULT-TS(1:10) TO WS-TODAY
           MOVE WS-RATE TO WS-RATE-ED
           MOVE WS-MONTHS TO WS-MONTHS-ED
           MOVE WS-AMOUNT TO MU-AMOUNT-1
           PERFORM FORMAT-MONEY
           DISPLAY '{"status":"OK"'
           IF WS-DB-MODE = 'Y'
               MOVE WS-LOAN-ID TO WS-ID-ED
               DISPLAY ',"loanId":' FUNCTION TRIM(WS-ID-ED)
           END-IF
           DISPLAY ',"amount":' FUNCTION TRIM(MU-FORMATTED)
                   ',"interestRate":' FUNCTION TRIM(WS-RATE-ED)
                   ',"durationMonths":'
                   FUNCTION TRIM(WS-MONTHS-ED)
           MOVE WS-PMT TO MU-AMOUNT-1
           PERFORM FORMAT-MONEY
           DISPLAY ',"monthlyPayment":'
                   FUNCTION TRIM(MU-FORMATTED)
                   ',"schedule":['
           MOVE WS-AMOUNT TO WS-PENDING
           MOVE 0 TO WS-TOT-PAID WS-TOT-INT
           MOVE 'Y' TO WS-FIRST-ROW
           PERFORM VARYING WS-M FROM 1 BY 1
                   UNTIL WS-M > WS-MONTHS
               COMPUTE WS-INT-M ROUNDED =
                   WS-PENDING * WS-RATE / 1200
               IF WS-M = WS-MONTHS
                   MOVE WS-PENDING TO WS-PRIN-M
                   COMPUTE WS-PAY-M = WS-PRIN-M + WS-INT-M
               ELSE
                   COMPUTE WS-PRIN-M = WS-PMT - WS-INT-M
                   MOVE WS-PMT TO WS-PAY-M
               END-IF
               SUBTRACT WS-PRIN-M FROM WS-PENDING
               ADD WS-PAY-M TO WS-TOT-PAID
               ADD WS-INT-M TO WS-TOT-INT
               PERFORM PRINT-ROW
           END-PERFORM
           MOVE WS-TOT-PAID TO MU-AMOUNT-1
           PERFORM FORMAT-MONEY
           DISPLAY '],"totalPaid":' FUNCTION TRIM(MU-FORMATTED)
           MOVE WS-TOT-INT TO MU-AMOUNT-1
           PERFORM FORMAT-MONEY
           DISPLAY ',"totalInterest":'
                   FUNCTION TRIM(MU-FORMATTED) '}'
           PERFORM LOG-SIMULATION.

       PRINT-ROW.
           IF WS-FIRST-ROW = 'Y'
               MOVE 'N' TO WS-FIRST-ROW
           ELSE
               DISPLAY ','
           END-IF
           MOVE 'ADD-MONTHS' TO DU-OPERATION
           MOVE WS-TODAY TO DU-DATE-1
           MOVE WS-M TO DU-NUMBER
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE WS-M TO WS-M-ED
           DISPLAY '{"month":' FUNCTION TRIM(WS-M-ED)
                   ',"dueDate":"' DU-RESULT-DATE '"'
           MOVE WS-PAY-M TO MU-AMOUNT-1
           PERFORM FORMAT-MONEY
           DISPLAY ',"payment":' FUNCTION TRIM(MU-FORMATTED)
           MOVE WS-INT-M TO MU-AMOUNT-1
           PERFORM FORMAT-MONEY
           DISPLAY ',"interest":' FUNCTION TRIM(MU-FORMATTED)
           MOVE WS-PRIN-M TO MU-AMOUNT-1
           PERFORM FORMAT-MONEY
           DISPLAY ',"principal":' FUNCTION TRIM(MU-FORMATTED)
           MOVE WS-PENDING TO MU-AMOUNT-1
           PERFORM FORMAT-MONEY
           DISPLAY ',"remaining":' FUNCTION TRIM(MU-FORMATTED)
                   '}'.

       LOG-SIMULATION.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'LOAN-SIM' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-MONTHS TO WS-MONTHS-ED
           STRING 'simulation months='
                  FUNCTION TRIM(WS-MONTHS-ED)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
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
