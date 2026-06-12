      ******************************************************************
      * LOAN-REJECT.cbl - Fase 8: loan rejection (rechazo).
      *
      * Bridge input (one JSON line on stdin):
      *   {"loanId":3,"reason":"Insufficient income","user":"risk"}
      *
      * Only REQUESTED loans can be rejected (E014). The optional
      * reason is stored in the audit entry. Audited.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-REJECT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-LOAN-ID              PIC 9(10).
       01  WS-LOAN-STATUS          PIC X(10).
       01  WS-AUD-USER             PIC X(50).
       01  WS-AUD-OLD              PIC X(500).
       01  WS-AUD-NEW              PIC X(500).
       01  WS-DB-CONN              PIC X(64).
       01  WS-DB-USER              PIC X(32).
       01  WS-DB-PASS              PIC X(32).

      * environment and control fields
       01  WS-REASON               PIC X(120).
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
           IF WS-OK = 'Y' PERFORM FETCH-LOAN END-IF
           IF WS-OK = 'Y' PERFORM REJECT-LOAN END-IF
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
           MOVE 'loanId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND NOT = 'Y' OR JU-VALUE = SPACES
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'loanId' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-LOAN-ID = FUNCTION NUMVAL(JU-VALUE)
           MOVE 'reason' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE JU-VALUE TO WS-REASON
           ELSE
               MOVE 'NOT SPECIFIED' TO WS-REASON
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

       FETCH-LOAN.
           EXEC SQL
               SELECT status INTO :WS-LOAN-STATUS
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
               WHEN WS-LOAN-STATUS NOT = 'REQUESTED'
                   MOVE 'E014' TO WS-ERR-CODE
                   MOVE SPACES TO WS-ERR-CTX
                   STRING 'LOAN STATUS '
                          FUNCTION TRIM(WS-LOAN-STATUS)
                       DELIMITED BY SIZE INTO WS-ERR-CTX
                   END-STRING
                   MOVE 'N' TO WS-OK
           END-EVALUATE.

       REJECT-LOAN.
           EXEC SQL
               UPDATE loans
                  SET status = 'REJECTED'
                WHERE loan_id = :WS-LOAN-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       WRITE-AUDIT.
           MOVE '{"status":"REQUESTED"}' TO WS-AUD-OLD
           MOVE SPACES TO WS-AUD-NEW
           STRING '{"status":"REJECTED","reason":"'
                  FUNCTION TRIM(WS-REASON) '"}'
               DELIMITED BY SIZE INTO WS-AUD-NEW
           END-STRING
           EXEC SQL
               INSERT INTO audit_logs
                      (username, operation, entity_type,
                       entity_id, old_value, new_value)
               VALUES (TRIM(TRAILING FROM :WS-AUD-USER),
                       'REJECT', 'LOAN', :WS-LOAN-ID,
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

       PRINT-OK.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'LOAN-REJECT' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-LOAN-ID TO WS-ID-ED
           STRING 'loan rejected id=' FUNCTION TRIM(WS-ID-ED)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
           CALL 'LOGGER' USING LOG-PARAMS
           DISPLAY '{"status":"OK","loanId":'
                   FUNCTION TRIM(WS-ID-ED)
                   ',"loanStatus":"REJECTED"}'.

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
