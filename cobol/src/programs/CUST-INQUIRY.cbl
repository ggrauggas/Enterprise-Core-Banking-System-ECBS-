      ******************************************************************
      * CUST-INQUIRY.cbl - Fase 4: customer inquiry (consulta).
      *
      * Bridge input (one JSON line on stdin), two modes:
      *   {"customerId":3}        -> single customer, full detail
      *   {}                      -> list (max 100, DELETED excluded)
      *   {"statusFilter":"INACTIVE"} -> list filtered by status
      *     (statusFilter "DELETED" makes deleted customers visible)
      *
      * Read-only: inquiries are not audited, only logged.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUST-INQUIRY.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-CUST-ID              PIC 9(10).
       01  WS-FILTER               PIC X(10).
       01  WS-FILTER-ALL           PIC 9.
       01  WS-ROW-ID               PIC 9(10).
       01  WS-ROW-FIRST            PIC X(50).
       01  WS-ROW-LAST             PIC X(80).
       01  WS-ROW-BDATE            PIC X(10).
       01  WS-ROW-EMAIL            PIC X(120).
       01  WS-ROW-PHONE            PIC X(20).
       01  WS-ROW-STATUS           PIC X(10).
       01  WS-ROW-CREATED          PIC X(19).
       01  WS-ROW-UPDATED          PIC X(19).
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
           IF WS-OK = 'Y'
               IF WS-SINGLE = 'Y'
                   PERFORM GET-ONE
               ELSE
                   PERFORM LIST-CUSTOMERS
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
           MOVE 'customerId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 'Y' TO WS-SINGLE
               COMPUTE WS-CUST-ID = FUNCTION NUMVAL(JU-VALUE)
           END-IF
           MOVE 'statusFilter' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-FILTER-ALL
               MOVE FUNCTION UPPER-CASE(JU-VALUE) TO WS-FILTER
           ELSE
               MOVE 1 TO WS-FILTER-ALL
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
      *        SUBSTR(CAST(...)) instead of TO_CHAR: ocesql would
      *        read ':MI'/':SS' in the format mask as host variables
               SELECT customer_id, first_name, last_name,
                      TO_CHAR(birth_date, 'YYYY-MM-DD'),
                      email, phone, status,
                      SUBSTR(CAST(created_at AS VARCHAR), 1, 19),
                      SUBSTR(CAST(updated_at AS VARCHAR), 1, 19)
                 INTO :WS-ROW-ID, :WS-ROW-FIRST, :WS-ROW-LAST,
                      :WS-ROW-BDATE, :WS-ROW-EMAIL, :WS-ROW-PHONE,
                      :WS-ROW-STATUS, :WS-ROW-CREATED,
                      :WS-ROW-UPDATED
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
               WHEN OTHER
                   PERFORM PRINT-ONE
           END-EVALUATE.

       PRINT-ONE.
           MOVE WS-ROW-ID TO WS-ID-ED
           DISPLAY '{"status":"OK","customer":{'
                   '"customerId":' FUNCTION TRIM(WS-ID-ED)
                   ',"firstName":"' FUNCTION TRIM(WS-ROW-FIRST)
                   '","lastName":"' FUNCTION TRIM(WS-ROW-LAST)
                   '","birthDate":"' WS-ROW-BDATE
                   '","email":"' FUNCTION TRIM(WS-ROW-EMAIL)
                   '","phone":"' FUNCTION TRIM(WS-ROW-PHONE)
                   '","status":"' FUNCTION TRIM(WS-ROW-STATUS)
                   '","createdAt":"' WS-ROW-CREATED
                   '","updatedAt":"' WS-ROW-UPDATED
                   '"}}'
           PERFORM LOG-INQUIRY.

       LIST-CUSTOMERS.
           EXEC SQL
               DECLARE CUSTCUR CURSOR FOR
               SELECT customer_id, first_name, last_name,
                      TO_CHAR(birth_date, 'YYYY-MM-DD'),
                      email, phone, status
                 FROM customers
                WHERE (:WS-FILTER-ALL = 1 AND status <> 'DELETED')
                   OR (:WS-FILTER-ALL = 0
                       AND status = TRIM(TRAILING FROM :WS-FILTER))
                ORDER BY customer_id
                LIMIT 100
           END-EXEC
           EXEC SQL
               OPEN CUSTCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY '{"status":"OK","customers":['
           MOVE 'Y' TO WS-FIRST-ROW
           MOVE 0 TO WS-COUNT
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH CUSTCUR
                    INTO :WS-ROW-ID, :WS-ROW-FIRST, :WS-ROW-LAST,
                         :WS-ROW-BDATE, :WS-ROW-EMAIL,
                         :WS-ROW-PHONE, :WS-ROW-STATUS
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
               CLOSE CUSTCUR
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
           DISPLAY '{"customerId":' FUNCTION TRIM(WS-ID-ED)
                   ',"firstName":"' FUNCTION TRIM(WS-ROW-FIRST)
                   '","lastName":"' FUNCTION TRIM(WS-ROW-LAST)
                   '","birthDate":"' WS-ROW-BDATE
                   '","email":"' FUNCTION TRIM(WS-ROW-EMAIL)
                   '","phone":"' FUNCTION TRIM(WS-ROW-PHONE)
                   '","status":"' FUNCTION TRIM(WS-ROW-STATUS)
                   '"}'.

       LOG-INQUIRY.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'CUST-INQUIRY' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           IF WS-SINGLE = 'Y'
               MOVE WS-CUST-ID TO WS-ID-ED
               STRING 'customer inquiry id='
                      FUNCTION TRIM(WS-ID-ED)
                   DELIMITED BY SIZE INTO LOG-MSG
               END-STRING
           ELSE
               MOVE WS-COUNT TO WS-COUNT-ED
               STRING 'customer list returned rows='
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

       PRINT-ERROR.
           MOVE WS-ERR-CODE TO EH-ERROR-CODE
           MOVE WS-ERR-CTX TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS
           DISPLAY '{"status":"ERROR","errorCode":"'
                   FUNCTION TRIM(WS-ERR-CODE)
                   '","message":"' FUNCTION TRIM(EH-MESSAGE) '"}'.
