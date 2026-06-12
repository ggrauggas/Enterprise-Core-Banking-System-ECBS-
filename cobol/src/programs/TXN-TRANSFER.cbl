      ******************************************************************
      * TXN-TRANSFER.cbl - Fase 6: atomic transfer between accounts.
      *
      * Bridge input (one JSON line on stdin):
      *   {"fromAccountId":1,"toAccountId":3,"amount":150.00,
      *    "description":"Rent","user":"operator1"}
      *
      * Validations: origin and destination must exist (E004) and
      * be ACTIVE (E007), they must differ (E019), amount > 0
      * (E018) and the origin needs sufficient funds (E005).
      *
      * Atomic double entry inside ONE database transaction:
      *   debit origin + credit destination
      *   + TRANSFER_OUT row (origin, related = destination)
      *   + TRANSFER_IN  row (destination, related = origin)
      *   + audit_logs entry with both balances before/after.
      * Any SQL failure rolls everything back.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXN-TRANSFER.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-FROM-ID              PIC 9(10).
       01  WS-TO-ID                PIC 9(10).
       01  WS-AMOUNT               PIC S9(13)V99 COMP-3.
       01  WS-DESC                 PIC X(200).
       01  WS-FROM-STATUS          PIC X(10).
       01  WS-TO-STATUS            PIC X(10).
       01  WS-FUNDS-OK             PIC 9.
       01  WS-FROM-OLD             PIC X(20).
       01  WS-TO-OLD               PIC X(20).
       01  WS-FROM-NEW             PIC X(20).
       01  WS-TO-NEW               PIC X(20).
       01  WS-AMT-TXT              PIC X(20).
       01  WS-TX-OUT               PIC 9(10).
       01  WS-TX-IN                PIC 9(10).
       01  WS-AUD-USER             PIC X(50).
       01  WS-AUD-OLD              PIC X(500).
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
       01  WS-ID2-ED               PIC Z(9)9.
       01  WS-TX-ED                PIC Z(9)9.
       01  WS-TX2-ED               PIC Z(9)9.

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
           IF WS-OK = 'Y' PERFORM FETCH-ORIGIN END-IF
           IF WS-OK = 'Y' PERFORM FETCH-DESTINATION END-IF
           IF WS-OK = 'Y' PERFORM APPLY-MOVEMENTS END-IF
           IF WS-OK = 'Y' PERFORM INSERT-TXNS END-IF
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
           MOVE 'fromAccountId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'fromAccountId' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-FROM-ID = FUNCTION NUMVAL(JU-VALUE)
           MOVE 'toAccountId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'toAccountId' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-TO-ID = FUNCTION NUMVAL(JU-VALUE)
           IF WS-FROM-ID = WS-TO-ID
               MOVE 'E019' TO WS-ERR-CODE
               PERFORM SET-ORIGIN-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'amount' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'amount' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-AMOUNT = FUNCTION NUMVAL(JU-VALUE)
           IF WS-AMOUNT <= 0
               MOVE 'E018' TO WS-ERR-CODE
               MOVE 'AMOUNT MUST BE POSITIVE' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'description' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE JU-VALUE TO WS-DESC
           ELSE
               MOVE 'TRANSFER' TO WS-DESC
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

       FETCH-ORIGIN.
           EXEC SQL
               SELECT status, CAST(balance AS VARCHAR),
                      CASE WHEN balance >= :WS-AMOUNT
                           THEN 1 ELSE 0 END
                 INTO :WS-FROM-STATUS, :WS-FROM-OLD, :WS-FUNDS-OK
                 FROM accounts
                WHERE account_id = :WS-FROM-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   PERFORM SET-ORIGIN-CTX
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
               WHEN WS-FROM-STATUS = 'CLOSED'
                   MOVE 'E007' TO WS-ERR-CODE
                   PERFORM SET-ORIGIN-CTX
                   MOVE 'N' TO WS-OK
               WHEN WS-FUNDS-OK NOT = 1
                   MOVE 'E005' TO WS-ERR-CODE
                   MOVE SPACES TO WS-ERR-CTX
                   STRING 'ORIGIN BALANCE '
                          FUNCTION TRIM(WS-FROM-OLD)
                       DELIMITED BY SIZE INTO WS-ERR-CTX
                   END-STRING
                   MOVE 'N' TO WS-OK
           END-EVALUATE.

       FETCH-DESTINATION.
           EXEC SQL
               SELECT status, CAST(balance AS VARCHAR)
                 INTO :WS-TO-STATUS, :WS-TO-OLD
                 FROM accounts
                WHERE account_id = :WS-TO-ID
           END-EXEC
           EVALUATE TRUE
               WHEN SQLCODE = 100
                   MOVE 'E004' TO WS-ERR-CODE
                   PERFORM SET-DEST-CTX
                   MOVE 'N' TO WS-OK
               WHEN SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
               WHEN WS-TO-STATUS = 'CLOSED'
                   MOVE 'E007' TO WS-ERR-CODE
                   PERFORM SET-DEST-CTX
                   MOVE 'N' TO WS-OK
           END-EVALUATE.

       APPLY-MOVEMENTS.
           EXEC SQL
               UPDATE accounts
                  SET balance = balance - :WS-AMOUNT
                WHERE account_id = :WS-FROM-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               UPDATE accounts
                  SET balance = balance + :WS-AMOUNT
                WHERE account_id = :WS-TO-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               SELECT CAST(balance AS VARCHAR),
                      CAST(:WS-AMOUNT AS VARCHAR)
                 INTO :WS-FROM-NEW, :WS-AMT-TXT
                 FROM accounts
                WHERE account_id = :WS-FROM-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               SELECT CAST(balance AS VARCHAR)
                 INTO :WS-TO-NEW
                 FROM accounts
                WHERE account_id = :WS-TO-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       INSERT-TXNS.
           EXEC SQL
               INSERT INTO transactions
                      (account_id, transaction_type, amount,
                       description, related_account_id)
               VALUES (:WS-FROM-ID, 'TRANSFER_OUT', :WS-AMOUNT,
                       NULLIF(TRIM(TRAILING FROM :WS-DESC), ''),
                       :WS-TO-ID)
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               SELECT currval('transactions_transaction_id_seq')
                 INTO :WS-TX-OUT
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               INSERT INTO transactions
                      (account_id, transaction_type, amount,
                       description, related_account_id)
               VALUES (:WS-TO-ID, 'TRANSFER_IN', :WS-AMOUNT,
                       NULLIF(TRIM(TRAILING FROM :WS-DESC), ''),
                       :WS-FROM-ID)
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           EXEC SQL
               SELECT currval('transactions_transaction_id_seq')
                 INTO :WS-TX-IN
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       WRITE-AUDIT.
           MOVE SPACES TO WS-AUD-OLD
           STRING '{"originBalance":' FUNCTION TRIM(WS-FROM-OLD)
                  ',"destBalance":' FUNCTION TRIM(WS-TO-OLD) '}'
               DELIMITED BY SIZE INTO WS-AUD-OLD
           END-STRING
           MOVE WS-TO-ID TO WS-ID2-ED
           MOVE SPACES TO WS-AUD-NEW
           STRING '{"originBalance":' FUNCTION TRIM(WS-FROM-NEW)
                  ',"destBalance":' FUNCTION TRIM(WS-TO-NEW)
                  ',"amount":' FUNCTION TRIM(WS-AMT-TXT)
                  ',"toAccountId":' FUNCTION TRIM(WS-ID2-ED) '}'
               DELIMITED BY SIZE INTO WS-AUD-NEW
           END-STRING
           EXEC SQL
               INSERT INTO audit_logs
                      (username, operation, entity_type,
                       entity_id, old_value, new_value)
               VALUES (TRIM(TRAILING FROM :WS-AUD-USER),
                       'TRANSFER', 'ACCOUNT', :WS-FROM-ID,
                       CAST(TRIM(TRAILING FROM :WS-AUD-OLD)
                            AS JSONB),
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

       SET-ORIGIN-CTX.
           MOVE WS-FROM-ID TO WS-ID-ED
           MOVE SPACES TO WS-ERR-CTX
           STRING 'ORIGIN ACCOUNT ' FUNCTION TRIM(WS-ID-ED)
               DELIMITED BY SIZE INTO WS-ERR-CTX
           END-STRING.

       SET-DEST-CTX.
           MOVE WS-TO-ID TO WS-ID-ED
           MOVE SPACES TO WS-ERR-CTX
           STRING 'DESTINATION ACCOUNT ' FUNCTION TRIM(WS-ID-ED)
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
           MOVE 'TXN-TRANSFER' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-FROM-ID TO WS-ID-ED
           MOVE WS-TO-ID TO WS-ID2-ED
           STRING 'transfer ' FUNCTION TRIM(WS-AMT-TXT)
                  ' from=' FUNCTION TRIM(WS-ID-ED)
                  ' to=' FUNCTION TRIM(WS-ID2-ED)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
           CALL 'LOGGER' USING LOG-PARAMS
           MOVE WS-TX-OUT TO WS-TX-ED
           MOVE WS-TX-IN TO WS-TX2-ED
           DISPLAY '{"status":"OK","transferOutId":'
                   FUNCTION TRIM(WS-TX-ED)
                   ',"transferInId":' FUNCTION TRIM(WS-TX2-ED)
                   ',"fromAccountId":' FUNCTION TRIM(WS-ID-ED)
                   ',"toAccountId":' FUNCTION TRIM(WS-ID2-ED)
                   ',"amount":' FUNCTION TRIM(WS-AMT-TXT)
                   ',"fromNewBalance":'
                   FUNCTION TRIM(WS-FROM-NEW)
                   ',"toNewBalance":' FUNCTION TRIM(WS-TO-NEW)
                   '}'.

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
