!**********************************************************************
!  ROUTINE:   FUZZY FORTRAN OPERATORS
!  PURPOSE:   Illustrate Hindmarsh's computation of EPS, and APL
!             tolerant comparisons, tolerant CEIL/FLOOR, and Tolerant
!             ROUND functions - implemented in Fortran.
!  PLATFORM:  PC Windows Fortran, Compaq-Digital CVF 6.1a, AIX XLF90
!  TO RUN:    Windows: DF EPS.F90
!             AIX: XLF90 eps.f -o eps.exe -qfloat=nomaf
!  CALLS:     none
!  AUTHOR:    H. D. Knoble <hdk@psu.edu> 22 September 1978
!  REVISIONS:
!**********************************************************************
!
      DOUBLE PRECISION EPS,EPS3, X,Y,Z, D1MACH,TFLOOR,TCEIL,EPSF90
      LOGICAL TEQ,TNE,TGT,TGE,TLT,TLE
!---Following are Fuzzy Comparison (arithmetic statement) Functions.
!
      TEQ(X,Y)=DABS(X-Y).LE.DMAX1(DABS(X),DABS(Y))*EPS3
      TNE(X,Y)=.NOT.TEQ(X,Y)
      TGT(X,Y)=(X-Y).GT.DMAX1(DABS(X),DABS(Y))*EPS3
      TLE(X,Y)=.NOT.TGT(X,Y)
      TLT(X,Y)=TLE(X,Y).AND.TNE(X,Y)
      TGE(X,Y)=TGT(X,Y).OR.TEQ(X,Y)
!
!---Compute EPS for this computer.  EPS is the smallest real number on
!   this architecture such that 1+EPS>1 and 1-EPS<1.
!   EPSILON(X) is a Fortran 90 built-in Intrinsic function. They should
!   be identically equal.
!
      EPS=D1MACH(NULL)
      EPSF90=EPSILON(X)
      IF(EPS.NE.EPSF90) THEN
        WRITE(*,2)'EPS=',EPS,' .NE. EPSF90=',EPSF90
2       FORMAT(A,Z16,A,Z16)
      ENDIF
!---Accept a representation if exact, or one bit on either side.
      EPS3=3.D0*EPS
      WRITE(*,1) EPS,EPS, EPS3,EPS3
1     FORMAT(' EPS=',D16.8,2X,Z16, ', EPS3=',D16.8,2X,Z16)
!---Illustrate Fuzzy Comparisons using EPS3. Any other magnitudes will
!   behave similarly.
      Z=1.D0
      I=49
        X=1.D0/I
        Y=X*I
        WRITE(*,*) 'X=1.D0/',I,', Y=X*',I,', Z=1.D0'
        WRITE(*,*) 'Y=',Y,' Z=',Z
        WRITE(*,3) X,Y,Z
3       FORMAT(' X=',Z16,' Y=',Z16,' Z=',Z16)
!---Floating-point Y is not identical (.EQ.) to floating-point Z.
        IF(Y.EQ.Z) WRITE(*,*) 'Fuzzy Comparisons: Y=Z'
        IF(Y.NE.Z) WRITE(*,*) 'Fuzzy Comparisons: Y<>Z'
!---But Y is tolerantly (and algebraically) equal to Z.
        IF(TEQ(Y,Z)) THEN
          WRITE(*,*) 'but TEQ(Y,Z) is .TRUE.'
          WRITE(*,*) 'That is, Y is computationally equal to Z.'
        ENDIF
        IF(TNE(Y,Z)) WRITE(*,*) 'and TNE(Y,Z) is .TRUE.'
      WRITE(*,*) ' '
!---Evaluate Fuzzy FLOOR and CEILing Function values using a Comparison
!   Tolerance, CT, of EPS3.
      X=0.11D0
      Y=((X*11.D0)-X)-0.1D0
      YFLOOR=TFLOOR(Y,EPS3)
      YCEIL=TCEIL(Y,EPS3)
55    Z=1.D0
      WRITE(*,*) 'X=0.11D0, Y=X*11.D0-X-0.1D0, Z=1.D0'
      WRITE(*,*) 'X=',X,' Y=',Y,' Z=',Z
      WRITE(*,3) X,Y,Z
!---Floating-point Y is not identical (.EQ.) to floating-point Z.
      IF(Y.EQ.Z) WRITE(*,*) 'Fuzzy FLOOR/CEIL: Y=Z'
      IF(Y.NE.Z) WRITE(*,*) 'Fuzzy FLOOR/CEIL: Y<>Z'
      IF(TFLOOR(Y,EPS3).EQ.TCEIL(Y,EPS3).AND.TFLOOR(Y,EPS3).EQ.Z) THEN
