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
	
	if test -n "$dportsdir" ; then
	  if test -d "$dportsdir" -a -e "$dportsdir/PortIndex" ; then
		:
	  else
		AC_MSG_ERROR([$dportsdir not a valid dports tree])
	  fi
	else
		dnl If the user didn't give a path, look for default
		if test -n "$1" ; then
		  if test -d "$1" -a -e "$1/PortIndex" ; then
			dportsdir=$1
		  fi
		fi
	fi

	if test -n "$dportsdir" ; then
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
		portconfigdir="\${sysconfdir}/ports"
	else
		dnl just use the default /etc/ports
		portconfigdir="/etc/ports"
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

# OD_PROG_MD5
#---------------------------------------
AC_DEFUN([OD_PROG_MD5],[

	AC_PATH_PROG([MD5], [md5], ,  [ $PATH:/usr/bin:/bin ])

	if test "x$MD5" = "x" ; then
		AC_PATH_PROG([OPENSSL], [openssl],
			[AC_MSG_ERROR([No suitable md5 program found])],
			[ $PATH:/usr/local/openssl/bin:/usr/bin:/bin ])

		MD5="$OPENSSL md5"
	fi

	AC_SUBST(MD5)
])
