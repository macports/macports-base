#------------------------------------------------------------------------
# MP_COMPILER_ATTRIBUTE_LF_PRIVATE
#
#	Determines whether the compiler supports the symbol
#	'visibility("hidden")' attribute
#
# Arguments:
#	None.
#
# Requires:
#	none
#
# Depends:
#	none
#
# Results:
#
#	Defines the following macros:
#		LF_PRIVATE
#
#------------------------------------------------------------------------

AC_DEFUN([MP_COMPILER_ATTRIBUTE_LF_PRIVATE], [
	AC_MSG_CHECKING([for gcc symbol visibility attribute])
	AC_CACHE_VAL(mp_cv_attribute_mp_private, [
		AC_COMPILE_IFELSE([
			AC_LANG_SOURCE([
				#if defined(__GNUC__) && defined(__APPLE__) && __GNUC__ < 4
				# error Darwin does not support the visibility attribute with gcc releases prior to 4
				#elif defined(WIN32) && __GNUC__ < 4
				# error MinGW/Cygwin do not support the visibility attribute with gcc releases prior to 4.
				#endif
				int a __attribute__ ((visibility("hidden")));
			])
		],[
			mp_cv_attribute_mp_private="__attribute__((visibility(\"hidden\")))"
		],[
			mp_cv_attribute_mp_private="no"
		])
	])

	AC_MSG_RESULT([$mp_cv_attribute_mp_private])
	
	if test x"$mp_cv_attribute_mp_private" = "xno"; then
		MP_PRIVATE=""
	else
		MP_PRIVATE="$mp_cv_attribute_mp_private"
	fi

	AC_DEFINE_UNQUOTED(MP_PRIVATE, $MP_PRIVATE, [Mark private symbols])
])


