dnl $Id$
builtin(include,m4/tcl.m4)
builtin(include,m4/pthread.m4)
builtin(include,m4/foundation.m4)

#------------------------------------------------------------------------
# MP_CHECK_FRAMEWORK_COREFOUNDATION --
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
AC_DEFUN(MP_CHECK_FRAMEWORK_COREFOUNDATION, [
	FRAMEWORK_LIBS="-framework CoreFoundation"

	AC_MSG_CHECKING([for CoreFoundation framework])

	AC_CACHE_VAL(mp_cv_have_framework_corefoundation, [
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
				mp_cv_have_framework_corefoundation="yes"
			], [
				mp_cv_have_framework_corefoundation="no"
			]
		)

		LIBS="$ac_save_LIBS"
	])

	AC_MSG_RESULT(${mp_cv_have_framework_corefoundation})

	if test x"${mp_cv_have_framework_corefoundation}" = "xyes"; then
		AC_DEFINE([HAVE_FRAMEWORK_COREFOUNDATION], [], [Define if CoreFoundation framework is available])
	fi

	AC_SUBST(HAVE_FRAMEWORK_COREFOUNDATION)
])


#------------------------------------------------------------------------
# MP_CHECK_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER --
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
AC_DEFUN(MP_CHECK_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER, [
	FRAMEWORK_LIBS="-framework CoreFoundation"

	AC_MSG_CHECKING([for CFNotificationCenterGetDarwinNotifyCenter])

	AC_CACHE_VAL(mp_cv_have_function_cfnotificationcentergetdarwinnotifycenter, [
		ac_save_LIBS="$LIBS"
		LIBS="$FRAMEWORK_LIBS $LIBS"
		
		AC_LINK_IFELSE([
			AC_LANG_PROGRAM([
					#include <CoreFoundation/CoreFoundation.h>
				], [
					CFNotificationCenterRef ref = CFNotificationCenterGetDarwinNotifyCenter();
			])
			], [
				mp_cv_have_function_cfnotificationcentergetdarwinnotifycenter="yes"
			], [
				mp_cv_have_function_cfnotificationcentergetdarwinnotifycenter="no"
			]
		)

		LIBS="$ac_save_LIBS"
	])

	AC_MSG_RESULT(${mp_cv_have_function_cfnotificationcentergetdarwinnotifycenter})

	if test x"${mp_cv_have_function_cfnotificationcentergetdarwinnotifycenter}" = "xyes"; then
		AC_DEFINE([HAVE_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER], [], [Define if function CFNotificationCenterGetDarwinNotifyCenter in CoreFoundation framework])
	fi

	AC_SUBST(HAVE_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER)
])


#------------------------------------------------------------------------
# MP_CHECK_FRAMEWORK_SYSTEMCONFIGURATION --
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
AC_DEFUN(MP_CHECK_FRAMEWORK_SYSTEMCONFIGURATION, [
	FRAMEWORK_LIBS="-framework SystemConfiguration"

	AC_MSG_CHECKING([for SystemConfiguration framework])

	AC_CACHE_VAL(mp_cv_have_framework_systemconfiguration, [
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
				mp_cv_have_framework_systemconfiguration="yes"
			], [
				mp_cv_have_framework_systemconfiguration="no"
			]
		)

		LIBS="$ac_save_LIBS"
	])

	AC_MSG_RESULT(${mp_cv_have_framework_systemconfiguration})

	if test x"${mp_cv_have_framework_systemconfiguration}" = "xyes"; then
		AC_DEFINE([HAVE_FRAMEWORK_SYSTEMCONFIGURATION], [], [Define if SystemConfiguration framework is available])
	fi

	AC_SUBST(HAVE_FRAMEWORK_SYSTEMCONFIGURATION)
])


