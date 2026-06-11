      ******************************************************************
      * VALIDATION.cbl - generic field validation module.
      * Operations: EMAIL, PHONE, NOT-BLANK.
      * Returns VAL-RC '00' (valid) or 'VE' (validation error)
      * plus a human readable VAL-MESSAGE.
      *
      * CALL 'VALIDATION' USING VAL-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. VALIDATION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-I                    PIC 9(3).
       01  WS-LEN                  PIC 9(3).
       01  WS-AT-COUNT             PIC 9(3).
       01  WS-AT-POS               PIC 9(3).
       01  WS-DOT-AFTER-AT         PIC 9(3).
       01  WS-SPACE-COUNT          PIC 9(3).
       01  WS-START                PIC 9(3).
       01  WS-DIGITS               PIC 9(3).
       01  WS-BAD-CHAR             PIC 9(3).

       LINKAGE SECTION.
       01  VAL-PARAMS.
           05 VAL-OPERATION        PIC X(15).
           05 VAL-INPUT            PIC X(120).
           05 VAL-RC           PIC X(2).
           05 VAL-MESSAGE          PIC X(80).

       PROCEDURE DIVISION USING VAL-PARAMS.
       MAIN-PARA.
           MOVE '00' TO VAL-RC
           MOVE SPACES TO VAL-MESSAGE
           EVALUATE FUNCTION TRIM(VAL-OPERATION)
               WHEN 'EMAIL'     PERFORM VALIDATE-EMAIL
               WHEN 'PHONE'     PERFORM VALIDATE-PHONE
               WHEN 'NOT-BLANK' PERFORM VALIDATE-NOT-BLANK
               WHEN OTHER
                   MOVE 'VE' TO VAL-RC
                   MOVE 'UNKNOWN VALIDATION OPERATION' TO VAL-MESSAGE
           END-EVALUATE
           GOBACK.

       FIND-TRIMMED-LENGTH.
           MOVE 0 TO WS-LEN
           PERFORM VARYING WS-I FROM 120 BY -1
                   UNTIL WS-I < 1 OR WS-LEN > 0
               IF VAL-INPUT(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-LEN
               END-IF
           END-PERFORM.

       VALIDATE-NOT-BLANK.
           IF VAL-INPUT = SPACES
               MOVE 'VE' TO VAL-RC
               MOVE 'FIELD MUST NOT BE BLANK' TO VAL-MESSAGE
           END-IF.

       VALIDATE-EMAIL.
           PERFORM FIND-TRIMMED-LENGTH
           IF WS-LEN < 6
               MOVE 'VE' TO VAL-RC
               MOVE 'EMAIL TOO SHORT' TO VAL-MESSAGE
               EXIT PARAGRAPH
           END-IF
           MOVE 0 TO WS-AT-COUNT WS-AT-POS WS-DOT-AFTER-AT
                     WS-SPACE-COUNT
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LEN
               EVALUATE VAL-INPUT(WS-I:1)
                   WHEN '@'
                       ADD 1 TO WS-AT-COUNT
                       MOVE WS-I TO WS-AT-POS
                   WHEN '.'
                       IF WS-AT-POS > 0 AND WS-I > WS-AT-POS + 1
                           ADD 1 TO WS-DOT-AFTER-AT
                       END-IF
                   WHEN SPACE
                       ADD 1 TO WS-SPACE-COUNT
               END-EVALUATE
           END-PERFORM
           EVALUATE TRUE
               WHEN WS-SPACE-COUNT > 0
                   MOVE 'VE' TO VAL-RC
                   MOVE 'EMAIL MUST NOT CONTAIN SPACES'
                       TO VAL-MESSAGE
               WHEN WS-AT-COUNT NOT = 1
                   MOVE 'VE' TO VAL-RC
                   MOVE 'EMAIL MUST CONTAIN EXACTLY ONE @'
                       TO VAL-MESSAGE
               WHEN WS-AT-POS < 2 OR WS-AT-POS = WS-LEN
                   MOVE 'VE' TO VAL-RC
                   MOVE 'EMAIL LOCAL OR DOMAIN PART MISSING'
                       TO VAL-MESSAGE
               WHEN WS-DOT-AFTER-AT = 0
                   MOVE 'VE' TO VAL-RC
                   MOVE 'EMAIL DOMAIN MUST CONTAIN A DOT'
                       TO VAL-MESSAGE
               WHEN VAL-INPUT(WS-LEN:1) = '.'
                   MOVE 'VE' TO VAL-RC
                   MOVE 'EMAIL MUST NOT END WITH A DOT'
                       TO VAL-MESSAGE
           END-EVALUATE.

       VALIDATE-PHONE.
           PERFORM FIND-TRIMMED-LENGTH
           IF WS-LEN = 0
               MOVE 'VE' TO VAL-RC
               MOVE 'PHONE MUST NOT BE BLANK' TO VAL-MESSAGE
               EXIT PARAGRAPH
           END-IF
           MOVE 1 TO WS-START
           IF VAL-INPUT(1:1) = '+'
               MOVE 2 TO WS-START
           END-IF
           MOVE 0 TO WS-DIGITS WS-BAD-CHAR
           PERFORM VARYING WS-I FROM WS-START BY 1
                   UNTIL WS-I > WS-LEN
               IF VAL-INPUT(WS-I:1) IS NUMERIC
                   ADD 1 TO WS-DIGITS
               ELSE
                   ADD 1 TO WS-BAD-CHAR
               END-IF
           END-PERFORM
           EVALUATE TRUE
               WHEN WS-BAD-CHAR > 0
                   MOVE 'VE' TO VAL-RC
                   MOVE 'PHONE MUST CONTAIN ONLY DIGITS'
                       TO VAL-MESSAGE
               WHEN WS-DIGITS < 9 OR WS-DIGITS > 15
                   MOVE 'VE' TO VAL-RC
                   MOVE 'PHONE MUST HAVE 9 TO 15 DIGITS'
                       TO VAL-MESSAGE
           END-EVALUATE.
