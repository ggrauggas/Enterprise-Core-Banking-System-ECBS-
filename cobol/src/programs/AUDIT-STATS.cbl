      ******************************************************************
      * AUDIT-STATS.cbl - Fase 10: audit trail statistics.
      *
      * Bridge input: {} (no parameters)
      *
      * Returns aggregated figures of the audit trail: total
      * entries, distinct users, first/last event time, and the
      * breakdown by entity type and by operation (GROUP BY
      * cursors). Feeds the audit dashboard of the frontend.
      * Read-only: not audited, only logged.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. AUDIT-STATS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      * SQL host variables (declared inline so ocesql can see them)
       01  WS-TOTAL                PIC 9(9).
       01  WS-USERS                PIC 9(9).
       01  WS-FIRST-TS             PIC X(19).
       01  WS-LAST-TS              PIC X(19).
       01  WS-GRP-NAME             PIC X(30).
       01  WS-GRP-COUNT            PIC 9(9).
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
       01  WS-N-ED                 PIC ZZZZZZZZ9.

      * framework module parameter blocks
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
           PERFORM DB-CONNECT
           IF WS-OK = 'Y' PERFORM PRINT-STATS END-IF
           PERFORM FINISH-TRANSACTION
           IF WS-OK NOT = 'Y'
               PERFORM PRINT-ERROR
           END-IF
           STOP RUN.

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

       PRINT-STATS.
           EXEC SQL
               SELECT COUNT(*), COUNT(DISTINCT username),
                      COALESCE(SUBSTR(CAST(MIN(event_time)
                          AS VARCHAR), 1, 19), ''),
                      COALESCE(SUBSTR(CAST(MAX(event_time)
                          AS VARCHAR), 1, 19), '')
                 INTO :WS-TOTAL, :WS-USERS,
                      :WS-FIRST-TS, :WS-LAST-TS
                 FROM audit_logs
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           MOVE WS-TOTAL TO WS-N-ED
           DISPLAY '{"status":"OK","totalEntries":'
                   FUNCTION TRIM(WS-N-ED)
           MOVE WS-USERS TO WS-N-ED
           DISPLAY ',"distinctUsers":' FUNCTION TRIM(WS-N-ED)
                   ',"firstEvent":"' WS-FIRST-TS
                   '","lastEvent":"' WS-LAST-TS '"'
           PERFORM PRINT-BY-ENTITY
           IF WS-OK = 'Y'
               PERFORM PRINT-BY-OPERATION
           END-IF
           IF WS-OK = 'Y'
               DISPLAY '}'
               PERFORM LOG-STATS
           END-IF.

       PRINT-BY-ENTITY.
           EXEC SQL
               DECLARE ENTCUR CURSOR FOR
               SELECT entity_type, COUNT(*)
                 FROM audit_logs
                GROUP BY entity_type
                ORDER BY COUNT(*) DESC, entity_type
           END-EXEC
           EXEC SQL
               OPEN ENTCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY ',"byEntity":['
           MOVE 'Y' TO WS-FIRST-ROW
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH ENTCUR
                    INTO :WS-GRP-NAME, :WS-GRP-COUNT
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               PERFORM PRINT-GROUP-ROW
           END-PERFORM
           EXEC SQL
               CLOSE ENTCUR
           END-EXEC
           IF WS-OK = 'Y'
               DISPLAY ']'
           END-IF.

       PRINT-BY-OPERATION.
           EXEC SQL
               DECLARE OPCUR CURSOR FOR
               SELECT operation, COUNT(*)
                 FROM audit_logs
                GROUP BY operation
                ORDER BY COUNT(*) DESC, operation
                LIMIT 25
           END-EXEC
           EXEC SQL
               OPEN OPCUR
           END-EXEC
           IF SQLCODE NOT = 0
               PERFORM SQL-ERROR-PARA
               EXIT PARAGRAPH
           END-IF
           DISPLAY ',"byOperation":['
           MOVE 'Y' TO WS-FIRST-ROW
           PERFORM UNTIL WS-OK NOT = 'Y'
               EXEC SQL
                   FETCH OPCUR
                    INTO :WS-GRP-NAME, :WS-GRP-COUNT
               END-EXEC
               IF SQLCODE = 100
                   EXIT PERFORM
               END-IF
               IF SQLCODE NOT = 0
                   PERFORM SQL-ERROR-PARA
                   EXIT PERFORM
               END-IF
               PERFORM PRINT-GROUP-ROW
           END-PERFORM
           EXEC SQL
               CLOSE OPCUR
           END-EXEC
           IF WS-OK = 'Y'
               DISPLAY ']'
           END-IF.

       PRINT-GROUP-ROW.
           IF WS-FIRST-ROW = 'Y'
               MOVE 'N' TO WS-FIRST-ROW
           ELSE
               DISPLAY ','
           END-IF
           MOVE WS-GRP-COUNT TO WS-N-ED
           DISPLAY '{"name":"' FUNCTION TRIM(WS-GRP-NAME)
                   '","count":' FUNCTION TRIM(WS-N-ED) '}'.

       LOG-STATS.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'AUDIT-STATS' TO LOG-COMPONENT
           MOVE SPACES TO LOG-MSG
           MOVE WS-TOTAL TO WS-N-ED
           STRING 'audit stats total='
                  FUNCTION TRIM(WS-N-ED)
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