#------------------------------------------------------------------------
# MP_CHECK_FRAMEWORK_IOKIT --
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
AC_DEFUN(MP_CHECK_FRAMEWORK_IOKIT, [
	FRAMEWORK_LIBS="-framework IOKit"

	AC_MSG_CHECKING([for IOKit framework])

	AC_CACHE_VAL(mp_cv_have_framework_iokit, [
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
				mp_cv_have_framework_iokit="yes"
			], [
				mp_cv_have_framework_iokit="no"
			]
		)

		LIBS="$ac_save_LIBS"
	])

	AC_MSG_RESULT(${mp_cv_have_framework_iokit})

	if test x"${mp_cv_have_framework_iokit}" = "xyes"; then
		AC_DEFINE([HAVE_FRAMEWORK_IOKIT], [], [Define if IOKit framework is available])
	fi

	AC_SUBST(HAVE_FRAMEWORK_IOKIT)
])


dnl This macro checks if the user specified a ports tree
dnl explicitly. If not, search for it

# MP_PATH_PORTSDIR(DEFAULT_PORTSDIR)
#---------------------------------------
 AC_DEFUN([MP_PATH_PORTSDIR],[
 	dnl For ease of reading, run after gcc has been found/configured
 	AC_REQUIRE([AC_PROG_CC])

 	AC_ARG_WITH(ports-dir, [AS_HELP_STRING([--with-ports-dir=DIR],[Specify alternate ports directory])], [ portsdir="$withval" ] )


 	AC_MSG_CHECKING([for ports tree])
 	if test "x$portsdir" != "x" ; then
 	  if test -d "$portsdir" -a -e "$portsdir/PortIndex" ; then
 		:
 	  else
 		AC_MSG_ERROR([$portsdir not a valid ports tree])
 	  fi
 	else
 		dnl If the user didn't give a path, look for default
 		if test "x$1" != "x" ; then
 		  if test -d "$1" -a -e "$1/PortIndex" ; then
 			portsdir=$1
 		  fi
 		fi
 	fi

 	if test "x$portsdir" != "x" ; then
 		AC_MSG_RESULT($portsdir)
 		PORTSDIR="$portsdir"
 		AC_SUBST(PORTSDIR)
 	else
 		AC_MSG_WARN([No ports tree found])
 	fi

         ])


# MP_PATH_MPCONFIGDIR
#---------------------------------------
AC_DEFUN([MP_PATH_MPCONFIGDIR],[
	dnl if the user actually specified --prefix, shift
	dnl mpconfigdir to $prefix/etc/macports
	dnl 	AC_REQUIRE([MP_PATH_PORTSDIR])
	
        AC_MSG_CHECKING([for MacPorts config directory])

	mpconfigdir='${sysconfdir}/macports'

	AC_MSG_RESULT([$mpconfigdir])
	MPCONFIGDIR="$mpconfigdir"
        AC_SUBST(MPCONFIGDIR)

	])

# MP_CHECK_OLDLAYOUT
#---------------------------------------
AC_DEFUN([MP_CHECK_OLDLAYOUT],[
	dnl Bail if there is an existing install of DP/MP older than 1.5

	AC_MSG_CHECKING([that any existing MacPorts install can be upgraded])

	eval dpversionfile="${sysconfdir}/ports/dp_version"
	if test -f $dpversionfile; then
		AC_MSG_ERROR([Existing MacPorts or DarwinPorts install is too old to be upgraded. Install MacPorts 1.7.1 first.])
	else
		AC_MSG_RESULT([yes])
	fi

	])

# MP_CHECK_NOROOTPRIVILEGES
#-------------------------------------------------
AC_DEFUN([MP_CHECK_NOROOTPRIVILEGES],[
	dnl if with user specifies --with-no-root-privileges,
	dnl use current user and group.
	dnl use ~/Library/Tcl as Tcl package directory
		AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(no-root-privileges, [AS_HELP_STRING([--with-no-root-privileges],[Specify that MacPorts should be installed in your home directory])], [ROOTPRIVS=$withval] )

	if test "${ROOTPRIVS+set}" = set; then

		# Set install-user to current user
		AC_MSG_CHECKING([for install user])
		DSTUSR=`id -un`
		AC_MSG_RESULT([$DSTUSR])
		AC_SUBST(DSTUSR)
		
		# Set install-group to current user
		AC_MSG_CHECKING([for install group])
		DSTGRP=`id -gn`
		AC_MSG_RESULT([$DSTGRP])
		AC_SUBST(DSTGRP)

		# Set Tcl package directory to ~/Library/Tcl
	    AC_MSG_CHECKING(for Tcl package directory)
		ac_cv_c_tclpkgd="~$DSTUSR/Library/Tcl"
	    # Convert to a native path and substitute into the output files.
	    PACKAGE_DIR_NATIVE=`${CYGPATH} ${ac_cv_c_tclpkgd}`
	    TCL_PACKAGE_DIR=${PACKAGE_DIR_NATIVE}
	    AC_SUBST(TCL_PACKAGE_DIR)
		if test x"${ac_cv_c_tclpkgd}" = x ; then
			AC_MSG_ERROR(Tcl package directory not found.  Please specify its location with --with-tclpackage)
	    else
			AC_MSG_RESULT(${ac_cv_c_tclpkgd})
	    fi
	fi

])

