builtin(include,tcl.m4)

dnl This macro checks if the user specified a dports tree
dnl explicitly. If not, search for it

# OD_PATH_DPORTSDIR(DEFAULT_DPORTSDIR)
#---------------------------------------
AC_DEFUN([OD_PATH_DPORTSDIR],[
	dnl For ease of reading, run after gcc has been found/configured
	AC_REQUIRE([AC_PROG_CC])

	AC_ARG_WITH(dports-dir, [AC_HELP_STRING([--with-dports-dir=DIR], [Specify alternate dports directory])], [ dportsdir="$withval" ] )


	AC_MSG_CHECKING([for dports tree])
	
	if test "x$dportsdir" != "x" ; then
	  if test -d "$dportsdir" -a -e "$dportsdir/PortIndex" ; then
		:
	  else
		AC_MSG_ERROR([$dportsdir not a valid dports tree])
	  fi
	else
		dnl If the user didn't give a path, look for default
		if test "x$1" != "x" ; then
		  if test -d "$1" -a -e "$1/PortIndex" ; then
			dportsdir=$1
		  fi
		fi
	fi

	if test "x$dportsdir" != "x" ; then
		AC_MSG_RESULT($dportsdir)
		DPORTSDIR="$dportsdir"
		AC_SUBST(DPORTSDIR)
	else
		AC_MSG_WARN([No dports tree found])
	fi

        ])


# OD_PATH_PORTCONFIGDIR(DEFAULT_PORTCONFIGDIR, PREFIX)
#---------------------------------------
AC_DEFUN([OD_PATH_PORTCONFIGDIR],[
	dnl if the user actually specified --prefix, shift
	dnl portconfigdir to $prefix/etc/ports
	AC_REQUIRE([OD_PATH_DPORTSDIR])
	
        AC_MSG_CHECKING([for ports config directory])

	if test "$2" != "NONE" ; then
		dnl user gave --prefix
		portconfigdir='${sysconfdir}/ports'
	else
		dnl just use the default /etc/ports
		portconfigdir='/etc/ports'
	fi


	AC_MSG_RESULT([$portconfigdir])
	PORTCONFIGDIR="$portconfigdir"
        AC_SUBST(PORTCONFIGDIR)

	])

# OD_CHECK_INSTALLUSER
#-------------------------------------------------
AC_DEFUN([OD_CHECK_INSTALLUSER],[
	dnl if with user specifies --with-install-user,
	dnl use it. otherwise default to platform defaults
        AC_REQUIRE([OD_PATH_PORTCONFIGDIR])

	AC_ARG_WITH(install-user, [AC_HELP_STRING([--with-install-user=USER], [Specify user ownership of installed files])], [ DSTUSR=$withval ] )

	AC_MSG_CHECKING([for install user])
	if test "x$DSTUSR" = "x" ; then
	   DSTUSR=root
	fi

	AC_MSG_RESULT([$DSTUSR])
	AC_SUBST(DSTUSR)
])

# OD_CHECK_INSTALLGROUP
#-------------------------------------------------
AC_DEFUN([OD_CHECK_INSTALLGROUP],[
	dnl if with user specifies --with-install-group,
	dnl use it. otherwise default to platform defaults
        AC_REQUIRE([OD_CHECK_INSTALLUSER])

	AC_ARG_WITH(install-group, [AC_HELP_STRING([--with-install-group=GROUP], [Specify group ownership of installed files])], [ DSTGRP=$withval ] )

	AC_MSG_CHECKING([for install group])
	if test "x$DSTGRP" = "x" ; then
	   
	   case $host_os in
	   darwin*)
		DSTGRP="admin"
		;;
	   *)
		DSTGRP="wheel"
		;;
	   esac
	fi

	AC_MSG_RESULT([$DSTGRP])
	AC_SUBST(DSTGRP)
])

