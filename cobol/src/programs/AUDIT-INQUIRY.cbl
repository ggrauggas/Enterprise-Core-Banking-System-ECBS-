      ******************************************************************
      * AUDIT-INQUIRY.cbl - Fase 10: audit trail viewer engine.
      *
      * Bridge input (one JSON line on stdin) - every filter is
      * optional and they can be combined freely:
      *   {"entityType":"CUSTOMER","entityId":6,
      *    "username":"teller1","operation":"TRANSFER",
      *    "dateFrom":"2026-06-01","dateTo":"2026-06-12",
      *    "limit":50}
      *
      * Returns the matching audit entries newest first (default
      * limit 100, max 200) with the old/new values as raw JSON.
      * Read-only: the viewer itself is not audited, only logged.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. AUDIT-INQUIRY.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-F-ENT                PIC 9.
       01  WS-ENT                  PIC X(30).
       01  WS-F-EID                PIC 9.
       01  WS-EID                  PIC 9(10).
       01  WS-F-USR                PIC 9.
       01  WS-USR                  PIC X(50).
       01  WS-F-OP                 PIC 9.
       01  WS-OP                   PIC X(30).
       01  WS-F-FROM               PIC 9.
       01  WS-FROM                 PIC X(10).
       01  WS-F-TO                 PIC 9.
       01  WS-TO                   PIC X(10).
       01  WS-LIMIT                PIC 9(4).
       01  WS-ROW-ID               PIC 9(10).
       01  WS-ROW-USER             PIC X(50).
       01  WS-ROW-TS               PIC X(19).
       01  WS-ROW-OP               PIC X(30).
       01  WS-ROW-ENT              PIC X(30).
       01  WS-ROW-EID              PIC 9(10).
       01  WS-ROW-OLD              PIC X(600).
       01  WS-ROW-NEW              PIC X(600).
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
       01  WS-COUNT                PIC 9(4).
       01  WS-COUNT-ED             PIC ZZZ9.
       01  WS-ERR-CODE             PIC X(5).
       01  WS-ERR-CTX              PIC X(80).
       01  WS-SQLCODE-ED           PIC -9(9).
       01  WS-ID-ED                PIC Z(9)9.
       01  WS-EID-ED               PIC Z(9)9.

      * framework module parameter blocks
       01  JU-PARAMS.
           05 JU-BUFFER            PIC X(2000).
           05 JU-KEY               PIC X(32).
           05 JU-VALUE             PIC X(256).
           05 JU-FOUND             PIC X.
           05 JU-RC                PIC X(2).
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
           IF WS-OK = 'Y' PERFORM DB-CONNECT END-IF
           IF WS-OK = 'Y' PERFORM LIST-AUDIT END-IF
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
           MOVE 'entityType' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-F-ENT
               MOVE FUNCTION UPPER-CASE(JU-VALUE) TO WS-ENT
           ELSE
               MOVE 1 TO WS-F-ENT
               MOVE SPACES TO WS-ENT
           END-IF
           MOVE 'entityId' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-F-EID
               COMPUTE WS-EID = FUNCTION NUMVAL(JU-VALUE)
           ELSE
               MOVE 1 TO WS-F-EID
               MOVE 0 TO WS-EID
           END-IF
           MOVE 'username' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-F-USR
               MOVE JU-VALUE TO WS-USR
           ELSE
               MOVE 1 TO WS-F-USR
               MOVE SPACES TO WS-USR
           END-IF
           MOVE 'operation' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-F-OP
               MOVE FUNCTION UPPER-CASE(JU-VALUE) TO WS-OP
           ELSE
               MOVE 1 TO WS-F-OP
               MOVE SPACES TO WS-OP
           END-IF
           MOVE 'dateFrom' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-F-FROM
               MOVE JU-VALUE TO WS-FROM
               PERFORM VALIDATE-FILTER-DATE
           ELSE
               MOVE 1 TO WS-F-FROM
               MOVE '2000-01-01' TO WS-FROM
           END-IF
           IF WS-OK NOT = 'Y'
               EXIT PARAGRAPH
           END-IF
           MOVE 'dateTo' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               MOVE 0 TO WS-F-TO
               MOVE JU-VALUE TO WS-TO
               PERFORM VALIDATE-FILTER-DATE-TO
           ELSE
               MOVE 1 TO WS-F-TO
               MOVE '2099-12-31' TO WS-TO
           END-IF
           IF WS-OK NOT = 'Y'
               EXIT PARAGRAPH
           END-IF
           MOVE 'limit' TO JU-KEY
           PERFORM GET-JSON
           IF JU-FOUND = 'Y' AND JU-VALUE NOT = SPACES
               COMPUTE WS-LIMIT = FUNCTION NUMVAL(JU-VALUE)
           ELSE
               MOVE 100 TO WS-LIMIT
           END-IF
           IF WS-LIMIT = 0 OR WS-LIMIT > 200
               MOVE 200 TO WS-LIMIT
           END-IF.

       VALIDATE-FILTER-DATE.
           MOVE 'VALIDATE' TO DU-OPERATION
           MOVE WS-FROM TO DU-DATE-1
           CALL 'DATE_UTILS' USING DU-PARAMS
           IF DU-STATUS NOT = '00'
               MOVE 'E012' TO WS-ERR-CODE
               MOVE 'dateFrom' TO WS-ERR-CTX
               MOVE 'N' TO WS-OK
           END-IF.

       VALIDATE-FILTER-DATE-TO.
           MOVE 'VALIDATE' TO DU-OPERATION
           MOVE WS-TO TO DU-DATE-1
           CALL 'DATE_UTILS' USING DU-PARAMS
           IF DU-STATUS NOT = '00'
               MOVE 'E012' TO WS-ERR-CODE
               MOVE 'dateTo' TO WS-ERR-CTX
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

       LIST-AUDIT.
           EXEC SQL
               DECLARE AUDCUR CURSOR FOR
               SELECT audit_id, username,
                      SUBSTR(CAST(event_time AS VARCHAR), 1, 19),
                      operation, entity_type,
                      COALESCE(entity_id, 0),
                      COALESCE(CAST(old_value AS VARCHAR),
                               'null'),
                      COALESCE(CAST(new_value AS VARCHAR),
                               'null')
                 FROM audit_logs
                WHERE (:WS-F-ENT = 1
                       OR entity_type =
                          TRIM(TRAILING FROM :WS-ENT))
                  AND (:WS-F-EID = 1 OR entity_id = :WS-EID)
                  AND (:WS-F-USR = 1
                       OR username =
                          TRIM(TRAILING FROM :WS-USR))
                  AND (:WS-F-OP = 1
                       OR operation =
                          TRIM(TRAILING FROM :WS-OP))
                  AND (:WS-F-FROM = 1
                       OR event_time >= CAST(:WS-FROM AS DATE))
                  AND (:WS-F-TO = 1
                       OR event_time <
                          CAST(:WS-TO AS DATE) + 1)
                ORDER BY audit_id DESC
                LIMIT :WS-LIMIT
           END-EXEC
           EXEC SQL
               OPEN AUDCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY '{"status":"OK","entries":['
           MOVE 'Y' TO WS-FIRST-ROW
           MOVE 0 TO WS-COUNT
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH AUDCUR
                    INTO :WS-ROW-ID, :WS-ROW-USER, :WS-ROW-TS,
                         :WS-ROW-OP, :WS-ROW-ENT, :WS-ROW-EID,
                         :WS-ROW-OLD, :WS-ROW-NEW
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
               CLOSE AUDCUR
           END-EXEC
           IF WS-OK = 'Y'
               MOVE WS-COUNT TO WS-COUNT-ED
               DISPLAY '],"count":' FUNCTION TRIM(WS-COUNT-ED) '}'
               PERFORM LOG-INQUIRY
           END-IF.

      * oldValue/newValue are emitted as raw JSON (object or null)
       PRINT-ROW.
           IF WS-FIRST-ROW = 'Y'
               MOVE 'N' TO WS-FIRST-ROW
           ELSE
               DISPLAY ','
           END-IF
           MOVE WS-ROW-ID TO WS-ID-ED
           MOVE WS-ROW-EID TO WS-EID-ED
           DISPLAY '{"auditId":' FUNCTION TRIM(WS-ID-ED)
                   ',"username":"' FUNCTION TRIM(WS-ROW-USER)
                   '","eventTime":"' WS-ROW-TS
                   '","operation":"' FUNCTION TRIM(WS-ROW-OP)
                   '","entityType":"' FUNCTION TRIM(WS-ROW-ENT)
                   '","entityId":' FUNCTION TRIM(WS-EID-ED)
                   ',"oldValue":' FUNCTION TRIM(WS-ROW-OLD)
                   ',"newValue":' FUNCTION TRIM(WS-ROW-NEW)
                   '}'.

       LOG-INQUIRY.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'AUDIT-INQ' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-COUNT TO WS-COUNT-ED
           STRING 'audit inquiry rows='
                  FUNCTION TRIM(WS-COUNT-ED)
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
