/*
 * xinstall.c
 * $Id$
 * Copyright (c) 1987, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * 2003/12/29:
 *
 * Substantially revamped from original BSD source to become a Tcl builtin
 * procedure for the MacPorts Project.
 * Author: Jordan K. Hubbard
 */

#if HAVE_CONFIG_H
#include <config.h>
#endif

#if HAVE_SYS_CDEFS_H
#include <sys/cdefs.h>
#endif

#include <sys/param.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/wait.h>

#include <ctype.h>

#if HAVE_ERR_H
#include <err.h>
#endif

#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>

#include <tcl.h>

#if HAVE_PATHS_H
#include <paths.h>
#endif

#ifndef _PATH_DEVNULL
#define _PATH_DEVNULL	"/dev/null"
#endif

#ifndef MAXBSIZE
#define MAXBSIZE 65536
#endif

#ifndef S_ISTXT
#ifdef S_ISVTX
#define S_ISTXT S_ISVTX
#else
#error "Not sure how to set S_ISTXT"
#endif
#endif

/* copyfile is available on Tiger and later */
#if HAVE_COPYFILE
extern int copyfile(const char *from, const char *to, void *state,
                    uint32_t flags) __attribute((weak_import));
#endif

#ifndef ALLPERMS
#define ALLPERMS (S_ISUID|S_ISGID|S_ISTXT|S_IRWXU|S_IRWXG|S_IRWXO)
#endif

#if !HAVE_SETMODE
void * setmode(const char *mode_str); 
mode_t getmode(const void *set, mode_t mode);
#endif

/* Bootstrap aid - this doesn't exist in most older releases */
#ifndef MAP_FAILED
#define MAP_FAILED ((void *)-1)	/* from <sys/mman.h> */
#endif

#define MAX_CMP_SIZE	(16 * 1024 * 1024)

#define	DIRECTORY	0x01		/* Tell install it's a directory. */
#define	SETFLAGS	0x02		/* Tell install to set flags. */
#define	NOCHANGEBITS	(UF_IMMUTABLE | UF_APPEND | SF_IMMUTABLE | SF_APPEND)
#define	BACKUP_SUFFIX	".old"

static struct passwd *pp;
static struct group *gp;
static gid_t gid;
static uid_t uid;
static const char *suffix = BACKUP_SUFFIX;
static char *funcname;
static int safecopy, docompare, dostrip, dobackup, dopreserve, nommap;
static mode_t mode;

static int	copy(Tcl_Interp *interp, int, const char *, int, const char *, off_t);
static int	compare(int, const char *, size_t, int, const char *, size_t);
static int	create_newfile(Tcl_Interp *interp, const char *, int, struct stat *);
static int	create_tempfile(const char *, char *, size_t);
static int	install(Tcl_Interp *interp, const char *, const char *, u_long, u_int);
static int	install_dir(Tcl_Interp *interp, char *);
static u_long	numeric_id(Tcl_Interp *interp, const char *, const char *, int *rval);
static void	strip(const char *);
static int	trymmap(int);
static void	usage(Tcl_Interp *interp);

extern int	ui_info(Tcl_Interp *interp, char *mesg);

