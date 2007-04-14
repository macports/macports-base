builtin(include,tcl.m4)

#------------------------------------------------------------------------
# OD_CHECK_FRAMEWORK_COREFOUNDATION --
#
#	Check if CoreFoundation framework is available, define HAVE_FRAMEWORK_COREFOUNDATION if so.
#
# Arguments:
#       None.
#
# Requires:
#       None.
#
# Depends:
#		AC_LANG_PROGRAM
#
# Results:
#       Result is cached.
#
#	If CoreFoundation framework is available, defines the following variables:
#		HAVE_FRAMEWORK_COREFOUNDATION
#
#------------------------------------------------------------------------
AC_DEFUN(OD_CHECK_FRAMEWORK_COREFOUNDATION, [
	FRAMEWORK_LIBS="-framework CoreFoundation"

	AC_MSG_CHECKING([for CoreFoundation framework])

	AC_CACHE_VAL(od_cv_have_framework_corefoundation, [
		ac_save_LIBS="$LIBS"
		LIBS="$FRAMEWORK_LIBS $LIBS"
		
		AC_LINK_IFELSE([
			AC_LANG_PROGRAM([
					#include <CoreFoundation/CoreFoundation.h>
				], [
					CFURLRef url = CFURLCreateWithFileSystemPath(NULL, CFSTR("/testing"), kCFURLPOSIXPathStyle, 1);
					CFArrayRef bundles = CFBundleCreateBundlesFromDirectory(NULL, url, CFSTR("pkg"));
			])
			], [
				od_cv_have_framework_corefoundation="yes"
			], [
				od_cv_have_framework_corefoundation="no"
			]
		)

		LIBS="$ac_save_LIBS"
	])

	AC_MSG_RESULT(${od_cv_have_framework_corefoundation})

	if test x"${od_cv_have_framework_corefoundation}" = "xyes"; then
		AC_DEFINE([HAVE_FRAMEWORK_COREFOUNDATION], [], [Define if CoreFoundation framework is available])
	fi

	AC_SUBST(HAVE_FRAMEWORK_COREFOUNDATION)
])


#------------------------------------------------------------------------
# OD_CHECK_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER --
#
#	Check if if the routine CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER
#	is available in CoreFoundation.
#
# Arguments:
#       None.
#
# Requires:
#       None.
#
# Depends:
#		AC_LANG_PROGRAM
#
# Results:
#       Result is cached.
#
#	If function CFNotificationCenterGetDarwinNotifyCenter is in the CoreFoundation framework, defines the following variables:
#		HAVE_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER
#
#------------------------------------------------------------------------
AC_DEFUN(OD_CHECK_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER, [
	FRAMEWORK_LIBS="-framework CoreFoundation"

	AC_MSG_CHECKING([for CFNotificationCenterGetDarwinNotifyCenter])

	AC_CACHE_VAL(od_cv_have_function_cfnotificationcentergetdarwinnotifycenter, [
		ac_save_LIBS="$LIBS"
		LIBS="$FRAMEWORK_LIBS $LIBS"
		
		AC_LINK_IFELSE([
			AC_LANG_PROGRAM([
					#include <CoreFoundation/CoreFoundation.h>
				], [
					CFNotificationCenterRef ref = CFNotificationCenterGetDarwinNotifyCenter();
			])
			], [
				od_cv_have_function_cfnotificationcentergetdarwinnotifycenter="yes"
			], [
				od_cv_have_function_cfnotificationcentergetdarwinnotifycenter="no"
			]
		)

		LIBS="$ac_save_LIBS"
	])

	AC_MSG_RESULT(${od_cv_have_function_cfnotificationcentergetdarwinnotifycenter})

	if test x"${od_cv_have_function_cfnotificationcentergetdarwinnotifycenter}" = "xyes"; then
		AC_DEFINE([HAVE_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER], [], [Define if function CFNotificationCenterGetDarwinNotifyCenter in CoreFoundation framework])
	fi

	AC_SUBST(HAVE_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER)
])


