      ******************************************************************
      * IBAN_UTILS.cbl - IBAN helper module (ISO 13616, mod 97-10).
      * Operations:
      *   BUILD    -> from IB-COUNTRY (2 letters) and IB-BBAN of
      *               IB-BBAN-LEN digits, computes the 2 check
      *               digits and returns the full IBAN in IB-IBAN.
      *   VALIDATE -> checks IB-IBAN (rearranged mod 97 must be 1).
      * IB-RC: '00' ok, 'VE' invalid input or failed validation.
      *
      * CALL 'IBAN_UTILS' USING IB-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "IBAN_UTILS".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-WORK                 PIC X(40).
       01  WS-WORK-LEN             PIC 9(3).
       01  WS-REM                  PIC 9(4).
       01  WS-I                    PIC 9(3).
       01  WS-LEN                  PIC 9(3).
       01  WS-CH                   PIC X.
       01  WS-VAL                  PIC 9(2).
       01  WS-CHECK                PIC 9(2).

       LINKAGE SECTION.
       01  IB-PARAMS.
           05 IB-OPERATION         PIC X(10).
           05 IB-COUNTRY           PIC X(2).
           05 IB-BBAN              PIC X(30).
           05 IB-BBAN-LEN          PIC 9(2).
           05 IB-IBAN              PIC X(34).
           05 IB-RC                PIC X(2).

       PROCEDURE DIVISION USING IB-PARAMS.
       MAIN-PARA.
           MOVE '00' TO IB-RC
           EVALUATE FUNCTION TRIM(IB-OPERATION)
               WHEN 'BUILD'    PERFORM BUILD-PARA
               WHEN 'VALIDATE' PERFORM VALIDATE-PARA
               WHEN OTHER      MOVE 'VE' TO IB-RC
           END-EVALUATE
           GOBACK.

      * check digits = 98 - mod97(BBAN || country || '00')
       BUILD-PARA.
           IF IB-BBAN-LEN = 0 OR IB-BBAN-LEN > 30
               MOVE 'VE' TO IB-RC
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-WORK
           STRING IB-BBAN(1:IB-BBAN-LEN) IB-COUNTRY '00'
               DELIMITED BY SIZE INTO WS-WORK
           END-STRING
           COMPUTE WS-WORK-LEN = IB-BBAN-LEN + 4
           PERFORM MOD97-PARA
           IF IB-RC NOT = '00'
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-CHECK = 98 - WS-REM
           MOVE SPACES TO IB-IBAN
           STRING IB-COUNTRY WS-CHECK IB-BBAN(1:IB-BBAN-LEN)
               DELIMITED BY SIZE INTO IB-IBAN
           END-STRING.

      * valid when mod97(BBAN || country || check digits) = 1
       VALIDATE-PARA.
           MOVE 0 TO WS-LEN
           PERFORM VARYING WS-I FROM 34 BY -1
                   UNTIL WS-I < 1 OR WS-LEN > 0
               IF IB-IBAN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-LEN
               END-IF
           END-PERFORM
           IF WS-LEN < 5
               MOVE 'VE' TO IB-RC
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-WORK
           STRING IB-IBAN(5:WS-LEN - 4) IB-IBAN(1:4)
               DELIMITED BY SIZE INTO WS-WORK
           END-STRING
           MOVE WS-LEN TO WS-WORK-LEN
           PERFORM MOD97-PARA
           IF IB-RC = '00' AND WS-REM NOT = 1
               MOVE 'VE' TO IB-RC
           END-IF.

      * running mod 97 over WS-WORK(1:WS-WORK-LEN); letters expand
      * to two digits (A=10 .. Z=35) as per ISO 13616
       MOD97-PARA.
           MOVE 0 TO WS-REM
           PERFORM VARYING WS-I FROM 1 BY 1
                   UNTIL WS-I > WS-WORK-LEN
               MOVE WS-WORK(WS-I:1) TO WS-CH
               IF WS-CH IS NUMERIC
                   COMPUTE WS-REM = FUNCTION MOD(
                       WS-REM * 10 + FUNCTION NUMVAL(WS-CH), 97)
               ELSE
                   IF WS-CH >= 'A' AND WS-CH <= 'Z'
                       COMPUTE WS-VAL = FUNCTION ORD(WS-CH)
                               - FUNCTION ORD('A') + 10
                       COMPUTE WS-REM = FUNCTION MOD(
                           WS-REM * 100 + WS-VAL, 97)
                   ELSE
                       MOVE 'VE' TO IB-RC
                       MOVE WS-WORK-LEN TO WS-I
                   END-IF
               END-IF
           END-PERFORM.
