dnl $Id: configure.ac,v 1.2 2003/06/21 21:47:48 ssen Exp $
dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.52)
AC_INIT([nbsd-mtree], [20021009], [agc@netbsd.org])
AC_CONFIG_SRCDIR([mtree.c])
AC_CONFIG_HEADER(config.h)
AC_ARG_PROGRAM

AC_CANONICAL_HOST
CANONICAL_HOST=$host
AC_SUBST(CANONICAL_HOST)

# Checks for programs.
AC_PROG_MAKE_SET
AC_PROG_AWK
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LN_S

AUTOCONF=${AUTOCONF-"$srcdir/missing --run autoconf"}
AC_SUBST(AUTOCONF)
AUTOHEADER=${AUTOHEADER-"$srcdir/missing --run autoheader"}
AC_SUBST(AUTOHEADER)

dnl Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([assert.h dirent.h err.h errno.h fcntl.h fnmatch.h fts.h limits.h inttypes.h md5.h md5global.h machine/endian.h netdb.h pwd.h rmd160.h sha1.h signal.h termios.h utmp.h])
AC_CHECK_HEADERS([sys/bitypes.h sys/byteorder.h sys/cdefs.h])
AC_CHECK_HEADERS([sys/endian.h sys/file.h sys/mkdev.h sys/param.h sys/queue.h sys/stat.h sys/time.h sys/ttycom.h])

dnl Checks for typedefs, structures, and compiler characteristics.
AC_C___ATTRIBUTE__
AC_C_CONST
AC_TYPE_SIZE_T
AC_CHECK_TYPES([long long, int8_t, int16_t, int32_t, int64_t, u_int8_t, u_int16_t, u_int32_t, u_int64_t, uint8_t, uint16_t, uint32_t, uint64_t],[],[],
[#if STDC_HEADERS
#include <stdlib.h>
#include <stddef.h>
#endif
#ifdef HAVE_INTTYPES_H
#include <inttypes.h>
#endif
#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_BITYPES_H
#include <sys/bitypes.h>
#endif])
AC_C_BIGENDIAN

# Checks for library functions.
AC_FUNC_MALLOC
AC_FUNC_STRERROR_R
AC_FUNC_VPRINTF
AC_CHECK_FUNCS([bcopy bzero chflags dirfd err errx fgetln fparseln getmode getprogname lchmod lchown MD5File memset memcpy RMD160File setlocale setmode setprogname SHA1File strsep warn warnx])
#
AH_BOTTOM([

#ifdef HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#ifndef __IDSTRING
# define __IDSTRING(name,string) \
       static const char name[] __attribute__((__unused__)) = string
#endif

#ifndef  __RCSID
# define __RCSID(_s)     __IDSTRING(rcsid,_s)
#endif

#ifndef __COPYRIGHT
# define __COPYRIGHT(_s) __IDSTRING(copyright,_s)
#endif

#ifndef __P
# if defined(__STDC__) || defined(__cplusplus)
#  define __P(protos)     protos          /* full-blown ANSI C */
# else
#  define __P(protos)     ()              /* traditional C preprocessor */
# endif
#endif

#ifndef __CONCAT
#  if defined(__STDC__) || defined(__cplusplus)
#  define __CONCAT(x,y)   x ## y
# else
#  define __CONCAT(x,y)   x/**/y
# endif
#endif

#ifndef __BEGIN_DECLS
# if defined(__cplusplus)
#  define __BEGIN_DECLS   extern "C" {
# else
#  define __BEGIN_DECLS
# endif
#endif

#ifndef __END_DECLS
# if defined(__cplusplus)
#  define __END_DECLS     };
# else
#  define __END_DECLS
# endif
#endif

#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif

#ifdef HAVE_SYS_ENDIAN_H
#include <sys/endian.h>
#endif

#ifdef HAVE_MACHINE_ENDIAN_H
#include <machine/endian.h>
#endif

#ifdef HAVE_SYS_BYTEORDER_H
#include <sys/byteorder.h>
#endif

#ifndef LITTLE_ENDIAN
# define LITTLE_ENDIAN 1234
#endif

#ifndef BIG_ENDIAN
# define BIG_ENDIAN    4321
#endif

#ifndef BYTE_ORDER
# if defined(_BIG_ENDIAN)
#  define BYTE_ORDER BIG_ENDIAN
# elif defined(_LITTE_ENDIAN)
#  define BYTE_ORDER LITTLE_ENDIAN
# elif defined(WORDS_BIGENDIAN)
#  define BYTE_ORDER BIG_ENDIAN
# else 
#  define BYTE_ORDER LITTLE_ENDIAN
# endif
#endif

#if defined(HAVE_MEMSET)
#define MEMSET_BZERO(p,l)	memset((p), 0, (l))
#else
# if defined(HAVE_BZERO)
#define MEMSET_BZERO(p,l)	bzero((p), (l))
# else
#error You need either memset or bzero
# endif
#endif

#if defined(HAVE_MEMCPY)
#define MEMCPY_BCOPY(d,s,l)	memcpy((d), (s), (l))
#else
# if defined(HAVE_BCOPY)
#define MEMCPY_BCOPY(d,s,l)	bcopy((s), (d), (l))
# else
#error You need either memcpy or bcopy
# endif
#endif
])

AC_CONFIG_FILES([Makefile])
AC_OUTPUT
