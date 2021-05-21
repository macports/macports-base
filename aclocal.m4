builtin(include,m4/tcl.m4)

dnl Search for a variable in a list. Run ACTION-IF-FOUND if it is in the list,
dnl ACTION-IF-NOT-FOUND otherwise.
dnl
dnl Parameters:
dnl  - The name of the list.
dnl  - The name of the variable that should be searched in the list.
dnl  - An optional action to be run if found
dnl  - An optional action to be run if not found
dnl
dnl _MP_LIST_CONTAINS_QUOTED([listname], [varname], [ACTION-IF-FOUND], [ACTION-IF-NOT-FOUND])
AC_DEFUN([_MP_LIST_CONTAINS], [dnl
	mp_list_contains_present=
	eval "mp_list_contains_list=\"$$1\""
	for mp_list_contains_entry in $mp_list_contains_list; do
		test -z "$mp_list_contains_entry" && continue
		if test "x$$2" = "x$mp_list_contains_entry"; then
			mp_list_contains_present=1
			break
		fi
	done
	if test "x$mp_list_contains_present" = "x"; then
		m4_ifvaln([$3], [$3], [:])dnl
		m4_ifvaln([$4], [else $4])dnl
	fi
])

dnl Quote a variable and prepend it to a list.
dnl
dnl Parameters:
dnl  - The name of the list.
dnl  - The name of the variable that should be quoted and prepended to the
dnl    list.
AC_DEFUN([_MP_LIST_PREPEND_QUOTED], [dnl
	_MP_QUOTE([$2])
	_MP_VAR_PREPEND([$1], ["$$2 "])
])


dnl Quote a variable and append it to a list.
dnl
dnl Parameters:
dnl  - The name of the list.
dnl  - The name of the variable that should be quoted and appended to the list.
AC_DEFUN([_MP_LIST_APPEND_QUOTED], [dnl
	_MP_QUOTE([$2])
	AS_VAR_APPEND([$1], [" $$2"])
])

dnl Prepend the shell expansion of a value to a variable.
dnl
dnl Parameters:
dnl  - The name of the variable to which the second argument should be
dnl    prepended.
dnl  - The value that should be expanded using the shell expansion rules and
dnl    prepended to the variable given in the first argument.
AC_DEFUN([_MP_VAR_PREPEND], [dnl
	AC_REQUIRE([_MP_VAR_PREPEND_PREPARE])dnl
	mp_fn_var_prepend $1 $2
])

dnl Define the function required for _MP_VAR_PREPEND
AC_DEFUN([_MP_VAR_PREPEND_PREPARE], [dnl
	mp_fn_var_prepend() {
		eval "$[]1=\"$[]2\$$[]1\""
	}
])

dnl Quote a variable in single quotes (escaping any existing single quotes) and
dnl store it in itself.
dnl
dnl Parameters:
dnl  - The name of the variable that should be quoted using single quotes.
AC_DEFUN([_MP_QUOTE], [dnl
	case $$1 in
		*\'*)
			$1=$(AS_ECHO(["$$1"]) | sed "s/'/'\\\\\\\\''/g")
		;;
	esac
	$1="'$$1'"dnl
])


dnl Extract the key part of a key-value pair given as string in the form
dnl  --key=value or
dnl   -key=value
dnl
dnl Parameters:
dnl  - The variable name to assign to
dnl  - The (quoted, if necessary) key-value pair
AC_DEFUN([_MP_EXTRACT_KEY], [dnl
	$1=$(AS_ECHO([$2]) | sed -E 's/^--?([[^=]]+)=.*$/\1/')dnl
])

dnl Similar to AC_ARG_VAR, but implemented with --with-pkg=PATH for PKG.
dnl
dnl Parameters: Similar to AC_ARG_VAR ($2 gets some boiler plate around it)
AC_DEFUN([MP_TOOL_PATH], [dnl
	AC_ARG_WITH([m4_tolower($1)], [AS_HELP_STRING([--with-m4_tolower($1)=PATH],
			[path to alternate $2 command])], [$1=$withval],dnl
		[])dnl
])

