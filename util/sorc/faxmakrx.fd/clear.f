      SUBROUTINE CLEAR(BLAT,XINDEF,FLD,IMAX,JMAX,KEY,IRTN)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:   CLEAR        FILLS EDGES OF FIELD WITH INDEFINITES.
C   PRGMMR: KRISHNA KUMAR         ORG: W/NP12    DATE: 1999-08-01
C
C ABSTRACT: FILLS THE AREA OUTSIDE OF THE GIVEN LATITUDE WITH
C   INDEFINATES.
C
C PROGRAM HISTORY LOG:
C   89-11-29  ORIGINAL AUTHOR HENRICHSEN.
C   92-07-06  HENRICHSEN     CONVERT TO FORTRAN 77.
C   94-10-11  HENRICHSEN     PASS IN INDEF ARG.
C 1999-08-01  KRISHNA KUMAR  CONVERTED THIS CODE FROM CRAY TO IBM 
C                            RS/6000.
C
C USAGE:   CALL CLEAR(BLAT,XINDEF,FLD,IMAX,JMAX,KEY,IRTN)
C   INPUT  ARGUMENT LIST:
C     BLAT     - REAL*4  THE GIVEN MAXIMUM LATITUDE FOR WHICH
C                INDEFINITES WILL BE INSERTED INTO DATA FIELD.
C     XINDEF   - REAL*4  THE GIVEN VALUE TO BE PUT IN FIELD.
C     FLD      - REAL*4 (IMAX,JMAX) ARRAY CONTAINING DATA FIELD.
C     IMAX/JMAX- INTEGER*4 DIMENSIONS OF FLD.
C     KEY      - INTEGER*4 GRID KEY FLAG USED FOR SUB TRULL.
C
C   OUTPUT ARGUMENT LIST:
C     IRTN     - RETURN CODE.
C              - =0 EVERYTHING OK.
C              - =1 KEY OUT OF RANGE (RANGE IS 1 TO 14).
C
C REMARKS:
C
C ATTRIBUTES:
C   LANGUAGE: F90
C   MACHINE:  IBM
C
C$$$
C
C
      REAL   ALAT
      REAL   ALONG
      REAL   BLAT
      REAL   FLD(IMAX,JMAX)
      REAL   XI
      REAL   XINDEF
      REAL   XJ
C
C    CHECK VALUE OF KEY
C
      IRTN = 0
      NUMPNT = 0
      PRINT *, ' KEYCLR = ',KEY
      IF(KEY.GT.0.AND.KEY.LE.14) THEN
C
          DO J=1,JMAX
             XJ = J
            DO  I=1,IMAX
              XI = I
              CALL TRULL(XI,XJ,ALAT,ALONG,KEY)
C
C              CHECK TO SEE IF ALAT IS LESS THAN OR EQ TO BLAT.
C              IF TRUE LOAD AN INDEF AT THAT GRID POINT.
C
              IF(ALAT.LE.BLAT) THEN
C
                 FLD(I,J) = XINDEF
                 NUMPNT = NUMPNT + 1
              ENDIF
            ENDDO
          ENDDO
C
        WRITE(6,FMT='('' CLEAR; FILLED '',I4,'' POINTS OUT SIDE'',
     1   '' OF '',F5.2,'' WITH INDEFINITES USING GRID KEY='',I2)')
     2      NUMPNT,BLAT,KEY
      ELSE
C
C       KEY IS OUT OF RANGE.
C
        WRITE(6,FMT='('' *** ERROR SUB CLEAR;'',
     1       '' GRID KEY VALUE '',I2,'' IS BAD.'')')KEY
           IRNT = 1
       ENDIF
      RETURN
      END