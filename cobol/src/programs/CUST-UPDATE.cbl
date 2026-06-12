      ******************************************************************
      * CUST-UPDATE.cbl - Fase 4: customer modification.
      *
      * Bridge input (one JSON line on stdin):
      *   {"customerId":3,"email":"new@example.com",
      *    "phone":"+34600000001","user":"operator1"}
      * Only the provided fields (firstName, lastName, email, phone)
      * are changed; missing or blank keys keep the current value.
      *
      * Loads the current row, merges and validates the new values,
      * rejects duplicate emails, updates the row and writes an
      * audit_logs entry with the old and new values as JSON.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUST-UPDATE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-CUST-ID              PIC 9(10).
       01  WS-OLD-FIRST            PIC X(50).
       01  WS-OLD-LAST             PIC X(80).
       01  WS-OLD-EMAIL            PIC X(120).
       01  WS-OLD-PHONE            PIC X(20).
       01  WS-OLD-STATUS           PIC X(10).
       01  WS-NEW-FIRST            PIC X(50).
       01  WS-NEW-LAST             PIC X(80).
       01  WS-NEW-EMAIL            PIC X(120).
       01  WS-NEW-PHONE            PIC X(20).
       01  WS-DUP-COUNT            PIC 9(9).
       01  WS-AUD-USER             PIC X(50).
       01  WS-AUD-OLD              PIC X(500).
       01  WS-AUD-NEW              PIC X(500).
       01  WS-DB-CONN              PIC X(64).
       01  WS-DB-USER              PIC X(32).
       01  WS-DB-PASS              PIC X(32).

      * input staging and control fields
       01  WS-IN-FIRST             PIC X(50).
       01  WS-IN-LAST              PIC X(80).
       01  WS-IN-EMAIL             PIC X(120).
       01  WS-IN-PHONE             PIC X(20).
       01  WS-HAS-FIRST            PIC X.
       01  WS-HAS-LAST             PIC X.
       01  WS-HAS-EMAIL            PIC X.
       01  WS-HAS-PHONE            PIC X.
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
       01  VAL-PARAMS.
           05 VAL-OPERATION        PIC X(15).
           05 VAL-INPUT            PIC X(120).
           05 VAL-RC               PIC X(2).
           05 VAL-MESSAGE          PIC X(80).
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
           IF WS-OK = 'Y' PERFORM FETCH-CURRENT END-IF
           IF WS-OK = 'Y' PERFORM MERGE-AND-VALIDATE END-IF
           IF WS-OK = 'Y' PERFORM CHECK-DUPLICATE END-IF
           IF WS-OK = 'Y' PERFORM UPDATE-CUSTOMER END-IF
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

           MOVE 'firstName' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 'Y' TO WS-HAS-FIRST
               MOVE JU-VALUE TO WS-IN-FIRST
           ELSE
               MOVE 'N' TO WS-HAS-FIRST
           END-IF
           MOVE 'lastName' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 'Y' TO WS-HAS-LAST
               MOVE JU-VALUE TO WS-IN-LAST
           ELSE
               MOVE 'N' TO WS-HAS-LAST
           END-IF
           MOVE 'email' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 'Y' TO WS-HAS-EMAIL
               MOVE JU-VALUE TO WS-IN-EMAIL
           ELSE
               MOVE 'N' TO WS-HAS-EMAIL
           END-IF
           MOVE 'phone' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 'Y' TO WS-HAS-PHONE
               MOVE JU-VALUE TO WS-IN-PHONE
           ELSE
               MOVE 'N' TO WS-HAS-PHONE
           END-IF
           MOVE 'user' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE JU-VALUE TO WS-AUD-USER
           ELSE
               MOVE 'SYSTEM' TO WS-AUD-USER
           END-IF
           IF WS-HAS-FIRST = 'N' AND WS-HAS-LAST = 'N'
                   AND WS-HAS-EMAIL = 'N' AND WS-HAS-PHONE = 'N'
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'NO FIELDS TO UPDATE' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
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

       FETCH-CURRENT.
           EXEC SQL
               SELECT first_name, last_name, email, phone, status
                 INTO :WS-OLD-FIRST, :WS-OLD-LAST, :WS-OLD-EMAIL,
                      :WS-OLD-PHONE, :WS-OLD-STATUS
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
               WHEN WS-OLD-STATUS = 'DELETED'
                   MOVE 'E014' TO WS-ERR-CODE
                   MOVE 'CUSTOMER IS DELETED' TO WS-ERR-CTX
                   MOVE 'N' TO WS-OK
           END-EVALUATE.

       MERGE-AND-VALIDATE.
           IF WS-HAS-FIRST = 'Y'
               MOVE WS-IN-FIRST TO WS-NEW-FIRST
           ELSE
               MOVE WS-OLD-FIRST TO WS-NEW-FIRST
           END-IF
           IF WS-HAS-LAST = 'Y'
               MOVE WS-IN-LAST TO WS-NEW-LAST
           ELSE
               MOVE WS-OLD-LAST TO WS-NEW-LAST
           END-IF
           IF WS-HAS-EMAIL = 'Y'
               MOVE WS-IN-EMAIL TO WS-NEW-EMAIL
           ELSE
               MOVE WS-OLD-EMAIL TO WS-NEW-EMAIL
           END-IF
           IF WS-HAS-PHONE = 'Y'
               MOVE WS-IN-PHONE TO WS-NEW-PHONE
           ELSE
               MOVE WS-OLD-PHONE TO WS-NEW-PHONE
           END-IF
           MOVE 'EMAIL' TO VAL-OPERATION
           MOVE WS-NEW-EMAIL TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           IF VAL-RC NOT = '00'
               MOVE 'E001' TO WS-ERR-CODE
               MOVE VAL-MESSAGE TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'PHONE' TO VAL-OPERATION
           MOVE WS-NEW-PHONE TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           IF VAL-RC NOT = '00'
               MOVE 'E002' TO WS-ERR-CODE
               MOVE VAL-MESSAGE TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
           END-IF.

       CHECK-DUPLICATE.
           EXEC SQL
               SELECT COUNT(*) INTO :WS-DUP-COUNT
                 FROM customers
                WHERE email = TRIM(TRAILING FROM :WS-NEW-EMAIL)
                  AND customer_id <> :WS-CUST-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           IF WS-DUP-COUNT > 0
               MOVE 'E003' TO WS-ERR-CODE
               MOVE SPACES TO WS-ERR-CTX
               STRING 'EMAIL ' FUNCTION TRIM(WS-NEW-EMAIL)
                   DELIMITED BY SIZE INTO WS-ERR-CTX
               END-STRING
               MOVE 'N' TO WS-OK
           END-IF.

       UPDATE-CUSTOMER.
           EXEC SQL
               UPDATE customers
                  SET first_name = TRIM(TRAILING FROM :WS-NEW-FIRST),
                      last_name = TRIM(TRAILING FROM :WS-NEW-LAST),
                      email = TRIM(TRAILING FROM :WS-NEW-EMAIL),
                      phone = TRIM(TRAILING FROM :WS-NEW-PHONE)
                WHERE customer_id = :WS-CUST-ID
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       WRITE-AUDIT.
           MOVE SPACES TO WS-AUD-OLD
           STRING '{"firstName":"' FUNCTION TRIM(WS-OLD-FIRST)
                  '","lastName":"' FUNCTION TRIM(WS-OLD-LAST)
                  '","email":"' FUNCTION TRIM(WS-OLD-EMAIL)
                  '","phone":"' FUNCTION TRIM(WS-OLD-PHONE) '"}'
               DELIMITED BY SIZE INTO WS-AUD-OLD
           END-STRING
           MOVE SPACES TO WS-AUD-NEW
           STRING '{"firstName":"' FUNCTION TRIM(WS-NEW-FIRST)
                  '","lastName":"' FUNCTION TRIM(WS-NEW-LAST)
                  '","email":"' FUNCTION TRIM(WS-NEW-EMAIL)
                  '","phone":"' FUNCTION TRIM(WS-NEW-PHONE) '"}'
               DELIMITED BY SIZE INTO WS-AUD-NEW
           END-STRING
           EXEC SQL
               INSERT INTO audit_logs
                      (username, operation, entity_type,
                       entity_id, old_value, new_value)
               VALUES (TRIM(TRAILING FROM :WS-AUD-USER),
                       'UPDATE', 'CUSTOMER', :WS-CUST-ID,
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
           MOVE 'CUST-UPDATE' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-CUST-ID TO WS-ID-ED
           STRING 'customer updated id='
                  FUNCTION TRIM(WS-ID-ED)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
           CALL 'LOGGER' USING LOG-PARAMS
           DISPLAY '{"status":"OK","customerId":'
                   FUNCTION TRIM(WS-ID-ED)
                   ',"email":"' FUNCTION TRIM(WS-NEW-EMAIL) '"}'.

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