# MP_CHECK_RUNUSER
#-------------------------------------------------
AC_DEFUN([MP_CHECK_RUNUSER],[
	dnl if with user specifies --with-macports-user,
	dnl use it. otherwise default to platform defaults
       AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(macports-user, [AS_HELP_STRING([--with-macports-user=USER],[Specify user to drop privileges to, if possible, during compiles etc.])], [ RUNUSR=$withval ] )
	
	AC_MSG_CHECKING([for macports user])
	if test "x$RUNUSR" = "x" ; then
# dropping root privs is still buggy
#	   RUNUSR=`id -un`
	   RUNUSR=root
	fi

	AC_MSG_RESULT([$RUNUSR])
	AC_SUBST(RUNUSR)
])


# MP_SHARED_DIRECTORY
#-------------------------------------------------
AC_DEFUN([MP_SHARED_DIRECTORY],[
	dnl if with user specifies --with-shared-directory,
	dnl use 0775 permissions for ${prefix} directories
        AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(shared-directory, [AS_HELP_STRING([--with-shared-directory],[Use 0775 permissions for installed directories])], [ SHAREDIR=$withval ] )

	if test "${SHAREDIR+set}" = set; then	
		AC_MSG_CHECKING([whether to share the install directory with all members of the install group])
	    DSTMODE=0775

		AC_MSG_RESULT([$DSTMODE])
		AC_SUBST(DSTMODE)
	fi
])

# MP_CHECK_INSTALLUSER
#-------------------------------------------------
AC_DEFUN([MP_CHECK_INSTALLUSER],[
	dnl if with user specifies --with-install-user,
	dnl use it. otherwise default to platform defaults
        AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(install-user, [AS_HELP_STRING([--with-install-user=USER],[Specify user ownership of installed files])], [ DSTUSR=$withval ] )
	
	AC_MSG_CHECKING([for install user])
	if test "x$DSTUSR" = "x" ; then
	   DSTUSR=root
	fi

	AC_MSG_RESULT([$DSTUSR])
	AC_SUBST(DSTUSR)
])

# MP_CHECK_INSTALLGROUP
#-------------------------------------------------
AC_DEFUN([MP_CHECK_INSTALLGROUP],[
	dnl if with user specifies --with-install-group,
	dnl use it. otherwise default to platform defaults
        AC_REQUIRE([MP_CHECK_INSTALLUSER])

	AC_ARG_WITH(install-group, [AS_HELP_STRING([--with-install-group=GROUP],[Specify group ownership of installed files])], [ DSTGRP=$withval ] )

	AC_MSG_CHECKING([for install group])
	if test "x$DSTGRP" = "x" ; then
	   
	   case $host_os in
	   darwin*)
		DSTGRP="admin"
		;;
	   freebsd*)
		DSTGRP="wheel"
		;;
	   linux*)
		DSTGRP="root"
		;;
	   *)
		DSTGRP="wheel"
		;;
	   esac
	fi

	AC_MSG_RESULT([$DSTGRP])
	AC_SUBST(DSTGRP)
])

# MP_DIRECTORY_MODE
#-------------------------------------------------
AC_DEFUN([MP_DIRECTORY_MODE],[
	dnl if with user specifies --with-directory-mode,
	dnl use the specified permissions for ${prefix} directories
	dnl otherwise use 0755
        AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(directory-mode, [AS_HELP_STRING([--with-directory-mode=MODE],[Specify directory mode of installed directories])], [ DSTMODE=$withval ] )
	
	AC_MSG_CHECKING([what permissions to use for installation directories])
	if test "x$DSTMODE" = "x" ; then
	   DSTMODE=0755
	fi

	AC_MSG_RESULT([$DSTMODE])
	AC_SUBST(DSTMODE)
])