int
InstallCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	struct stat from_sb, to_sb;
	mode_t *set;
	u_long fset;
	int no_target, rval;
	u_int iflags;
	char *flags, *curdir;
	const char *group, *owner, *cp;
	Tcl_Obj *to_name;
	int dodir = 0;

	suffix = BACKUP_SUFFIX;
	mode = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;
	safecopy = docompare = dostrip = dobackup = dopreserve = nommap = 0;
	iflags = 0;
	group = owner = curdir = NULL;
	funcname = Tcl_GetString(objv[0]);
	/* Adjust arguments */
	++objv, --objc;

	while (objc && (cp = Tcl_GetString(*objv)) && *cp == '-') {
		char ch = *++cp;

		if (!strchr("BbCcdfgMmopSsvW", ch))
			break;
		switch(ch) {
		case 'B':
			if (objc < 2) {
				Tcl_WrongNumArgs(interp, 1, objv, "-B");
				return TCL_ERROR;
			}
			suffix = Tcl_GetString(*(++objv));
			objv++, objc -= 2;
			/* FALLTHROUGH */
		case 'b':
			dobackup = 1;
			objv++, objc--;
			break;
		case 'C':
			docompare = 1;
			objv++, objc--;
			break;
		case 'c':
			/* For backwards compatibility. */
			objv++, objc--;
			break;
		case 'd':
			dodir = 1;
			objv++, objc--;
			break;
		case 'f':
#if defined(UF_IMMUTABLE) && defined(SF_IMMUTABLE)
			if (objc < 2) {
				Tcl_WrongNumArgs(interp, 1, objv, "-f");
				return TCL_ERROR;
			}
			flags = Tcl_GetString(*(++objv));
			if (strtofflags(&flags, &fset, NULL)) {
				Tcl_SetResult(interp, "invalid flags for -f", TCL_STATIC);
				return TCL_ERROR;
			}
			iflags |= SETFLAGS;
			objv++, objc -= 2;
#endif
			break;
		case 'g':
			if (objc < 2) {
				Tcl_WrongNumArgs(interp, 1, objv, "-g");
				return TCL_ERROR;
			}
			group = Tcl_GetString(*(++objv));
			objv++, objc -= 2;
			break;
		case 'M':
			nommap = 1;
			objv++, objc--;
			break;
		case 'm':
			if (!objc) {
				Tcl_WrongNumArgs(interp, 1, objv, "-m");
				return TCL_ERROR;
			}
			if (!(set = setmode(Tcl_GetString(*(++objv))))) {
				char errmsg[255];

				snprintf(errmsg, sizeof errmsg, "%s: Invalid file mode: %s",
					 funcname, Tcl_GetString(*objv));
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return TCL_ERROR;
			}
			mode = getmode(set, 0);
			free(set);
			objv++, objc -= 2;
			break;
		case 'o':
			if (!objc) {
				Tcl_WrongNumArgs(interp, 1, objv, "-o");
				return TCL_ERROR;
			}
			owner = Tcl_GetString(*(++objv));
			objv++, objc -= 2;
			break;
		case 'p':
			docompare = dopreserve = 1;
			objv++, objc--;
			break;
		case 'S':
			safecopy = 1;
			objv++, objc--;
			break;
		case 's':
			dostrip = 1;
			objv++, objc--;
			break;
		case 'v':
			/* provided only for compatibility with install(1) */
			objv++, objc--;
			break;
		case 'W':
			if (!objc) {
				Tcl_WrongNumArgs(interp, 1, objv, "-W");
				return TCL_ERROR;
			}
			curdir = Tcl_GetString(*(++objv));
			objv++, objc -= 2;
			break;
		case '?':
		default:
			usage(interp);
			return TCL_ERROR;
		}
	}

	/* some options make no sense when creating directories */
	if (dostrip && dodir) {
		usage(interp);
		return TCL_ERROR;
	}

	/* must have at least two arguments, except when creating directories */
	if (objc < 2 && !dodir) {
		usage(interp);
		return TCL_ERROR;
	}
	else if (dodir && !objc) {
		usage(interp);
		return TCL_ERROR;
	}
	/* need to make a temp copy so we can compare stripped version */
	if (docompare && dostrip)
		safecopy = 1;

	/* Start out hoping for the best */
	rval = TCL_OK;

	/* If curdir is set, chdir to it */
	if (curdir) {
		if (chdir(curdir)) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Unable to chdir to %s, %s", funcname, curdir, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
		else {
			char msg[255];

			snprintf(msg, sizeof msg, "%s: chdir(%s)\n", funcname, curdir);
			ui_info(interp, msg);
		}
	}

	/* get group and owner id's */
	if (group != NULL) {
		if ((gp = getgrnam(group)) != NULL)
			gid = gp->gr_gid;
		else
			gid = (gid_t)numeric_id(interp, group, "group", &rval);
	} else
		gid = (gid_t)-1;
	/* If the numeric conversion failed, bail */
	if (rval != TCL_OK)
		return rval;

	if (owner != NULL) {
		if ((pp = getpwnam(owner)) != NULL)
			uid = pp->pw_uid;
		else
			uid = (uid_t)numeric_id(interp, owner, "user", &rval);
	} else
		uid = (uid_t)-1;
	/* If the numeric conversion failed, bail */
	if (rval != TCL_OK)
		return rval;

	if (dodir) {
		for (; objc; ++objv, --objc) {
			rval = install_dir(interp, Tcl_GetString(*objv));
			if (rval != TCL_OK)
				return rval;
		}
		return rval;
	}

	to_name = objv[objc - 1];
	no_target = stat(Tcl_GetString(to_name), &to_sb);
	if (!no_target && S_ISDIR(to_sb.st_mode)) {
		for (; *objv != to_name; ++objv) {
			rval = install(interp, Tcl_GetString(*objv), Tcl_GetString(to_name), fset, iflags | DIRECTORY);
			if (rval != TCL_OK)
				return rval;
		}
		return rval;
	}

	/* can't do file1 file2 directory/file */
	if (objc != 2) {
		usage(interp);
		return TCL_ERROR;
	}

	if (!no_target) {
		if (stat(Tcl_GetString(*objv), &from_sb)) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Cannot stat: %s, %s",
				 funcname, Tcl_GetString(*objv), strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
		if (!S_ISREG(to_sb.st_mode)) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Inappropriate file type: %s",
				 funcname, Tcl_GetString(to_name));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
		if (to_sb.st_dev == from_sb.st_dev &&
		    to_sb.st_ino == from_sb.st_ino) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: %s and %s are the same file",
				 funcname, Tcl_GetString(*objv), Tcl_GetString(to_name));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
	}
	return install(interp, Tcl_GetString(*objv), Tcl_GetString(to_name), fset, iflags);
}