# OD_LIB_MD5
#---------------------------------------
# Check for an md5 implementation
AC_DEFUN([OD_LIB_MD5],[

	# Check for libmd, which is prefered
	AC_CHECK_LIB([md], [MD5Update],[
		AC_CHECK_HEADERS([md5.h], ,[
			AC_MSG_ERROR([libmd was found, but md5.h is missing.])])
		AC_DEFINE([HAVE_LIBMD], ,[Define if you have the `md' library (-lmd).])
		MD5_LIBS="-lmd"]
	)
	if test "x$MD5_LIBS" = "x" ; then
		# If libmd is not found, check for libcrypto from OpenSSL
		AC_CHECK_LIB([crypto], [MD5_Update],[
			AC_CHECK_HEADERS([openssl/md5.h],,[
				AC_MSG_ERROR([libcrypt was found, but header file openssl/md5.h is missing.])])
				AC_DEFINE([HAVE_LIBCRYPTO],,[Define if you have the `crypto' library (-lcrypto).])
			MD5_LIBS="-lcrypto"
		], [
			AC_MSG_ERROR([Neither OpenSSL or libmd were found. A working md5 implementation is required.])
		])
	fi
	if test "x$MD5_LIBS" = "x"; then
		AC_MSG_ERROR([Neither OpenSSL or libmd were found. A working md5 implementation is required.])
	fi
	AC_SUBST([MD5_LIBS])
])

# OD_PROG_MTREE
#---------------------------------------
AC_DEFUN([OD_PROG_MTREE],[

	AC_PATH_PROG([MTREE], [mtree], ,  [/usr/bin:/usr/sbin:/bin:/sbin])

	if test "x$MTREE" = "x" ; then
		AC_CONFIG_SUBDIRS([src/programs/mtree])
		MTREE='$(TOPSRCDIR)/src/programs/mtree/mtree'
#		MTREE='${prefix}/bin/mtree'
		REPLACEMENT_PROGS="$REPLACEMENT_PROGS mtree"
	fi

	AC_SUBST(MTREE)
])

#------------------------------------------------------------------------
# OD_TCL_PACKAGE_DIR --
#
#	Locate the correct directory for Tcl package installation
#
# Arguments:
#	None.
#
# Requires:
#	TCLVERSION must be set
#	CYGPATH must be set
#	TCLSH must be set
#
# Results:
#
#	Adds a --with-tclpackage switch to configure.
#	Result is cached.
#
#	Substs the following vars:
#		TCL_PACKAGE_DIR
#------------------------------------------------------------------------

AC_DEFUN(OD_TCL_PACKAGE_DIR, [
    AC_MSG_CHECKING(for Tcl package directory)

    AC_ARG_WITH(tclpackage, [  --with-tclpackage       Tcl package installation directory.], with_tclpackagedir=${withval})

    if test x"${with_tclpackagedir}" != x ; then
	ac_cv_c_tclpkgd=${with_tclpackagedir}
    else
	AC_CACHE_VAL(ac_cv_c_tclpkgd, [
	    # Use the value from --with-tclpackagedir, if it was given

	    if test x"${with_tclpackagedir}" != x ; then
		ac_cv_c_tclpkgd=${with_tclpackagedir}
	    else
		# On darwin we can do some intelligent guessing
		case $host_os in
		    darwin*)
		    	tcl_autopath=`echo 'puts \$auto_path' | $TCLSH`
			for path in $tcl_autopath; do
			    if test "$path" = "/Library/Tcl"; then
				ac_cv_c_tclpkgd="$path"
				break
			    fi
			    if test "$path" = "/System/Library/Tcl"; then
				if test -d "$path"; then
				    ac_cv_c_tclpkgd="$path"
				    break
			        fi
			    fi
			done
		    ;;
		esac
    		if test x"${ac_cv_c_tclpkgd}" = x ; then
		    # Fudge a path from the first entry in the auto_path
		    tcl_pkgpath=`echo 'puts [[lindex \$auto_path 0]]' | $TCLSH`
		    if test -d "$tcl_pkgpath"; then
			ac_cv_c_tclpkgd="$tcl_pkgpath"
		    fi
		    # If the first entry does not exist, do nothing
		fi
	    fi
	])
    fi

    if test x"${ac_cv_c_tclpkgd}" = x ; then
	AC_MSG_ERROR(Tcl package directory not found.  Please specify its location with --with-tclpackagedir)
    else
	AC_MSG_RESULT(${ac_cv_c_tclpkgd})
    fi

    # Convert to a native path and substitute into the output files.

    PACKAGE_DIR_NATIVE=`${CYGPATH} ${ac_cv_c_tclpkgd}`

    TCL_PACKAGE_DIR=${PACKAGE_DIR_NATIVE}

    AC_SUBST(TCL_PACKAGE_DIR)
])

# OD_PROG_TCLSH
#---------------------------------------
AC_DEFUN([OD_PROG_TCLSH],[


	case $host_os in
		freebsd*)
			# FreeBSD installs a dummy tclsh (annoying)
			# Look for a real versioned tclsh first
			AC_PATH_PROG([TCLSH], [tclsh${TCL_VERSION} tclsh])
			;;
		*)
			# Otherwise, look for a non-versioned tclsh
			AC_PATH_PROG([TCLSH], [tclsh tclsh${TCL_VERSION}])
			;;
	esac
	if test "x$TCLSH" = "x" ; then
		AC_MSG_ERROR([Could not find tclsh])
	fi

	AC_SUBST(TCLSH)
])

