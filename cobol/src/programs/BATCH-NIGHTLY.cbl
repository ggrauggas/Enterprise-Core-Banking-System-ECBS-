      ******************************************************************
      * BATCH-NIGHTLY.cbl - Fase 9: nightly batch (modulo critico).
      *
      * Bridge input: {} (optionally {"user":"scheduler"})
      *
      * Four sequential job steps over the whole portfolio:
      *   1 INTEREST  monthly interest on ACTIVE SAVINGS accounts
      *               (annual rate WS-SAVINGS-RATE, MONEY_UTILS)
      *   2 FEES      maintenance fee on ACTIVE CHECKING accounts
      *               (skipped, never overdrawn: balance >= fee)
      *   3 LOANS     French monthly payment of each ACTIVE loan,
      *               charged to the holder's richest ACTIVE
      *               account (skip + error count if no funds)
      *   4 CARDS     settlement of ACTIVE cards: spent credit is
      *               charged to the linked account and the
      *               available credit is restored to the limit
      *
      * Bookkeeping: a batch_runs row brackets the run (RUNNING ->
      * SUCCESS/FAILED with counters); every movement leaves its
      * transactions row; one audit_logs entry per step. Output
      * files (line sequential, in ECBS_BATCH_DIR):
      *   BATCH_LOG.log     append-only detail of every action
      *   RUN_SUMMARY.rpt   per-step counters of the last run
      *   AUDIT_REPORT.rpt  audit entries of the last run
      *
      * The four steps run inside ONE database transaction: any SQL
      * failure rolls back every movement and the run is closed as
      * FAILED in a separate transaction.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-NIGHTLY.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL BATCH-LOG-FILE
               ASSIGN TO WS-LOG-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-LOG-FS.
           SELECT SUMMARY-FILE
               ASSIGN TO WS-SUM-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-SUM-FS.
           SELECT AUDIT-RPT-FILE
               ASSIGN TO WS-RPT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-RPT-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  BATCH-LOG-FILE.
       01  LOG-LINE-REC            PIC X(200).
       FD  SUMMARY-FILE.
       01  SUM-LINE-REC            PIC X(120).
       FD  AUDIT-RPT-FILE.
       01  RPT-LINE-REC            PIC X(250).

       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-RUN-ID               PIC 9(10).
       01  WS-ACCT-ID              PIC 9(10).
       01  WS-BAL-TXT              PIC X(20).
       01  WS-AMOUNT               PIC S9(13)V99 COMP-3.
       01  WS-AMT-TXT              PIC X(20).
       01  WS-FEE                  PIC S9(13)V99 COMP-3 VALUE 5.00.
       01  WS-FLAG                 PIC 9.
       01  WS-DESC                 PIC X(200).
       01  WS-LOAN-ID              PIC 9(10).
       01  WS-LOAN-CUST            PIC 9(10).
       01  WS-LOAN-AMT-TXT         PIC X(20).
       01  WS-LOAN-RATE-TXT        PIC X(20).
       01  WS-LOAN-MONTHS          PIC 9(4).
       01  WS-PAY-ACCT             PIC 9(10).
       01  WS-CARD-ID              PIC 9(10).
       01  WS-CARD-ACCT            PIC 9(10).
       01  WS-SPENT-TXT            PIC X(20).
       01  WS-TOT-PROC             PIC 9(6).
       01  WS-TOT-ERR              PIC 9(6).
       01  WS-SUMMARY              PIC X(200).
       01  WS-RUN-STATUS           PIC X(10).
       01  WS-AUD-NEW              PIC X(500).
       01  WS-AUD-USER             PIC X(50).
       01  WS-STEP-NAME            PIC X(30).
       01  WS-RPT-USER             PIC X(50).
       01  WS-RPT-OP               PIC X(30).
       01  WS-RPT-VAL              PIC X(150).
       01  WS-RPT-TS               PIC X(19).
       01  WS-DB-CONN              PIC X(64).
       01  WS-DB-USER              PIC X(32).
       01  WS-DB-PASS              PIC X(32).

      * batch parameters (annual savings rate in %)
       01  WS-SAVINGS-RATE         PIC S9(3)V9(4) COMP-3 VALUE 2.00.
       01  WS-PMT                  PIC S9(13)V99 COMP-3.
       01  WS-LOAN-AMT             PIC S9(13)V99 COMP-3.
       01  WS-LOAN-RATE            PIC S9(3)V9(4) COMP-3.

      * counters per step: 1 interest, 2 fees, 3 loans, 4 cards
       01  WS-P1                   PIC 9(6) VALUE 0.
       01  WS-P2                   PIC 9(6) VALUE 0.
       01  WS-P3                   PIC 9(6) VALUE 0.
       01  WS-P4                   PIC 9(6) VALUE 0.
       01  WS-E1                   PIC 9(6) VALUE 0.
       01  WS-E2                   PIC 9(6) VALUE 0.
       01  WS-E3                   PIC 9(6) VALUE 0.
       01  WS-E4                   PIC 9(6) VALUE 0.

      * file handling
       01  WS-BATCH-DIR            PIC X(80) VALUE SPACES.
       01  WS-LOG-PATH             PIC X(120).
       01  WS-SUM-PATH             PIC X(120).
       01  WS-RPT-PATH             PIC X(120).
       01  WS-LOG-FS               PIC X(2).
       01  WS-SUM-FS               PIC X(2).
       01  WS-RPT-FS               PIC X(2).
       01  WS-LOG-MSG              PIC X(160).

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
       01  WS-RUN-ED               PIC Z(9)9.
       01  WS-ID-ED                PIC Z(9)9.
       01  WS-N-ED                 PIC ZZZZZ9.
       01  WS-N2-ED                PIC ZZZZZ9.

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
           PERFORM OPEN-FILES
           PERFORM DB-CONNECT
           IF WS-OK = 'Y' PERFORM INIT-RUN END-IF
           IF WS-OK = 'Y' PERFORM STEP-INTEREST END-IF
           IF WS-OK = 'Y' PERFORM STEP-FEES END-IF
           IF WS-OK = 'Y' PERFORM STEP-LOANS END-IF
           IF WS-OK = 'Y' PERFORM STEP-CARDS END-IF
           IF WS-OK = 'Y' PERFORM WRITE-STEP-AUDITS END-IF
           PERFORM CLOSE-RUN
           PERFORM WRITE-SUMMARY-FILE
           IF WS-CONNECTED = 'Y'
               PERFORM WRITE-AUDIT-REPORT
               EXEC SQL DISCONNECT ALL END-EXEC
           END-IF
           PERFORM CLOSE-FILES
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
           MOVE 'user' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE JU-VALUE TO WS-AUD-USER
           ELSE
               MOVE 'BATCH' TO WS-AUD-USER
           END-IF.

       OPEN-FILES.
           ACCEPT WS-BATCH-DIR FROM ENVIRONMENT 'ECBS_BATCH_DIR'
           IF WS-BATCH-DIR = SPACES
               MOVE '/opt/ecbs/batch-output' TO WS-BATCH-DIR
           END-IF
           MOVE SPACES TO WS-LOG-PATH
           STRING FUNCTION TRIM(WS-BATCH-DIR) '/BATCH_LOG.log'
               DELIMITED BY SIZE INTO WS-LOG-PATH
           END-STRING
           MOVE SPACES TO WS-SUM-PATH
           STRING FUNCTION TRIM(WS-BATCH-DIR) '/RUN_SUMMARY.rpt'
               DELIMITED BY SIZE INTO WS-SUM-PATH
           END-STRING
           MOVE SPACES TO WS-RPT-PATH
           STRING FUNCTION TRIM(WS-BATCH-DIR) '/AUDIT_REPORT.rpt'
               DELIMITED BY SIZE INTO WS-RPT-PATH
           END-STRING
           OPEN EXTEND BATCH-LOG-FILE.

       CLOSE-FILES.
           CLOSE BATCH-LOG-FILE.

       WRITE-LOG.
           MOVE 'CURRENT-TS' TO DU-OPERATION
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE WS-RUN-ID TO WS-RUN-ED
           MOVE SPACES TO LOG-LINE-REC
           STRING '[' DU-RESULT-TS '] RUN '
                  FUNCTION TRIM(WS-RUN-ED) ' '
                  FUNCTION TRIM(WS-LOG-MSG)
               DELIMITED BY SIZE INTO LOG-LINE-REC
           END-STRING
           WRITE LOG-LINE-REC.

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

      * Registers the run as RUNNING in its own transaction so the
      * row survives a rollback of the business steps.
       INIT-RUN.
           EXEC SQL
               INSERT INTO batch_runs (run_date, status)
               VALUES (CURRENT_DATE, 'RUNNING')
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               SELECT currval('batch_runs_batch_run_id_seq')
                 INTO :WS-RUN-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL COMMIT WORK END-EXEC
           MOVE 'NIGHTLY BATCH STARTED' TO WS-LOG-MSG
           PERFORM WRITE-LOG.

      * ---- STEP 1: monthly interest on ACTIVE SAVINGS accounts --
       STEP-INTEREST.
           EXEC SQL
               DECLARE SAVCUR CURSOR FOR
               SELECT account_id, CAST(balance AS VARCHAR)
                 FROM accounts
                WHERE account_type = 'SAVINGS'
                  AND status = 'ACTIVE'
                  AND balance > 0
                ORDER BY account_id
           END-EXEC
           EXEC SQL
               OPEN SAVCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH SAVCUR
                    INTO :WS-ACCT-ID, :WS-BAL-TXT
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               MOVE 'MONTHLY-INT' TO MU-OPERATION
               COMPUTE MU-AMOUNT-1 =
                   FUNCTION NUMVAL(WS-BAL-TXT)
               MOVE WS-SAVINGS-RATE TO MU-RATE
               CALL 'MONEY_UTILS' USING MU-PARAMS
               MOVE MU-RESULT TO WS-AMOUNT
               IF WS-AMOUNT > 0
                   PERFORM APPLY-INTEREST
               END-IF
           END-PERFORM
           EXEC SQL
               CLOSE SAVCUR
           END-EXEC.

       APPLY-INTEREST.
           EXEC SQL
               UPDATE accounts
                  SET balance = balance + :WS-AMOUNT
                WHERE account_id = :WS-ACCT-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               INSERT INTO transactions
                      (account_id, transaction_type, amount,
                       description)
               VALUES (:WS-ACCT-ID, 'INTEREST', :WS-AMOUNT,
                       'NIGHTLY BATCH INTEREST')
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-P1
           MOVE 'FORMAT' TO MU-OPERATION
           MOVE WS-AMOUNT TO MU-AMOUNT-1
           CALL 'MONEY_UTILS' USING MU-PARAMS
           MOVE WS-ACCT-ID TO WS-ID-ED
           MOVE SPACES TO WS-LOG-MSG
           STRING 'INTEREST account '
                  FUNCTION TRIM(WS-ID-ED) ' +'
                  FUNCTION TRIM(MU-FORMATTED)
               DELIMITED BY SIZE INTO WS-LOG-MSG
           END-STRING
           PERFORM WRITE-LOG.

      * ---- STEP 2: maintenance fee on ACTIVE CHECKING accounts --
       STEP-FEES.
           EXEC SQL
               DECLARE CHKCUR CURSOR FOR
               SELECT account_id,
                      CASE WHEN balance >= :WS-FEE
                           THEN 1 ELSE 0 END
                 FROM accounts
                WHERE account_type = 'CHECKING'
                  AND status = 'ACTIVE'
                ORDER BY account_id
           END-EXEC
           EXEC SQL
               OPEN CHKCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH CHKCUR
                    INTO :WS-ACCT-ID, :WS-FLAG
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               IF WS-FLAG = 1
                   PERFORM APPLY-FEE
               ELSE
                   ADD 1 TO WS-E2
                   MOVE WS-ACCT-ID TO WS-ID-ED
                   MOVE SPACES TO WS-LOG-MSG
                   STRING 'FEE SKIPPED account '
                          FUNCTION TRIM(WS-ID-ED)
                          ' (INSUFFICIENT BALANCE)'
                       DELIMITED BY SIZE INTO WS-LOG-MSG
                   END-STRING
                   PERFORM WRITE-LOG
               END-IF
           END-PERFORM
           EXEC SQL
               CLOSE CHKCUR
           END-EXEC.

       APPLY-FEE.
           EXEC SQL
               UPDATE accounts
                  SET balance = balance - :WS-FEE
                WHERE account_id = :WS-ACCT-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               INSERT INTO transactions
                      (account_id, transaction_type, amount,
                       description)
               VALUES (:WS-ACCT-ID, 'FEE', :WS-FEE,
                       'MONTHLY MAINTENANCE FEE')
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-P2
           MOVE WS-ACCT-ID TO WS-ID-ED
           MOVE SPACES TO WS-LOG-MSG
           STRING 'FEE account ' FUNCTION TRIM(WS-ID-ED)
                  ' -5.00'
               DELIMITED BY SIZE INTO WS-LOG-MSG
           END-STRING
           PERFORM WRITE-LOG.

      * ---- STEP 3: monthly payment of every ACTIVE loan ---------
       STEP-LOANS.
           EXEC SQL
               DECLARE LNCUR CURSOR FOR
               SELECT loan_id, customer_id,
                      CAST(amount AS VARCHAR),
                      CAST(interest_rate AS VARCHAR),
                      duration_months
                 FROM loans
                WHERE status = 'ACTIVE'
                ORDER BY loan_id
           END-EXEC
           EXEC SQL
               OPEN LNCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH LNCUR
                    INTO :WS-LOAN-ID, :WS-LOAN-CUST,
                         :WS-LOAN-AMT-TXT, :WS-LOAN-RATE-TXT,
                         :WS-LOAN-MONTHS
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               PERFORM CHARGE-LOAN
           END-PERFORM
           EXEC SQL
               CLOSE LNCUR
           END-EXEC.

       CHARGE-LOAN.
           COMPUTE WS-LOAN-AMT =
               FUNCTION NUMVAL(WS-LOAN-AMT-TXT)
           COMPUTE WS-LOAN-RATE =
               FUNCTION NUMVAL(WS-LOAN-RATE-TXT)
           IF WS-LOAN-RATE = 0
               COMPUTE WS-PMT ROUNDED =
                   WS-LOAN-AMT / WS-LOAN-MONTHS
           ELSE
               MOVE 'FRENCH-PMT' TO MU-OPERATION
               MOVE WS-LOAN-AMT TO MU-AMOUNT-1
               MOVE WS-LOAN-RATE TO MU-RATE
               MOVE WS-LOAN-MONTHS TO MU-MONTHS
               CALL 'MONEY_UTILS' USING MU-PARAMS
               MOVE MU-RESULT TO WS-PMT
           END-IF
      *    richest ACTIVE account of the loan holder
           EXEC SQL
               SELECT account_id,
                      CASE WHEN balance >= :WS-PMT
                           THEN 1 ELSE 0 END
                 INTO :WS-PAY-ACCT, :WS-FLAG
                 FROM accounts
                WHERE customer_id = :WS-LOAN-CUST
                  AND status = 'ACTIVE'
                ORDER BY balance DESC
                LIMIT 1
           END-EXEC
           MOVE WS-LOAN-ID TO WS-ID-ED
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   ADD 1 TO WS-E3
                   MOVE SPACES TO WS-LOG-MSG
                   STRING 'LOAN ' FUNCTION TRIM(WS-ID-ED)
                          ' SKIPPED (NO ACTIVE ACCOUNT)'
                       DELIMITED BY SIZE INTO WS-LOG-MSG
                   END-STRING
                   PERFORM WRITE-LOG
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
               WHEN WS-FLAG NOT = 1
                   ADD 1 TO WS-E3
                   MOVE SPACES TO WS-LOG-MSG
                   STRING 'LOAN ' FUNCTION TRIM(WS-ID-ED)
                          ' SKIPPED (INSUFFICIENT FUNDS)'
                       DELIMITED BY SIZE INTO WS-LOG-MSG
                   END-STRING
                   PERFORM WRITE-LOG
               WHEN OTHER
                   PERFORM APPLY-LOAN-PAYMENT
           END-EVALUATE.

       APPLY-LOAN-PAYMENT.
           EXEC SQL
               UPDATE accounts
                  SET balance = balance - :WS-PMT
                WHERE account_id = :WS-PAY-ACCT
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           MOVE WS-LOAN-ID TO WS-ID-ED
           MOVE SPACES TO WS-DESC
           STRING 'LOAN ' FUNCTION TRIM(WS-ID-ED)
                  ' MONTHLY PAYMENT'
               DELIMITED BY SIZE INTO WS-DESC
           END-STRING
           EXEC SQL
               INSERT INTO transactions
                      (account_id, transaction_type, amount,
                       description)
               VALUES (:WS-PAY-ACCT, 'LOAN_PAYMENT', :WS-PMT,
                       TRIM(TRAILING FROM :WS-DESC))
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-P3
           MOVE 'FORMAT' TO MU-OPERATION
           MOVE WS-PMT TO MU-AMOUNT-1
           CALL 'MONEY_UTILS' USING MU-PARAMS
           MOVE SPACES TO WS-LOG-MSG
           STRING 'LOAN_PAYMENT loan '
                  FUNCTION TRIM(WS-ID-ED) ' -'
                  FUNCTION TRIM(MU-FORMATTED)
               DELIMITED BY SIZE INTO WS-LOG-MSG
           END-STRING
           PERFORM WRITE-LOG.

      * ---- STEP 4: settlement of ACTIVE credit cards ------------
       STEP-CARDS.
           EXEC SQL
               DECLARE CDCUR CURSOR FOR
               SELECT card_id, account_id,
                      CAST(credit_limit - available_credit
                           AS VARCHAR)
                 FROM cards
                WHERE status = 'ACTIVE'
                  AND credit_limit > available_credit
                ORDER BY card_id
           END-EXEC
           EXEC SQL
               OPEN CDCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH CDCUR
                    INTO :WS-CARD-ID, :WS-CARD-ACCT,
                         :WS-SPENT-TXT
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               PERFORM SETTLE-CARD
           END-PERFORM
           EXEC SQL
               CLOSE CDCUR
           END-EXEC.

       SETTLE-CARD.
           COMPUTE WS-AMOUNT = FUNCTION NUMVAL(WS-SPENT-TXT)
           EXEC SQL
               SELECT CASE WHEN balance >= :WS-AMOUNT
                           AND status = 'ACTIVE'
                           THEN 1 ELSE 0 END
                 INTO :WS-FLAG
                 FROM accounts
                WHERE account_id = :WS-CARD-ACCT
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           MOVE WS-CARD-ID TO WS-ID-ED
           IF WS-FLAG NOT = 1
               ADD 1 TO WS-E4
               MOVE SPACES TO WS-LOG-MSG
               STRING 'CARD ' FUNCTION TRIM(WS-ID-ED)
                      ' SETTLEMENT SKIPPED (NO FUNDS)'
                   DELIMITED BY SIZE INTO WS-LOG-MSG
               END-STRING
               PERFORM WRITE-LOG
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               UPDATE accounts
                  SET balance = balance - :WS-AMOUNT
                WHERE account_id = :WS-CARD-ACCT
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-DESC
           STRING 'CARD ' FUNCTION TRIM(WS-ID-ED)
                  ' MONTHLY SETTLEMENT'
               DELIMITED BY SIZE INTO WS-DESC
           END-STRING
           EXEC SQL
               INSERT INTO transactions
                      (account_id, transaction_type, amount,
                       description)
               VALUES (:WS-CARD-ACCT, 'FEE', :WS-AMOUNT,
                       TRIM(TRAILING FROM :WS-DESC))
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               UPDATE cards
                  SET available_credit = credit_limit
                WHERE card_id = :WS-CARD-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-P4
           MOVE 'FORMAT' TO MU-OPERATION
           MOVE WS-AMOUNT TO MU-AMOUNT-1
           CALL 'MONEY_UTILS' USING MU-PARAMS
           MOVE SPACES TO WS-LOG-MSG
           STRING 'CARD_SETTLEMENT card '
                  FUNCTION TRIM(WS-ID-ED) ' -'
                  FUNCTION TRIM(MU-FORMATTED)
               DELIMITED BY SIZE INTO WS-LOG-MSG
           END-STRING
           PERFORM WRITE-LOG.

      * one audit_logs entry per step, tied to the batch run
       WRITE-STEP-AUDITS.
           MOVE 'INTEREST' TO WS-STEP-NAME
           MOVE WS-P1 TO WS-N-ED
           MOVE WS-E1 TO WS-N2-ED
           PERFORM WRITE-ONE-STEP-AUDIT
           IF WS-OK NOT = 'Y' EXIT PARAGRAPH END-IF
           MOVE 'FEES' TO WS-STEP-NAME
           MOVE WS-P2 TO WS-N-ED
           MOVE WS-E2 TO WS-N2-ED
           PERFORM WRITE-ONE-STEP-AUDIT
           IF WS-OK NOT = 'Y' EXIT PARAGRAPH END-IF
           MOVE 'LOANS' TO WS-STEP-NAME
           MOVE WS-P3 TO WS-N-ED
           MOVE WS-E3 TO WS-N2-ED
           PERFORM WRITE-ONE-STEP-AUDIT
           IF WS-OK NOT = 'Y' EXIT PARAGRAPH END-IF
           MOVE 'CARDS' TO WS-STEP-NAME
           MOVE WS-P4 TO WS-N-ED
           MOVE WS-E4 TO WS-N2-ED
           PERFORM WRITE-ONE-STEP-AUDIT.

       WRITE-ONE-STEP-AUDIT.
           MOVE SPACES TO WS-AUD-NEW
           STRING '{"step":"' FUNCTION TRIM(WS-STEP-NAME)
                  '","processed":' FUNCTION TRIM(WS-N-ED)
                  ',"errors":' FUNCTION TRIM(WS-N2-ED) '}'
               DELIMITED BY SIZE INTO WS-AUD-NEW
           END-STRING
           MOVE SPACES TO WS-DESC
           STRING 'BATCH_' FUNCTION TRIM(WS-STEP-NAME)
               DELIMITED BY SIZE INTO WS-DESC
           END-STRING
           EXEC SQL
               INSERT INTO audit_logs
                      (username, operation, entity_type,
                       entity_id, new_value)
               VALUES (TRIM(TRAILING FROM :WS-AUD-USER),
                       TRIM(TRAILING FROM :WS-DESC),
                       'BATCH', :WS-RUN-ID,
                       CAST(TRIM(TRAILING FROM :WS-AUD-NEW)
                            AS JSONB))
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

      * commit/rollback the business work, then close batch_runs
      * in its own transaction so the outcome is always recorded
       CLOSE-RUN.
           IF WS-CONNECTED NOT = 'Y'
               EXIT PARAGRAPH
           END-IF
           IF WS-OK = 'Y'
               EXEC SQL COMMIT WORK END-EXEC
               MOVE 'SUCCESS' TO WS-RUN-STATUS
           ELSE
               EXEC SQL ROLLBACK WORK END-EXEC
               MOVE 'FAILED' TO WS-RUN-STATUS
           END-IF
           COMPUTE WS-TOT-PROC = WS-P1 + WS-P2 + WS-P3 + WS-P4
           COMPUTE WS-TOT-ERR = WS-E1 + WS-E2 + WS-E3 + WS-E4
           MOVE WS-P1 TO WS-N-ED
           MOVE SPACES TO WS-SUMMARY
           STRING 'interest=' FUNCTION TRIM(WS-N-ED)
               DELIMITED BY SIZE INTO WS-SUMMARY
           END-STRING
           MOVE WS-P2 TO WS-N-ED
           STRING FUNCTION TRIM(WS-SUMMARY)
                  ' fees=' FUNCTION TRIM(WS-N-ED)
               DELIMITED BY SIZE INTO WS-SUMMARY
           END-STRING
           MOVE WS-P3 TO WS-N-ED
           STRING FUNCTION TRIM(WS-SUMMARY)
                  ' loans=' FUNCTION TRIM(WS-N-ED)
               DELIMITED BY SIZE INTO WS-SUMMARY
           END-STRING
           MOVE WS-P4 TO WS-N-ED
           STRING FUNCTION TRIM(WS-SUMMARY)
                  ' cards=' FUNCTION TRIM(WS-N-ED)
               DELIMITED BY SIZE INTO WS-SUMMARY
           END-STRING
           EXEC SQL
               UPDATE batch_runs
                  SET finished_at = now(),
                      status =
                          TRIM(TRAILING FROM :WS-RUN-STATUS),
                      processed_count = :WS-TOT-PROC,
                      error_count = :WS-TOT-ERR,
                      summary = TRIM(TRAILING FROM :WS-SUMMARY)
                WHERE batch_run_id = :WS-RUN-ID
           END-EXEC
           EXEC SQL COMMIT WORK END-EXEC
           MOVE SPACES TO WS-LOG-MSG
           STRING 'NIGHTLY BATCH FINISHED STATUS '
                  FUNCTION TRIM(WS-RUN-STATUS)
               DELIMITED BY SIZE INTO WS-LOG-MSG
           END-STRING
           PERFORM WRITE-LOG
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'BATCH' TO LOG-COMPONENT
           MOVE WS-LOG-MSG TO LOG-MSG
           CALL 'LOGGER' USING LOG-PARAMS.

       WRITE-SUMMARY-FILE.
           OPEN OUTPUT SUMMARY-FILE
           MOVE 'ECBS NIGHTLY BATCH - RUN SUMMARY'
             TO SUM-LINE-REC
           WRITE SUM-LINE-REC
           MOVE 'CURRENT-TS' TO DU-OPERATION
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE WS-RUN-ID TO WS-RUN-ED
           MOVE SPACES TO SUM-LINE-REC
           STRING 'RUN ID: ' FUNCTION TRIM(WS-RUN-ED)
                  '   DATE: ' DU-RESULT-TS
                  '   STATUS: ' FUNCTION TRIM(WS-RUN-STATUS)
               DELIMITED BY SIZE INTO SUM-LINE-REC
           END-STRING
           WRITE SUM-LINE-REC
           MOVE 'STEP        PROCESSED   ERRORS/SKIPS'
             TO SUM-LINE-REC
           WRITE SUM-LINE-REC
           MOVE 'INTEREST' TO WS-STEP-NAME
           MOVE WS-P1 TO WS-N-ED
           MOVE WS-E1 TO WS-N2-ED
           PERFORM WRITE-SUM-ROW
           MOVE 'FEES' TO WS-STEP-NAME
           MOVE WS-P2 TO WS-N-ED
           MOVE WS-E2 TO WS-N2-ED
           PERFORM WRITE-SUM-ROW
           MOVE 'LOANS' TO WS-STEP-NAME
           MOVE WS-P3 TO WS-N-ED
           MOVE WS-E3 TO WS-N2-ED
           PERFORM WRITE-SUM-ROW
           MOVE 'CARDS' TO WS-STEP-NAME
           MOVE WS-P4 TO WS-N-ED
           MOVE WS-E4 TO WS-N2-ED
           PERFORM WRITE-SUM-ROW
           MOVE 'TOTAL' TO WS-STEP-NAME
           MOVE WS-TOT-PROC TO WS-N-ED
           MOVE WS-TOT-ERR TO WS-N2-ED
           PERFORM WRITE-SUM-ROW
           CLOSE SUMMARY-FILE.

       WRITE-SUM-ROW.
           MOVE SPACES TO SUM-LINE-REC
           STRING WS-STEP-NAME(1:10) '  '
                  WS-N-ED '       ' WS-N2-ED
               DELIMITED BY SIZE INTO SUM-LINE-REC
           END-STRING
           WRITE SUM-LINE-REC.

      * audit entries of this run, dumped to AUDIT_REPORT.rpt
       WRITE-AUDIT-REPORT.
           OPEN OUTPUT AUDIT-RPT-FILE
           MOVE 'ECBS NIGHTLY BATCH - AUDIT REPORT'
             TO RPT-LINE-REC
           WRITE RPT-LINE-REC
           EXEC SQL
               DECLARE AUDCUR CURSOR FOR
               SELECT username, operation,
                      CAST(new_value AS VARCHAR),
                      SUBSTR(CAST(event_time AS VARCHAR), 1, 19)
                 FROM audit_logs
                WHERE entity_type = 'BATCH'
                  AND entity_id = :WS-RUN-ID
                ORDER BY audit_id
           END-EXEC
           EXEC SQL
               OPEN AUDCUR
           END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH AUDCUR
                    INTO :WS-RPT-USER, :WS-RPT-OP,
                         :WS-RPT-VAL, :WS-RPT-TS
               END-EXEC
               IF SQLCODE = 0
                   MOVE SPACES TO RPT-LINE-REC
                   STRING WS-RPT-TS ' '
                          FUNCTION TRIM(WS-RPT-USER) ' '
                          FUNCTION TRIM(WS-RPT-OP) ' '
                          FUNCTION TRIM(WS-RPT-VAL)
                       DELIMITED BY SIZE INTO RPT-LINE-REC
                   END-STRING
                   WRITE RPT-LINE-REC
               END-IF
           END-PERFORM
           EXEC SQL
               CLOSE AUDCUR
           END-EXEC
           CLOSE AUDIT-RPT-FILE.

       SQL-ERROR-PARA.
           MOVE 'N' TO WS-OK
           MOVE 'E010' TO WS-ERR-CODE
           MOVE SQLCODE TO WS-SQLCODE-ED
           MOVE SPACES TO WS-ERR-CTX
           STRING 'SQLCODE ' WS-SQLCODE-ED ' ' SQLERRMC(1:40)
               DELIMITED BY SIZE INTO WS-ERR-CTX
           END-STRING
           MOVE WS-ERR-CTX TO WS-LOG-MSG
           PERFORM WRITE-LOG.

       PRINT-OK.
           MOVE WS-RUN-ID TO WS-RUN-ED
           DISPLAY '{"status":"OK","batchRunId":'
                   FUNCTION TRIM(WS-RUN-ED)
                   ',"runStatus":"'
                   FUNCTION TRIM(WS-RUN-STATUS) '"'
           MOVE WS-P1 TO WS-N-ED
           DISPLAY ',"interest":' FUNCTION TRIM(WS-N-ED)
           MOVE WS-P2 TO WS-N-ED
           DISPLAY ',"fees":' FUNCTION TRIM(WS-N-ED)
           MOVE WS-P3 TO WS-N-ED
           DISPLAY ',"loans":' FUNCTION TRIM(WS-N-ED)
           MOVE WS-P4 TO WS-N-ED
           DISPLAY ',"cards":' FUNCTION TRIM(WS-N-ED)
           MOVE WS-TOT-PROC TO WS-N-ED
           MOVE WS-TOT-ERR TO WS-N2-ED
           DISPLAY ',"processed":' FUNCTION TRIM(WS-N-ED)
                   ',"errors":' FUNCTION TRIM(WS-N2-ED)
                   ',"files":["BATCH_LOG.log",'
                   '"RUN_SUMMARY.rpt","AUDIT_REPORT.rpt"]}'.

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
