! wrapfort_libf.f90
!     Auxiliary Fortran routines for Wrapfort
!

! fort_set_logical --
!     Set a logical value (from C to Fortran)
!
! Arguments:
!     var           Variable to be set
!     clog          Set to true (if /= 0), to false (if 0)
!
subroutine fort_set_logical( var, clog )
    logical :: var
    integer :: clog

    var = clog .ne. 0
end subroutine fort_set_logical

! fort_get_logical --
!     Get a logical value (from Fortran to C)
!
! Arguments:
!     var           Variable to be set
!     log           Set to 1 (if true), to 0 (if false)
!
subroutine fort_get_logical( var, flog )
    integer :: var
    logical :: flog

    var = merge(1,0,flog)
end subroutine fort_get_logical
