      ******************************************************************
      * LOGGER.cbl - central logging module.
      * Appends a timestamped line to the ECBS log file (path taken
      * from ECBS_LOG_FILE, default /opt/ecbs/logs/ecbs.log) and echoes
      * it on stderr. stdout is never touched: it is reserved for the
      * JSON responses of the online programs.
      *
      * CALL 'LOGGER' USING LOG-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOGGER.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL LOG-FILE ASSIGN TO WS-LOG-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  LOG-FILE.
       01  LOG-FILE-LINE           PIC X(260).

       WORKING-STORAGE SECTION.
       01  WS-LOG-PATH             PIC X(120).
       01  WS-FILE-STATUS          PIC XX.
       01  WS-NOW                  PIC X(21).
       01  WS-TS                   PIC X(19).
       01  WS-LINE                 PIC X(260).

       LINKAGE SECTION.
       01  LOG-PARAMS.
           05 LOG-LEVEL            PIC X(5).
           05 LOG-COMPONENT        PIC X(12).
           05 LOG-MSG              PIC X(200).

       PROCEDURE DIVISION USING LOG-PARAMS.
       MAIN-PARA.
           PERFORM BUILD-TIMESTAMP
           PERFORM BUILD-LINE
           PERFORM WRITE-LINE
           DISPLAY FUNCTION TRIM(WS-LINE) UPON SYSERR
           GOBACK.

       BUILD-TIMESTAMP.
           MOVE FUNCTION CURRENT-DATE TO WS-NOW
           MOVE SPACES TO WS-TS
           STRING WS-NOW(1:4) '-' WS-NOW(5:2) '-' WS-NOW(7:2)
                  ' ' WS-NOW(9:2) ':' WS-NOW(11:2) ':' WS-NOW(13:2)
               DELIMITED BY SIZE INTO WS-TS
           END-STRING.

       BUILD-LINE.
           MOVE SPACES TO WS-LINE
           STRING '[' WS-TS '] ['
                  FUNCTION TRIM(LOG-LEVEL) '] ['
                  FUNCTION TRIM(LOG-COMPONENT) '] '
                  FUNCTION TRIM(LOG-MSG)
               DELIMITED BY SIZE INTO WS-LINE
           END-STRING.

       WRITE-LINE.
           ACCEPT WS-LOG-PATH FROM ENVIRONMENT 'ECBS_LOG_FILE'
               ON EXCEPTION
                   MOVE '/opt/ecbs/logs/ecbs.log' TO WS-LOG-PATH
           END-ACCEPT
           IF WS-LOG-PATH = SPACES
               MOVE '/opt/ecbs/logs/ecbs.log' TO WS-LOG-PATH
           END-IF
           OPEN EXTEND LOG-FILE
      *    '05' = optional file did not exist and was created: success.
           IF WS-FILE-STATUS = '00' OR WS-FILE-STATUS = '05'
               MOVE WS-LINE TO LOG-FILE-LINE
               WRITE LOG-FILE-LINE
               CLOSE LOG-FILE
           ELSE
               DISPLAY 'LOGGER: cannot open log file, status '
                       WS-FILE-STATUS UPON SYSERR
           END-IF.