#------------------------------------------------------------------------
# MP_OBJC_RUNTIME --
#
#	Determine the default, working Objective C runtime
#
# Arguments:
#	None.
#
# Requires:
#	none
#
# Depends:
#	AC_PROG_OBJC from objc.m4
#
# Results:
#
#	Adds a --with-objc-runtime switch to configure.
#	Result is cached.
#
#	Defines one of the following preprocessor macros:
#		APPLE_RUNTIME GNU_RUNTIME
#
#	Substitutes the following variables:
#		OBJC_RUNTIME OBJC_RUNTIME_FLAGS OBJC_LIBS
#		OBJC_PTHREAD_CFLAGS OBJC_PTHREAD_LIBS
#------------------------------------------------------------------------
AC_DEFUN([MP_OBJC_RUNTIME],[
	AC_REQUIRE([AC_PROG_OBJC])
	AC_ARG_WITH(objc-runtime, AC_HELP_STRING([--with-objc-runtime], [Specify either "GNU" or "apple"]), [with_objc_runtime=${withval}])

	if test x"${with_objc_runtime}" != x; then
		case "${with_objc_runtime}" in
			GNU)
				;;
			apple)
				;;
			*)
				AC_MSG_ERROR([${with_objc_runtime} is not a valid argument to --with-objc-runtime. Please specify either "GNU" or "apple"])
				;;
		esac
	fi

	AC_LANG_PUSH([Objective C])

	# Check for common header, objc/objc.h
	AC_CHECK_HEADERS([objc/objc.h], ,[AC_MSG_ERROR([Can't locate Objective C runtime headers])])

	# Save LIBS & OBJCFLAGS 
	# depending on whether the cache is used,
	# the variables may or may not be modified.
	OLD_LIBS="${LIBS}"
	OLD_OBJCFLAGS="${OBJCFLAGS}"

	# Add -lobjc. The following tests will ensure that the library exists and functions with the detected Objective C compiler
	LIBS="${LIBS} -lobjc"

	# Test if pthreads are required to link against
	# libobjc - this is the case on FreeBSD.

	AC_MSG_CHECKING([if linking libobjc requires pthreads])
	AC_CACHE_VAL(mp_cv_objc_req_pthread, [
		# First, test if objc links without pthreads
		# The following uses quadrigraphs
		# '@<:@' = '['
		# '@:>@' = ']'
		AC_LINK_IFELSE([
				AC_LANG_PROGRAM([
						#include <objc/objc.h>
						#include <objc/Object.h>
					], [
						Object *obj = @<:@Object alloc@:>@;
						puts(@<:@obj name@:>@);
					])
				], [
					# Linked without -pthread
					mp_cv_objc_req_pthread="no"
				], [
					# Failed to link without -pthread
					mp_cv_objc_req_pthread="yes"
				]
		)

		# If the above failed, try with pthreads
		if test x"${mp_cv_objc_req_pthread}" = x"yes"; then
			LIBS="${LIBS} ${PTHREAD_LIBS}"
			OBJCFLAGS="${OBJCFLAGS} ${PTHREAD_CFLAGS}"
			AC_LINK_IFELSE([
					AC_LANG_PROGRAM([
							#include <objc/objc.h>
							#include <objc/Object.h>
						], [
							Object *obj = @<:@Object alloc@:>@;
							puts(@<:@obj name@:>@);
						])
					], [
						# Linked with -lpthread 
						mp_cv_objc_req_pthread="yes"
					], [
						# Failed to link against objc at all
						# This will be caught in the runtime
						# checks below
						mp_cv_objc_req_pthread="no"
					]
			)
		fi
	])
	AC_MSG_RESULT(${mp_cv_objc_req_pthread})

	if test x"${mp_cv_objc_req_pthread}" = x"no"; then
		OBJC_LIBS="-lobjc"
		OBJC_PTHREAD_LIBS="${PTHREAD_LIBS}"
		OBJC_PTHREAD_CFLAGS="${PTHREAD_CFLAGS}"
	elif test x"${mp_cv_objc_req_pthread}" = x"yes"; then
		OBJC_LIBS="-lobjc ${PTHREAD_LIBS}"
		OBJCFLAGS="${OBJCFLAGS} ${PTHREAD_CFLAGS}"
	fi

	if test x"${with_objc_runtime}" = x || test x"${with_objc_runtime}" = x"apple"; then
		AC_MSG_CHECKING([for Apple Objective-C runtime])
		AC_CACHE_VAL(mp_cv_objc_runtime_apple, [
			# The following uses quadrigraphs
			# '@<:@' = '['
			# '@:>@' = ']'
			AC_LINK_IFELSE([
					AC_LANG_PROGRAM([
							#include <objc/objc.h>
							#include <objc/objc-api.h>
						], [
							id class = objc_lookUpClass("Object");
							id obj = @<:@class alloc@:>@;
							puts(@<:@obj name@:>@);
						])
					], [
						mp_cv_objc_runtime_apple="yes"
					], [
						mp_cv_objc_runtime_apple="no"
					]
			)
		])
		AC_MSG_RESULT(${mp_cv_objc_runtime_apple})
	else
		mp_cv_objc_runtime_apple="no"
	fi

	if test x"${with_objc_runtime}" = x || test x"${with_objc_runtime}" = x"GNU"; then
		AC_MSG_CHECKING([for GNU Objective C runtime])
		AC_CACHE_VAL(mp_cv_objc_runtime_gnu, [
			# The following uses quadrigraphs
			# '@<:@' = '['
			# '@:>@' = ']'
			AC_LINK_IFELSE([
					AC_LANG_PROGRAM([
							#include <objc/objc.h>
							#include <objc/objc-api.h>
						], [
							id class = objc_lookup_class("Object");
							id obj = @<:@class alloc@:>@;
							puts(@<:@obj name@:>@);
						])
					], [
						mp_cv_objc_runtime_gnu="yes"
					], [
						mp_cv_objc_runtime_gnu="no"
					]
			)
		])
		AC_MSG_RESULT(${mp_cv_objc_runtime_gnu})
	else
		mp_cv_objc_runtime_gnu="no"
	fi

	# Apple runtime is prefered
	if test x"${mp_cv_objc_runtime_apple}" = x"yes"; then
			OBJC_RUNTIME="APPLE_RUNTIME"
			OBJC_RUNTIME_FLAGS="-fnext-runtime"
			AC_MSG_NOTICE([Using Apple Objective-C runtime])
			AC_DEFINE([APPLE_RUNTIME], 1, [Define if using the Apple Objective-C runtime and compiler.]) 
	elif test x"${mp_cv_objc_runtime_gnu}" = x"yes"; then
			OBJC_RUNTIME="GNU_RUNTIME"
			OBJC_RUNTIME_FLAGS="-fgnu-runtime"
			AC_MSG_NOTICE([Using GNU Objective-C runtime])
			AC_DEFINE([GNU_RUNTIME], 1, [Define if using the GNU Objective-C runtime and compiler.]) 
	else
			AC_MSG_FAILURE([Could not locate a working Objective-C runtime.])
	fi

	# Restore LIBS & OBJCFLAGS
	LIBS="${OLD_LIBS}"
	OBJCFLAGS="${OLD_OBJCFLAGS}"

	AC_SUBST([OBJC_RUNTIME])
	AC_SUBST([OBJC_RUNTIME_FLAGS])
	AC_SUBST([OBJC_LIBS])

	AC_SUBST([OBJC_PTHREAD_LIBS])
	AC_SUBST([OBJC_PTHREAD_CFLAGS])

	AC_LANG_POP([Objective C])
])

#------------------------------------------------------------------------
# MP_OBJC_FOUNDATION --
#
#	Find a functional Foundation implementation.
#	The NeXT Foundation implementation is prefered,
#	as it is most likely to be the system provided
#	Foundation.
#
# Arguments:
#	None.
#
# Requires:
#	OBJC_RUNTIME
#
# Depends:
#	AC_PROG_OBJC from objc.m4
#
# Results:
#
#	Adds a --with-objc-foundation switch to configure.
#	Result is cached.
#
#	Defines one of the following preprocessor macros:
#		APPLE_FOUNDATION GNUSTEP_FOUNDATION
#
#	Substitutes the following variables:
#		OBJC_FOUNDATION OBJC_FOUNDATION_LDFLAGS
#		OBJC_FOUNDATION_CPPFLAGS OBJC_FOUNDATION_LIBS
#------------------------------------------------------------------------
AC_DEFUN([MP_OBJC_FOUNDATION],[
	AC_REQUIRE([AC_PROG_OBJC])
	AC_ARG_WITH(objc-foundation, [  --with-objc-foundation  Specify either "GNUstep" or "apple"], [with_objc_foundation=${withval}])

	if test x"${with_objc_foundation}" != x; then
		case "${with_objc_foundation}" in
			GNUstep)
				;;
			GNU)
				with_objc_foundation="GNUstep"
				;;
			apple)
				;;
			*)
				AC_MSG_ERROR([${with_objc_foundation} is not a valid argument to --with-objc-foundation. Please specify either "GNU" or "apple"])
				;;
		esac
	fi

	AC_LANG_PUSH([Objective C])

	if test x"${with_objc_foundation}" == x || test x"${with_objc_foundation}" == x"apple"; then
		# '@<:@' = '['
		# '@:>@' = ']'
		AC_MSG_CHECKING([for Apple Foundation library])

		# Set NeXT LIBS and CFLAGS
		APPLE_FOUNDATION_CFLAGS="-framework Foundation"
		APPLE_FOUNDATION_LIBS="-framework Foundation"

		AC_CACHE_VAL(ac_cv_objc_foundation_apple, [
			# Save old LIBS and CFLAGS
			LIBS_OLD="${LIBS}"
			CFLAGS_OLD="${CFLAGS}"

			CFLAGS="${APPLE_FOUNDATION_CFLAGS} ${CFLAGS}"
			LIBS="${APPLE_FOUNDATION_LIBS} ${LIBS}"

			AC_LINK_IFELSE([
					AC_LANG_PROGRAM([
								#include <Foundation/Foundation.h>
							], [
								NSString *string = @<:@@<:@NSString alloc@:>@ initWithCString: "Hello World"@:>@;
								@<:@NSString length@:>@;
							])
					],[
						ac_cv_objc_foundation_apple="yes"
					],[
						ac_cv_objc_foundation_apple="no"
					]
			)
			# Restore LIBS and CFLAGS
			LIBS="${LIBS_OLD}"
			CFLAGS="${CFLAGS_OLD}"
		])
		AC_MSG_RESULT(${ac_cv_objc_foundation_apple})
	else
		ac_cv_objc_foundation_apple="no"
	fi

	if test x"${with_objc_foundation}" == x || test x${with_objc_foundation} == x"GNUstep"; then
		if test x"${GNUSTEP_SYSTEM_ROOT}" == x; then
			if test x"${with_objc_foundation}" == x"GNUstep"; then
				AC_MSG_ERROR([GNUSTEP_SYSTEM_ROOT is not defined in your environment, preventing the use of GNUstep's Foundation library])
			else
				AC_MSG_WARN([GNUSTEP_SYSTEM_ROOT is not defined in your environment, preventing the use of GNUstep's Foundation library])
			fi
		else

			AC_MSG_CHECKING([for GNUstep Foundation library])

			# Set GNUstep LDFLAGS, CPPFLAGS, and LIBS
			GNUSTEP_LDFLAGS="-L${GNUSTEP_SYSTEM_ROOT}/Library/Libraries/"
			GNUSTEP_CPPFLAGS="-I${GNUSTEP_SYSTEM_ROOT}/Library/Headers/"
			GNUSTEP_LIBS="-lgnustep-base"

			AC_CACHE_VAL(ac_cv_objc_foundation_gnustep, [
				# Save old LDFLAGS, CPPFLAGS, and LIBS
				LDFLAGS_OLD="${LDFLAGS}"
				CPPFLAGS_OLD="${CPPFLAGS}"
				LIBS_OLD="${LIBS}"

				LDFLAGS="${GNUSTEP_LDFLAGS} ${LDFLAGS}"
				CPPFLAGS="${GNUSTEP_CPPFLAGS} ${CPPFLAGS}"
				LIBS="${GNUSTEP_LIBS} ${LIBS}"

				AC_LINK_IFELSE([
						AC_LANG_PROGRAM([
									#include <Foundation/Foundation.h>
								], [
									NSString *string = @<:@@<:@NSString alloc@:>@ initWithCString: "Hello World"@:>@;
									@<:@NSString length@:>@;
								])
						],[
							ac_cv_objc_foundation_gnustep="yes"
						],[
							ac_cv_objc_foundation_gnustep="no"
						]
				)
				# Restore LDFLAGS, CPPFLAGS, and LIBS
				LDFLAGS="${LDFLAGS_OLD}"
				CPPFLAGS="${CPPFLAGS_OLD}"
				LIBS="${LIBS_OLD}"
			])
			AC_MSG_RESULT(${ac_cv_objc_foundation_gnustep})
		fi
	else
		ac_cv_objc_foundation_gnustep="no"
	fi

	# NeXT Foundation is prefered
	if test x"${ac_cv_objc_foundation_apple}" == x"yes"; then
		OBJC_FOUNDATION="Apple"
		OBJC_FOUNDATION_CPPFLAGS="${APPLE_FOUNDATION_CFLAGS}"
		OBJC_FOUNDATION_LIBS="${APPLE_FOUNDATION_LIBS}"
		OBJC_FOUNDATION_LDFLAGS=""
		AC_DEFINE([APPLE_FOUNDATION], 1, [Define if using the Apple Foundation framework]) 
		AC_MSG_NOTICE([Using Apple Foundation library])
	elif test x"${ac_cv_objc_foundation_gnustep}" == x"yes"; then
		OBJC_FOUNDATION="GNUstep"
		OBJC_FOUNDATION_CPPFLAGS="${GNUSTEP_CPPFLAGS}"
		OBJC_FOUNDATION_LIBS="${GNUSTEP_LIBS}"
		OBJC_FOUNDATION_LDFLAGS="${GNUSTEP_LDFLAGS}"
		AC_DEFINE([GNUSTEP_FOUNDATION], 1, [Define if using the GNUstep Foundation library]) 
		AC_MSG_NOTICE([Using GNUstep Foundation library])
	else
		AC_MSG_ERROR([Could not find a working Foundation implementation])
	fi

	AC_SUBST([OBJC_FOUNDATION])
	AC_SUBST([OBJC_FOUNDATION_LDFLAGS])
	AC_SUBST([OBJC_FOUNDATION_CPPFLAGS])
	AC_SUBST([OBJC_FOUNDATION_LIBS])

	AC_LANG_POP([Objective C])
])
