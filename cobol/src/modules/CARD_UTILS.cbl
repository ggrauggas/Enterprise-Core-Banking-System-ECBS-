      ******************************************************************
      * CARD_UTILS.cbl - card number helper module (Luhn mod 10).
      * Operations:
      *   GENERATE -> builds a deterministic 16-digit card number
      *               from CU-SEED (the card id): BIN '4539' +
      *               '0' + seed(10) + Luhn check digit.
      *   VALIDATE -> Luhn-checks the 16 digits in CU-CARD-NUMBER.
      * CU-RC: '00' ok, 'VE' invalid input or failed validation.
      *
      * CALL 'CARD_UTILS' USING CU-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "CARD_UTILS".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PAYLOAD              PIC X(15).
       01  WS-I                    PIC 9(2).
       01  WS-POS-RIGHT            PIC 9(2).
       01  WS-DIGIT                PIC 9(2).
       01  WS-TOTAL                PIC 9(4).
       01  WS-CHECK                PIC 9.
       01  WS-SEED-X               PIC 9(10).

       LINKAGE SECTION.
       01  CU-PARAMS.
           05 CU-OPERATION         PIC X(10).
           05 CU-SEED              PIC 9(10).
           05 CU-CARD-NUMBER       PIC X(16).
           05 CU-RC                PIC X(2).

       PROCEDURE DIVISION USING CU-PARAMS.
       MAIN-PARA.
           MOVE '00' TO CU-RC
           EVALUATE FUNCTION TRIM(CU-OPERATION)
               WHEN 'GENERATE' PERFORM GENERATE-PARA
               WHEN 'VALIDATE' PERFORM VALIDATE-PARA
               WHEN OTHER      MOVE 'VE' TO CU-RC
           END-EVALUATE
           GOBACK.

       GENERATE-PARA.
           MOVE CU-SEED TO WS-SEED-X
           MOVE SPACES TO WS-PAYLOAD
           STRING '4539' '0' WS-SEED-X
               DELIMITED BY SIZE INTO WS-PAYLOAD
           END-STRING
      *    Luhn over the 15-digit payload; the check digit will sit
      *    at position 1 from the right, so payload digits at even
      *    positions from the right get doubled
           MOVE 0 TO WS-TOTAL
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 15
               COMPUTE WS-POS-RIGHT = 16 - WS-I + 1
               MOVE FUNCTION NUMVAL(WS-PAYLOAD(WS-I:1))
                 TO WS-DIGIT
               IF FUNCTION MOD(WS-POS-RIGHT, 2) = 0
                   COMPUTE WS-DIGIT = WS-DIGIT * 2
                   IF WS-DIGIT > 9
                       SUBTRACT 9 FROM WS-DIGIT
                   END-IF
               END-IF
               ADD WS-DIGIT TO WS-TOTAL
           END-PERFORM
           COMPUTE WS-CHECK =
               FUNCTION MOD(10 - FUNCTION MOD(WS-TOTAL, 10), 10)
           MOVE SPACES TO CU-CARD-NUMBER
           STRING WS-PAYLOAD WS-CHECK
               DELIMITED BY SIZE INTO CU-CARD-NUMBER
           END-STRING.

       VALIDATE-PARA.
           IF CU-CARD-NUMBER(1:16) IS NOT NUMERIC
               MOVE 'VE' TO CU-RC
               EXIT PARAGRAPH
           END-IF
           MOVE 0 TO WS-TOTAL
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 16
               COMPUTE WS-POS-RIGHT = 16 - WS-I + 1
               MOVE FUNCTION NUMVAL(CU-CARD-NUMBER(WS-I:1))
                 TO WS-DIGIT
               IF FUNCTION MOD(WS-POS-RIGHT, 2) = 0
                   COMPUTE WS-DIGIT = WS-DIGIT * 2
                   IF WS-DIGIT > 9
                       SUBTRACT 9 FROM WS-DIGIT
                   END-IF
               END-IF
               ADD WS-DIGIT TO WS-TOTAL
           END-PERFORM
           IF FUNCTION MOD(WS-TOTAL, 10) NOT = 0
               MOVE 'VE' TO CU-RC
           END-IF.
