      ******************************************************************
      * TEST-DATEUTILS.cbl - unit tests for the DATE_UTILS module
      * (VALIDATE, ADD-MONTHS day clamping, DAYS-BETWEEN). Current-date
      * dependent operations are exercised by the higher-level suites.
      * RETURN-CODE = number of failures.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "TEST-DATEUTILS".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FAILURES             PIC 9(3) VALUE 0.

       01  DU-PARAMS.
           05 DU-OPERATION         PIC X(12).
           05 DU-DATE-1            PIC X(10).
           05 DU-DATE-2            PIC X(10).
           05 DU-NUMBER            PIC S9(5).
           05 DU-RESULT-DATE       PIC X(10).
           05 DU-RESULT-NUM        PIC S9(9).
           05 DU-RESULT-TS         PIC X(19).
           05 DU-STATUS            PIC X(2).

       PROCEDURE DIVISION.
       MAIN-PARA.
           DISPLAY "== TEST-DATEUTILS =="

      *    VALIDATE a real leap day
           MOVE "VALIDATE"   TO DU-OPERATION
           MOVE "2024-02-29" TO DU-DATE-1
           CALL "DATE_UTILS" USING DU-PARAMS
           PERFORM EXPECT-OK

      *    VALIDATE a non-leap 29 Feb -> invalid
           MOVE "VALIDATE"   TO DU-OPERATION
           MOVE "2026-02-29" TO DU-DATE-1
           CALL "DATE_UTILS" USING DU-PARAMS
           PERFORM EXPECT-VE

      *    VALIDATE a malformed month -> invalid
           MOVE "VALIDATE"   TO DU-OPERATION
           MOVE "2026-13-01" TO DU-DATE-1
           CALL "DATE_UTILS" USING DU-PARAMS
           PERFORM EXPECT-VE

      *    ADD-MONTHS clamps 31 Jan + 1 month to 28 Feb (2026)
           MOVE "ADD-MONTHS" TO DU-OPERATION
           MOVE "2026-01-31" TO DU-DATE-1
           MOVE 1            TO DU-NUMBER
           CALL "DATE_UTILS" USING DU-PARAMS
           IF DU-STATUS = "00" AND DU-RESULT-DATE = "2026-02-28"
               DISPLAY "PASS ADD-MONTHS clamps to " DU-RESULT-DATE
           ELSE
               DISPLAY "FAIL ADD-MONTHS got " DU-RESULT-DATE
                       " st=" DU-STATUS
               ADD 1 TO WS-FAILURES
           END-IF

      *    DAYS-BETWEEN 1 Jan -> 31 Jan = 30
           MOVE "DAYS-BETWEEN" TO DU-OPERATION
           MOVE "2026-01-01"   TO DU-DATE-1
           MOVE "2026-01-31"   TO DU-DATE-2
           CALL "DATE_UTILS" USING DU-PARAMS
           IF DU-STATUS = "00" AND DU-RESULT-NUM = 30
               DISPLAY "PASS DAYS-BETWEEN = " DU-RESULT-NUM
           ELSE
               DISPLAY "FAIL DAYS-BETWEEN got " DU-RESULT-NUM
                       " st=" DU-STATUS
               ADD 1 TO WS-FAILURES
           END-IF

           DISPLAY "FAILURES: " WS-FAILURES
           MOVE WS-FAILURES TO RETURN-CODE
           GOBACK.

       EXPECT-OK.
           IF DU-STATUS = "00"
               DISPLAY "PASS " FUNCTION TRIM(DU-OPERATION)
                       " '" FUNCTION TRIM(DU-DATE-1) "'"
           ELSE
               DISPLAY "FAIL " FUNCTION TRIM(DU-OPERATION)
                       " '" FUNCTION TRIM(DU-DATE-1)
                       "' expected 00 got " DU-STATUS
               ADD 1 TO WS-FAILURES
           END-IF.

       EXPECT-VE.
           IF DU-STATUS = "VE"
               DISPLAY "PASS " FUNCTION TRIM(DU-OPERATION)
                       " rejects '" FUNCTION TRIM(DU-DATE-1) "'"
           ELSE
               DISPLAY "FAIL " FUNCTION TRIM(DU-OPERATION)
                       " expected VE got " DU-STATUS
               ADD 1 TO WS-FAILURES
           END-IF.
