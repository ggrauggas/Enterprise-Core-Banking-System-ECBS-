      ******************************************************************
      * HELLO.cbl - ECBS smoke-test program (Fase 1).
      * Proves that the GnuCOBOL toolchain and the HTTP bridge work
      * end to end. Prints a JSON document on stdout, which is the
      * output convention for every ECBS online program.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HELLO.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TIMESTAMP            PIC X(16).

       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE FUNCTION CURRENT-DATE(1:16) TO WS-TIMESTAMP
           DISPLAY '{"program":"HELLO",'
                   '"status":"OK",'
                   '"message":"ECBS COBOL runtime ready",'
                   '"timestamp":"' WS-TIMESTAMP '"}'
           STOP RUN.
