      ******************************************************************
      * TEST-IBAN.cbl - unit tests for the IBAN_UTILS module (mod 97-10
      * build + validate, round trip). RETURN-CODE = number of failures.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "TEST-IBAN".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FAILURES             PIC 9(3) VALUE 0.

       01  IB-PARAMS.
           05 IB-OPERATION         PIC X(10).
           05 IB-COUNTRY           PIC X(2).
           05 IB-BBAN              PIC X(30).
           05 IB-BBAN-LEN          PIC 9(2).
           05 IB-IBAN              PIC X(34).
           05 IB-RC                PIC X(2).

       PROCEDURE DIVISION.
       MAIN-PARA.
           DISPLAY "== TEST-IBAN =="

      *    BUILD a Spanish IBAN from a 20-digit BBAN
           MOVE "BUILD"            TO IB-OPERATION
           MOVE "ES"               TO IB-COUNTRY
           MOVE "00750000000000000000" TO IB-BBAN
           MOVE 20                 TO IB-BBAN-LEN
           MOVE SPACES             TO IB-IBAN
           CALL "IBAN_UTILS" USING IB-PARAMS
           IF IB-RC = "00"
               DISPLAY "PASS BUILD -> " FUNCTION TRIM(IB-IBAN)
           ELSE
               DISPLAY "FAIL BUILD rc=" IB-RC
               ADD 1 TO WS-FAILURES
           END-IF

      *    VALIDATE the IBAN just built (round trip must succeed)
           MOVE "VALIDATE"         TO IB-OPERATION
           CALL "IBAN_UTILS" USING IB-PARAMS
           IF IB-RC = "00"
               DISPLAY "PASS VALIDATE round trip"
           ELSE
               DISPLAY "FAIL VALIDATE round trip rc=" IB-RC
               ADD 1 TO WS-FAILURES
           END-IF

      *    VALIDATE a tampered IBAN must fail
           MOVE "VALIDATE"         TO IB-OPERATION
           MOVE "ES9921000418450200051333" TO IB-IBAN
           CALL "IBAN_UTILS" USING IB-PARAMS
           IF IB-RC = "VE"
               DISPLAY "PASS VALIDATE rejects bad check digits"
           ELSE
               DISPLAY "FAIL VALIDATE should reject bad IBAN rc=" IB-RC
               ADD 1 TO WS-FAILURES
           END-IF

      *    Unknown operation -> VE
           MOVE "NOPE"             TO IB-OPERATION
           CALL "IBAN_UTILS" USING IB-PARAMS
           IF IB-RC = "VE"
               DISPLAY "PASS unknown op -> VE"
           ELSE
               DISPLAY "FAIL unknown op -> VE rc=" IB-RC
               ADD 1 TO WS-FAILURES
           END-IF

           DISPLAY "FAILURES: " WS-FAILURES
           MOVE WS-FAILURES TO RETURN-CODE
           GOBACK.
