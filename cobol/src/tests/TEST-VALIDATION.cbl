      ******************************************************************
      * TEST-VALIDATION.cbl - unit tests for the VALIDATION module
      * (EMAIL, PHONE, NOT-BLANK). RETURN-CODE = number of failures.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "TEST-VALIDATION".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FAILURES             PIC 9(3) VALUE 0.

       01  VAL-PARAMS.
           05 VAL-OPERATION        PIC X(15).
           05 VAL-INPUT            PIC X(120).
           05 VAL-RC               PIC X(2).
           05 VAL-MESSAGE          PIC X(80).

       PROCEDURE DIVISION.
       MAIN-PARA.
           DISPLAY "== TEST-VALIDATION =="

      *    Valid email
           MOVE "EMAIL"            TO VAL-OPERATION
           MOVE "ada@ecbs.com"     TO VAL-INPUT
           CALL "VALIDATION" USING VAL-PARAMS
           PERFORM EXPECT-OK

      *    Email missing @
           MOVE "EMAIL"            TO VAL-OPERATION
           MOVE "ada-ecbs.com"     TO VAL-INPUT
           CALL "VALIDATION" USING VAL-PARAMS
           PERFORM EXPECT-VE

      *    Email with space
           MOVE "EMAIL"            TO VAL-OPERATION
           MOVE "ad a@ecbs.com"    TO VAL-INPUT
           CALL "VALIDATION" USING VAL-PARAMS
           PERFORM EXPECT-VE

      *    Valid phone
           MOVE "PHONE"            TO VAL-OPERATION
           MOVE "+34600111222"     TO VAL-INPUT
           CALL "VALIDATION" USING VAL-PARAMS
           PERFORM EXPECT-OK

      *    Phone with letters
           MOVE "PHONE"            TO VAL-OPERATION
           MOVE "600ABC222"        TO VAL-INPUT
           CALL "VALIDATION" USING VAL-PARAMS
           PERFORM EXPECT-VE

      *    Phone too short
           MOVE "PHONE"            TO VAL-OPERATION
           MOVE "12345"            TO VAL-INPUT
           CALL "VALIDATION" USING VAL-PARAMS
           PERFORM EXPECT-VE

      *    NOT-BLANK passes for text
           MOVE "NOT-BLANK"        TO VAL-OPERATION
           MOVE "something"        TO VAL-INPUT
           CALL "VALIDATION" USING VAL-PARAMS
           PERFORM EXPECT-OK

      *    NOT-BLANK fails for spaces
           MOVE "NOT-BLANK"        TO VAL-OPERATION
           MOVE SPACES             TO VAL-INPUT
           CALL "VALIDATION" USING VAL-PARAMS
           PERFORM EXPECT-VE

           DISPLAY "FAILURES: " WS-FAILURES
           MOVE WS-FAILURES TO RETURN-CODE
           GOBACK.

       EXPECT-OK.
           IF VAL-RC = "00"
               DISPLAY "PASS " FUNCTION TRIM(VAL-OPERATION)
                       " '" FUNCTION TRIM(VAL-INPUT) "'"
           ELSE
               DISPLAY "FAIL " FUNCTION TRIM(VAL-OPERATION)
                       " '" FUNCTION TRIM(VAL-INPUT)
                       "' expected 00 got " VAL-RC
               ADD 1 TO WS-FAILURES
           END-IF.

       EXPECT-VE.
           IF VAL-RC = "VE"
               DISPLAY "PASS " FUNCTION TRIM(VAL-OPERATION)
                       " rejects '" FUNCTION TRIM(VAL-INPUT) "'"
           ELSE
               DISPLAY "FAIL " FUNCTION TRIM(VAL-OPERATION)
                       " expected VE got " VAL-RC
               ADD 1 TO WS-FAILURES
           END-IF.
