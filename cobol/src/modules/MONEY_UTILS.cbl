      ******************************************************************
      * MONEY_UTILS.cbl - monetary arithmetic module.
      * Amounts are PIC S9(13)V99 COMP-3, rates are annual percentages
      * PIC S9(3)V9(4) COMP-3.
      * Operations:
      *   ADD          -> RESULT = AMOUNT-1 + AMOUNT-2
      *   SUBTRACT     -> RESULT = AMOUNT-1 - AMOUNT-2
      *                   ('NF' = would go negative)
      *   FORMAT       -> MU-FORMATTED, display string of AMOUNT-1
      *   MONTHLY-INT  -> RESULT = AMOUNT-1 * RATE / 100 / 12
      *   FRENCH-PMT   -> RESULT = constant monthly annuity payment
      *                   (French amortisation: A=P*i*f/(f-1),
      *                    f=(1+i)^n, i=RATE/100/12, n=MONTHS)
      * MU-STATUS: '00' ok, 'NF' negative forbidden, 'VE' bad input.
      *
      * CALL 'MONEY_UTILS' USING MU-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "MONEY_UTILS".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-EDIT                 PIC -Z(12)9.99.
       01  WS-RATE-M               COMP-2.
       01  WS-FACTOR               COMP-2.

       LINKAGE SECTION.
       01  MU-PARAMS.
           05 MU-OPERATION         PIC X(12).
           05 MU-AMOUNT-1          PIC S9(13)V99 COMP-3.
           05 MU-AMOUNT-2          PIC S9(13)V99 COMP-3.
           05 MU-RATE              PIC S9(3)V9(4) COMP-3.
           05 MU-MONTHS            PIC 9(4).
           05 MU-RESULT            PIC S9(13)V99 COMP-3.
           05 MU-FORMATTED         PIC X(20).
           05 MU-STATUS            PIC X(2).

       PROCEDURE DIVISION USING MU-PARAMS.
       MAIN-PARA.
           MOVE '00' TO MU-STATUS
           EVALUATE FUNCTION TRIM(MU-OPERATION)
               WHEN 'ADD'         PERFORM ADD-PARA
               WHEN 'SUBTRACT'    PERFORM SUBTRACT-PARA
               WHEN 'FORMAT'      PERFORM FORMAT-PARA
               WHEN 'MONTHLY-INT' PERFORM MONTHLY-INT-PARA
               WHEN 'FRENCH-PMT'  PERFORM FRENCH-PMT-PARA
               WHEN OTHER         MOVE 'VE' TO MU-STATUS
           END-EVALUATE
           GOBACK.

       ADD-PARA.
           COMPUTE MU-RESULT = MU-AMOUNT-1 + MU-AMOUNT-2.

       SUBTRACT-PARA.
           COMPUTE MU-RESULT = MU-AMOUNT-1 - MU-AMOUNT-2
           IF MU-RESULT < 0
               MOVE 'NF' TO MU-STATUS
           END-IF.

       FORMAT-PARA.
           MOVE MU-AMOUNT-1 TO WS-EDIT
           MOVE SPACES TO MU-FORMATTED
           MOVE FUNCTION TRIM(WS-EDIT) TO MU-FORMATTED.

       MONTHLY-INT-PARA.
           COMPUTE MU-RESULT ROUNDED =
               MU-AMOUNT-1 * MU-RATE / 1200.

       FRENCH-PMT-PARA.
           IF MU-MONTHS = 0
               MOVE 'VE' TO MU-STATUS
               EXIT PARAGRAPH
           END-IF
           IF MU-RATE = 0
               COMPUTE MU-RESULT ROUNDED =
                   MU-AMOUNT-1 / MU-MONTHS
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-RATE-M = MU-RATE / 1200
           COMPUTE WS-FACTOR = (1 + WS-RATE-M) ** MU-MONTHS
           COMPUTE MU-RESULT ROUNDED =
               MU-AMOUNT-1 * WS-RATE-M * WS-FACTOR
               / (WS-FACTOR - 1).
