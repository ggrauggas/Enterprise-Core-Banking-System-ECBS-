      ******************************************************************
      * DATE_UTILS.cbl - date helper module. Dates travel as
      * ISO strings 'YYYY-MM-DD'.
      * Operations:
      *   CURRENT-TS   -> DU-RESULT-TS 'YYYY-MM-DD HH:MM:SS'
      *   VALIDATE     -> DU-DATE-1 valid calendar date?
      *   CALC-AGE     -> age in years of DU-DATE-1 (birth date)
      *   ADD-MONTHS   -> DU-DATE-1 + DU-NUMBER months (day clamped)
      *   DAYS-BETWEEN -> DU-DATE-2 minus DU-DATE-1 in days
      * DU-STATUS: '00' ok, 'VE' invalid input.
      *
      * CALL 'DATE_UTILS' USING DU-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "DATE_UTILS".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-NOW                  PIC X(21).
       01  WS-TODAY-NUM            PIC 9(8).
       01  WS-DATE-NUM             PIC 9(8).
       01  WS-INT-1                PIC S9(9).
       01  WS-INT-2                PIC S9(9).
       01  WS-Y                    PIC 9(4).
       01  WS-M                    PIC 9(2).
       01  WS-D                    PIC 9(2).
       01  WS-TOT-MONTHS           PIC S9(9).
       01  WS-D2                   PIC 9(2).
       01  WS-Y-ED                 PIC 9(4).
       01  WS-M-ED                 PIC 9(2).
       01  WS-D-ED                 PIC 9(2).
       01  WS-BIRTH-MMDD           PIC 9(4).
       01  WS-TODAY-MMDD           PIC 9(4).

       LINKAGE SECTION.
       01  DU-PARAMS.
           05 DU-OPERATION         PIC X(12).
           05 DU-DATE-1            PIC X(10).
           05 DU-DATE-2            PIC X(10).
           05 DU-NUMBER            PIC S9(5).
           05 DU-RESULT-DATE       PIC X(10).
           05 DU-RESULT-NUM        PIC S9(9).
           05 DU-RESULT-TS         PIC X(19).
           05 DU-STATUS            PIC X(2).

       PROCEDURE DIVISION USING DU-PARAMS.
       MAIN-PARA.
           MOVE '00' TO DU-STATUS
           EVALUATE FUNCTION TRIM(DU-OPERATION)
               WHEN 'CURRENT-TS'   PERFORM CURRENT-TS-PARA
               WHEN 'VALIDATE'     PERFORM VALIDATE-PARA
               WHEN 'CALC-AGE'     PERFORM CALC-AGE-PARA
               WHEN 'ADD-MONTHS'   PERFORM ADD-MONTHS-PARA
               WHEN 'DAYS-BETWEEN' PERFORM DAYS-BETWEEN-PARA
               WHEN OTHER          MOVE 'VE' TO DU-STATUS
           END-EVALUATE
           GOBACK.

       CURRENT-TS-PARA.
           MOVE FUNCTION CURRENT-DATE TO WS-NOW
           MOVE SPACES TO DU-RESULT-TS
           STRING WS-NOW(1:4) '-' WS-NOW(5:2) '-' WS-NOW(7:2)
                  ' ' WS-NOW(9:2) ':' WS-NOW(11:2) ':' WS-NOW(13:2)
               DELIMITED BY SIZE INTO DU-RESULT-TS
           END-STRING.

      * Parses DU-DATE-1 into WS-Y/M/D and WS-DATE-NUM.
      * Sets DU-STATUS = 'VE' when malformed or not a calendar date.
       PARSE-DATE-1.
           IF DU-DATE-1(5:1) NOT = '-' OR DU-DATE-1(8:1) NOT = '-'
                   OR DU-DATE-1(1:4) IS NOT NUMERIC
                   OR DU-DATE-1(6:2) IS NOT NUMERIC
                   OR DU-DATE-1(9:2) IS NOT NUMERIC
               MOVE 'VE' TO DU-STATUS
               EXIT PARAGRAPH
           END-IF
           MOVE DU-DATE-1(1:4) TO WS-Y
           MOVE DU-DATE-1(6:2) TO WS-M
           MOVE DU-DATE-1(9:2) TO WS-D
           COMPUTE WS-DATE-NUM = WS-Y * 10000 + WS-M * 100 + WS-D
           IF FUNCTION INTEGER-OF-DATE(WS-DATE-NUM) = 0
               MOVE 'VE' TO DU-STATUS
           END-IF.

       VALIDATE-PARA.
           PERFORM PARSE-DATE-1.

       CALC-AGE-PARA.
           PERFORM PARSE-DATE-1
           IF DU-STATUS = 'VE'
               EXIT PARAGRAPH
           END-IF
           MOVE FUNCTION CURRENT-DATE TO WS-NOW
           MOVE WS-NOW(1:8) TO WS-TODAY-NUM
           COMPUTE DU-RESULT-NUM =
               FUNCTION INTEGER(WS-TODAY-NUM / 10000) - WS-Y
           COMPUTE WS-BIRTH-MMDD = WS-M * 100 + WS-D
           COMPUTE WS-TODAY-MMDD =
               FUNCTION MOD(WS-TODAY-NUM, 10000)
           IF WS-TODAY-MMDD < WS-BIRTH-MMDD
               SUBTRACT 1 FROM DU-RESULT-NUM
           END-IF.

       ADD-MONTHS-PARA.
           PERFORM PARSE-DATE-1
           IF DU-STATUS = 'VE'
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-TOT-MONTHS = WS-Y * 12 + WS-M - 1 + DU-NUMBER
           COMPUTE WS-Y = FUNCTION INTEGER(WS-TOT-MONTHS / 12)
           COMPUTE WS-M = FUNCTION MOD(WS-TOT-MONTHS, 12) + 1
           MOVE WS-D TO WS-D2
           MOVE 0 TO WS-INT-1
           PERFORM UNTIL WS-INT-1 > 0 OR WS-D2 < 28
               COMPUTE WS-DATE-NUM =
                   WS-Y * 10000 + WS-M * 100 + WS-D2
               COMPUTE WS-INT-1 =
                   FUNCTION INTEGER-OF-DATE(WS-DATE-NUM)
               IF WS-INT-1 = 0
                   SUBTRACT 1 FROM WS-D2
               END-IF
           END-PERFORM
           MOVE WS-Y TO WS-Y-ED
           MOVE WS-M TO WS-M-ED
           MOVE WS-D2 TO WS-D-ED
           MOVE SPACES TO DU-RESULT-DATE
           STRING WS-Y-ED '-' WS-M-ED '-' WS-D-ED
               DELIMITED BY SIZE INTO DU-RESULT-DATE
           END-STRING.

       DAYS-BETWEEN-PARA.
           PERFORM PARSE-DATE-1
           IF DU-STATUS = 'VE'
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-INT-1 = FUNCTION INTEGER-OF-DATE(WS-DATE-NUM)
           IF DU-DATE-2(5:1) NOT = '-' OR DU-DATE-2(8:1) NOT = '-'
                   OR DU-DATE-2(1:4) IS NOT NUMERIC
                   OR DU-DATE-2(6:2) IS NOT NUMERIC
                   OR DU-DATE-2(9:2) IS NOT NUMERIC
               MOVE 'VE' TO DU-STATUS
               EXIT PARAGRAPH
           END-IF
           MOVE DU-DATE-2(1:4) TO WS-Y
           MOVE DU-DATE-2(6:2) TO WS-M
           MOVE DU-DATE-2(9:2) TO WS-D
           COMPUTE WS-DATE-NUM = WS-Y * 10000 + WS-M * 100 + WS-D
           COMPUTE WS-INT-2 = FUNCTION INTEGER-OF-DATE(WS-DATE-NUM)
           IF WS-INT-2 = 0
               MOVE 'VE' TO DU-STATUS
               EXIT PARAGRAPH
           END-IF
           COMPUTE DU-RESULT-NUM = WS-INT-2 - WS-INT-1.
