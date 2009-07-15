/*
 * flock.c
 * $Id$
 *
 * Copyright (c) 2009 The MacPorts Project
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of The MacPorts Project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#if HAVE_CONFIG_H
#include <config.h>
#endif

#if HAVE_SYS_FILE_H
#include <sys/file.h>
#endif

#include <errno.h>
#include <inttypes.h>
#include <string.h>

#include <tcl.h>

#include "flock.h"

int
FlockCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	static const char errorstr[] = "use one of \"-shared\", \"-exclusive\", or \"-unlock\", and optionally \"-noblock\"";
	int operation = 0, fd, i, ret;
	int errnoval = 0;
	int oshared = 0, oexclusive = 0, ounlock = 0, onoblock = 0;
#if defined(HAVE_LOCKF) && !defined(HAVE_FLOCK)
	off_t curpos;
#endif
	char *res;
	Tcl_Channel channel;
	ClientData handle;

	if (objc < 3 || objc > 4) {
		Tcl_WrongNumArgs(interp, 1, objv, "channelId switches");
		return TCL_ERROR;
	}

    	if ((channel = Tcl_GetChannel(interp, Tcl_GetString(objv[1]), NULL)) == NULL)
		return TCL_ERROR;

	if (Tcl_GetChannelHandle(channel, TCL_READABLE|TCL_WRITABLE, &handle) != TCL_OK) {
		Tcl_SetResult(interp, "error getting channel handle", TCL_STATIC);
		return TCL_ERROR;
	}
	fd = (int)(intptr_t)handle;

	for (i = 2; i < objc; i++) {
		char *arg = Tcl_GetString(objv[i]);
		if (!strcmp(arg, "-shared")) {
		  oshared = 1;
		} else if (!strcmp(arg, "-exclusive")) {
		  oexclusive = 1;
		} else if (!strcmp(arg, "-unlock")) {
		  ounlock = 1;
		} else if (!strcmp(arg, "-noblock")) {
		  onoblock = 1;
		}
	}

	/* verify the arguments */

	if((oshared + oexclusive + ounlock) != 1) {
	  /* only one of the options should have been specified */
	  Tcl_SetResult(interp, (void *) &errorstr, TCL_STATIC);
	  return TCL_ERROR;
	}

	if(onoblock && ounlock) {
	  /* should not be specified together */
	  Tcl_SetResult(interp, "-noblock cannot be used with -unlock", TCL_STATIC);
	  return TCL_ERROR;
	}
	  
#if HAVE_FLOCK
	/* prefer flock if present */
	if(oshared) operation |= LOCK_SH;

	if(oexclusive) operation |= LOCK_EX;

	if(ounlock) operation |= LOCK_UN;

	if(onoblock) operation |= LOCK_NB;

	ret = flock(fd, operation);
	if(ret == -1) {
	  errnoval = errno;
	}
#else
#if HAVE_LOCKF
	if(ounlock) operation = F_ULOCK;

	/* lockf semantics don't map to shared locks. */
	if(oshared || oexclusive) {
	  if(onoblock) {
	    operation = F_TLOCK;
	  } else {
	    operation = F_LOCK;
	  }
	}

	curpos = lseek(fd, 0, SEEK_CUR);
	if(curpos == -1) {
		Tcl_SetResult(interp, (void *) "Seek error", TCL_STATIC);
		return TCL_ERROR;
	}

	ret = lockf(fd, operation, 0); /* lock entire file */

	curpos = lseek(fd, curpos, SEEK_SET);
	if(curpos == -1) {
		Tcl_SetResult(interp, (void *) "Seek error", TCL_STATIC);
		return TCL_ERROR;
	}

	if(ret == -1) {
	  errnoval = errno;
	  if((oshared || oexclusive)) {
	    /* map the errno val to what we would expect for flock */
	    if(onoblock && errnoval == EAGAIN) {
	      /* on some systems, EAGAIN=EWOULDBLOCK, but lets be safe */
	      errnoval = EWOULDBLOCK;
	    } else if(errnoval == EINVAL) {
	      errnoval = EOPNOTSUPP;
	    }
	  }
	}
#else
#error no available locking implementation
#endif /* HAVE_LOCKF */
#endif /* HAVE_FLOCK */

	if (ret != 0)
	{
		switch(errnoval) {
			case EAGAIN:
				res = "EAGAIN";
				break;
			case EBADF:
				res = "EBADF";
				break;
			case EINVAL:
				res = "EINVAL";
				break;
			case EOPNOTSUPP:
				res = "EOPNOTSUPP";
				break;
			default:
				res = strerror(errno);
				break;
		}
		Tcl_SetResult(interp, (void *) res, TCL_STATIC);
		return TCL_ERROR;
	}
	return TCL_OK;
}
