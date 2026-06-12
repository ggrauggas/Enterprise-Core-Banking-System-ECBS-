      ******************************************************************
      * CUST-CREATE.cbl - Fase 4: customer registration (alta).
      *
      * Bridge input (one JSON line on stdin):
      *   {"firstName":"Nora","lastName":"Salas Marti",
      *    "birthDate":"1990-05-17","email":"nora@example.com",
      *    "phone":"+34600123987","user":"operator1"}
      *
      * Validates every field (VALIDATION / DATE_UTILS), rejects
      * duplicate emails, inserts the row with embedded SQL and
      * writes the matching audit_logs entry. Replies on stdout:
      *   {"status":"OK","customerId":N,"email":"..."}
      *   {"status":"ERROR","errorCode":"Exxx","message":"..."}
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUST-CREATE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-FIRST-NAME           PIC X(50).
       01  WS-LAST-NAME            PIC X(80).
       01  WS-BIRTH-DATE           PIC X(10).
       01  WS-EMAIL                PIC X(120).
       01  WS-PHONE                PIC X(20).
       01  WS-CUST-ID              PIC 9(10).
       01  WS-DUP-COUNT            PIC 9(9).
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
           IF WS-OK = 'Y' PERFORM VALIDATE-INPUT END-IF
           IF WS-OK = 'Y' PERFORM DB-CONNECT END-IF
           IF WS-OK = 'Y' PERFORM CHECK-DUPLICATE END-IF
           IF WS-OK = 'Y' PERFORM INSERT-CUSTOMER END-IF
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
           MOVE 'firstName' TO JU-KEY
           PERFORM GET-JSON
           MOVE JU-VALUE TO WS-FIRST-NAME
           MOVE 'lastName' TO JU-KEY
           PERFORM GET-JSON
           MOVE JU-VALUE TO WS-LAST-NAME
           MOVE 'birthDate' TO JU-KEY
           PERFORM GET-JSON
           MOVE JU-VALUE TO WS-BIRTH-DATE
           MOVE 'email' TO JU-KEY
           PERFORM GET-JSON
           MOVE JU-VALUE TO WS-EMAIL
           MOVE 'phone' TO JU-KEY
           PERFORM GET-JSON
           MOVE JU-VALUE TO WS-PHONE
           MOVE 'user' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE JU-VALUE TO WS-AUD-USER
           ELSE
               MOVE 'SYSTEM' TO WS-AUD-USER
           END-IF.

       VALIDATE-INPUT.
           MOVE 'NOT-BLANK' TO VAL-OPERATION
           MOVE WS-FIRST-NAME TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           IF VAL-RC NOT = '00'
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'firstName' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'NOT-BLANK' TO VAL-OPERATION
           MOVE WS-LAST-NAME TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           IF VAL-RC NOT = '00'
               MOVE 'E011' TO WS-ERR-CODE
               MOVE 'lastName' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'EMAIL' TO VAL-OPERATION
           MOVE WS-EMAIL TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           IF VAL-RC NOT = '00'
               MOVE 'E001' TO WS-ERR-CODE
               MOVE VAL-MESSAGE TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'PHONE' TO VAL-OPERATION
           MOVE WS-PHONE TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           IF VAL-RC NOT = '00'
               MOVE 'E002' TO WS-ERR-CODE
               MOVE VAL-MESSAGE TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'VALIDATE' TO DU-OPERATION
           MOVE WS-BIRTH-DATE TO DU-DATE-1
           CALL 'DATE_UTILS' USING DU-PARAMS
           IF DU-STATUS NOT = '00'
               MOVE 'E012' TO WS-ERR-CODE
               MOVE 'birthDate' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
               EXIT PARAGRAPH
           END-IF
           MOVE 'CALC-AGE' TO DU-OPERATION
           MOVE WS-BIRTH-DATE TO DU-DATE-1
           CALL 'DATE_UTILS' USING DU-PARAMS
           IF DU-RESULT-NUM < 18
               MOVE 'E013' TO WS-ERR-CODE
               MOVE 'birthDate' TO WS-ERR-CTX
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

       CHECK-DUPLICATE.
           EXEC SQL
               SELECT COUNT(*) INTO :WS-DUP-COUNT
                 FROM customers
                WHERE email = TRIM(TRAILING FROM :WS-EMAIL)
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           IF WS-DUP-COUNT > 0
               MOVE 'E003' TO WS-ERR-CODE
               MOVE SPACES TO WS-ERR-CTX
               STRING 'EMAIL ' FUNCTION TRIM(WS-EMAIL)
                   DELIMITED BY SIZE INTO WS-ERR-CTX
               END-STRING
               MOVE 'N' TO WS-OK
           END-IF.

       INSERT-CUSTOMER.
           EXEC SQL
               INSERT INTO customers
                      (first_name, last_name, birth_date,
                       email, phone, status)
               VALUES (TRIM(TRAILING FROM :WS-FIRST-NAME),
                       TRIM(TRAILING FROM :WS-LAST-NAME),
                       CAST(:WS-BIRTH-DATE AS DATE),
                       TRIM(TRAILING FROM :WS-EMAIL),
                       TRIM(TRAILING FROM :WS-PHONE),
                       'ACTIVE')
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
      *    email is UNIQUE, so it identifies the new row
           EXEC SQL
               SELECT customer_id INTO :WS-CUST-ID
                 FROM customers
                WHERE email = TRIM(TRAILING FROM :WS-EMAIL)
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
           END-IF.

       WRITE-AUDIT.
           MOVE SPACES TO WS-AUD-NEW
           STRING '{"firstName":"' FUNCTION TRIM(WS-FIRST-NAME)
                  '","lastName":"' FUNCTION TRIM(WS-LAST-NAME)
                  '","birthDate":"' WS-BIRTH-DATE
                  '","email":"' FUNCTION TRIM(WS-EMAIL)
                  '","phone":"' FUNCTION TRIM(WS-PHONE)
                  '","status":"ACTIVE"}'
               DELIMITED BY SIZE INTO WS-AUD-NEW
           END-STRING
           EXEC SQL
               INSERT INTO audit_logs
                      (username, operation, entity_type,
                       entity_id, old_value, new_value)
               VALUES (TRIM(TRAILING FROM :WS-AUD-USER),
                       'CREATE', 'CUSTOMER', :WS-CUST-ID, NULL,
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
           MOVE 'CUST-CREATE' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-CUST-ID TO WS-ID-ED
           STRING 'customer created id='
                  FUNCTION TRIM(WS-ID-ED)
                  ' email=' FUNCTION TRIM(WS-EMAIL)
               DELIMITED BY SIZE INTO LOG-MSG
           END-STRING
           CALL 'LOGGER' USING LOG-PARAMS
           DISPLAY '{"status":"OK","customerId":'
                   FUNCTION TRIM(WS-ID-ED)
                   ',"email":"' FUNCTION TRIM(WS-EMAIL) '"}'.

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