static u_long
numeric_id(Tcl_Interp *interp, const char *name, const char *type, int *rval)
{
	u_long val;
	char *ep;

	/*
	 * XXX
	 * We know that uid_t's and gid_t's are unsigned longs.
	 */
	errno = 0;
	*rval = TCL_OK;
	val = strtoul(name, &ep, 10);
	if (errno) {
		char errmsg[255];

		snprintf(errmsg, sizeof errmsg, "%s: Bad uid: %s", funcname, name);
		Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
		*rval = TCL_ERROR;
	}
	if (*ep != '\0') {
		char errmsg[255];

		snprintf(errmsg, sizeof errmsg, "%s: Unknown %s %s", funcname, type, name);
		Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
		*rval = TCL_ERROR;
	}
	return (val);
}

/*
 * install --
 *	build a path name and install the file
 */
static int
install(Tcl_Interp *interp, const char *from_name, const char *to_name, u_long fset, u_int flags)
{
	struct stat from_sb, temp_sb, to_sb;
	struct timeval tvb[2];
	int devnull, files_match, from_fd = 0, serrno, target;
	int tempcopy, temp_fd, to_fd = 0;
	char backup[MAXPATHLEN], *p, pathbuf[MAXPATHLEN], tempfile[MAXPATHLEN];
	char msg[256];

	files_match = 0;

	/* If try to install NULL file to a directory, fails. */
	if (flags & DIRECTORY || strcmp(from_name, _PATH_DEVNULL)) {
		if (stat(from_name, &from_sb)) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Cannot stat: %s, %s",
				 funcname, from_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
		if (!S_ISREG(from_sb.st_mode)) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Inappropriate file type: %s",
				 funcname, from_name);
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			errno = EINVAL;
			return TCL_ERROR;
		}
		/* Build the target path. */
		if (flags & DIRECTORY) {
			(void)snprintf(pathbuf, sizeof(pathbuf), "%s/%s",
				       to_name, (p = strrchr(from_name, '/')) ? ++p : from_name);
			to_name = pathbuf;
		}
		devnull = 0;
	} else {
		devnull = 1;
	}

	target = stat(to_name, &to_sb) == 0;

	/* Only install to regular files. */
	if (target && !S_ISREG(to_sb.st_mode)) {
		char errmsg[255];

		snprintf(errmsg, sizeof errmsg, "%s: Can only install to regular files, not to %s",
			 funcname, to_name);
		Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
		errno = EINVAL;
		return TCL_ERROR;
	}

	/* Only copy safe if the target exists. */
	tempcopy = safecopy && target;

	if (!devnull && (from_fd = open(from_name, O_RDONLY, 0)) < 0) {
		char errmsg[255];

		snprintf(errmsg, sizeof errmsg, "%s: Unable to open: %s, %s",
			 funcname, from_name, strerror(errno));
		Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
		return TCL_ERROR;
	}

	/* If we don't strip, we can compare first. */
	if (docompare && !dostrip && target) {
		if ((to_fd = open(to_name, O_RDONLY, 0)) < 0) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Unable to open: %s, %s",
				 funcname, to_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}

		if (devnull)
			files_match = to_sb.st_size == 0;
		else
			files_match = !(compare(from_fd, from_name,
			    (size_t)from_sb.st_size, to_fd,
			    to_name, (size_t)to_sb.st_size));

		/* Close "to" file unless we match. */
		if (!files_match)
			(void)close(to_fd);
	}

	if (!files_match) {
		if (tempcopy) {
			to_fd = create_tempfile(to_name, tempfile,
			    sizeof(tempfile));
			if (to_fd < 0) {
				char errmsg[255];

				snprintf(errmsg, sizeof errmsg, "%s: Unable to open temporary file for: %s, %s",
					 funcname, to_name, strerror(errno));
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return TCL_ERROR;
			}
		} else {
			if ((to_fd = create_newfile(interp, to_name, target, &to_sb)) < 0) {
				char errmsg[255];

				snprintf(errmsg, sizeof errmsg, "%s: Unable to create new file for: %s, %s",
					 funcname, to_name, strerror(errno));
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return TCL_ERROR;
			}
			snprintf(msg, sizeof msg, "%s: %s -> %s\n", funcname, from_name, to_name);
			ui_info(interp, msg);
		}
		if (!devnull) {
			if (copy(interp, from_fd, from_name, to_fd,
			     tempcopy ? tempfile : to_name, from_sb.st_size) != TCL_OK)
				return TCL_ERROR;
#if HAVE_COPYFILE
			if (copyfile)
				copyfile(from_name, tempcopy ? tempfile : to_name, 0, 0x5);
#endif
		}
	}

	if (dostrip) {
		strip(tempcopy ? tempfile : to_name);

		/*
		 * Re-open our fd on the target, in case we used a strip
		 * that does not work in-place -- like GNU binutils strip.
		 */
		close(to_fd);
		to_fd = open(tempcopy ? tempfile : to_name, O_RDONLY, 0);
		if (to_fd < 0) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Error stripping %s, %s",
				 funcname, to_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
	}

	/*
	 * Compare the stripped temp file with the target.
	 */
	if (docompare && dostrip && target) {
		temp_fd = to_fd;

		/* Re-open to_fd using the real target name. */
		if ((to_fd = open(to_name, O_RDONLY, 0)) < 0) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Cannot open strip target %s, %s",
				 funcname, to_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}

		if (fstat(temp_fd, &temp_sb)) {
			char errmsg[255];

			serrno = errno;
			(void)unlink(tempfile);
			errno = serrno;
			snprintf(errmsg, sizeof errmsg, "%s: Cannot stat %s, %s",
				 funcname, tempfile, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}

		if (compare(temp_fd, tempfile, (size_t)temp_sb.st_size, to_fd,
			    to_name, (size_t)to_sb.st_size) == 0) {
			/*
			 * If target has more than one link we need to
			 * replace it in order to snap the extra links.
			 * Need to preserve target file times, though.
			 */
			if (to_sb.st_nlink != 1) {
				tvb[0].tv_sec = to_sb.st_atime;
				tvb[0].tv_usec = 0;
				tvb[1].tv_sec = to_sb.st_mtime;
				tvb[1].tv_usec = 0;
				(void)utimes(tempfile, tvb);
			} else {
				files_match = 1;
				(void)unlink(tempfile);
			}
			(void)close(temp_fd);
		}
	}

	/*
	 * Move the new file into place if doing a safe copy
	 * and the files are different (or just not compared).
	 */
	if (tempcopy && !files_match) {
		/* Try to turn off the immutable bits. */
#if defined(UF_IMMUTABLE) && defined(SF_IMMUTABLE)
		if (to_sb.st_flags & NOCHANGEBITS)
			(void)chflags(to_name, to_sb.st_flags & ~NOCHANGEBITS);
#endif
		if (dobackup) {
			if ((size_t)snprintf(backup, MAXPATHLEN, "%s%s", to_name,
					     suffix) != strlen(to_name) + strlen(suffix)) {
				char errmsg[255];

				unlink(tempfile);
				snprintf(errmsg, sizeof errmsg, "%s: Backup filename %s too long",
					 funcname, to_name);
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return TCL_ERROR;
			}
			snprintf(msg, sizeof msg, "%s: %s -> %s\n", funcname, to_name, backup);
			ui_info(interp, msg);
			if (rename(to_name, backup) < 0) {
				char errmsg[255];

				serrno = errno;
				unlink(tempfile);
				errno = serrno;
				snprintf(errmsg, sizeof errmsg,	"%s: Rename: %s to %s, %s",
					 funcname, to_name, backup, strerror(errno));
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return TCL_ERROR;
			}
		}
		snprintf(msg, sizeof msg, "%s: %s -> %s\n", funcname, from_name, to_name);
		ui_info(interp, msg);
		if (rename(tempfile, to_name) < 0) {
			char errmsg[255];

			serrno = errno;
			unlink(tempfile);
			errno = serrno;
			snprintf(errmsg, sizeof errmsg, "%s: Rename: %s to %s, %s",
				 funcname, tempfile, to_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}

		/* Re-open to_fd so we aren't hosed by the rename(2). */
		(void) close(to_fd);
		if ((to_fd = open(to_name, O_RDONLY, 0)) < 0) {
			char errmsg[255];

			snprintf(errmsg, sizeof errmsg, "%s: Cannot open %s, %s",
				 funcname, to_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
	}

	/*
	 * Preserve the timestamp of the source file if necessary.
	 */
	if (dopreserve && !files_match && !devnull) {
		tvb[0].tv_sec = from_sb.st_atime;
		tvb[0].tv_usec = 0;
		tvb[1].tv_sec = from_sb.st_mtime;
		tvb[1].tv_usec = 0;
		(void)utimes(to_name, tvb);
	}

	if (fstat(to_fd, &to_sb) == -1) {
		char errmsg[255];

		serrno = errno;
		(void)unlink(to_name);
		errno = serrno;
		snprintf(errmsg, sizeof errmsg, "%s: Cannot stat %s, %s",
			 funcname, to_name, strerror(errno));
		Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
		return TCL_ERROR;
	}

	/*
	 * Set owner, group, mode for target; do the chown first,
	 * chown may lose the setuid bits.
	 */
	if ((gid != (gid_t)-1 && gid != to_sb.st_gid) ||
	    (uid != (uid_t)-1 && uid != to_sb.st_uid) ||
	    (mode != (to_sb.st_mode & ALLPERMS))) {
#if defined(UF_IMMUTABLE) && defined(SF_IMMUTABLE)
		/* Try to turn off the immutable bits. */
		if (to_sb.st_flags & NOCHANGEBITS)
			(void)fchflags(to_fd, to_sb.st_flags & ~NOCHANGEBITS);
#endif
	}

	if ((gid != (gid_t)-1 && gid != to_sb.st_gid) ||
	    (uid != (uid_t)-1 && uid != to_sb.st_uid))
		if (fchown(to_fd, uid, gid) == -1) {
			char errmsg[255];

			serrno = errno;
			(void)unlink(to_name);
			errno = serrno;
			snprintf(errmsg, sizeof errmsg, "%s: chown/chgrp %s, %s",
				 funcname, to_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}

	if (mode != (to_sb.st_mode & ALLPERMS))
		if (fchmod(to_fd, mode)) {
			char errmsg[255];

			serrno = errno;
			(void)unlink(to_name);
			errno = serrno;
			snprintf(errmsg, sizeof errmsg, "%s: chmod %s, %s",
				 funcname, to_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}

	/*
	 * If provided a set of flags, set them, otherwise, preserve the
	 * flags, except for the dump flag.
	 * NFS does not support flags.  Ignore EOPNOTSUPP flags if we're just
	 * trying to turn off UF_NODUMP.  If we're trying to set real flags,
	 * then warn if the fs doesn't support it, otherwise fail.
	 */
#if defined(UF_NODUMP)
	if (!devnull && (flags & SETFLAGS ||
	    (from_sb.st_flags & ~UF_NODUMP) != to_sb.st_flags) &&
	    fchflags(to_fd,
	    flags & SETFLAGS ? fset : from_sb.st_flags & ~UF_NODUMP)) {
		if (flags & SETFLAGS) {
			if (errno != EOPNOTSUPP) {
				char errmsg[255];

				serrno = errno;
				(void)unlink(to_name);
				errno = serrno;
				snprintf(errmsg, sizeof errmsg, "%s: chflags %s, %s",
					 funcname, to_name, strerror(errno));
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return TCL_ERROR;
			}
		}
	}
#endif
	(void)close(to_fd);
	if (!devnull)
		(void)close(from_fd);
	return TCL_OK;
}

/*
 * compare --
 *	compare two files; non-zero means files differ
 */
static int
compare(int from_fd, const char *from_name UNUSED, size_t from_len,
	int to_fd, const char *to_name UNUSED, size_t to_len)
{
	char *p, *q;
	int rv;
	int done_compare;

	rv = 0;
	if (from_len != to_len)
		return 1;

	if (from_len <= MAX_CMP_SIZE) {
		done_compare = 0;
		if (trymmap(from_fd) && trymmap(to_fd)) {
			p = mmap(NULL, from_len, PROT_READ, MAP_SHARED, from_fd, (off_t)0);
			if (p == (char *)MAP_FAILED)
				goto out;
			q = mmap(NULL, from_len, PROT_READ, MAP_SHARED, to_fd, (off_t)0);
			if (q == (char *)MAP_FAILED) {
				munmap(p, from_len);
				goto out;
			}

			rv = memcmp(p, q, from_len);
			munmap(p, from_len);
			munmap(q, from_len);
			done_compare = 1;
		}
	out:
		if (!done_compare) {
			char buf1[MAXBSIZE];
			char buf2[MAXBSIZE];
			int n1, n2;

			rv = 0;
			lseek(from_fd, 0, SEEK_SET);
			lseek(to_fd, 0, SEEK_SET);
			while (rv == 0) {
				n1 = read(from_fd, buf1, sizeof(buf1));
				if (n1 == 0)
					break;		/* EOF */
				else if (n1 > 0) {
					n2 = read(to_fd, buf2, n1);
					if (n2 == n1)
						rv = memcmp(buf1, buf2, n1);
					else
						rv = 1;	/* out of sync */
				} else
					rv = 1;		/* read failure */
			}
			lseek(from_fd, 0, SEEK_SET);
			lseek(to_fd, 0, SEEK_SET);
		}
	} else
		rv = 1;	/* don't bother in this case */

	return rv;
}

/*
 * create_tempfile --
 *	create a temporary file based on path and open it
 */
static int
create_tempfile(const char *path, char *temp, size_t tsize)
{
	char *p;

	(void)strncpy(temp, path, tsize);
	temp[tsize - 1] = '\0';
	if ((p = strrchr(temp, '/')) != NULL)
		p++;
	else
		p = temp;
	(void)strncpy(p, "INS@XXXX", &temp[tsize - 1] - p);
	temp[tsize - 1] = '\0';
	return (mkstemp(temp));
}

/*
 * create_newfile --
 *	create a new file, overwriting an existing one if necessary
 */
static int
create_newfile(Tcl_Interp *interp, const char *path, int target, struct stat *sbp)
{
	char backup[MAXPATHLEN];
	int saved_errno = 0;
	int newfd;
	char msg[256];

	if (target) {
		/*
		 * Unlink now... avoid ETXTBSY errors later.  Try to turn
		 * off the append/immutable bits -- if we fail, go ahead,
		 * it might work.
		 */
#if defined(UF_IMMUTABLE) && defined(SF_IMMUTABLE)
		if (sbp->st_flags & NOCHANGEBITS)
			(void)chflags(path, sbp->st_flags & ~NOCHANGEBITS);
#endif

		if (dobackup) {
			if ((size_t)snprintf(backup, MAXPATHLEN, "%s%s",
					     path, suffix) != strlen(path) + strlen(suffix)) {
				char errmsg[255];

				snprintf(errmsg, sizeof errmsg, "%s: Backup filename %s too long",
					 funcname, path);
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return -1;
			}
			(void)snprintf(backup, MAXPATHLEN, "%s%s", path, suffix);
			snprintf(msg, sizeof msg, "%s: %s -> %s\n", funcname, path, backup);
			ui_info(interp, msg);
			if (rename(path, backup) < 0) {
				char errmsg[255];

				snprintf(errmsg, sizeof errmsg, "%s: Rename: %s to %s, %s",
					 funcname, path, backup, strerror(errno));
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return -1;
			}
		} else
			if (unlink(path) < 0)
				saved_errno = errno;
	}

	newfd = open(path, O_CREAT | O_RDWR | O_TRUNC, S_IRUSR | S_IWUSR);
	if (newfd < 0 && saved_errno != 0)
		errno = saved_errno;
	return newfd;
}

/*
 * copy --
 *	copy from one file to another
 */
static int
copy(Tcl_Interp *interp, int from_fd, const char *from_name, int to_fd, const char *to_name,
     off_t size)
{
	int nr, nw;
	int serrno;
	char *p, buf[MAXBSIZE];
	int done_copy;

	/* Rewind file descriptors. */
	if (lseek(from_fd, (off_t)0, SEEK_SET) == (off_t)-1) {
		char errmsg[255];

		snprintf(errmsg, sizeof errmsg, "%s: lseek %s, %s", funcname, from_name, strerror(errno));
		Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
		return TCL_ERROR;
	}
	if (lseek(to_fd, (off_t)0, SEEK_SET) == (off_t)-1) {
		char errmsg[255];

		snprintf(errmsg, sizeof errmsg, "%s: lseek %s, %s", funcname, to_name, strerror(errno));
		Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
		return TCL_ERROR;
	}
	/*
	 * Mmap and write if less than 8M (the limit is so we don't totally
	 * trash memory on big files.  This is really a minor hack, but it
	 * wins some CPU back.
	 */
	done_copy = 0;
	if (size <= 8 * 1048576 && trymmap(from_fd) &&
	    (p = mmap(NULL, (size_t)size, PROT_READ, MAP_SHARED,
		    from_fd, (off_t)0)) != (char *)MAP_FAILED) {
		if ((nw = write(to_fd, p, size)) != size) {
			char errmsg[255];

			serrno = errno;
			(void)unlink(to_name);
			errno = nw > 0 ? EIO : serrno;
			snprintf(errmsg, sizeof errmsg, "%s: Write error on %s, %s",
				 funcname, to_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
		done_copy = 1;
	}
	if (!done_copy) {
		while ((nr = read(from_fd, buf, sizeof(buf))) > 0)
			if ((nw = write(to_fd, buf, nr)) != nr) {
				char errmsg[255];

				serrno = errno;
				(void)unlink(to_name);
				errno = nw > 0 ? EIO : serrno;
				snprintf(errmsg, sizeof errmsg, "%s: Write error on %s, %s",
					 funcname, to_name, strerror(errno));
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return TCL_ERROR;
			}
		if (nr != 0) {
			char errmsg[255];

			serrno = errno;
			(void)unlink(to_name);
			errno = serrno;
			snprintf(errmsg, sizeof errmsg, "%s: Error on %s, %s",
				 funcname, from_name, strerror(errno));
			Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
			return TCL_ERROR;
		}
	}
	return TCL_OK;
}

/*
 * strip --
 *	use strip(1) to strip the target file
 */
static void
strip(const char *to_name)
{
	const char *stripbin;
	int serrno, status;

	switch (fork()) {
	case -1:
		serrno = errno;
		(void)unlink(to_name);
		errno = serrno;
		return;

	case 0:
		stripbin = getenv("STRIPBIN");
		if (stripbin == NULL)
			stripbin = "strip";
		execlp(stripbin, stripbin, to_name, (char *)NULL);
		return;

	default:
		if (wait(&status) == -1 || status) {
			serrno = errno;
			(void)unlink(to_name);
			return;
		}
	}
}

/*
 * install_dir --
 *	build directory heirarchy
 */
int
install_dir(Tcl_Interp *interp, char *path)
{
	char *p;
	struct stat sb;
	int ch;

	for (p = path;; ++p)
		if (!*p || (p != path && *p  == '/')) {
			ch = *p;
			*p = '\0';
			if (stat(path, &sb)) {
				if (errno != ENOENT || mkdir(path, 0755) < 0) {
					char errmsg[255];

					*p = ch;
					snprintf(errmsg, sizeof errmsg, "%s: mkdir %s, %s",
						 funcname, path, strerror(errno));
					Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
					return TCL_ERROR;
				}
				else {
					char msg[255];

					snprintf(msg, sizeof msg, "%s: mkdir %s\n", funcname, path);
					ui_info(interp, msg);
				}
			} else if (!S_ISDIR(sb.st_mode)) {
				char errmsg[255];

				snprintf(errmsg, sizeof errmsg, "%s: directory target %s exists and is not a directory",
					 funcname, path);
				Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
				return TCL_ERROR;
			}
			if (!(*p = ch))
				break;
 		}

	if ((gid != (gid_t)-1 || uid != (uid_t)-1) && chown(path, uid, gid))
		{ /* Don't bother to warn */ };
	if (chmod(path, mode))
		{ /* Don't bother to warn */ };
	return TCL_OK;
}

/*
 * usage --
 *	copy usage message to Tcl result.
 */
static void
usage(Tcl_Interp *interp)
{
	char errmsg[500];

	snprintf(errmsg, sizeof errmsg, 
"%s usage: %s [-bCcpSsv] [-B suffix] [-W dir] [-f flags] [-g group] [-m mode]\n"
"               [-o owner] file1 file2\n"
"       %s [-bCcpSsv] [-B suffix] [-W dir] [-f flags] [-g group] [-m mode]\n"
"               [-o owner] file1 ... fileN directory\n"
"       %s -d [-v] [-g group] [-m mode] [-o owner] directory ...",
		funcname, funcname, funcname, funcname);
	Tcl_SetResult(interp, errmsg, TCL_VOLATILE);
}

/*
 * trymmap --
 *	return true (1) if mmap should be tried, false (0) if not.
 */
int
trymmap(int fd)
{
/*
 * The ifdef is for bootstrapping - f_fstypename doesn't exist in
 * pre-Lite2-merge systems.
 */
#ifdef MFSNAMELEN
	struct statfs stfs;

	if (nommap || fstatfs(fd, &stfs) != 0)
		return (0);
	if (strcmp(stfs.f_fstypename, "ufs") == 0 ||
	    strcmp(stfs.f_fstypename, "cd9660") == 0)
		return (1);
#endif
	return (0);
}
