      ******************************************************************
      * RPT-CUSTOMER.cbl - Fase 11: full customer statement.
      *
      * Bridge input (one JSON line on stdin):
      *   {"customerId":1}
      *
      * Returns a complete picture of one customer as JSON: personal
      * data, every account (with balance), every card and every
      * loan, plus a summary block (account/card/loan counts, total
      * balance, active loan amount). Read-only: not audited.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPT-CUSTOMER.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-CUST-ID              PIC 9(10).
       01  WS-FIRST                PIC X(50).
       01  WS-LAST                 PIC X(80).
       01  WS-BDATE                PIC X(10).
       01  WS-EMAIL                PIC X(120).
       01  WS-PHONE                PIC X(20).
       01  WS-STATUS               PIC X(10).
       01  WS-A-ID                 PIC 9(10).
       01  WS-A-IBAN               PIC X(34).
       01  WS-A-BAL                PIC X(20).
       01  WS-A-TYPE               PIC X(10).
       01  WS-A-STATUS             PIC X(10).
       01  WS-C-ID                 PIC 9(10).
       01  WS-C-NUM                PIC X(16).
       01  WS-C-LIMIT              PIC X(20).
       01  WS-C-AVAIL              PIC X(20).
       01  WS-C-STATUS             PIC X(10).
       01  WS-L-ID                 PIC 9(10).
       01  WS-L-AMT                PIC X(20).
       01  WS-L-RATE               PIC X(20).
       01  WS-L-MONTHS             PIC 9(4).
       01  WS-L-STATUS             PIC X(10).
       01  WS-SUM-ACCTS            PIC 9(9).
       01  WS-SUM-BAL              PIC X(24).
       01  WS-SUM-CARDS            PIC 9(9).
       01  WS-SUM-LOANS            PIC 9(9).
       01  WS-SUM-LOANAMT          PIC X(24).
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
       01  WS-ERR-CODE             PIC X(5).
       01  WS-ERR-CTX              PIC X(80).
       01  WS-SQLCODE-ED           PIC -9(9).
       01  WS-ID-ED                PIC Z(9)9.
       01  WS-NZ                   PIC Z(8)9.
       01  WS-MONTHS-ED            PIC ZZZ9.

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
           IF WS-OK = 'Y' PERFORM FETCH-CUSTOMER END-IF
           IF WS-OK = 'Y' PERFORM PRINT-REPORT END-IF
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
           MOVE 'customerId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'customerId' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-CUST-ID = FUNCTION NUMVAL(JU-VALUE).

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

       FETCH-CUSTOMER.
           EXEC SQL
               SELECT first_name, last_name,
                      TO_CHAR(birth_date, 'YYYY-MM-DD'),
                      email, phone, status
                 INTO :WS-FIRST, :WS-LAST, :WS-BDATE,
                      :WS-EMAIL, :WS-PHONE, :WS-STATUS
                 FROM customers
                WHERE customer_id = :WS-CUST-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   MOVE WS-CUST-ID TO WS-ID-ED
                   MOVE SPACES TO WS-ERR-CTX
                   STRING 'CUSTOMER ' FUNCTION TRIM(WS-ID-ED)
                       DELIMITED BY SIZE INTO WS-ERR-CTX
                   END-STRING
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
           END-EVALUATE.

       PRINT-REPORT.
           PERFORM FETCH-SUMMARY
           IF WS-OK NOT = 'Y'
               EXIT PARAGRAPH
           END-IF
           MOVE WS-CUST-ID TO WS-ID-ED
           DISPLAY '{"status":"OK","report":"CUSTOMER"'
                   ',"customer":{"customerId":'
                   FUNCTION TRIM(WS-ID-ED)
                   ',"firstName":"' FUNCTION TRIM(WS-FIRST)
                   '","lastName":"' FUNCTION TRIM(WS-LAST)
                   '","birthDate":"' WS-BDATE
                   '","email":"' FUNCTION TRIM(WS-EMAIL)
                   '","phone":"' FUNCTION TRIM(WS-PHONE)
                   '","status":"' FUNCTION TRIM(WS-STATUS)
                   '"}'
           PERFORM PRINT-ACCOUNTS
           IF WS-OK = 'Y' PERFORM PRINT-CARDS END-IF
           IF WS-OK = 'Y' PERFORM PRINT-LOANS END-IF
           IF WS-OK = 'Y'
               PERFORM PRINT-SUMMARY
               DISPLAY '}'
               PERFORM LOG-REPORT
           END-IF.

      * gathered with simple separate statements (ocesql does not
      * parse scalar subqueries in the select list)
       FETCH-SUMMARY.
           EXEC SQL
               SELECT COUNT(*) INTO :WS-SUM-ACCTS
                 FROM accounts WHERE customer_id = :WS-CUST-ID
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT CAST(COALESCE(SUM(balance),0) AS VARCHAR)
                 INTO :WS-SUM-BAL
                 FROM accounts
                WHERE customer_id = :WS-CUST-ID
                  AND status = 'ACTIVE'
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT COUNT(*) INTO :WS-SUM-CARDS
                 FROM cards ca
                 JOIN accounts ac
                   ON ac.account_id = ca.account_id
                WHERE ac.customer_id = :WS-CUST-ID
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT COUNT(*) INTO :WS-SUM-LOANS
                 FROM loans WHERE customer_id = :WS-CUST-ID
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM SQL-ERROR-PARA
              EXIT PARAGRAPH END-IF
           EXEC SQL
               SELECT CAST(COALESCE(SUM(amount),0) AS VARCHAR)
                 INTO :WS-SUM-LOANAMT
                 FROM loans
                WHERE customer_id = :WS-CUST-ID
                  AND status = 'ACTIVE'
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       PRINT-ACCOUNTS.
           EXEC SQL
               DECLARE RACUR CURSOR FOR
               SELECT account_id, iban,
                      CAST(balance AS VARCHAR),
                      account_type, status
                 FROM accounts
                WHERE customer_id = :WS-CUST-ID
                ORDER BY account_id
           END-EXEC
           EXEC SQL OPEN RACUR END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY ',"accounts":['
           MOVE 'Y' TO WS-FIRST-ROW
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH RACUR
                    INTO :WS-A-ID, :WS-A-IBAN, :WS-A-BAL,
                         :WS-A-TYPE, :WS-A-STATUS
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               IF WS-FIRST-ROW = 'Y'
                   MOVE 'N' TO WS-FIRST-ROW
               ELSE
                   DISPLAY ','
               END-IF
               MOVE WS-A-ID TO WS-ID-ED
               DISPLAY '{"accountId":' FUNCTION TRIM(WS-ID-ED)
                       ',"iban":"' FUNCTION TRIM(WS-A-IBAN)
                       '","balance":' FUNCTION TRIM(WS-A-BAL)
                       ',"accountType":"' FUNCTION TRIM(WS-A-TYPE)
                       '","status":"' FUNCTION TRIM(WS-A-STATUS)
                       '"}'
           END-PERFORM
           EXEC SQL CLOSE RACUR END-EXEC
           DISPLAY ']'.

       PRINT-CARDS.
           EXEC SQL
               DECLARE RCCUR CURSOR FOR
               SELECT ca.card_id, ca.card_number,
                      CAST(ca.credit_limit AS VARCHAR),
                      CAST(ca.available_credit AS VARCHAR),
                      ca.status
                 FROM cards ca
                 JOIN accounts ac
                   ON ac.account_id = ca.account_id
                WHERE ac.customer_id = :WS-CUST-ID
                ORDER BY ca.card_id
           END-EXEC
           EXEC SQL OPEN RCCUR END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY ',"cards":['
           MOVE 'Y' TO WS-FIRST-ROW
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH RCCUR
                    INTO :WS-C-ID, :WS-C-NUM, :WS-C-LIMIT,
                         :WS-C-AVAIL, :WS-C-STATUS
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               IF WS-FIRST-ROW = 'Y'
                   MOVE 'N' TO WS-FIRST-ROW
               ELSE
                   DISPLAY ','
               END-IF
               MOVE WS-C-ID TO WS-ID-ED
               DISPLAY '{"cardId":' FUNCTION TRIM(WS-ID-ED)
                       ',"cardNumber":"' FUNCTION TRIM(WS-C-NUM)
                       '","creditLimit":' FUNCTION TRIM(WS-C-LIMIT)
                       ',"availableCredit":'
                       FUNCTION TRIM(WS-C-AVAIL)
                       ',"status":"' FUNCTION TRIM(WS-C-STATUS)
                       '"}'
           END-PERFORM
           EXEC SQL CLOSE RCCUR END-EXEC
           DISPLAY ']'.

       PRINT-LOANS.
           EXEC SQL
               DECLARE RLCUR CURSOR FOR
               SELECT loan_id, CAST(amount AS VARCHAR),
                      CAST(interest_rate AS VARCHAR),
                      duration_months, status
                 FROM loans
                WHERE customer_id = :WS-CUST-ID
                ORDER BY loan_id
           END-EXEC
           EXEC SQL OPEN RLCUR END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY ',"loans":['
           MOVE 'Y' TO WS-FIRST-ROW
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH RLCUR
                    INTO :WS-L-ID, :WS-L-AMT, :WS-L-RATE,
                         :WS-L-MONTHS, :WS-L-STATUS
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               IF WS-FIRST-ROW = 'Y'
                   MOVE 'N' TO WS-FIRST-ROW
               ELSE
                   DISPLAY ','
               END-IF
               MOVE WS-L-ID TO WS-ID-ED
               MOVE WS-L-MONTHS TO WS-MONTHS-ED
               DISPLAY '{"loanId":' FUNCTION TRIM(WS-ID-ED)
                       ',"amount":' FUNCTION TRIM(WS-L-AMT)
                       ',"interestRate":' FUNCTION TRIM(WS-L-RATE)
                       ',"durationMonths":'
                       FUNCTION TRIM(WS-MONTHS-ED)
                       ',"loanStatus":"' FUNCTION TRIM(WS-L-STATUS)
                       '"}'
           END-PERFORM
           EXEC SQL CLOSE RLCUR END-EXEC
           DISPLAY ']'.

       PRINT-SUMMARY.
           MOVE WS-SUM-ACCTS TO WS-NZ
           DISPLAY ',"summary":{"accountCount":'
                   FUNCTION TRIM(WS-NZ)
           DISPLAY ',"totalBalance":' FUNCTION TRIM(WS-SUM-BAL)
           MOVE WS-SUM-CARDS TO WS-NZ
           DISPLAY ',"cardCount":' FUNCTION TRIM(WS-NZ)
           MOVE WS-SUM-LOANS TO WS-NZ
           DISPLAY ',"loanCount":' FUNCTION TRIM(WS-NZ)
           DISPLAY ',"activeLoanAmount":'
                   FUNCTION TRIM(WS-SUM-LOANAMT) '}'.

       LOG-REPORT.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'RPT-CUST' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-CUST-ID TO WS-ID-ED
           STRING 'customer report id='
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
