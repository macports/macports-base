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