# MP_PATH_APPLICATIONS
#---------------------------------------
AC_DEFUN([MP_PATH_APPLICATIONS],[
        AC_REQUIRE([MP_CHECK_INSTALLUSER])

    AC_ARG_WITH(applications-dir,[AS_HELP_STRING([--with-applications-dir],[Applications installation directory.])], MPAPPLICATIONSDIR=${withval})

    oldprefix=$prefix
    if test "x$prefix" = "xNONE" ; then
	prefix=$ac_default_prefix
    fi
    AC_MSG_CHECKING([for Applications installation directory])

	if test "x$MPAPPLICATIONSDIR" = "x" ; then
	    if test "$DSTUSR" = "root" ; then
		MPAPPLICATIONSDIR="/Applications/MacPorts"
	    else
		MPAPPLICATIONSDIR="$(eval echo ~$DSTUSR)/Applications/MacPorts"
	    fi
	fi

	AC_MSG_RESULT([$MPAPPLICATIONSDIR])
    AC_SUBST(MPAPPLICATIONSDIR)
    prefix=$oldprefix
])

# MP_PATH_FRAMEWORKS
#---------------------------------------
AC_DEFUN([MP_PATH_FRAMEWORKS],[
        AC_REQUIRE([MP_CHECK_INSTALLUSER])

    AC_ARG_WITH(frameworks-dir,[AS_HELP_STRING([--with-frameworks-dir],[Frameworks installation directory.])], MPFRAMEWORKSDIR=${withval})

    oldprefix=$prefix
    if test "x$prefix" = "xNONE" ; then
	prefix=$ac_default_prefix
    fi
    AC_MSG_CHECKING([for Frameworks installation directory])

	if test "x$MPFRAMEWORKSDIR" = "x" ; then
		MPFRAMEWORKSDIR="${prefix}/Library/Frameworks"
	fi

	AC_MSG_RESULT([$MPFRAMEWORKSDIR])
    AC_SUBST(MPFRAMEWORKSDIR)
    prefix=$oldprefix
])


# MP_UNIVERSAL_OPTIONS
#---------------------------------------
AC_DEFUN([MP_UNIVERSAL_OPTIONS],[
  AC_ARG_WITH(universal-archs,[AS_HELP_STRING([--with-universal-archs="CPU"],[Universal CPU architectures (space separated)])], UNIVERSAL_ARCHS=${withval})

  if test "x$UNIVERSAL_ARCHS" = "x"; then
    case "$MACOSX_VERSION" in
      10.[[0-5]]*)
        UNIVERSAL_ARCHS="i386 ppc"
        ;;
      *)
        UNIVERSAL_ARCHS="x86_64 i386"
        ;;
    esac
  fi

  AC_MSG_CHECKING([for Universal CPU architectures])
  AC_MSG_RESULT([$UNIVERSAL_ARCHS])
  AC_SUBST(UNIVERSAL_ARCHS)
])

# MP_LIB_MD5
#---------------------------------------
# Check for an md5 implementation
AC_DEFUN([MP_LIB_MD5],[

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
	if test "x$MD5_LIBS" = "x"; then
		AC_MSG_ERROR([Neither CommonCrypto nor libmd were found. A working md5 implementation is required.])
	fi
	AC_SUBST([MD5_LIBS])
])

