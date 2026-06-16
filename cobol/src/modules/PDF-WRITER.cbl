      ******************************************************************
      * PDF-WRITER.cbl - generic PDF generator from a table of text
      * lines. Produces a real, single-page Courier 9pt PDF with a
      * byte-exact cross-reference table, so the file opens in any
      * standard viewer.
      *
      * The byte offset of every object and the content-stream length
      * are tracked exactly: each LINE SEQUENTIAL write emits the
      * trimmed record plus one LF, so a running counter (trimmed
      * length + 1) gives the true offsets used in the xref table and
      * startxref. The xref entries end in CR so they are the
      * standard 20 bytes (CR LF terminator).
      *
      * CALL 'PDF-WRITER' USING PW-PARAMS
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. "PDF-WRITER".

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT PDF-FILE ASSIGN TO WS-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  PDF-FILE.
       01  PDF-REC                 PIC X(300).

       WORKING-STORAGE SECTION.
       01  WS-PATH                 PIC X(120).
       01  WS-FS                   PIC X(2).
       01  WS-OFF                  PIC 9(9) VALUE 0.
       01  WS-LEN                  PIC 9(4).
       01  WS-I                    PIC 9(4).
       01  WS-J                    PIC 9(4).
       01  WS-CAP                  PIC 9(4).
       01  WS-CONTENT-BYTES        PIC 9(9) VALUE 0.
       01  WS-STARTXREF            PIC 9(9).
       01  WS-OBJ-OFF              OCCURS 6 PIC 9(9).
       01  WS-EC-CNT               PIC 9(4) VALUE 0.
       01  WS-EC-LINE              OCCURS 210 PIC X(240).
       01  WS-ESC                  PIC X(230).
       01  WS-ESC-LEN              PIC 9(4).
       01  WS-SRC                  PIC X(120).
       01  WS-SRCLEN               PIC 9(4).
       01  WS-CH                   PIC X.
       01  WS-NUMZ                 PIC Z(8)9.
       01  WS-NUM-PAD              PIC 9(10).
       01  WS-CR                   PIC X VALUE X'0D'.
       01  WS-LINEBUF              PIC X(300).

       LINKAGE SECTION.
       01  PW-PARAMS.
           05 PW-FILEPATH          PIC X(120).
           05 PW-TITLE             PIC X(80).
           05 PW-LINE-CNT          PIC 9(4).
           05 PW-LINE              OCCURS 200 PIC X(100).
           05 PW-RC                PIC X(2).

       PROCEDURE DIVISION USING PW-PARAMS.
       MAIN-PARA.
           MOVE '00' TO PW-RC
           MOVE PW-FILEPATH TO WS-PATH
           MOVE PW-LINE-CNT TO WS-CAP
           IF WS-CAP > 58
               MOVE 58 TO WS-CAP
           END-IF
           PERFORM BUILD-CONTENT
           OPEN OUTPUT PDF-FILE
           IF WS-FS NOT = '00'
               MOVE 'IO' TO PW-RC
               GOBACK
           END-IF
           MOVE 0 TO WS-OFF
           PERFORM WRITE-BODY
           PERFORM WRITE-XREF
           CLOSE PDF-FILE
           GOBACK.

      * builds the text content stream lines and totals their bytes
       BUILD-CONTENT.
           MOVE 0 TO WS-EC-CNT
           ADD 1 TO WS-EC-CNT
           MOVE 'BT /F1 9 Tf 50 770 Td 12 TL'
             TO WS-EC-LINE(WS-EC-CNT)
           MOVE PW-TITLE TO WS-SRC
           PERFORM ESCAPE-SRC
           ADD 1 TO WS-EC-CNT
           STRING '(' WS-ESC(1:WS-ESC-LEN) ') Tj'
               DELIMITED BY SIZE INTO WS-EC-LINE(WS-EC-CNT)
           END-STRING
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-CAP
               MOVE PW-LINE(WS-I) TO WS-SRC
               PERFORM ESCAPE-SRC
               ADD 1 TO WS-EC-CNT
               STRING 'T* (' WS-ESC(1:WS-ESC-LEN) ') Tj'
                   DELIMITED BY SIZE INTO WS-EC-LINE(WS-EC-CNT)
               END-STRING
           END-PERFORM
           ADD 1 TO WS-EC-CNT
           MOVE 'ET' TO WS-EC-LINE(WS-EC-CNT)
           MOVE 0 TO WS-CONTENT-BYTES
           PERFORM VARYING WS-I FROM 1 BY 1
                   UNTIL WS-I > WS-EC-CNT
               MOVE WS-EC-LINE(WS-I) TO WS-LINEBUF
               PERFORM CALC-LEN
               ADD WS-LEN TO WS-CONTENT-BYTES
               ADD 1 TO WS-CONTENT-BYTES
           END-PERFORM.

      * escapes (, ) and backslash in WS-SRC into WS-ESC
       ESCAPE-SRC.
           MOVE 0 TO WS-SRCLEN
           PERFORM VARYING WS-J FROM 120 BY -1
                   UNTIL WS-J < 1 OR WS-SRCLEN > 0
               IF WS-SRC(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-SRCLEN
               END-IF
           END-PERFORM
           MOVE SPACES TO WS-ESC
           MOVE 0 TO WS-ESC-LEN
           PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > WS-SRCLEN
               MOVE WS-SRC(WS-J:1) TO WS-CH
               IF WS-CH = '(' OR WS-CH = ')' OR WS-CH = '\'
                   ADD 1 TO WS-ESC-LEN
                   MOVE '\' TO WS-ESC(WS-ESC-LEN:1)
               END-IF
               ADD 1 TO WS-ESC-LEN
               MOVE WS-CH TO WS-ESC(WS-ESC-LEN:1)
           END-PERFORM
           IF WS-ESC-LEN = 0
               MOVE 1 TO WS-ESC-LEN
               MOVE SPACE TO WS-ESC(1:1)
           END-IF.

      * trimmed (trailing-space) length of WS-LINEBUF; CR is kept
       CALC-LEN.
           MOVE 0 TO WS-LEN
           PERFORM VARYING WS-J FROM 300 BY -1
                   UNTIL WS-J < 1 OR WS-LEN > 0
               IF WS-LINEBUF(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-LEN
               END-IF
           END-PERFORM.

       WRITE-PDF-LINE.
           PERFORM CALC-LEN
           MOVE WS-LINEBUF TO PDF-REC
           WRITE PDF-REC
           ADD WS-LEN TO WS-OFF
           ADD 1 TO WS-OFF.

       WRITE-BODY.
           MOVE '%PDF-1.4' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE WS-OFF TO WS-OBJ-OFF(1)
           MOVE '1 0 obj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE '<< /Type /Catalog /Pages 2 0 R >>' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE 'endobj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE WS-OFF TO WS-OBJ-OFF(2)
           MOVE '2 0 obj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE '<< /Type /Pages /Kids [3 0 R] /Count 1 >>'
             TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE 'endobj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE WS-OFF TO WS-OBJ-OFF(3)
           MOVE '3 0 obj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE SPACES TO WS-LINEBUF
           STRING '<< /Type /Page /Parent 2 0 R '
                  '/MediaBox [0 0 612 792] /Contents 4 0 R '
                  '/Resources << /Font << /F1 5 0 R >> >> >>'
               DELIMITED BY SIZE INTO WS-LINEBUF
           END-STRING
           PERFORM WRITE-PDF-LINE
           MOVE 'endobj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE WS-OFF TO WS-OBJ-OFF(4)
           MOVE '4 0 obj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE WS-CONTENT-BYTES TO WS-NUMZ
           MOVE SPACES TO WS-LINEBUF
           STRING '<< /Length ' FUNCTION TRIM(WS-NUMZ) ' >>'
               DELIMITED BY SIZE INTO WS-LINEBUF
           END-STRING
           PERFORM WRITE-PDF-LINE
           MOVE 'stream' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           PERFORM VARYING WS-I FROM 1 BY 1
                   UNTIL WS-I > WS-EC-CNT
               MOVE WS-EC-LINE(WS-I) TO WS-LINEBUF
               PERFORM WRITE-PDF-LINE
           END-PERFORM
           MOVE 'endstream' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE 'endobj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE WS-OFF TO WS-OBJ-OFF(5)
           MOVE '5 0 obj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE SPACES TO WS-LINEBUF
           STRING '<< /Type /Font /Subtype /Type1 '
                  '/BaseFont /Courier >>'
               DELIMITED BY SIZE INTO WS-LINEBUF
           END-STRING
           PERFORM WRITE-PDF-LINE
           MOVE 'endobj' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE.

       WRITE-XREF.
           MOVE WS-OFF TO WS-STARTXREF
           MOVE 'xref' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE '0 6' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE SPACES TO WS-LINEBUF
           STRING '0000000000 65535 f' WS-CR
               DELIMITED BY SIZE INTO WS-LINEBUF
           END-STRING
           PERFORM WRITE-PDF-LINE
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 5
               MOVE WS-OBJ-OFF(WS-I) TO WS-NUM-PAD
               MOVE SPACES TO WS-LINEBUF
               STRING WS-NUM-PAD ' 00000 n' WS-CR
                   DELIMITED BY SIZE INTO WS-LINEBUF
               END-STRING
               PERFORM WRITE-PDF-LINE
           END-PERFORM
           MOVE 'trailer' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE '<< /Size 6 /Root 1 0 R >>' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE 'startxref' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE WS-STARTXREF TO WS-NUMZ
           MOVE FUNCTION TRIM(WS-NUMZ) TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE
           MOVE '%%EOF' TO WS-LINEBUF
           PERFORM WRITE-PDF-LINE.