dnl Configure a project contained in a subdirectory. Different from
dnl AC_CONFIG_SUBDIRS (on which this macro is based), you can pass parameters
dnl to the sub-configure script.
dnl
dnl Parameters:
dnl  - The relative path to the directory that contains the configure script
dnl    to be run
dnl  - Parameters to pass to the configure script
dnl
dnl MP_CONFIG_SUBDIR([path-to-directory], [configure-parameters])
AC_DEFUN([MP_CONFIG_SUBDIR], [

	ac_dir="$1"

	mp_popdir=$(pwd)

	AS_MKDIR_P(["$ac_dir"])
	_AC_SRCDIRS(["$ac_dir"])
	cd "$ac_dir"

	if test "$no_recursion" != yes || test ! -f "$ac_srcdir/config.status"; then
		AC_MSG_NOTICE([=== configuring in $ac_dir ($mp_popdir/$ac_dir)])
		if test -f "$ac_srcdir/configure"; then
			# Run 'make distclean' first, ignoring errors; unfortunately some
			# of our projects are not reconfigure-safe and will not correctly
			# pick up modified configure variables or recompile files affected
			# by such variables. See
			# https://github.com/macports/macports-base/pull/79 and
			# https://github.com/macports/macports-base/pull/80
			make distclean || true

			mp_sub_configure_args=
			mp_sub_configure_keys=
			# Compile a list of keys that have been given to the MP_CONFIG_SUBDIR
			# macro; we want to skip copying those parameters from the original
			# configure invocation.
			for mp_arg in $2; do
				case $mp_arg in
					--*=* | -*=*)
						_MP_EXTRACT_KEY([mp_arg_key], ["$mp_arg"])
						_MP_LIST_APPEND_QUOTED([mp_sub_configure_keys], [mp_arg_key])
					;;
				esac
				_MP_LIST_APPEND_QUOTED([mp_sub_configure_args], [mp_arg])
			done
			# Walk the list of arguments given to the original configure script;
			# filter out a few common ones we likely would not want to pass along,
			# add --disable-option-checking and filter those already given as
			# argument to MP_CONFIG_SUBDIR.
			# Most of this code is adapted from _AC_OUTPUT_SUBDIRS in
			# $prefix/share/autoconf/autoconf/status.m4.
			mp_prev=
			eval "set x $ac_configure_args"
			shift
			for mp_arg; do
				if test -n "$mp_prev"; then
					mp_prev=
					continue
				fi
				case $mp_arg in
					  -cache-file \
					| --cache-file \
					| --cache-fil \
					| --cache-fi \
					| --cache-f \
					| --cache- \
					| --cache \
					| --cach \
					| --cac \
					| --ca \
					| --c)
						mp_prev=cache_file
					;;
					  -cache-file=* \
					| --cache-file=* \
					| --cache-fil=* \
					| --cache-fi=* \
					| --cache-f=* \
					| --cache-=* \
					| --cache=* \
					| --cach=* \
					| --cac=* \
					| --ca=* \
					| --c=*)
						# ignore --cache-file
					;;
					  --config-cache \
					| -C)
						# ignore -C
					;;
					  -srcdir \
					| --srcdir \
					| -srcdi \
					| -srcd \
					| -src \
					| -sr)
						mp_prev=srcdir
					;;
					  -srcdir=* \
					| --srcdir=* \
					| --srcdi=* \
					| --srcd=* \
					| --src=* \
					| --sr=*)
						# ignore --srcdir
					;;
					  -prefix \
					| --prefix \
					| --prefi \
					| --pref \
					| --pre \
					| --pr \
					| --p)
						mp_prev=prefix
					;;
					  -prefix=* \
					| --prefix=* \
					| --prefi=* \
					| --pref=* \
					| --pre=* \
					| --pr=* \
					| --p=*)
						# ignore --prefix
					;;
					--disable-option-checking)
						# ignore --disable-option-checking
					;;
					--*=* | -*=*)
						_MP_EXTRACT_KEY([mp_arg_key], ["$mp_arg"])
						_MP_LIST_CONTAINS([mp_sub_configure_keys], [mp_arg_key], [], [
							_MP_LIST_APPEND_QUOTED([mp_sub_configure_args], [mp_arg])
						])
					;;
					*)
						# always pass positional arguments
						_MP_LIST_APPEND_QUOTED([mp_sub_configure_args], [mp_arg])
					;;
				esac
			done

			# Now prepend some arguments that should always be present unless
			# overriden, such as --prefix, --silent, --disable-option-checking,
			# --cache-file, --srcdir
			# Pass --prefix unless already given
			mp_arg_key=prefix
			_MP_LIST_CONTAINS([mp_sub_configure_args], [mp_arg_key], [], [
				mp_arg="--prefix=$prefix"
				_MP_LIST_PREPEND_QUOTED([mp_sub_configure_args], [mp_arg])
			])

			# Pass --silent
			if test "$silent" = yes; then
				mp_arg="--silent"
				_MP_LIST_PREPEND_QUOTED([mp_sub_configure_args], [mp_arg])
			fi

			# Always prepend --disable-option-checking to silence warnings, since
			# different subdirs can have different --enable and --with options.
			mp_arg="--disable-option-checking"
			_MP_LIST_PREPEND_QUOTED([mp_sub_configure_args], [mp_arg])

			# Make the cache file name correct relative to the subdirectory.
			case $cache_file in
				[[\\/]]* | ?:[[\\/]]* )
					mp_sub_cache_file=$cache_file
				;;
				*) # Relative name.
					mp_sub_cache_file=$ac_top_build_prefix$cache_file
				;;
			esac
			mp_arg="--cache-file=$mp_sub_cache_file"
			_MP_LIST_PREPEND_QUOTED([mp_sub_configure_args], [mp_arg])

			mp_arg="--srcdir=$ac_srcdir"
			_MP_LIST_APPEND_QUOTED([mp_sub_configure_args], [mp_arg])

			mp_arg="CC=$CC"
			_MP_LIST_APPEND_QUOTED([mp_sub_configure_args], [mp_arg])

			AC_MSG_NOTICE([running $SHELL $ac_srcdir/configure $mp_sub_configure_args in $ac_dir])
			eval "\$SHELL \$ac_srcdir/configure $mp_sub_configure_args" || AC_MSG_ERROR([configure failed for $ac_dir])
		else
			AC_MSG_ERROR([no configure script found in $ac_dir])
		fi
		AC_MSG_NOTICE([=== finished configuring in $ac_dir ($mp_popdir/$ac_dir)])
	fi
	cd "$mp_popdir"
])


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

	AC_SUBST(HAVE_FRAMEWORK_COREFOUNDATION, [$mp_cv_have_framework_corefoundation])
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

	AC_SUBST(HAVE_FRAMEWORK_SYSTEMCONFIGURATION, [$mp_cv_have_framework_systemconfiguration])
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
					#include <IOKit/pwr_mgt/IOPMLib.h>
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

	AC_SUBST(HAVE_FRAMEWORK_IOKIT, [$mp_cv_have_framework_iokit])
])