#------------------------------------------------------------------------
# OD_CHECK_FRAMEWORK_SYSTEMCONFIGURATION --
#
#	Check if SystemConfiguration framework is available, define HAVE_FRAMEWORK_SYSTEMCONFIGURATION if so.
#
# Arguments:
#       None.
#
# Requires:
#       None.
#
# Depends:
#		AC_LANG_PROGRAM
#
# Results:
#       Result is cached.
#
#	If SystemConfiguration framework is available, defines the following variables:
#		HAVE_FRAMEWORK_SYSTEMCONFIGURATION
#
#------------------------------------------------------------------------
AC_DEFUN(OD_CHECK_FRAMEWORK_SYSTEMCONFIGURATION, [
	FRAMEWORK_LIBS="-framework SystemConfiguration"

	AC_MSG_CHECKING([for SystemConfiguration framework])

	AC_CACHE_VAL(od_cv_have_framework_systemconfiguration, [
		ac_save_LIBS="$LIBS"
		LIBS="$FRAMEWORK_LIBS $LIBS"
		
		AC_LINK_IFELSE([
			AC_LANG_PROGRAM([
					#include <SystemConfiguration/SystemConfiguration.h>
				], [
					int err = SCError();
					SCDynamicStoreRef dsRef = SCDynamicStoreCreate(NULL, NULL, NULL, NULL);
			])
			], [
				od_cv_have_framework_systemconfiguration="yes"
			], [
				od_cv_have_framework_systemconfiguration="no"
			]
		)

		LIBS="$ac_save_LIBS"
	])

	AC_MSG_RESULT(${od_cv_have_framework_systemconfiguration})

	if test x"${od_cv_have_framework_systemconfiguration}" = "xyes"; then
		AC_DEFINE([HAVE_FRAMEWORK_SYSTEMCONFIGURATION], [], [Define if SystemConfiguration framework is available])
	fi

	AC_SUBST(HAVE_FRAMEWORK_SYSTEMCONFIGURATION)
])


#------------------------------------------------------------------------
# OD_CHECK_FRAMEWORK_IOKIT --
#
#	Check if IOKit framework is available, define HAVE_FRAMEWORK_IOKIT if so.
#
# Arguments:
#       None.
#
# Requires:
#       None.
#
# Depends:
#		AC_LANG_PROGRAM
#
# Results:
#       Result is cached.
#
#	If IOKit framework is available, defines the following variables:
#		HAVE_FRAMEWORK_IOKIT
#
#------------------------------------------------------------------------
AC_DEFUN(OD_CHECK_FRAMEWORK_IOKIT, [
	FRAMEWORK_LIBS="-framework IOKit"

	AC_MSG_CHECKING([for IOKit framework])

	AC_CACHE_VAL(od_cv_have_framework_iokit, [
		ac_save_LIBS="$LIBS"
		LIBS="$FRAMEWORK_LIBS $LIBS"
		
		AC_LINK_IFELSE([
			AC_LANG_PROGRAM([
					#include <IOKit/IOKitLib.h>
				], [
					IOCreateReceivePort(0, NULL);
					IORegisterForSystemPower(0, NULL, NULL, NULL);
			])
			], [
				od_cv_have_framework_iokit="yes"
			], [
				od_cv_have_framework_iokit="no"
			]
		)

		LIBS="$ac_save_LIBS"
	])

	AC_MSG_RESULT(${od_cv_have_framework_iokit})

	if test x"${od_cv_have_framework_iokit}" = "xyes"; then
		AC_DEFINE([HAVE_FRAMEWORK_IOKIT], [], [Define if IOKit framework is available])
	fi

	AC_SUBST(HAVE_FRAMEWORK_IOKIT)
])


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


