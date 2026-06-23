      ******************************************************************
      * TEST-MONEY.cbl - unit tests for the MONEY_UTILS module.
      * Drives every operation through CALL 'MONEY_UTILS' and checks the
      * result / status. Prints PASS/FAIL per assertion and sets the
      * RETURN-CODE to the number of failures (0 = green).
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "TEST-MONEY".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FAILURES             PIC 9(3) VALUE 0.
       01  WS-EXPECTED             PIC S9(13)V99 COMP-3.

       01  MU-PARAMS.
           05 MU-OPERATION         PIC X(12).
           05 MU-AMOUNT-1          PIC S9(13)V99 COMP-3.
           05 MU-AMOUNT-2          PIC S9(13)V99 COMP-3.
           05 MU-RATE              PIC S9(3)V9(4) COMP-3.
           05 MU-MONTHS            PIC 9(4).
           05 MU-RESULT            PIC S9(13)V99 COMP-3.
           05 MU-FORMATTED         PIC X(20).
           05 MU-STATUS            PIC X(2).

       PROCEDURE DIVISION.
       MAIN-PARA.
           DISPLAY "== TEST-MONEY =="

      *    ADD: 100.00 + 50.25 = 150.25
           MOVE "ADD"      TO MU-OPERATION
           MOVE 100.00     TO MU-AMOUNT-1
           MOVE 50.25      TO MU-AMOUNT-2
           CALL "MONEY_UTILS" USING MU-PARAMS
           MOVE 150.25     TO WS-EXPECTED
           PERFORM CHECK-RESULT
           IF MU-STATUS = "00"
               DISPLAY "PASS ADD status"
           ELSE
               DISPLAY "FAIL ADD status"
               ADD 1 TO WS-FAILURES
           END-IF

      *    SUBTRACT: 100.00 - 30.00 = 70.00
           MOVE "SUBTRACT" TO MU-OPERATION
           MOVE 100.00     TO MU-AMOUNT-1
           MOVE 30.00      TO MU-AMOUNT-2
           CALL "MONEY_UTILS" USING MU-PARAMS
           MOVE 70.00      TO WS-EXPECTED
           PERFORM CHECK-RESULT

      *    SUBTRACT going negative -> status NF
           MOVE "SUBTRACT" TO MU-OPERATION
           MOVE 30.00      TO MU-AMOUNT-1
           MOVE 100.00     TO MU-AMOUNT-2
           CALL "MONEY_UTILS" USING MU-PARAMS
           IF MU-STATUS = "NF"
               DISPLAY "PASS SUBTRACT negative -> NF"
           ELSE
               DISPLAY "FAIL SUBTRACT negative -> NF"
               ADD 1 TO WS-FAILURES
           END-IF

      *    MONTHLY-INT: 1000 at 12% annual -> 10.00 / month
           MOVE "MONTHLY-INT" TO MU-OPERATION
           MOVE 1000.00    TO MU-AMOUNT-1
           MOVE 12.0000    TO MU-RATE
           CALL "MONEY_UTILS" USING MU-PARAMS
           MOVE 10.00      TO WS-EXPECTED
           PERFORM CHECK-RESULT

      *    FRENCH-PMT with 0% rate: 1000 / 10 = 100.00
           MOVE "FRENCH-PMT" TO MU-OPERATION
           MOVE 1000.00    TO MU-AMOUNT-1
           MOVE 0.0000     TO MU-RATE
           MOVE 10         TO MU-MONTHS
           CALL "MONEY_UTILS" USING MU-PARAMS
           MOVE 100.00     TO WS-EXPECTED
           PERFORM CHECK-RESULT

      *    Unknown operation -> status VE
           MOVE "NONSENSE"  TO MU-OPERATION
           CALL "MONEY_UTILS" USING MU-PARAMS
           IF MU-STATUS = "VE"
               DISPLAY "PASS unknown op -> VE"
           ELSE
               DISPLAY "FAIL unknown op -> VE"
               ADD 1 TO WS-FAILURES
           END-IF

           DISPLAY "FAILURES: " WS-FAILURES
           MOVE WS-FAILURES TO RETURN-CODE
           GOBACK.

       CHECK-RESULT.
           IF MU-RESULT = WS-EXPECTED
               DISPLAY "PASS " FUNCTION TRIM(MU-OPERATION)
                       " = " MU-RESULT
           ELSE
               DISPLAY "FAIL " FUNCTION TRIM(MU-OPERATION)
                       " expected " WS-EXPECTED " got " MU-RESULT
               ADD 1 TO WS-FAILURES
           END-IF.