# MP_PATH_MPCONFIGDIR
#---------------------------------------
AC_DEFUN([MP_PATH_MPCONFIGDIR],[
	dnl if the user actually specified --prefix, shift
	dnl mpconfigdir to $prefix/etc/macports
	
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
	if test -f "$dpversionfile"; then
		AC_MSG_ERROR([Existing MacPorts or DarwinPorts install is too old to be upgraded. Install MacPorts 1.7.1 first.])
	else
		AC_MSG_RESULT([yes])
	fi

	])

# MP_CHECK_NOROOTPRIVILEGES
#-------------------------------------------------
AC_DEFUN([MP_CHECK_NOROOTPRIVILEGES],[
	dnl if the user specifies --with-no-root-privileges,
	dnl use current user and group.
	dnl use ~/Library/Tcl as Tcl package directory
	AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(no-root-privileges, [AS_HELP_STRING([--with-no-root-privileges],[specify that MacPorts should be installed in your home directory])], [ROOTPRIVS=$withval] )

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

		# Set run-user to current user
		AC_MSG_CHECKING([for macports user])
		RUNUSR=`id -un`
		AC_MSG_RESULT([$RUNUSR])
		AC_SUBST(RUNUSR)
	fi

])

# MP_CHECK_RUNUSER
#-------------------------------------------------
AC_DEFUN([MP_CHECK_RUNUSER],[
	dnl if the user specifies --with-macports-user,
	dnl use it, otherwise default to platform defaults
	AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(macports-user, [AS_HELP_STRING([--with-macports-user=USER],[specify user to drop privileges to, if possible, during compiles, etc.])], [ RUNUSR=$withval ] )
	
	AC_MSG_CHECKING([for macports user])
	if test "x$RUNUSR" = "x" ; then
		RUNUSR=macports
	fi

	AC_MSG_RESULT([$RUNUSR])
	AC_SUBST(RUNUSR)
])