# MP_PROG_DAEMONDO
#---------------------------------------
AC_DEFUN([MP_PROG_DAEMONDO],[
	AC_REQUIRE([MP_CHECK_FRAMEWORK_COREFOUNDATION])
	AC_REQUIRE([MP_CHECK_FRAMEWORK_SYSTEMCONFIGURATION])
	AC_REQUIRE([MP_CHECK_FRAMEWORK_IOKIT])
	AC_REQUIRE([MP_CHECK_FUNCTION_CFNOTIFICATIONCENTERGETDARWINNOTIFYCENTER])
	
    AC_MSG_CHECKING(for whether we will build daemondo)
    result=no
	case $host_os in
	darwin*)
		if test "x$mp_cv_have_framework_corefoundation" == "xyes" &&
		   test "x$mp_cv_have_framework_systemconfiguration" == "xyes" &&
		   test "x$mp_cv_have_framework_iokit" == "xyes" &&
		   test "x$mp_cv_have_function_cfnotificationcentergetdarwinnotifycenter" == "xyes"; then
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
# MP_TCL_PACKAGE_DIR --
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

AC_DEFUN(MP_TCL_PACKAGE_DIR, [
	AC_REQUIRE([MP_CHECK_INSTALLUSER])

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
			if test "$DSTUSR" = "root" ; then
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
			elif test "$path" = "~/Library/Tcl"; then
			    ac_cv_c_tclpkgd="~$DSTUSR/Library/Tcl"
			    break
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

# MP_PROG_TCLSH
#---------------------------------------
AC_DEFUN([MP_PROG_TCLSH],[


	case $host_os in
		freebsd*)
			# FreeBSD installs a dummy tclsh (annoying)
			# Look for a real versioned tclsh with threads first
			# Look for a real versioned tclsh without threads second
			AC_PATH_PROG([TCLSH], [tclsh${TCL_VERSION}-threads tclsh${TCL_VERSION} tclsh])
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

# MP_TCL_PACKAGE
#	Determine if a Tcl package is present.
#
# Arguments:
#	Package name (may include the version)
#
# Syntax:
#   MP_TCL_PACKAGE (package, [action-if-found], [action-if-not-found])
#
# Requires:
#	TCLSH must be set
#
# Results:
#	Execute action-if-found or action-if-not-found
#---------------------------------------
AC_DEFUN([MP_TCL_PACKAGE],[
	AC_MSG_CHECKING([for Tcl $1 package])
	package_present=`echo 'if {[[catch {package require $1}]]} {puts -nonewline 0} else {puts -nonewline 1}' | $TCLSH`
	AS_IF([test "$package_present" = "1"], [$2], [$3])[]
])

# MP_TCL_THREAD_SUPPORT
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
AC_DEFUN([MP_TCL_THREAD_SUPPORT],[
	AC_MSG_CHECKING([whether tclsh was compiled with threads])
	tcl_threadenabled=`echo 'puts -nonewline [[info exists tcl_platform(threaded)]]' | $TCLSH`
	if test "$tcl_threadenabled" = "1" ; then
		AC_MSG_RESULT([yes])
	else
		AC_MSG_RESULT([no])
		AC_MSG_ERROR([tcl wasn't compiled with threads enabled])
	fi
])

# MP_LIBCURL_FLAGS
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
AC_DEFUN([MP_LIBCURL_FLAGS],[
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
	if test "x$curlprefix" = "x"; then
		# System curl-config emits absurd output for --libs
		# See rdar://7244457
		LDFLAGS_LIBCURL="-lcurl"
	else
		# Due to a bug in dist, --arch flags are improperly supplied by curl-config.
		# Get rid of them.
		LDFLAGS_LIBCURL=$($CURL_CONFIG --libs | [sed 's/-arch [A-Za-z0-9_]* //g'])
	fi

	AC_SUBST(CFLAGS_LIBCURL)
	AC_SUBST(LDFLAGS_LIBCURL)
])

dnl This macro tests if the compiler supports GCC's
dnl __attribute__ syntax for unused variables/parameters
AC_DEFUN([MP_COMPILER_ATTRIBUTE_UNUSED], [
	AC_MSG_CHECKING([how to mark unused variables])
	AC_COMPILE_IFELSE(
		[AC_LANG_SOURCE([[int a __attribute__ ((unused));]])],
		[AC_DEFINE(UNUSED, [__attribute__((unused))], [Attribute to mark unused variables])],
		[AC_DEFINE(UNUSED, [])])

	AC_MSG_RESULT([])
	
])

dnl This macro ensures MP installation prefix bin/sbin paths are NOT in PATH
dnl for configure to prevent potential problems when base/ code is updated
dnl and ports are installed that would match needed items.
AC_DEFUN([MP_PATH_SCAN],[
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
	AC_SUBST(PATH_CLEANED,$newPATH)
	prefix=$oldprefix
])

dnl This macro tests for sed support of -E (BSD) or -r (GNU)
AC_DEFUN([MP_SED_EXTENDED_REGEXP],[
	AC_PATH_PROG(SED, [sed])

	if test "x$SED" = "x"; then
		AC_MSG_ERROR([cannot find sed. Is sed installed?])
	fi

	AC_MSG_CHECKING([which sed flag to use for extended regexp])
	[any_sed_flag=`echo foo | $SED    -e s/foo+/OK/ 2>&1 | grep OK`]
	[bsd_sed_flag=`echo foo | $SED -E -e s/foo+/OK/ 2>&1 | grep OK`]
	[gnu_sed_flag=`echo foo | $SED -r -e s/foo+/OK/ 2>&1 | grep OK`]
	if test "x$any_sed_flag" = "xOK" ; then
		AC_MSG_RESULT([none])
		SED_EXT=
	elif test "x$bsd_sed_flag" = "xOK" ; then
		AC_MSG_RESULT([-E (BSD)])
		SED_EXT=-E
	elif test "x$gnu_sed_flag" = "xOK" ; then
		AC_MSG_RESULT([-r (GNU)])
		SED_EXT=-r
	else
		AC_MSG_RESULT([not available])
		SED_EXT='N/A'
	fi
	AC_SUBST(SED_EXT)
])

dnl This macro tests for tar support of --no-same-owner
AC_DEFUN([MP_TAR_NO_SAME_OWNER],[
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

dnl This macro tests for GNU patch
AC_DEFUN([MP_PATCH_GNU_VERSION],[
	AC_PATH_PROG(PATCH, [patch])
	AC_PATH_PROG(GNUPATCH, [gpatch])
	
	AC_MSG_CHECKING([for GNU (FSF) patch])
	AS_IF([test -n "$GNUPATCH"], [PATCH_CMD=$GNUPATCH], [PATCH_CMD=$PATCH])
	[fsf_version=`$PATCH_CMD --version 2>&1 | grep "Free Software Foundation"`]
	if test -z "$fsf_version" ; then
		AC_MSG_RESULT([none])
	else
		AC_MSG_RESULT([$PATCH_CMD])
		GNUPATCH="$PATCH_CMD"
	fi
])

#------------------------------------------------------------------------
# MP_CHECK_READLINK_IS_P1003_1A --
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
AC_DEFUN(MP_CHECK_READLINK_IS_P1003_1A, [
	AC_MSG_CHECKING([if readlink conforms to POSIX 1003.1a])

	AC_CACHE_VAL(mp_cv_readlink_is_posix_1003_1a, [
		AC_COMPILE_IFELSE([
			AC_LANG_PROGRAM([
					#include <unistd.h>
					ssize_t readlink(const char *, char *, size_t);
				], [
			])
			], [
				mp_cv_readlink_is_posix_1003_1a="yes"
			], [
				mp_cv_readlink_is_posix_1003_1a="no"
			]
		)
	])

	AC_MSG_RESULT(${mp_cv_readlink_is_posix_1003_1a})

	if test x"${mp_cv_readlink_is_posix_1003_1a}" = "xno"; then
		AC_DEFINE([READLINK_IS_NOT_P1003_1A], [], [Define to 1 if readlink does not conform with POSIX 1003.1a (where third argument is a size_t and return value is a ssize_t)])
	fi

	AC_SUBST(READLINK_IS_NOT_P1003_1A)
])

#------------------------------------------------------------------------
# MP_WERROR --
#
#       Enable -Werror
#
# Arguments:
#       None.
#
# Requires:
#       none
#
# Depends:
#       none
#
# Results:
#       Substitutes WERROR_CFLAGS variable
#------------------------------------------------------------------------
AC_DEFUN([MP_WERROR],[
	AC_REQUIRE([AC_PROG_CC])
	AC_ARG_ENABLE(werror, AS_HELP_STRING([--enable-werror],[Add -Werror to CFLAGS. Used for development.]), [enable_werror=${enableval}], [enable_werror=no])
	if test x"$enable_werror" != "xno"; then
		CFLAGS_WERROR="-Werror"
	else
		CFLAGS_WERROR=""
	fi
	AC_SUBST([CFLAGS_WERROR])
])
