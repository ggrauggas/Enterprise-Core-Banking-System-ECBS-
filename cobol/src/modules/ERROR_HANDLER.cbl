      ******************************************************************
      * ERROR_HANDLER.cbl - central error catalogue and formatter.
      * Resolves an ECBS error code into a standard message
      * "[CODE] TEXT - CONTEXT", logs it through LOGGER and returns
      * the formatted message to the caller.
      *
      * CALL 'ERROR_HANDLER' USING EH-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "ERROR_HANDLER".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ERR-DEFS.
           05 FILLER  PIC X(5)  VALUE 'E001'.
           05 FILLER  PIC X(40) VALUE 'INVALID EMAIL FORMAT'.
           05 FILLER  PIC X(5)  VALUE 'E002'.
           05 FILLER  PIC X(40) VALUE 'INVALID PHONE FORMAT'.
           05 FILLER  PIC X(5)  VALUE 'E003'.
           05 FILLER  PIC X(40) VALUE 'DUPLICATE RECORD'.
           05 FILLER  PIC X(5)  VALUE 'E004'.
           05 FILLER  PIC X(40) VALUE 'RECORD NOT FOUND'.
           05 FILLER  PIC X(5)  VALUE 'E005'.
           05 FILLER  PIC X(40) VALUE 'INSUFFICIENT FUNDS'.
           05 FILLER  PIC X(5)  VALUE 'E006'.
           05 FILLER  PIC X(40) VALUE 'NEGATIVE BALANCE NOT ALLOWED'.
           05 FILLER  PIC X(5)  VALUE 'E007'.
           05 FILLER  PIC X(40) VALUE 'ACCOUNT IS CLOSED'.
           05 FILLER  PIC X(5)  VALUE 'E008'.
           05 FILLER  PIC X(40) VALUE 'CARD IS BLOCKED'.
           05 FILLER  PIC X(5)  VALUE 'E009'.
           05 FILLER  PIC X(40) VALUE 'CREDIT LIMIT EXCEEDED'.
           05 FILLER  PIC X(5)  VALUE 'E010'.
           05 FILLER  PIC X(40) VALUE 'INTERNAL ERROR'.
           05 FILLER  PIC X(5)  VALUE 'E011'.
           05 FILLER  PIC X(40) VALUE 'MANDATORY FIELD MISSING'.
           05 FILLER  PIC X(5)  VALUE 'E012'.
           05 FILLER  PIC X(40) VALUE 'INVALID DATE'.
           05 FILLER  PIC X(5)  VALUE 'E013'.
           05 FILLER  PIC X(40) VALUE 'CUSTOMER MUST BE AN ADULT'.
           05 FILLER  PIC X(5)  VALUE 'E014'.
           05 FILLER  PIC X(40) VALUE 'INVALID STATUS TRANSITION'.
       01  WS-ERR-TABLE REDEFINES WS-ERR-DEFS.
           05 WS-ERR-ENTRY OCCURS 14 TIMES.
              10 WS-ERR-CODE       PIC X(5).
              10 WS-ERR-TEXT       PIC X(40).
       01  WS-IDX                  PIC 9(2).
       01  WS-FOUND-TEXT           PIC X(40).
       01  WS-LOG-PARAMS.
           05 WS-LOG-LEVEL         PIC X(5).
           05 WS-LOG-COMPONENT     PIC X(12).
           05 WS-LOG-MSG           PIC X(200).

       LINKAGE SECTION.
       01  EH-PARAMS.
           05 EH-ERROR-CODE        PIC X(5).
           05 EH-CONTEXT           PIC X(80).
           05 EH-SEVERITY          PIC X.
           05 EH-MESSAGE           PIC X(120).

       PROCEDURE DIVISION USING EH-PARAMS.
       MAIN-PARA.
           MOVE 'UNKNOWN ERROR CODE' TO WS-FOUND-TEXT
           PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > 14
               IF FUNCTION TRIM(WS-ERR-CODE(WS-IDX))
                       = FUNCTION TRIM(EH-ERROR-CODE)
                   MOVE WS-ERR-TEXT(WS-IDX) TO WS-FOUND-TEXT
                   MOVE 15 TO WS-IDX
               END-IF
           END-PERFORM

           MOVE SPACES TO EH-MESSAGE
           STRING '[' FUNCTION TRIM(EH-ERROR-CODE) '] '
                  FUNCTION TRIM(WS-FOUND-TEXT)
                  ' - ' FUNCTION TRIM(EH-CONTEXT)
               DELIMITED BY SIZE INTO EH-MESSAGE
           END-STRING

           EVALUATE EH-SEVERITY
               WHEN 'W'    MOVE 'WARN'  TO WS-LOG-LEVEL
               WHEN 'I'    MOVE 'INFO'  TO WS-LOG-LEVEL
               WHEN OTHER  MOVE 'ERROR' TO WS-LOG-LEVEL
           END-EVALUATE
           MOVE 'ERR-HANDLER' TO WS-LOG-COMPONENT
           MOVE EH-MESSAGE TO WS-LOG-MSG
           CALL 'LOGGER' USING WS-LOG-PARAMS
           GOBACK.