# MP_SHARED_DIRECTORY
#-------------------------------------------------
AC_DEFUN([MP_SHARED_DIRECTORY],[
	dnl if the user specifies --with-shared-directory,
	dnl use 0775 permissions for ${prefix} directories
	AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(shared-directory, [AS_HELP_STRING([--with-shared-directory],[use 0775 permissions for installed directories])], [ SHAREDIR=$withval ] )

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
	dnl if the user specifies --with-install-user,
	dnl use it, otherwise default to platform defaults
	AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(install-user, [AS_HELP_STRING([--with-install-user=USER],[specify user ownership of installed files])], [ DSTUSR=$withval ] )
	
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
	dnl if the user specifies --with-install-group,
	dnl use it, otherwise default to platform defaults
	AC_REQUIRE([MP_CHECK_INSTALLUSER])

	AC_ARG_WITH(install-group, [AS_HELP_STRING([--with-install-group=GROUP],[specify group ownership of installed files])], [ DSTGRP=$withval ] )

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
	dnl if the user specifies --with-directory-mode,
	dnl use the specified permissions for ${prefix} directories,
	dnl otherwise use 0755
	AC_REQUIRE([MP_PATH_MPCONFIGDIR])

	AC_ARG_WITH(directory-mode, [AS_HELP_STRING([--with-directory-mode=MODE],[specify directory mode of installed directories])], [ DSTMODE=$withval ] )
	
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

	AC_ARG_WITH(applications-dir,[AS_HELP_STRING([--with-applications-dir],[applications installation directory])], MPAPPLICATIONSDIR=${withval})

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

	AC_ARG_WITH(frameworks-dir,[AS_HELP_STRING([--with-frameworks-dir],[frameworks installation directory])], MPFRAMEWORKSDIR=${withval})

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

# MP_CHECK_STARTUPITEMS
#-------------------------------------------------
AC_DEFUN([MP_CHECK_STARTUPITEMS],[
	dnl if the user specifies --without-startupitems,
	dnl set "startupitem_install no" in macports.conf
	AC_ARG_WITH(startupitems, [AS_HELP_STRING([--without-startupitems],[set "startupitem_install no" in macports.conf])], [with_startupitems=$withval], [with_startupitems=default] )

	AC_MSG_CHECKING([for startupitem_install])

	if test "x$with_startupitems" = "xno" ; then
		startupitem_install="startupitem_install	no"
	elif test "x$with_startupitems" = "xdefault" -a "$DSTUSR" != "root" ; then
		startupitem_install="startupitem_install	no"
		with_startupitems=no
	else
		startupitem_install="#startupitem_install	yes"
		with_startupitems=yes
	fi

	AC_MSG_RESULT([$with_startupitems])
	AC_SUBST(startupitem_install)
])


# MP_UNIVERSAL_OPTIONS
#---------------------------------------
AC_DEFUN([MP_UNIVERSAL_OPTIONS],[
	AC_ARG_WITH(universal-archs,[AS_HELP_STRING([--with-universal-archs="CPU"],[universal CPU architectures (space separated)])], UNIVERSAL_ARCHS=${withval})

	if test "x$UNIVERSAL_ARCHS" = "x"; then
		case "$MACOSX_VERSION" in
			10.1[[0-3]]*)
				UNIVERSAL_ARCHS="x86_64 i386"
			;;
			10.1[[4-9]]*)
				UNIVERSAL_ARCHS="x86_64"
			;;
			10.[[0-5]]*)
				UNIVERSAL_ARCHS="i386 ppc"
			;;
			10.[[6-9]]*)
				UNIVERSAL_ARCHS="x86_64 i386"
			;;
			*)
				UNIVERSAL_ARCHS="arm64 x86_64"
			;;
		esac
	fi

	UNIVERSAL_ARCHFLAGS=
	for arch in $UNIVERSAL_ARCHS; do
		UNIVERSAL_ARCHFLAGS="$UNIVERSAL_ARCHFLAGS -arch $arch"
	done

	AC_MSG_CHECKING([for Universal CPU architectures])
	AC_MSG_RESULT([$UNIVERSAL_ARCHS])
	AC_SUBST(UNIVERSAL_ARCHS)
	AC_SUBST(UNIVERSAL_ARCHFLAGS)
])