!---But Tolerant Floor/Ceil of Y is identical (and algebraically equal)
!   to Z.
        WRITE(*,*) 'but TFLOOR(Y,EPS3)=TCEIL(Y,EPS3)=Z.'
        WRITE(*,*) 'That is, TFLOOR/TCEIL return exact whole numbers.'
      ENDIF
      STOP
      END
      DOUBLE PRECISION FUNCTION D1MACH (IDUM)
      INTEGER IDUM
!=======================================================================
! This routine computes the unit roundoff of the machine in double
! precision.  This is defined as the smallest positive machine real
! number, EPS, such that (1.0D0+EPS > 1.0D0) & (1.D0-EPS < 1.D0).
! This computation of EPS is the work of Alan C. Hindmarsh.
! For computation of Machine Parameters also see:
!  W. J. Cody, "MACHAR: A subroutine to dynamically determine machine
!  parameters, " TOMS 14, December, 1988; or
!  Alan C. Hindmarsh at  http://www.netlib.org/lapack/util/dlamch.f
!  or Werner W. Schulz at  http://www.ozemail.com.au/~milleraj/ .
!
!  This routine appears to give bit-for-bit the same results as
!  the Intrinsic function EPSILON(x) for x single or double precision.
!  hdk - 25 August 1999.
!-----------------------------------------------------------------------
      DOUBLE PRECISION EPS, COMP
!     EPS = 1.0D0
!10   EPS = EPS*0.5D0
!     COMP = 1.0D0 + EPS
!     IF (COMP .NE. 1.0D0) GO TO 10
!     D1MACH = EPS*2.0D0
      EPS = 1.0D0
      COMP = 2.0D0
      DO WHILE ( COMP .NE. 1.0D0 )
         EPS = EPS*0.5D0
         COMP = 1.0D0 + EPS
      ENDDO
      D1MACH = EPS*2.0D0
      RETURN
      END
      DOUBLE PRECISION FUNCTION TFLOOR(X,CT)
!===========Tolerant FLOOR Function.
!
!    C  -  is given as a double precision argument to be operated on.
!          it is assumed that X is represented with m mantissa bits.
!    CT -  is   given   as   a   Comparison   Tolerance   such   that
!          0.lt.CT.le.3-Sqrt(5)/2. If the relative difference between
!          X and a whole number is  less  than  CT,  then  TFLOOR  is
!          returned   as   this   whole   number.   By  treating  the
!          floating-point numbers as a finite ordered set  note  that
!          the  heuristic  eps=2.**(-(m-1))   and   CT=3*eps   causes
!          arguments  of  TFLOOR/TCEIL to be treated as whole numbers
!          if they are  exactly  whole  numbers  or  are  immediately
!          adjacent to whole number representations.  Since EPS,  the
!          "distance"  between  floating-point  numbers  on  the unit
!          interval, and m, the number of bits in X's mantissa, exist
!          on  every  floating-point   computer,   TFLOOR/TCEIL   are
!          consistently definable on every floating-point computer.
!
!          For more information see the following references:
!    {1} P. E. Hagerty, "More on Fuzzy Floor and Ceiling," APL  QUOTE
!        QUAD 8(4):20-24, June 1978. Note that TFLOOR=FL5 took five
!        years of refereed evolution (publication).
!
!    {2} L. M. Breed, "Definitions for Fuzzy Floor and Ceiling",  APL
!        QUOTE QUAD 8(3):16-23, March 1978.
!
!   H. D. KNOBLE, Penn State University.
!=====================================================================
      DOUBLE PRECISION X,Q,RMAX,EPS5,CT,FLOOR,DINT
!---------FLOOR(X) is the largest integer algegraically less than
!         or equal to X; that is, the unfuzzy Floor Function.
      DINT(X)=X-DMOD(X,1.D0)
      FLOOR(X)=DINT(X)-DMOD(2.D0+DSIGN(1.D0,X),3.D0)
!---------Hagerty's FL5 Function follows...
      Q=1.D0
      IF(X.LT.0)Q=1.D0-CT
      RMAX=Q/(2.D0-CT)
      EPS5=CT/Q
      TFLOOR=FLOOR(X+DMAX1(CT,DMIN1(RMAX,EPS5*DABS(1.D0+FLOOR(X)))))
      IF(X.LE.0 .OR. (TFLOOR-X).LT.RMAX)RETURN
      TFLOOR=TFLOOR-1.D0
      RETURN
      END
      DOUBLE PRECISION FUNCTION TCEIL(X,CT)
!==========Tolerant Ceiling Function.
!    See TFLOOR.
      DOUBLE PRECISION X,CT,TFLOOR
      TCEIL= -TFLOOR(-X,CT)
      RETURN
      END
      DOUBLE PRECISION FUNCTION ROUND(X,CT)
!=========Tolerant Round Function
!  See Knuth, Art of Computer Programming, Vol. 1, Problem 1.2.4-5.
      DOUBLE PRECISION TFLOOR,X,CT
      ROUND=TFLOOR(X+0.5D0,CT)
      RETURN
      END