# OD_PATH_PORTCONFIGDIR
#---------------------------------------
AC_DEFUN([OD_PATH_PORTCONFIGDIR],[
	dnl if the user actually specified --prefix, shift
	dnl portconfigdir to $prefix/etc/ports
	dnl 	AC_REQUIRE([OD_PATH_DPORTSDIR])
	
        AC_MSG_CHECKING([for ports config directory])

	portconfigdir='${sysconfdir}/ports'

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

# OD_DIRECTORY_MODE
#-------------------------------------------------
AC_DEFUN([OD_DIRECTORY_MODE],[
	dnl if with user specifies --with-directory-mode,
	dnl use the specified permissions for ${prefix} directories
	dnl otherwise use 0775
        AC_REQUIRE([OD_PATH_PORTCONFIGDIR])

	AC_ARG_WITH(directory-mode, [AC_HELP_STRING([--with-directory-mode=MODE], [Specify directory mode of installed directories])], [ DSTMODE=$withval ] )
	
	AC_MSG_CHECKING([what permissions to use for installation directories])
	if test "x$DSTMODE" = "x" ; then
	   DSTMODE=0775
	fi

	AC_MSG_RESULT([$DSTMODE])
	AC_SUBST(DSTMODE)
])

# OD_LIB_MD5
#---------------------------------------
# Check for an md5 implementation
AC_DEFUN([OD_LIB_MD5],[

	# Check for libmd, which is prefered
	AC_CHECK_LIB([md], [MD5Update],[
		AC_CHECK_HEADERS([md5.h], ,[
			case $host_os in
				darwin*)	
					AC_MSG_NOTICE([Please install the BSD SDK package from the Xcode Developer Tools CD.])
					;;
				*)	
					AC_MSG_NOTICE([Please install the libmd developer headers for your platform.])
					;;
			esac
			AC_MSG_ERROR([libmd was found, but md5.h is missing.])
		])
		AC_DEFINE([HAVE_LIBMD], ,[Define if you have the `md' library (-lmd).])
		MD5_LIBS="-lmd"]
	)
	if test "x$MD5_LIBS" = "x" ; then
		# If libmd is not found, check for libcrypto from OpenSSL
		AC_CHECK_LIB([crypto], [MD5_Update],[
			AC_CHECK_HEADERS([openssl/md5.h],,[
				case $host_os in
					darwin*)	
					AC_MSG_NOTICE([Please install the BSD SDK package from the Xcode Developer Tools CD.])
						;;
					*)	
					AC_MSG_NOTICE([Please install the libmd developer headers for your platform.])
						;;
				esac
				AC_MSG_ERROR([libcrypt was found, but header file openssl/md5.h is missing.])
			])
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

dnl This macro checks for X11 presence. If the libraries are
dnl present, so must the headers be. If nothing is present,
dnl print a warning

# OD_CHECK_X11
# ---------------------
AC_DEFUN([OD_CHECK_X11], [

	AC_PATH_XTRA

	# Check for libX11
	AC_CHECK_LIB([X11], [XOpenDisplay],[
		has_x_runtime=yes
		], [ has_x_runtime=no ], [-L/usr/X11R6/lib $X_LIBS])

# 	echo "------done---------"
# 	echo "x_includes=${x_includes}"
# 	echo "x_libraries=${x_libraries}"
# 	echo "no_x=${no_x}"
# 	echo "X_CFLAGS=${X_CFLAGS}"
# 	echo "X_LIBS=${X_LIBS}"
# 	echo "X_DISPLAY_MISSING=${X_DISPLAY_MISSING}"
# 	echo "has_x_runtime=${has_x_runtime}"
# 	echo "host_os=${host_os}"
# 	echo "------done---------"

	state=

	case "__${has_x_runtime}__${no_x}__" in
		"__no__yes__")
		# either the user said --without-x, or it was not found
		# at all (runtime or headers)
			AC_MSG_WARN([X11 not available. You will not be able to use dports that use X11])
			state=0
			;;
		"__yes__yes__")
			state=1
			;;
		"__yes____")
			state=2
			;;
		*)
			state=3
			;;
	esac

	case $host_os in
		darwin*)	
			case $state in
				1)
					cat <<EOF;
Please install the X11 SDK packages from the
Xcode Developer Tools CD
EOF
					AC_MSG_ERROR([Broken X11 install. No X11 headers])

					;;
				3)
					cat <<EOF;
Unknown configuration problem. Please install the X11 runtime
and/or X11 SDK  packages from the Xcode Developer Tools CD
EOF
					AC_MSG_ERROR([Broken X11 install])
					;;
			esac
			;;
		*)	
			case $state in
				1)
					cat <<EOF;
Please install the X11 developer headers for your platform
EOF
					AC_MSG_ERROR([Broken X11 install. No X11 headers])

					;;
				3)
					cat <<EOF;
Unknown configuration problem. Please install the X11
implementation for your platform
EOF
					AC_MSG_ERROR([Broken X11 install])
					;;
			esac
			;;
	esac

])

# OD_PROG_MTREE
#---------------------------------------
AC_DEFUN([OD_PROG_MTREE],[

	AC_PATH_PROG([MTREE], [mtree], ,  [/usr/bin:/usr/sbin:/bin:/sbin])

	if test "x$MTREE" = "x" ; then
		AC_CONFIG_SUBDIRS([src/programs/mtree])
		MTREE='$(TOPSRCDIR)/src/programs/mtree/mtree'
		REPLACEMENT_PROGS="$REPLACEMENT_PROGS mtree"
	fi

	AC_SUBST(MTREE)
])

# OD_PROG_XAR
#---------------------------------------
AC_DEFUN([OD_PROG_XAR],[

	AC_PATH_PROG([XAR], [xar], ,  [/usr/bin:/usr/sbin:/bin:/sbin])

	if test "x$XAR" = "x" ; then
		AC_CONFIG_SUBDIRS([src/programs/xar])
		XAR='$(TOPSRCDIR)/src/programs/xar/xar'
		REPLACEMENT_PROGS="$REPLACEMENT_PROGS xar"
	fi

	AC_SUBST(XAR)
])

# OD_PROG_DAEMONDO
#---------------------------------------
AC_DEFUN([OD_PROG_DAEMONDO],[
	AC_REQUIRE([OD_CHECK_FRAMEWORK_COREFOUNDATION])
	AC_REQUIRE([OD_CHECK_FRAMEWORK_SYSTEMCONFIGURATION])
	AC_REQUIRE([OD_CHECK_FRAMEWORK_IOKIT])
	AC_REQUIRE([OD_CHECK_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER])
	
    AC_MSG_CHECKING(for whether we will build daemondo)
    result=no
	case $host_os in
	darwin*)
		if test "x$od_cv_have_framework_corefoundation" == "xyes" &&
		   test "x$od_cv_have_framework_systemconfiguration" == "xyes" &&
		   test "x$od_cv_have_framework_iokit" == "xyes" &&
		   test "x$od_cv_have_function_cfnotificationcentergetdarwinnotifycenter" == "xyes"; then
			result=yes
			EXTRA_PROGS="$EXTRA_PROGS daemondo"
			AC_CONFIG_FILES([src/programs/daemondo/Makefile])
		fi
		;;
	*)
	esac
	AC_MSG_RESULT(${result})
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
	    # Use the value from --with-tclpackage, if it was given

	    if test x"${with_tclpackagedir}" != x ; then
		echo "tclpackagedir"
		ac_cv_c_tclpkgd=${with_tclpackagedir}
	    else
		# On darwin we can do some intelligent guessing
		case $host_os in
		    darwin*)
		    	tcl_autopath=`echo 'puts -nonewline \$auto_path' | $TCLSH`
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
		    tcl_pkgpath=`echo 'puts -nonewline [[lindex \$auto_path 0]]' | $TCLSH`
		    if test -d "$tcl_pkgpath"; then
			ac_cv_c_tclpkgd="$tcl_pkgpath"
		    fi
		    # If the first entry does not exist, do nothing
		fi
	    fi
	])
    fi

    if test x"${ac_cv_c_tclpkgd}" = x ; then
	AC_MSG_ERROR(Tcl package directory not found.  Please specify its location with --with-tclpackage)
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

# OD_TCL_PACKAGE
#	Determine if a Tcl package is present.
#
# Arguments:
#	Package name (may include the version)
#
# Syntax:
#   OD_TCL_PACKAGE (package, [action-if-found], [action-if-not-found])
#
# Requires:
#	TCLSH must be set
#
# Results:
#	Execute action-if-found or action-if-not-found
#---------------------------------------
AC_DEFUN([OD_TCL_PACKAGE],[
	AC_MSG_CHECKING([for Tcl $1 package])
	package_present=`echo 'if {[[catch {package require $1}]]} {puts -nonewline 0} else {puts -nonewline 1}' | $TCLSH`
	AS_IF([test "$package_present" = "1"], [$2], [$3])[]
])

# OD_TCL_THREAD_SUPPORT
#	Determine if thread support is available in tclsh.
#
# Arguments:
#	None.
#
# Requires:
#	TCLSH must be set
#
# Results:
#   Fails if thread support isn't available.
#---------------------------------------
AC_DEFUN([OD_TCL_THREAD_SUPPORT],[
	AC_MSG_CHECKING([whether tclsh was compiled with threads])
	tcl_threadenabled=`echo 'puts -nonewline [[info exists tcl_platform(threaded)]]' | $TCLSH`
	if test "$tcl_threadenabled" = "1" ; then
		AC_MSG_RESULT([yes])
	else
		AC_MSG_RESULT([no])
		AC_MSG_ERROR([tcl wasn't compiled with threads enabled])
	fi
])

# OD_LIBCURL_FLAGS
#	Sets the flags to compile with libcurl.
#
# Arguments:
#	None.
#
# Requires:
#   curl-config or user parameters to define the flags.
#
# Results:
#   defines some help strings.
#   sets CFLAGS_LIBCURL and LDFLAGS_LIBCURL
#---------------------------------------
AC_DEFUN([OD_LIBCURL_FLAGS],[
	AC_ARG_WITH(curlprefix,
		   [  --with-curlprefix       base directory for the cURL install '/usr', '/usr/local',...],
		   [  curlprefix=$withval ])

	if test "x$curlprefix" = "x"; then
		AC_PATH_PROG([CURL_CONFIG], [curl-config])
	else
		AC_PATH_PROG([CURL_CONFIG], [curl-config], , [$curlprefix/bin])
	fi

	if test "x$CURL_CONFIG" = "x"; then
		AC_MSG_ERROR([cannot find curl-config. Is libcurl installed?])
	fi

	CFLAGS_LIBCURL=$($CURL_CONFIG --cflags)
	# Due to a bug in dist, --arch flags are improperly supplied by curl-config.
	# Get rid of them.
	LDFLAGS_LIBCURL=$($CURL_CONFIG --libs | [sed 's/-arch [A-Za-z0-9]* //g'])

	AC_SUBST(CFLAGS_LIBCURL)
	AC_SUBST(LDFLAGS_LIBCURL)
])

# OD_LIBCURL_VERSION
#	Determine the version of libcurl.
#
# Arguments:
#	None.
#
# Requires:
#	CURL must be set (AC_PATH_PROG(CURL, [curl], []))
#
# Results:
#   sets libcurl_version to "0" or some number
#---------------------------------------
AC_DEFUN([OD_LIBCURL_VERSION],[
	if test "x$CURL" = "x"; then
		libcurl_version="0"
	else
		AC_MSG_CHECKING([libcurl version])
		libcurl_version=`$CURL -V | sed '2,$d' | awk '{print $ 2}' | sed -e 's/\.//g' -e 's/-.*//g'`
		AC_MSG_RESULT([$libcurl_version])
	fi
])


# OD_PATH_SQLITE3
#	Specify sqlite3 location
#
# Arguments:
#	None.
#
# Requires:
#   System or user-specified --with-sqlite=dir to specify
#
# Results:
#   Sets SQLITE3_DIR to the directory where sqlite3 tcl pkgIndex.tcl is
#---------------------------------------
AC_DEFUN([OD_PATH_SQLITE3],[

	AC_ARG_WITH([sqlite],
		AS_HELP_STRING([--with-sqlite3=DIR],
			[directory for sqlite3 (default /usr/lib/sqlite3)]),		
		[od_sqlite3_dir=$withval], [od_sqlite3_dir=/usr/lib/sqlite3])
		
	AC_CACHE_CHECK([for sqlite3 location], [od_cv_sqlite3_dir],
		[od_cv_sqlite3_dir=
		test -r "${od_sqlite3_dir}/pkgIndex.tcl" && od_cv_sqlite3_dir=$od_sqlite3_dir
		])
		
	SQLITE3_DIR=$od_cv_sqlite3_dir
	AC_SUBST(SQLITE3_DIR)
])

dnl This macro tests if the compiler supports GCC's
dnl __attribute__ syntax for unused variables/parameters
AC_DEFUN([OD_COMPILER_ATTRIBUTE_UNUSED], [
	AC_MSG_CHECKING([how to mark unused variables])
	AC_COMPILE_IFELSE(
		[AC_LANG_SOURCE([[int a __attribute__ ((unused));]])],
		[AC_DEFINE(UNUSED, [__attribute__((unused))], [Attribute to mark unused variables])],
		[AC_DEFINE(UNUSED, [])])

	AC_MSG_RESULT([])
	
])

dnl This macro ensures DP installation prefix bin/sbin paths are NOT in PATH
dnl for configure to prevent potential problems when base/ code is updated
dnl and ports are installed that would match needed items.
AC_DEFUN([OD_PATH_SCAN],[
	oldprefix=$prefix
	if test "x$prefix" = "xNONE" ; then
		prefix=$ac_default_prefix
	fi
	oldPATH=$PATH
	newPATH=
	as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
	for as_dir in $oldPATH
	do
		IFS=$as_save_IFS
		if test "x$as_dir" != "x$prefix/bin" &&
			test "x$as_dir" != "x$prefix/sbin"; then
			if test -z "$newPATH"; then
				newPATH=$as_dir
			else
				newPATH=$newPATH$PATH_SEPARATOR$as_dir
			fi
		fi
	done
	PATH=$newPATH; export PATH
	prefix=$oldprefix
])

dnl This macro tests for tar support of --no-same-owner
AC_DEFUN([OD_TAR_NO_SAME_OWNER],[
	AC_PATH_PROG(TAR, [tar])
	AC_PATH_PROG(GNUTAR, [gnutar])
	
	AC_MSG_CHECKING([for which tar variant to use])
	AS_IF([test -n "$GNUTAR"], [TAR_CMD=$GNUTAR], [TAR_CMD=$TAR])
	AC_MSG_RESULT([$TAR_CMD])
	AC_SUBST(TAR_CMD)

	AC_MSG_CHECKING([for $TAR_CMD --no-same-owner support])
	[no_same_owner_support=`$TAR_CMD --help 2>&1 | grep no-same-owner`]
	if test -z "$no_same_owner_support" ; then
		AC_MSG_RESULT([no])
	else
		AC_MSG_RESULT([yes])
		TAR_CMD="$TAR_CMD --no-same-owner"
	fi
])

#------------------------------------------------------------------------
# DP_CHECK_READLINK_IS_P1003_1A --
#
#	Check if readlink conforms to POSIX 1003.1a standard, define
#	READLINK_IS_NOT_P1003_1A if it doesn't.
#
# Arguments:
#       None.
#
# Requires:
#       None.
#
# Depends:
#		AC_LANG_PROGRAM
#
# Results:
#       Result is cached.
#
#	If readlink doesn't conform to POSIX 1003.1a, defines the following variables:
#		READLINK_IS_NOT_P1003_1A
#
#------------------------------------------------------------------------
AC_DEFUN(DP_CHECK_READLINK_IS_P1003_1A, [
	AC_MSG_CHECKING([if readlink conforms to POSIX 1003.1a])

	AC_CACHE_VAL(dp_cv_readlink_is_posix_1003_1a, [
		AC_COMPILE_IFELSE([
			AC_LANG_PROGRAM([
					#include <unistd.h>
					ssize_t readlink(const char *, char *, size_t);
				], [
			])
			], [
				dp_cv_readlink_is_posix_1003_1a="yes"
			], [
				dp_cv_readlink_is_posix_1003_1a="no"
			]
		)
	])

	AC_MSG_RESULT(${dp_cv_readlink_is_posix_1003_1a})

	if test x"${dp_cv_readlink_is_posix_1003_1a}" = "xno"; then
		AC_DEFINE([READLINK_IS_NOT_P1003_1A], [], [Define to 1 if readlink does not conform with POSIX 1003.1a (where third argument is a size_t and return value is a ssize_t)])
	fi

	AC_SUBST(READLINK_IS_NOT_P1003_1A)
])