# MP_LIB_MD5
#---------------------------------------
# Check for an md5 implementation
AC_DEFUN([MP_LIB_MD5],[
	# Check for libmd from FreeBSD, which is preferred
	AC_CHECK_LIB([md], [MD5File],[
		AC_CHECK_HEADERS([md5.h sha.h], ,[
			AC_MSG_ERROR([libmd was found, but md5.h or sha.h is missing.])
		])
		ac_save_LIBS="$LIBS"
		LIBS="-lmd $LIBS"
		AC_CHECK_FUNCS([SHA1_File])
		LIBS="$ac_save_LIBS"
		AC_CHECK_HEADERS([ripemd.h sha256.h])
		AC_DEFINE([HAVE_LIBMD], ,[Define if you have the `md' library (-lmd).])
		MD5_LIBS="-lmd"]
	)
	if test "x$MD5_LIBS" = "x"; then
		# If libmd is not found, check for libcrypto from OpenSSL
		AC_CHECK_LIB([crypto], [MD5_Update],[
			AC_CHECK_HEADERS([openssl/md5.h openssl/sha.h], ,[
				AC_MSG_ERROR([libcrypto was found, but openssl/md5.h or openssl/sha.h is missing.])
			])
			AC_CHECK_HEADERS([openssl/ripemd.h])
			ac_save_LIBS="$LIBS"
			LIBS="-lcrypto $LIBS"
			AC_CHECK_FUNCS([SHA256_Update])
			LIBS="$ac_save_LIBS"
			AC_DEFINE([HAVE_LIBCRYPTO], ,[Define if you have the `crypto' library (-lcrypto).])
			MD5_LIBS="-lcrypto"]
		)
	fi
	if test "x$MD5_LIBS" = "x"; then
		AC_MSG_ERROR([Neither CommonCrypto, libmd nor libcrypto were found. A working md5 implementation is required.])
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
			if test "x$mp_cv_have_framework_corefoundation" = "xyes" &&
			   test "x$mp_cv_have_framework_systemconfiguration" = "xyes" &&
			   test "x$mp_cv_have_framework_iokit" = "xyes" &&
			   test "x$mp_cv_have_function_cfnotificationcentergetdarwinnotifycenter" = "xyes"; then
				result=yes
				EXTRA_PROGS="$EXTRA_PROGS daemondo"
				AC_CONFIG_FILES([src/programs/daemondo/Makefile])
			fi
		;;
		*)
	esac
	AC_MSG_RESULT(${result})
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
		   [  --with-curlprefix       base directory for the curl install ('/usr', '/usr/local', ...)],
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

# MP_SQLITE3_FLAGS
#	Sets the flags to compile with libsqlite3 and tclsqlite3.
#
# Arguments:
#	None.
#
# Requires:
#   pkgconfig, libsqlite3 in /usr/lib, or user parameters to define the flags.
#
# Results:
#   defines some help strings.
#   sets CFLAGS_SQLITE3 and LDFLAGS_SQLITE3
#---------------------------------------
AC_DEFUN([MP_SQLITE3_FLAGS],[
    # first sqlite3 itself
	AC_ARG_WITH(sqlite3prefix,
		   [  --with-sqlite3prefix    base directory for the sqlite3 install ('/usr', '/usr/local', ...)],
		   [  sqlite3prefix=$withval ])

	if test "x$sqlite3prefix" = "x"; then
		# see if it's somewhere like /usr that needs no extra flags
		LDFLAGS_SQLITE3="-lsqlite3"
		AC_CHECK_HEADER(sqlite3.h, [],[
		    # nope - try pkg-config
			AC_PATH_PROG([PKG_CONFIG], [pkg-config])
			if test "x$PKG_CONFIG" = "x" || ! $PKG_CONFIG --exists sqlite3; then
				AC_MSG_ERROR([cannot find sqlite3 header])
			else
				CFLAGS_SQLITE3=$($PKG_CONFIG --cflags sqlite3)
				LDFLAGS_SQLITE3=$($PKG_CONFIG --libs sqlite3)
				# for tclsqlite below
				mp_sqlite3_dir=$($PKG_CONFIG --variable=prefix sqlite3)
            			if test "x$mp_sqlite3_dir" != "x"; then
                			mp_sqlite3_dir=${mp_sqlite3_dir}/lib/sqlite3
            			fi
			fi
		])
	else
	    CFLAGS_SQLITE3="-I${sqlite3prefix}/include"
		LDFLAGS_SQLITE3="-L${sqlite3prefix}/lib -lsqlite3"
	fi

	# check if we have sqlite3ext.h, using the appropriate cppflags
	CPPFLAGS_OLD="${CPPFLAGS}"
	CPPFLAGS="${CPPFLAGS} ${CFLAGS_SQLITE3}"
	AC_CHECK_HEADERS(sqlite3ext.h)
	CPPFLAGS="${CPPFLAGS_OLD}"

	AC_SUBST(CFLAGS_SQLITE3)
	AC_SUBST(LDFLAGS_SQLITE3)
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

dnl This macro ensures MP installation prefix paths are NOT in CFLAGS,
dnl CPPFLAGS, OBJCFLAGS, LDFLAGS for configure to prevent potential problems
dnl when base/ code is updated and ports are installed that would match needed
dnl items.
AC_DEFUN([MP_FLAGS_SCAN],[
	AC_ARG_ENABLE(
		[flag-sanitization],
		AS_HELP_STRING([--disable-flag-sanitization], [do not sanitize CPPFLAGS, CFLAGS, OBJCFLAGS and LDFLAGS]),
		[disable_mp_flags_scan=yes],
		[disable_mp_flags_scan=no])

	if test x"$disable_mp_flags_scan" != "xyes"; then
		# Get a value for $prefix
		oldprefix=$prefix
		if test "x$prefix" = "xNONE" ; then
			prefix=$ac_default_prefix
		fi

		mp_flags_scan_found=

		# Clean CFLAGS CPPFLAGS OBJCFLAGS and LDFLAGS
		for mp_flags_flagname in CFLAGS CPPFLAGS OBJCFLAGS LDFLAGS; do
			mp_flags_scan_flag_cleaned=
			eval "set x \$$mp_flags_flagname"
			shift
			for mp_flags_scan_val; do
				case "$mp_flags_scan_val" in
					-I$prefix/* | -L$prefix/*)
						AC_MSG_NOTICE([Removing `$mp_flags_scan_val' from \$$mp_flags_flagname because it might cause a self-dependency])
						mp_flags_scan_found=1
						;; #(
					*)
						if test -z "$mp_flags_scan_flag_cleaned"; then
							mp_flags_scan_flag_cleaned=$mp_flags_scan_val
						else
							AS_VAR_APPEND([mp_flags_scan_flag_cleaned], [" $mp_flags_scan_val"])
						fi
						;;
				esac
			done
			if test -z "$mp_flags_scan_flag_cleaned"; then
				(unset $mp_flags_flagname) >/dev/null 2>&1 && unset $mp_flags_flagname
				(export -n $mp_flags_flagname) >/dev/null 2>&1 && export -n $mp_flags_flagname
			else
				eval "$mp_flags_flagname=\"$mp_flags_scan_flag_cleaned\""
				export $mp_flags_flagname
			fi
			eval "ac_env_${mp_flags_flagname}_set=\${${mp_flags_flagname}+set}"
			eval "ac_env_${mp_flags_flagname}_value=\${${mp_flags_flagname}}"
			eval "ac_cv_env_${mp_flags_flagname}_set=\${${mp_flags_flagname}+set}"
			eval "ac_cv_env_${mp_flags_flagname}_value=\${${mp_flags_flagname}}"
		done

		# Since those are all precious variables they have been saved into config.cache and put into $ac_configure_args
		# We need to remove them at least from $ac_configure_args, because that's being passed to sub-configures
		eval "set x $ac_configure_args"
		shift
		ac_configure_args=
		for mp_flags_configure_arg; do
			case "$mp_flags_configure_arg" in
				CFLAGS=* | CPPFLAGS=* | OBJCFLAGS=* | LDFLAGS=*)
					mp_flags_configure_arg_key=$(AS_ECHO(["$mp_flags_configure_arg"]) | sed -E 's/^([[^=]]+)=.*$/\1/')
					eval "mp_flags_configure_arg_newval=\$$mp_flags_configure_arg_key"
					if test -n "$mp_flags_configure_arg_newval"; then
						AS_VAR_APPEND([ac_configure_args], [" '$mp_flags_configure_arg_key=$mp_flags_configure_arg_newval'"])
					fi
					;;
				*)
					AS_VAR_APPEND([ac_configure_args], [" '$mp_flags_configure_arg'"])
					;;
			esac
		done

		if ! test -z "$mp_flags_scan_found"; then
			AC_MSG_NOTICE([See https://trac.macports.org/ticket/42756 for rationale on why this script is removing these values])
			AC_MSG_NOTICE([Pass --disable-flag-sanitization if you're aware of the potential problems and want to risk them anyway])
		fi

		# Restore $prefix
		prefix=$oldprefix
	fi
])


dnl This macro ensures MP installation prefix paths are NOT in PATH
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
		case "$as_dir" in
			$prefix/*)
				;;
			*)
				if test -z "$newPATH"; then
					newPATH=$as_dir
				else
					newPATH=$newPATH$PATH_SEPARATOR$as_dir
				fi
				;;
		esac
	done
	PATH=$newPATH; export PATH
	AC_SUBST(PATH_CLEANED,$newPATH)
	prefix=$oldprefix
])

dnl This macro tests for tar support of -q (BSD) or not (GNU)
AC_DEFUN([MP_TAR_FAST_READ],[
	AC_PATH_PROG(TAR, [tar])
	
	AC_MSG_CHECKING([whether tar supports -q])
	if $TAR -t -q -f - </dev/null 2>/dev/null ; then
		AC_MSG_RESULT([yes (bsdtar)])
		TAR_Q='q'
	else
		AC_MSG_RESULT([no (gnutar)])
		TAR_Q=
	fi
	AC_SUBST(TAR_Q)
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
	AC_ARG_ENABLE(werror, AS_HELP_STRING([--enable-werror],[add -Werror to CFLAGS (used for development)]), [enable_werror=${enableval}], [enable_werror=no])
	if test x"$enable_werror" != "xno"; then
		CFLAGS_WERROR="-Werror"
	else
		CFLAGS_WERROR=""
	fi
	AC_SUBST([CFLAGS_WERROR])
])

#------------------------------------------------------------------------
# MP_CHECK_SQLITE_VERSION --
#
#	Check the version of SQLite that was found
#
# Arguments:
#       None.
#
# Requires:
#       MP_SQLITE3_FLAGS
#
# Depends:
#		AC_LANG_SOURCE
#
# Results:
#		Result is cached.
#
#       Sets mp_sqlite_version to the older of the SQLite versions
#       found in the header and at runtime, in the same numeric format
#       as SQLITE_VERSION_NUMBER.
#       (Runtime check is skipped if cross-compiling and the result is
#       then always the header version.)
#
#------------------------------------------------------------------------
AC_DEFUN(MP_CHECK_SQLITE_VERSION, [
	AC_REQUIRE([MP_SQLITE3_FLAGS])

	AC_MSG_CHECKING([for SQLite version in header])

	mp_check_sqlite_version_cppflags_save=$CPPFLAGS
	mp_check_sqlite_version_ldflags_save=$LDFLAGS
	CPPFLAGS="$CPPFLAGS $CFLAGS_SQLITE3"
	LDFLAGS="$LDFLAGS $LDFLAGS_SQLITE3"

	AC_CACHE_VAL([mp_cv_sqlite_version], [
		AC_PREPROC_IFELSE(
			[AC_LANG_SOURCE(
				[[
					#include <sqlite3.h>
					#ifndef SQLITE_VERSION_NUMBER
					#  error "SQLITE_VERSION_NUMBER undefined"
					#else
					int mp_sqlite_version = SQLITE_VERSION_NUMBER;
					#endif
				]]
			)],
			[mp_cv_sqlite_version=`grep '^[[[:space:]]]*int mp_sqlite_version = [[0-9]]*;$' conftest.i | sed -E 's/[[^0-9]]*([[0-9]]+);/\1/'`],
			[AC_MSG_ERROR("SQLITE_VERSION_NUMBER undefined or sqlite3.h not found")]
		)
	])

	AC_MSG_RESULT(${mp_cv_sqlite_version})
	mp_sqlite_version=${mp_cv_sqlite_version}

    AC_MSG_CHECKING([for SQLite version at runtime])
    AC_CACHE_VAL([mp_cv_sqlite_run_version], [
        AC_RUN_IFELSE(
            [AC_LANG_SOURCE(
				[[
				    #include <stdio.h>
					#include <sqlite3.h>
					int main(int argc, char* argv[])
					{
					    int vers = sqlite3_libversion_number();
					    if (argc > 1) {
					        printf("%d\n", vers);
					    }
					    return 0;
					}
				]]
			)],
			[mp_cv_sqlite_run_version=`./conftest$EXEEXT noisy`],
			[AC_MSG_ERROR("Failed to run sqlite3_libversion_number test program")],
			[mp_cv_sqlite_run_version=$mp_cv_sqlite_version]
		)
    ])
    AC_MSG_RESULT(${mp_cv_sqlite_run_version})
    if test "$mp_cv_sqlite_run_version" -lt "$mp_cv_sqlite_version"; then
        mp_sqlite_version=$mp_cv_sqlite_run_version
    fi

	CPPFLAGS=$mp_check_sqlite_version_cppflags_save
	LDFLAGS=$mp_check_sqlite_version_ldflags_save
])

#------------------------------------------------------------------------
# MP_PLATFORM --
#
#       Export target platform and major version
#
# Arguments:
#       none.
#
# Requires:
#       none.
#
# Depends:
#       none.
#
# Results:
#       Defines OS_PLATFORM and OS_MAJOR.
#
#------------------------------------------------------------------------
AC_DEFUN([MP_PLATFORM],[
        AC_MSG_CHECKING([for target platform])
        OS_PLATFORM=`uname -s | tr '[[:upper:]]' '[[:lower:]]'`
		OS_MAJOR=`uname -r | cut -d '.' -f 1`
        AC_MSG_RESULT($OS_PLATFORM $OS_MAJOR)
        AC_SUBST(OS_PLATFORM)
        AC_SUBST(OS_MAJOR)
])

#------------------------------------------------------------------------
# MP_TRACEMODE_SUPPORT --
#
#       Check whether trace mode is supported on this platform
#
# Arguments:
#       none.
#
# Requires:
#       OS_PLATFORM and OS_MAJOR from MP_PLATFORM.
#
# Depends:
#       none.
#
# Results:
#       Defines the TRACEMODE_SUPPORT substitution and the
#       HAVE_TRACEMODE_SUPPORT macro.
#
#------------------------------------------------------------------------
AC_DEFUN([MP_TRACEMODE_SUPPORT],[
		AC_REQUIRE([MP_PLATFORM])

		AC_CHECK_FUNCS([kqueue kevent])

		AC_MSG_CHECKING([whether trace mode is supported on this platform])
		if test x"${OS_PLATFORM}" != "xdarwin"; then
			AC_MSG_RESULT([not darwin, no])
			TRACEMODE_SUPPORT=0
		elif test x"${ac_cv_func_kqueue}" != "xyes"; then
			AC_MSG_RESULT([kqueue() not available, no])
			TRACEMODE_SUPPORT=0
		elif test x"${ac_cv_func_kevent}" != "xyes"; then
			AC_MSG_RESULT([kevent() not available, no])
			TRACEMODE_SUPPORT=0
		else
			AC_EGREP_CPP(yes_have_ev_receipt, [
				#include <sys/types.h>
				#include <sys/event.h>
				#include <sys/time.h>
				#ifdef EV_RECEIPT
				yes_have_ev_receipt
				#endif
			],[
				AC_MSG_RESULT([yes])
				TRACEMODE_SUPPORT=1
				AC_DEFINE([HAVE_TRACEMODE_SUPPORT], [1], [Platform supports tracemode.])
			],[
				AC_MSG_RESULT([EV_RECEIPT not available, no])
				TRACEMODE_SUPPORT=0
			])
		fi
        AC_SUBST(TRACEMODE_SUPPORT)
])
