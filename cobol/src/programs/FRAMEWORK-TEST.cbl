      ******************************************************************
      * FRAMEWORK-TEST.cbl - exercises every Fase 3 framework module
      * (VALIDATION, DATE_UTILS, MONEY_UTILS, ERROR_HANDLER, LOGGER)
      * and the CUSTOMER copybook, reporting the results as JSON so
      * the whole framework can be smoke-tested through the bridge.
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAMEWORK-TEST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY CUSTOMER.

       01  VAL-PARAMS.
           05 VAL-OPERATION        PIC X(15).
           05 VAL-INPUT            PIC X(120).
           05 VAL-RC           PIC X(2).
           05 VAL-MESSAGE          PIC X(80).

       01  DU-PARAMS.
           05 DU-OPERATION         PIC X(12).
           05 DU-DATE-1            PIC X(10).
           05 DU-DATE-2            PIC X(10).
           05 DU-NUMBER            PIC S9(5).
           05 DU-RESULT-DATE       PIC X(10).
           05 DU-RESULT-NUM        PIC S9(9).
           05 DU-RESULT-TS         PIC X(19).
           05 DU-STATUS            PIC X(2).

       01  MU-PARAMS.
           05 MU-OPERATION         PIC X(12).
           05 MU-AMOUNT-1          PIC S9(13)V99 COMP-3.
           05 MU-AMOUNT-2          PIC S9(13)V99 COMP-3.
           05 MU-RATE              PIC S9(3)V9(4) COMP-3.
           05 MU-MONTHS            PIC 9(4).
           05 MU-RESULT            PIC S9(13)V99 COMP-3.
           05 MU-FORMATTED         PIC X(20).
           05 MU-STATUS            PIC X(2).

       01  EH-PARAMS.
           05 EH-ERROR-CODE        PIC X(5).
           05 EH-CONTEXT           PIC X(80).
           05 EH-SEVERITY          PIC X.
           05 EH-MESSAGE           PIC X(120).

       01  LOG-PARAMS.
           05 LOG-LEVEL            PIC X(5).
           05 LOG-COMPONENT        PIC X(12).
           05 LOG-MSG              PIC X(200).

       01  WS-EMAIL-OK             PIC X(2).
       01  WS-EMAIL-BAD            PIC X(2).
       01  WS-EMAIL-BAD-MSG        PIC X(80).
       01  WS-PHONE-OK             PIC X(2).
       01  WS-DATE-OK              PIC X(2).
       01  WS-DATE-BAD             PIC X(2).
       01  WS-TS                   PIC X(19).
       01  WS-ADD-MONTHS           PIC X(10).
       01  WS-AGE-ED               PIC -ZZZZZZZZ9.
       01  WS-DAYS-ED              PIC -ZZZZZZZZ9.
       01  WS-MONEY-ADD            PIC X(20).
       01  WS-FRENCH-PMT           PIC X(20).

       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM TEST-VALIDATION
           PERFORM TEST-DATE-UTILS
           PERFORM TEST-MONEY-UTILS
           PERFORM TEST-ERROR-HANDLER
           PERFORM TEST-LOGGER
           PERFORM TEST-COPYBOOK
           PERFORM PRINT-JSON
           STOP RUN.

       TEST-VALIDATION.
           MOVE 'EMAIL' TO VAL-OPERATION
           MOVE 'maria.garcia@example.com' TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           MOVE VAL-RC TO WS-EMAIL-OK

           MOVE 'EMAIL' TO VAL-OPERATION
           MOVE 'not-an-email' TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           MOVE VAL-RC TO WS-EMAIL-BAD
           MOVE VAL-MESSAGE TO WS-EMAIL-BAD-MSG

           MOVE 'PHONE' TO VAL-OPERATION
           MOVE '+34600111222' TO VAL-INPUT
           CALL 'VALIDATION' USING VAL-PARAMS
           MOVE VAL-RC TO WS-PHONE-OK.

       TEST-DATE-UTILS.
           MOVE 'VALIDATE' TO DU-OPERATION
           MOVE '1985-03-12' TO DU-DATE-1
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-STATUS TO WS-DATE-OK

           MOVE 'VALIDATE' TO DU-OPERATION
           MOVE '2026-02-30' TO DU-DATE-1
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-STATUS TO WS-DATE-BAD

           MOVE 'CURRENT-TS' TO DU-OPERATION
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-RESULT-TS TO WS-TS

           MOVE 'CALC-AGE' TO DU-OPERATION
           MOVE '1985-03-12' TO DU-DATE-1
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-RESULT-NUM TO WS-AGE-ED

           MOVE 'ADD-MONTHS' TO DU-OPERATION
           MOVE '2026-01-31' TO DU-DATE-1
           MOVE 1 TO DU-NUMBER
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-RESULT-DATE TO WS-ADD-MONTHS

           MOVE 'DAYS-BETWEEN' TO DU-OPERATION
           MOVE '2026-01-01' TO DU-DATE-1
           MOVE '2026-06-11' TO DU-DATE-2
           CALL 'DATE_UTILS' USING DU-PARAMS
           MOVE DU-RESULT-NUM TO WS-DAYS-ED.

       TEST-MONEY-UTILS.
           MOVE 'ADD' TO MU-OPERATION
           MOVE 100.50 TO MU-AMOUNT-1
           MOVE 200.25 TO MU-AMOUNT-2
           CALL 'MONEY_UTILS' USING MU-PARAMS

           MOVE 'FORMAT' TO MU-OPERATION
           MOVE MU-RESULT TO MU-AMOUNT-1
           CALL 'MONEY_UTILS' USING MU-PARAMS
           MOVE MU-FORMATTED TO WS-MONEY-ADD

           MOVE 'FRENCH-PMT' TO MU-OPERATION
           MOVE 12000.00 TO MU-AMOUNT-1
           MOVE 5.50 TO MU-RATE
           MOVE 60 TO MU-MONTHS
           CALL 'MONEY_UTILS' USING MU-PARAMS

           MOVE 'FORMAT' TO MU-OPERATION
           MOVE MU-RESULT TO MU-AMOUNT-1
           CALL 'MONEY_UTILS' USING MU-PARAMS
           MOVE MU-FORMATTED TO WS-FRENCH-PMT.

       TEST-ERROR-HANDLER.
           MOVE 'E005' TO EH-ERROR-CODE
           MOVE 'ACCOUNT 3' TO EH-CONTEXT
           MOVE 'E' TO EH-SEVERITY
           CALL 'ERROR_HANDLER' USING EH-PARAMS.

       TEST-LOGGER.
           MOVE 'INFO' TO LOG-LEVEL
           MOVE 'FRWK-TEST' TO LOG-COMPONENT
           MOVE 'framework smoke test executed' TO LOG-MSG
           CALL 'LOGGER' USING LOG-PARAMS.

       TEST-COPYBOOK.
           MOVE 1 TO CUST-ID
           MOVE 'Maria' TO CUST-FIRST-NAME
           MOVE 'Garcia Lopez' TO CUST-LAST-NAME
           MOVE 'maria.garcia@example.com' TO CUST-EMAIL
           MOVE 'ACTIVE' TO CUST-STATUS.

       PRINT-JSON.
           DISPLAY '{'
           DISPLAY '"program":"FRAMEWORK-TEST",'
           DISPLAY '"emailOk":"' WS-EMAIL-OK '",'
           DISPLAY '"emailBad":"' WS-EMAIL-BAD '",'
           DISPLAY '"emailBadMsg":"'
                   FUNCTION TRIM(WS-EMAIL-BAD-MSG) '",'
           DISPLAY '"phoneOk":"' WS-PHONE-OK '",'
           DISPLAY '"dateValid":"' WS-DATE-OK '",'
           DISPLAY '"dateInvalid":"' WS-DATE-BAD '",'
           DISPLAY '"currentTs":"' WS-TS '",'
           DISPLAY '"age":' FUNCTION TRIM(WS-AGE-ED) ','
           DISPLAY '"addMonths":"' WS-ADD-MONTHS '",'
           DISPLAY '"daysBetween":' FUNCTION TRIM(WS-DAYS-ED) ','
           DISPLAY '"moneyAdd":"' FUNCTION TRIM(WS-MONEY-ADD) '",'
           DISPLAY '"frenchPayment":"'
                   FUNCTION TRIM(WS-FRENCH-PMT) '",'
           DISPLAY '"errorMessage":"'
                   FUNCTION TRIM(EH-MESSAGE) '",'
           DISPLAY '"copybookEmail":"'
                   FUNCTION TRIM(CUST-EMAIL) '",'
           DISPLAY '"copybookActive":'
           IF CUST-ACTIVE
               DISPLAY 'true,'
           ELSE
               DISPLAY 'false,'
           END-IF
           DISPLAY '"status":"OK"'
           DISPLAY '}'.
