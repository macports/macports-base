#
# Include the TEA standard macro set
#

builtin(include,tclconfig/tcl.m4)

#
# Add here whatever m4 macros you want to define for your package
#

#------------------------------------------------------------------------
# CRITCL_TEA_PUBLIC_PACKAGE_HEADERS --
#
#	Locate the installed public FOO header files
#
# Arguments:
#	Name of the package to search headers for.
#
# Requires:
#	CYGPATH must be set
#
# Results:
#
#	Adds a --with-[$1]-include switch to configure.
#	Result is cached.
#
#	Substs the following vars:
#		CRITCL_API_$1_INCLUDE
#------------------------------------------------------------------------

AC_DEFUN([CRITCL_TEA_PUBLIC_PACKAGE_HEADERS],[
    # CRITCL_TEA_PUBLIC_PACKAGE_HEADERS: $1
    AC_MSG_CHECKING([for $1 public headers])
    AC_ARG_WITH([$1-include], [  --with-$1-include       directory containing the public $1 header files], [with_$1_include=${withval}])
    AC_CACHE_VAL(ac_cv_c_$1_header, [
	# Use the value from --with-$1-include, if it was given

	if test x"[$]{with_$1_include}" != x ; then
	    if test -f "[$]{with_$1_include}/$1Decls.h" ; then
		ac_cv_c_$1_header=[$]{with_$1_include}
	    else
		AC_MSG_ERROR([[$]{with_$1_include} directory does not contain $1Decls.h])
	    fi
	else
	    list=""
	    if test "`uname -s`" = "Darwin"; then
		# If $1 was built as a framework, attempt to use
		# the framework's Headers directory
		case [$]{$1_DEFS} in
		    *$1_FRAMEWORK*)
			list="`ls -d [$]{$1_BIN_DIR}/Headers 2>/dev/null`"
			;;
		esac
	    fi

	    # Check order: pkg --prefix location, Tcl's --prefix location,
	    # relative to directory of $1Config.sh.

	    eval "temp_includedir=[$]{includedir}"
	    list="[$]list \
		`ls -d [$]{temp_includedir}        2>/dev/null` \
		`ls -d [$]{$1_PREFIX}/include     2>/dev/null` \
		`ls -d [$]{$1_BIN_DIR}/../include 2>/dev/null` \
		`ls -d ${TCL_PREFIX}/include     2>/dev/null` \
		`ls -d ${TCL_BIN_DIR}/../include 2>/dev/null`"

	    if test "[$]{TEA_PLATFORM}" != "windows" -o "[$]GCC" = "yes"; then
		list="[$]list /usr/local/include /usr/include"
		if test x"[$]{$1_INCLUDE_SPEC}" != x ; then
		    d=`echo "[$]{$1_INCLUDE_SPEC}" | sed -e 's/^-I//'`
		    list="[$]list `ls -d ${d} 2>/dev/null`"
		fi
	    fi
	    for i in [$]list ; do
		if test -f "[$]i/$1/$1Decls.h" ; then
		    ac_cv_c_$1_header=[$]i
		    break
		fi
	    done
	fi
    ])

    # Print a message based on how we determined the include path
    if test x"[$]{ac_cv_c_$1_header}" = x ; then
	AC_MSG_ERROR([$1Decls.h not found.  Please specify its location with --with-$1-include])
    else
	AC_MSG_RESULT([[$]{ac_cv_c_$1_header}])
    fi

    # Convert to a native path and substitute into the transfer variable.
    # NOTE: Anything going into actual TEA would have to use A TEA_xx
    # transfer variable, instead of critcl.
    INCLUDE_DIR_NATIVE=`[$]{CYGPATH} [$]{ac_cv_c_$1_header}`
    CRITCL_API_$1_INCLUDE="\"[$]{INCLUDE_DIR_NATIVE}\""
    AC_SUBST([CRITCL_API_$1_INCLUDE])
])

#------------------------------------------------------------------------
# CRITCL_TEA_WITH_CONFIG --
#
#	Declare a --with-FOO option, with default and legal values.
#
# Arguments:
#	Name of the option.
#	List of legal values.
#	Default value.
#	Option description.
#
# Requires:
# Results:
#	Adds a --with-[$1] switch to configure.
#
#	Substs the following vars:
#		CRITCL_UCONFIG_$1
#------------------------------------------------------------------------

AC_DEFUN([CRITCL_TEA_WITH_CONFIG],[
    # CRITCL_TEA_WITH_CONFIG: $1
    AC_ARG_WITH([$1],
	AC_HELP_STRING([--with-$1],
		       [$4]),
	[with_uc_$1=${withval}])

    # Use default if user did not specify anything.
    if test x"[$]{with_uc_$1}" = x ; then
	with_uc_$1="$3"
    fi

    AC_MSG_CHECKING([Validating $1])
    tcl_ok=no
    for x in $2
    do
        if test "[$]x" = "[$]with_uc_$1" ; then
	    tcl_ok=yes
	    break
	fi
    done
    if test "[$]tcl_ok" = "no" ; then
	AC_MSG_ERROR([Illegal value [$]with_uc_$1, expected one of: $2])
    else
	AC_MSG_RESULT([[$]with_uc_$1])
    fi

    CRITCL_UCONFIG_$1="-with-$1 \"[$]with_uc_$1\""
    AC_SUBST([CRITCL_UCONFIG_$1])
])

#------------------------------------------------------------------------
# CRITCL_TEA_BOOL_CONFIG --
#
#	Declare a --disable/enable-FOO option, with default.
#
# Arguments:
#	Name of the option.
#	Default value.
#	Option description.
#
# Requires:
# Results:
#	Adds a --enable-[$1] switch to configure.
#
#	Substs the following vars:
#		CRITCL_UCONFIG_$1
#------------------------------------------------------------------------

AC_DEFUN([CRITCL_TEA_BOOL_CONFIG],[
    # CRITCL_TEA_BOOL_CONFIG: $1
    AC_ARG_ENABLE([$1],
	AC_HELP_STRING([--enable-$1],[$3]),
	[bool_uc_$1=${enableval}]
	[bool_uc_$1="$2"])

    if test "bool_uc_$1" = "yes" ; then
    	CRITCL_UCONFIG_$1="-enable $1"
    else
    	CRITCL_UCONFIG_$1="-disable $1"
    fi

    AC_SUBST([CRITCL_UCONFIG_$1])
])
