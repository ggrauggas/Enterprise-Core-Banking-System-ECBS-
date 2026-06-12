      ******************************************************************
      * JSON_UTILS.cbl - minimal JSON helper for bridge payloads.
      * Extracts the value of a top-level key from a flat JSON
      * object, e.g. the request body the HTTP bridge pipes through
      * stdin:  {"firstName": "Maria", "customerId": 7}
      * Supports string and numeric values, optional blanks around
      * the colon and the escapes \" and \\ inside strings.
      * Output: JU-FOUND 'Y'/'N', value (space padded) in JU-VALUE.
      *
      * CALL 'JSON_UTILS' USING JU-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "JSON_UTILS".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PATTERN              PIC X(34).
       01  WS-PAT-LEN              PIC 9(3).
       01  WS-KEY-LEN              PIC 9(3).
       01  WS-I                    PIC 9(5).
       01  WS-V                    PIC 9(3).
       01  WS-LIMIT                PIC 9(5).
       01  WS-MATCH-POS            PIC 9(5).
       01  WS-CH                   PIC X.

       LINKAGE SECTION.
       01  JU-PARAMS.
           05 JU-BUFFER            PIC X(2000).
           05 JU-KEY               PIC X(32).
           05 JU-VALUE             PIC X(256).
           05 JU-FOUND             PIC X.
           05 JU-RC                PIC X(2).

       PROCEDURE DIVISION USING JU-PARAMS.
       MAIN-PARA.
           MOVE '00' TO JU-RC
           MOVE 'N' TO JU-FOUND
           MOVE SPACES TO JU-VALUE
           PERFORM BUILD-PATTERN
           IF WS-KEY-LEN = 0
               MOVE 'NF' TO JU-RC
               GOBACK
           END-IF
           PERFORM FIND-KEY
           IF WS-MATCH-POS > 0
               PERFORM EXTRACT-VALUE
           END-IF
           IF JU-FOUND = 'N'
               MOVE 'NF' TO JU-RC
           END-IF
           GOBACK.

      * Search pattern is the quoted key: "key"
       BUILD-PATTERN.
           MOVE 0 TO WS-KEY-LEN
           PERFORM VARYING WS-I FROM 32 BY -1
                   UNTIL WS-I < 1 OR WS-KEY-LEN > 0
               IF JU-KEY(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-KEY-LEN
               END-IF
           END-PERFORM
           IF WS-KEY-LEN = 0
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-PATTERN
           STRING '"' JU-KEY(1:WS-KEY-LEN) '"'
               DELIMITED BY SIZE INTO WS-PATTERN
           END-STRING
           COMPUTE WS-PAT-LEN = WS-KEY-LEN + 2.

       FIND-KEY.
           MOVE 0 TO WS-MATCH-POS
           COMPUTE WS-LIMIT = 2000 - WS-PAT-LEN + 1
           PERFORM VARYING WS-I FROM 1 BY 1
                   UNTIL WS-I > WS-LIMIT OR WS-MATCH-POS > 0
               IF JU-BUFFER(WS-I:WS-PAT-LEN)
                       = WS-PATTERN(1:WS-PAT-LEN)
                   MOVE WS-I TO WS-MATCH-POS
               END-IF
           END-PERFORM.

      * Past the key: skip blanks, require ':', skip blanks, then
      * read either a quoted string or a bare (numeric/bool) token.
       EXTRACT-VALUE.
           COMPUTE WS-I = WS-MATCH-POS + WS-PAT-LEN
           PERFORM SKIP-BLANKS
           IF WS-I > 2000 OR JU-BUFFER(WS-I:1) NOT = ':'
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-I
           PERFORM SKIP-BLANKS
           IF WS-I > 2000
               EXIT PARAGRAPH
           END-IF
           MOVE 'Y' TO JU-FOUND
           IF JU-BUFFER(WS-I:1) = '"'
               ADD 1 TO WS-I
               PERFORM EXTRACT-STRING
           ELSE
               PERFORM EXTRACT-BARE
           END-IF.

       SKIP-BLANKS.
           PERFORM UNTIL WS-I > 2000
                   OR JU-BUFFER(WS-I:1) NOT = SPACE
               ADD 1 TO WS-I
           END-PERFORM.

       EXTRACT-STRING.
           MOVE 0 TO WS-V
           PERFORM UNTIL WS-I > 2000 OR WS-V > 255
                   OR JU-BUFFER(WS-I:1) = '"'
               MOVE JU-BUFFER(WS-I:1) TO WS-CH
               IF WS-CH = '\' AND WS-I < 2000
                   ADD 1 TO WS-I
                   MOVE JU-BUFFER(WS-I:1) TO WS-CH
               END-IF
               ADD 1 TO WS-V
               MOVE WS-CH TO JU-VALUE(WS-V:1)
               ADD 1 TO WS-I
           END-PERFORM.

       EXTRACT-BARE.
           MOVE 0 TO WS-V
           PERFORM UNTIL WS-I > 2000 OR WS-V > 255
                   OR JU-BUFFER(WS-I:1) = ','
                   OR JU-BUFFER(WS-I:1) = '}'
                   OR JU-BUFFER(WS-I:1) = SPACE
               ADD 1 TO WS-V
               MOVE JU-BUFFER(WS-I:1) TO JU-VALUE(WS-V:1)
               ADD 1 TO WS-I
           END-PERFORM.
