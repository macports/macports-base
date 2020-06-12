/*
 * curl.c
 *
 * Copyright (c) 2005 Paul Guyot
 * Copyright 2006-2011, 2013-2014 The MacPorts Project
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
 * 3. Neither the name of MacPorts Team nor the names of its contributors
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

#include <ctype.h>
#include <errno.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <utime.h>

#include <curl/curl.h>

#include <tcl.h>

#include "curl.h"

/*
 * Some compiled-in constants that we may wish to change later, given more
 * empirical data. These represent "best guess" values for now.
 */
#define _CURL_CONNECTION_TIMEOUT	((long)(30))		/* 30 seconds */
#define _CURL_MINIMUM_XFER_SPEED	((long)1024)		/* 1KB/sec */
#define _CURL_MINIMUM_XFER_TIMEOUT	((long)(60))		/* 1 minute */
#define _CURL_MINIMUM_PROGRESS_INTERVAL ((double)(0.2)) /* 0.2 seconds */

#if defined CURLOPT_ACCEPT_ENCODING
#define _CURL_ENCODING CURLOPT_ACCEPT_ENCODING
#else
#define _CURL_ENCODING CURLOPT_ENCODING
#endif

/* ========================================================================= **
 * Definitions
 * ========================================================================= */

/* ------------------------------------------------------------------------- **
 * Global curl handles
 * ------------------------------------------------------------------------- */
/* If we want to use TclX' signal handling mechanism we need curl to return
 * control to our code from time to time so we can call Tcl_AsyncInvoke to
 * process pending signals. To do that, we could either abuse the curl progress
 * callback (which would mean we could no longer use the default curl progress
 * callback, or we need to use the curl multi API. */
static CURLM* theMHandle = NULL;
/* We use a single global handle rather than creating and destroying handles to
 * take advantage of HTTP pipelining, especially to the packages servers. */
static CURL* theHandle = NULL;

/* ------------------------------------------------------------------------- **
 * Prototypes
 * ------------------------------------------------------------------------- */
int SetResultFromCurlErrorCode(Tcl_Interp* interp, CURLcode inErrorCode);
int SetResultFromCurlMErrorCode(Tcl_Interp* interp, CURLMcode inErrorCode);
int CurlFetchCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int CurlIsNewerCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int CurlGetSizeCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int CurlPostCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);

typedef struct {
	Tcl_Interp *interp;
	const char *proc;
	double prevcalltime;
} tcl_callback_t;

static int CurlProgressHandler(tcl_callback_t *callback, double dltotal, double dlnow, double ultotal, double ulnow);
static void CurlProgressCleanup(tcl_callback_t *callback);

void CurlInit(void);

/* ========================================================================= **
 * Entry points
 * ========================================================================= */

/**
 * Set the result if a libcurl error occurred return TCL_ERROR.
 * Otherwise, set the result to "" and return TCL_OK.
 *
 * @param interp		pointer to the interpreter.
 * @param inErrorCode	code of the error.
 * @return TCL_OK if inErrorCode is 0, TCL_ERROR otherwise.
 */
int
SetResultFromCurlErrorCode(Tcl_Interp *interp, CURLcode inErrorCode)
{
	int result = TCL_ERROR;

	if (inErrorCode == CURLE_OK) {
		Tcl_SetResult(interp, "", TCL_STATIC);
		result = TCL_OK;
	} else {
		Tcl_SetResult(interp, (char *)curl_easy_strerror(inErrorCode), TCL_VOLATILE);
	}

	return result;
}

/**
 * Set the result if a libcurl multi error occurred return TCL_ERROR.
 * Otherwise, set the result to "" and return TCL_OK.
 *
 * @param interp		pointer to the interpreter.
 * @param inErrorCode	code of the multi error.
 * @return TCL_OK if inErrorCode is 0, TCL_ERROR otherwise.
 */
int
SetResultFromCurlMErrorCode(Tcl_Interp *interp, CURLMcode inErrorCode)
{
	int result = TCL_ERROR;

	if (inErrorCode == CURLM_OK) {
		Tcl_SetResult(interp, "", TCL_STATIC);
		result = TCL_OK;
	} else {
		Tcl_SetResult(interp, (char *)curl_multi_strerror(inErrorCode), TCL_VOLATILE);
	}

	return result;
}

/**
 * curl fetch subcommand entry point.
 *
 * syntax: curl fetch [--disable-epsv] [--ignore-ssl-cert] [--remote-time] [-u userpass] [--effective-url lasturlvar] [--progress "builtin"|callback] [--enable-compression] url filename
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CurlFetchCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;
	bool handleAdded = false;
	FILE* theFile = NULL;
	char theErrorString[CURL_ERROR_SIZE];

	/* Always 0-initialize the error string, since older curl versions may not
	 * initialize the error string buffer at all. See
	 * https://trac.macports.org/ticket/60581. */
	theErrorString[0] = '\0';

	do {
		int noprogress = 1;
		int useepsv = 1;
		int ignoresslcert = 0;
		int remotetime = 0;
		const char* theUserPassString = NULL;
		const char* effectiveURLVarName = NULL;
		tcl_callback_t progressCallback = {
			.interp = interp,
			.proc = NULL,
			.prevcalltime = 0.0
		};
		char* effectiveURL = NULL;
		char* userAgent = PACKAGE_NAME "/" PACKAGE_VERSION " libcurl/" LIBCURL_VERSION;
		const int MAXHTTPHEADERS = 100;
		int numHTTPHeaders = 0;
		const char* httpHeaders[MAXHTTPHEADERS];
		int optioncrsr;
		int lastoption;
		const char* theURL;
		const char* theFilePath;
		long theFileTime = 0;
		CURLcode theCurlCode;
		CURLMcode theCurlMCode;
		struct curl_slist *headers = NULL;
		struct CURLMsg *info = NULL;
		int running; /* number of running transfers */
		char* acceptEncoding = NULL;

		/* we might have options and then the url and the file */
		/* let's process the options first */

		optioncrsr = 2;
		lastoption = objc - 3;
		while (optioncrsr <= lastoption) {
			/* get the option */
			const char* theOption = Tcl_GetString(objv[optioncrsr]);

			if (strcmp(theOption, "--disable-epsv") == 0) {
				useepsv = 0;
			} else if (strcmp(theOption, "--ignore-ssl-cert") == 0) {
				ignoresslcert = 1;
			} else if (strcmp(theOption, "--remote-time") == 0) {
				remotetime = 1;
			} else if (strcmp(theOption, "-u") == 0) {
				/* check we also have the parameter */
				if (optioncrsr < lastoption) {
					optioncrsr++;
					theUserPassString = Tcl_GetString(objv[optioncrsr]);
				} else {
					Tcl_SetResult(interp,
						"curl fetch: -u option requires a parameter",
						TCL_STATIC);
					theResult = TCL_ERROR;
					break;
				}
			} else if (strcmp(theOption, "--effective-url") == 0) {
				/* check we also have the parameter */
				if (optioncrsr < lastoption) {
					optioncrsr++;
					effectiveURLVarName = Tcl_GetString(objv[optioncrsr]);
				} else {
					Tcl_SetResult(interp,
						"curl fetch: --effective-url option requires a parameter",
						TCL_STATIC);
					theResult = TCL_ERROR;
					break;
				}
			} else if (strcmp(theOption, "--user-agent") == 0) {
				/* check we also have the parameter */
				if (optioncrsr < lastoption) {
					optioncrsr++;
					userAgent = Tcl_GetString(objv[optioncrsr]);
				} else {
					Tcl_SetResult(interp,
						"curl fetch: --user-agent option requires a parameter",
						TCL_STATIC);
					theResult = TCL_ERROR;
					break;
				}
			} else if (strcmp(theOption, "--append-http-header") == 0) {
				/* check we also have the parameter */
				if (optioncrsr < lastoption) {
					optioncrsr++;
					if (numHTTPHeaders < MAXHTTPHEADERS) {
						httpHeaders[numHTTPHeaders++] = Tcl_GetString(objv[optioncrsr]);
					} else {
						Tcl_SetResult(interp,
							"curl fetch: Too many --append-http-header options",
							TCL_STATIC);
						theResult = TCL_ERROR;
						break;
					}
				} else {
					Tcl_SetResult(interp,
						"curl fetch: --append-http-header option requires a parameter",
						TCL_STATIC);
					theResult = TCL_ERROR;
					break;
				}
			} else if (strcmp(theOption, "--progress") == 0) {
				/* check we also have the parameter */
				if (optioncrsr < lastoption) {
					optioncrsr++;
					noprogress = 0;
					progressCallback.proc = Tcl_GetString(objv[optioncrsr]);
				} else {
					Tcl_SetResult(interp,
						"curl fetch: --progress option requires a parameter",
						TCL_STATIC);
					theResult = TCL_ERROR;
					break;
				}
			} else if (strcmp(theOption, "--enable-compression") == 0) {
				acceptEncoding = "";
			} else {
				Tcl_ResetResult(interp);
				Tcl_AppendResult(interp, "curl fetch: unknown option ", theOption, NULL);
				theResult = TCL_ERROR;
				break;
			}

			optioncrsr++;
		}

		if (optioncrsr <= lastoption) {
			/* something went wrong */
			break;
		}

		/*	first (second) parameter is -v or the url,
			second (third) parameter is the file */

		if (objc >= 4) {
			/* Retrieve the url */
			theURL = Tcl_GetString(objv[objc - 2]);

			/* Retrieve the file path */
			theFilePath = Tcl_GetString(objv[objc - 1]);
		} else {
			Tcl_WrongNumArgs(interp, 1, objv, "fetch [options] url file");
			theResult = TCL_ERROR;
			break;
		}

		/* Open the file */
		theFile = fopen(theFilePath, "w");
		if (theFile == NULL) {
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
			break;
		}

		/* Create the CURL handles */
		if (theMHandle == NULL) {
			/* Re-use existing multi handle if theMHandle isn't NULL */
			theMHandle = curl_multi_init();
			if (theMHandle == NULL) {
				theResult = TCL_ERROR;
				Tcl_SetResult(interp, "error in curl_multi_init", TCL_STATIC);
				break;
			}
		}

		if (theHandle == NULL) {
			/* Re-use existing handle if theHandle isn't NULL */
			theHandle = curl_easy_init();
			if (theHandle == NULL) {
				theResult = TCL_ERROR;
				Tcl_SetResult(interp, "error in curl_easy_init", TCL_STATIC);
				break;
			}
		}
		/* If we're re-using a handle, the previous call did ensure to reset it
		 * to the default state using curl_easy_reset(3) */

		/* Setup the handle */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_URL, theURL);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

#if LIBCURL_VERSION_NUM >= 0x071304 && LIBCURL_VERSION_NUM <= 0x071307
		/* FTP_PROXY workaround for Snow Leopard */
		if (strncmp(theURL, "ftp:", 4) == 0) {
			char *ftp_proxy = getenv("FTP_PROXY");
			if (ftp_proxy) {
				theCurlCode = curl_easy_setopt(theHandle, CURLOPT_PROXY, ftp_proxy);
				if (theCurlCode != CURLE_OK) {
					theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
					break;
				}
			}
		}
#endif

		/* -L option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FOLLOWLOCATION, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* --max-redirs option, same default as curl command line */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_MAXREDIRS, 50);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* echo any cookies received on a redirect */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_COOKIEJAR, "/dev/null");
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -f option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FAILONERROR, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -A option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_USERAGENT, userAgent);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout on connections */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_CONNECTTIMEOUT, _CURL_CONNECTION_TIMEOUT);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set minimum connection speed */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_LOW_SPEED_LIMIT, _CURL_MINIMUM_XFER_SPEED);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout interval for connections < min xfer speed */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_LOW_SPEED_TIME, _CURL_MINIMUM_XFER_TIMEOUT);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* skip the header data */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_HEADER, 0);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* write to the file */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_WRITEDATA, theFile);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we want/don't want progress */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_NOPROGRESS, noprogress);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we want/don't want a custom progress function */
		if (noprogress == 0 && strcmp(progressCallback.proc, "builtin") != 0) {
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_PROGRESSDATA, &progressCallback);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}

			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_PROGRESSFUNCTION, CurlProgressHandler);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
		}

		/* we want/don't want to use epsv */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FTP_USE_EPSV, useepsv);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we may want to ignore ssl errors */
		if (ignoresslcert) {
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_SSL_VERIFYPEER, (long) 0);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_SSL_VERIFYHOST, (long) 0);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
		}

		/* we want/don't want remote time */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FILETIME, remotetime);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set the l/p, if any */
		if (theUserPassString) {
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_USERPWD, theUserPassString);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
		}

		/* a CURLOPT_ACCEPT_ENCODING of "" means to let cURL write the
		 * Accept-Encoding header for you, based on what the library
		 * was compiled to support.
		 * A value of NULL disables all attemps at decompressing responses.
		*/
#ifdef _CURL_ENCODING
		theCurlCode = curl_easy_setopt(theHandle, _CURL_ENCODING, acceptEncoding);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}
#endif

		/* Clear the Pragma: no-cache header */
		headers = curl_slist_append(headers, "Pragma:");
		/* Append any optional headers */
		for (int iH = 0; iH < numHTTPHeaders; ++iH) {
			headers = curl_slist_append(headers, httpHeaders[iH]);
		}
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_HTTPHEADER, headers);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_ERRORBUFFER, theErrorString);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* add the easy handle to the multi handle */
		theCurlMCode = curl_multi_add_handle(theMHandle, theHandle);
		if (theCurlMCode != CURLM_OK) {
			theResult = SetResultFromCurlMErrorCode(interp, theCurlMCode);
			break;
		}
		handleAdded = true;

		/* select(2) the file descriptors used by curl and interleave with
		 * checks for TclX signals */
		do {
			int rc; /* select() return code */

			/* arguments for select(2) */
			int nfds;
			fd_set readfds;
			fd_set writefds;
			fd_set errorfds;
			struct timeval timeout;

			long curl_timeout = -1;

			/* curl_multi_timeout introduced in libcurl 7.15.4 */
#if LIBCURL_VERSION_NUM >= 0x070f04
			/* get the next timeout */
			theCurlMCode = curl_multi_timeout(theMHandle, &curl_timeout);
			if (theCurlMCode != CURLM_OK) {
				theResult = SetResultFromCurlMErrorCode(interp, theCurlMCode);
				break;
			}
#endif

			timeout.tv_sec = 1;
			timeout.tv_usec = 0;
			/* convert the timeout into a suitable format for select(2) and
			 * limit the timeout to 1 second at most */
			if (curl_timeout >= 0 && curl_timeout < 1000) {
				timeout.tv_sec = 0;
				/* convert ms to us */
				timeout.tv_usec = curl_timeout * 1000;
			}

			/* get the fd sets for select(2) */
			FD_ZERO(&readfds);
			FD_ZERO(&writefds);
			FD_ZERO(&errorfds);
			theCurlMCode = curl_multi_fdset(theMHandle, &readfds, &writefds, &errorfds, &nfds);
			if (theCurlMCode != CURLM_OK) {
				theResult = SetResultFromCurlMErrorCode(interp, theCurlMCode);
				break;
			}

			/* The value of nfds is guaranteed to be >= -1. Passing nfds + 1 to
			 * select(2) makes the case of nfds == -1 a sleep. */
			rc = select(nfds + 1, &readfds, &writefds, &errorfds, &timeout);
			if (-1 == rc) {
				/* check for signals first to avoid breaking our special
				 * handling of SIGINT and SIGTERM */
				if (Tcl_AsyncReady()) {
					theResult = Tcl_AsyncInvoke(interp, theResult);
					if (theResult != TCL_OK) {
						break;
					}
				}

				/* select error */
				Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
				theResult = TCL_ERROR;
				break;
			}

			/* timeout or activity */
			theCurlMCode = curl_multi_perform(theMHandle, &running);

			/* process signals from TclX */
			if (Tcl_AsyncReady()) {
				theResult = Tcl_AsyncInvoke(interp, theResult);
				if (theResult != TCL_OK) {
					break;
				}
			}
		} while (running > 0);

		/* Find out whether the transfer succeeded or failed. */
		info = curl_multi_info_read(theMHandle, &running);
		if (running > 0) {
			fprintf(stderr, "Warning: curl_multi_info_read has %d more structs available\n", running);
		}

		/* free header memory */
		curl_slist_free_all(headers);

		/* signal cleanup to the progress callback */
		if (noprogress == 0 && strcmp(progressCallback.proc, "builtin") != 0) {
			CurlProgressCleanup(&progressCallback);
		}

		/* check for errors in the loop */
		if (theResult != TCL_OK || theCurlMCode != CURLM_OK) {
			break;
		}

		/* we should always get CURLMSG_DONE unless we aborted due to a Tcl
		 * signal */
		if (info == NULL) {
			Tcl_SetResult(interp, "curl_multi_info_read() returned NULL", TCL_STATIC);
			theResult = TCL_ERROR;
			break;
		}

		if (info->msg != CURLMSG_DONE) {
			snprintf(theErrorString, sizeof(theErrorString), "curl_multi_info_read() returned unexpected {.msg = %d, .data.result = %d}", info->msg, info->data.result);
			Tcl_SetResult(interp, theErrorString, TCL_VOLATILE);
			theResult = TCL_ERROR;
			break;
		}
		
		if (info->data.result != CURLE_OK) {
			/* execution failed, use the error string if it is set */
			if (theErrorString[0] != '\0') {
				Tcl_SetResult(interp, theErrorString, TCL_VOLATILE);
			} else {
				/* When the error buffer does not hold useful information,
				 * generate our own message. Use a larger buffer since we add
				 * a significant amount of text. */
				char errbuf[256 + CURL_ERROR_SIZE];
				snprintf(errbuf, sizeof(errbuf),
					"curl_multi_info_read() returned {.msg = CURLMSG_DONE, "
					".data.result = %d (!= CURLE_OK)}, but the error buffer "
					"is not set. curl_easy_strerror(.data.result): %s",
					info->data.result, curl_easy_strerror(info->data.result));
				Tcl_SetResult(interp, errbuf, TCL_VOLATILE);
			}
			theResult = TCL_ERROR;
			break;
		}

		/* close the file */
		(void) fclose(theFile);
		theFile = NULL;

#if LIBCURL_VERSION_NUM == 0x070d01 /* work around broken Tiger version of curl */
		if (remotetime) {
			FILE *fp;
			char *tmp, *p;
			char buf[BUFSIZ];
			size_t size;

			tmp = tmpnam(NULL);
			fp = fopen(tmp, "w");
			if (fp == NULL) {
				Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
				theResult = TCL_ERROR;
				break;
			}
			theFile = fopen(theFilePath, "r");
			if (theFile == NULL) {
				Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
				theResult = TCL_ERROR;
				break;
			}
			if ((p = fgets(buf, BUFSIZ, theFile)) != NULL) {
				/* skip stray header escaping into output */
				if (strncmp(p, "Last-Modified:", 14) != 0)
					rewind(theFile);
			}
			while ((size = fread(buf, 1, BUFSIZ, theFile)) > 0) {
				fwrite(buf, 1, size, fp);
			}
			(void) fclose(theFile);
			theFile = NULL;
			fclose(fp);
			if (rename(tmp, theFilePath) != 0) {
				Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
				theResult = TCL_ERROR;
				break;
			}
		}
#endif

		if (remotetime) {
			theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_FILETIME, &theFileTime);
			if (theCurlCode == CURLE_OK && theFileTime > 0) {
				struct utimbuf times;
				times.actime = (time_t)theFileTime;
				times.modtime = (time_t)theFileTime;
				utime(theFilePath, &times); /* set the time we got */
			}
		}

		/* If --effective-url option was given, set given variable name to last effective url used by curl */
		if (effectiveURLVarName != NULL) {
			theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_EFFECTIVE_URL, &effectiveURL);
			Tcl_SetVar(interp, effectiveURLVarName,
				(effectiveURL == NULL || theCurlCode != CURLE_OK) ? "" : effectiveURL, 0);
		}
	} while (0);

	if (handleAdded) {
		/* Remove the handle from the multi handle, but ignore errors to avoid
		 * cluttering the real error info that might be somewhere further up */
		curl_multi_remove_handle(theMHandle, theHandle);
		handleAdded = false;
	}

	/* reset the connection */
	if (theHandle != NULL) {
		curl_easy_reset(theHandle);
	}
	if (theFile != NULL) {
		fclose(theFile);
	}

	return theResult;
}

/**
 * curl isnewer subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CurlIsNewerCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;
	FILE* theFile = NULL;

	do {
		int optioncrsr;
		int lastoption;
		int ignoresslcert = 0;
		long theResponseCode = 0;
		const char* theURL;
		CURLcode theCurlCode;
		long theModDate;
		long userModDate;

		optioncrsr = 2;
		lastoption = objc - 3;
		while (optioncrsr <= lastoption) {
			/* get the option */
			const char* theOption = Tcl_GetString(objv[optioncrsr]);

			if (strcmp(theOption, "--ignore-ssl-cert") == 0) {
				ignoresslcert = 1;
			} else {
				Tcl_ResetResult(interp);
				Tcl_AppendResult(interp, "curl isnewer: unknown option ", theOption, NULL);
				theResult = TCL_ERROR;
				break;
			}

			optioncrsr++;
		}

		if (optioncrsr <= lastoption) {
			/* something went wrong */
			break;
		}

		/* first (second) parameter is the url, second (third) parameter is the date */
		if (objc < 4 || objc > 5) {
			Tcl_WrongNumArgs(interp, 1, objv, "isnewer [--ignore-ssl-cert] url date");
			theResult = TCL_ERROR;
			break;
		}

		/* Retrieve the url */
		theURL = Tcl_GetString(objv[objc - 2]);

		/* Get the date */
		theResult = Tcl_GetLongFromObj(interp, objv[objc - 1], &userModDate);
		if (theResult != TCL_OK) {
			break;
		}

		/* Open the file (dev/null) */
		theFile = fopen("/dev/null", "a");
		if (theFile == NULL) {
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
			break;
		}

		/* Create the CURL handle */
		if (theHandle == NULL) {
			/* Re-use existing handle if theHandle isn't NULL */
			theHandle = curl_easy_init();
		}
		/* If we're re-using a handle, the previous call did ensure to reset it
		 * to the default state using curl_easy_reset(3) */

		/* Setup the handle */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_URL, theURL);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -L option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FOLLOWLOCATION, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* --max-redirs option, same default as curl command line */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_MAXREDIRS, 50);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* echo any cookies received on a redirect */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_COOKIEJAR, "/dev/null");
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -f option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FAILONERROR, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout on connections */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_CONNECTTIMEOUT, _CURL_CONNECTION_TIMEOUT);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set minimum connection speed */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_LOW_SPEED_LIMIT, _CURL_MINIMUM_XFER_SPEED);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout interval for connections < min xfer speed */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_LOW_SPEED_TIME, _CURL_MINIMUM_XFER_TIMEOUT);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* write to the file */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_WRITEDATA, theFile);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we may want to ignore ssl errors */
		if (ignoresslcert) {
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_SSL_VERIFYPEER, (long) 0);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_SSL_VERIFYHOST, (long) 0);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
		}

		/* save the modification date */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FILETIME, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* skip the download if the file wasn't modified */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_TIMECONDITION, CURL_TIMECOND_IFMODSINCE);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_TIMEVALUE, userModDate);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we do not want any progress */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_NOPROGRESS, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* actually fetch the resource */
		theCurlCode = curl_easy_perform(theHandle);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* close the file */
		(void) fclose(theFile);
		theFile = NULL;

		/* check everything went fine */
		theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_HTTP_CODE, &theResponseCode);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		theModDate = -1;

		if (theResponseCode != 304) {
			/* get the modification date */
			theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_FILETIME, &theModDate);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}

			/* compare this with the date provided by user */
			if (theModDate < -1) {
				Tcl_SetResult(interp, "Couldn't get resource modification date", TCL_STATIC);
				theResult = TCL_ERROR;
				break;
			}
		}

		if (theModDate > userModDate) {
			Tcl_SetResult(interp, "1", TCL_STATIC);
		} else {
			Tcl_SetResult(interp, "0", TCL_STATIC);
		}
	} while (0);

	/* reset the connection */
	if (theHandle != NULL) {
		curl_easy_reset(theHandle);
	}

	if (theFile != NULL) {
		fclose(theFile);
	}

	return theResult;
}

/**
 * curl getsize subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CurlGetSizeCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;
	FILE* theFile = NULL;

	do {
		int optioncrsr;
		int lastoption;
		int ignoresslcert = 0;
		char theSizeString[32];
		const char* theURL;
		CURLcode theCurlCode;
		double theFileSize;

		optioncrsr = 2;
		lastoption = objc - 2;
		while (optioncrsr <= lastoption) {
			/* get the option */
			const char* theOption = Tcl_GetString(objv[optioncrsr]);

			if (strcmp(theOption, "--ignore-ssl-cert") == 0) {
				ignoresslcert = 1;
			} else {
				Tcl_ResetResult(interp);
				Tcl_AppendResult(interp, "curl getsize: unknown option ", theOption, NULL);
				theResult = TCL_ERROR;
				break;
			}

			optioncrsr++;
		}

		if (optioncrsr <= lastoption) {
			/* something went wrong */
			break;
		}

		/* first (second) parameter is the url */
		if (objc < 3 || objc > 4) {
			Tcl_WrongNumArgs(interp, 1, objv, "getsize [--ignore-ssl-cert] url");
			theResult = TCL_ERROR;
			break;
		}

		/* Retrieve the url */
		theURL = Tcl_GetString(objv[objc - 1]);

		/* Open the file (dev/null) */
		theFile = fopen("/dev/null", "a");
		if (theFile == NULL) {
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
			break;
		}

		/* Create the CURL handle */
		if (theHandle == NULL) {
			/* Re-use existing handle if theHandle isn't NULL */
			theHandle = curl_easy_init();
		}
		/* If we're re-using a handle, the previous call did ensure to reset it
		 * to the default state using curl_easy_reset(3) */

		/* Setup the handle */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_URL, theURL);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -L option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FOLLOWLOCATION, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* --max-redirs option, same default as curl command line */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_MAXREDIRS, 50);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* echo any cookies received on a redirect */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_COOKIEJAR, "/dev/null");
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -f option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FAILONERROR, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout on connections */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_CONNECTTIMEOUT, _CURL_CONNECTION_TIMEOUT);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set minimum connection speed */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_LOW_SPEED_LIMIT, _CURL_MINIMUM_XFER_SPEED);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout interval for connections < min xfer speed */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_LOW_SPEED_TIME, _CURL_MINIMUM_XFER_TIMEOUT);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* write to the file */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_WRITEDATA, theFile);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we may want to ignore ssl errors */
		if (ignoresslcert) {
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_SSL_VERIFYPEER, (long) 0);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_SSL_VERIFYHOST, (long) 0);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
		}

		/* skip the header data */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_HEADER, 0);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* skip the body data */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_NOBODY, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we do not want any progress */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_NOPROGRESS, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* actually fetch the resource */
		theCurlCode = curl_easy_perform(theHandle);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* close the file */
		(void) fclose(theFile);
		theFile = NULL;

		theFileSize = 0.0;

		/* get the file size */
		theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &theFileSize);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		(void) snprintf(theSizeString, sizeof(theSizeString),
			"%.0f", theFileSize);
		Tcl_SetResult(interp, theSizeString, TCL_VOLATILE);
	} while (0);

	/* reset the connection */
	if (theHandle != NULL) {
		curl_easy_reset(theHandle);
	}

	if (theFile != NULL) {
		fclose(theFile);
	}

	return theResult;
}

/**
 * curl post postdata url
 *
 * syntax: curl post [--user-agent useragentstring] [--progress "builtin"|callback] postdata url
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CurlPostCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;
	FILE* theFile = NULL;

	do {
		const char* theURL;
		const char* thePostData;
		CURLcode theCurlCode;
		int noprogress = 1;
		tcl_callback_t progressCallback = {
			.interp = interp,
			.proc = NULL,
			.prevcalltime = 0.0
		};
		char* userAgent = PACKAGE_NAME "/" PACKAGE_VERSION " libcurl/" LIBCURL_VERSION;
		int optioncrsr;
		int lastoption;

		/* we might have options and then postdata and the url */
		/* let's process the options first */

		optioncrsr = 2;
		lastoption = objc - 3;
		while (optioncrsr <= lastoption) {
			/* get the option */
			const char* theOption = Tcl_GetString(objv[optioncrsr]);

			if (strcmp(theOption, "--user-agent") == 0) {
				/* check we also have the parameter */
				if (optioncrsr < lastoption) {
					optioncrsr++;
					userAgent = Tcl_GetString(objv[optioncrsr]);
				} else {
					Tcl_SetResult(interp,
						"curl post: --user-agent option requires a parameter",
						TCL_STATIC);
					theResult = TCL_ERROR;
					break;
				}
			} else if (strcmp(theOption, "--progress") == 0) {
				/* check we also have the parameter */
				if (optioncrsr < lastoption) {
					optioncrsr++;
					noprogress = 0;
					progressCallback.proc = Tcl_GetString(objv[optioncrsr]);
				} else {
					Tcl_SetResult(interp,
						"curl post: --progress option requires a parameter",
						TCL_STATIC);
					theResult = TCL_ERROR;
					break;
				}
			} else {
				Tcl_ResetResult(interp);
				Tcl_AppendResult(interp, "curl post: unknown option ", theOption, NULL);
				theResult = TCL_ERROR;
				break;
			}

			optioncrsr++;
		}

		if (optioncrsr <= lastoption) {
			/* something went wrong */
			break;
		}

		/*	first (second) parameter is -v or the url,
			second (third) parameter is the file */

		if (objc >= 4) {
			/* Retrieve the url - it is the last parameter */
			theURL = Tcl_GetString(objv[objc - 1]);

			/* Retrieve the post data - it's before the url */
			thePostData = Tcl_GetString(objv[objc - 2]);
		} else {
			Tcl_WrongNumArgs(interp, 1, objv, "post [options] postdata file");
			theResult = TCL_ERROR;
			break;
		}

		/* Open the file (dev/null) */
		theFile = fopen("/dev/null", "a");
		if (theFile == NULL) {
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
			break;
		}

		/* Create the CURL handle */
		if (theHandle == NULL) {
			/* Re-use existing handle if theHandle isn't NULL */
			theHandle = curl_easy_init();
		}
		/* If we're re-using a handle, the previous call did ensure to reset it
		 * to the default state using curl_easy_reset(3) */

		/* Setup the handle */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_URL, theURL);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* Specify the POST data */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_POSTFIELDS, thePostData);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -L option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FOLLOWLOCATION, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* --max-redirs option, same default as curl command line */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_MAXREDIRS, 50);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* echo any cookies received on a redirect */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_COOKIEJAR, "/dev/null");
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -f option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FAILONERROR, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* -A option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_USERAGENT, userAgent);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout on connections */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_CONNECTTIMEOUT, _CURL_CONNECTION_TIMEOUT);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set minimum connection speed */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_LOW_SPEED_LIMIT, _CURL_MINIMUM_XFER_SPEED);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout interval for connections < min xfer speed */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_LOW_SPEED_TIME, _CURL_MINIMUM_XFER_TIMEOUT);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* write to the file */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_WRITEDATA, theFile);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* skip the header data */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_HEADER, 0);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we want/don't want progress */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_NOPROGRESS, noprogress);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* we want/don't want a custom progress function */
		if (noprogress == 0 && strcmp(progressCallback.proc, "builtin") != 0) {
			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_PROGRESSDATA, &progressCallback);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}

			theCurlCode = curl_easy_setopt(theHandle, CURLOPT_PROGRESSFUNCTION, CurlProgressHandler);
			if (theCurlCode != CURLE_OK) {
				theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
				break;
			}
		}

		/* actually perform the POST */
		theCurlCode = curl_easy_perform(theHandle);

		/* signal cleanup to the progress callback */
		if (noprogress == 0 && strcmp(progressCallback.proc, "builtin") != 0) {
			CurlProgressCleanup(&progressCallback);
		}

		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* close the file */
		(void) fclose(theFile);
		theFile = NULL;
	} while (0);

	/* reset the connection */
	if (theHandle != NULL) {
		curl_easy_reset(theHandle);
	}

	if (theFile != NULL) {
		fclose(theFile);
	}

	return theResult;
}

/**
 * curl command entry point.
 *
 * @param clientData	custom data (ignored)
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CurlCmd(
		ClientData clientData UNUSED,
		Tcl_Interp* interp,
		int objc,
		Tcl_Obj* CONST objv[])
{
	typedef enum {
		kCurlFetch,
		kCurlIsNewer,
		kCurlGetSize,
		kCurlPost
	} EOption;

	static const char *options[] = {
		"fetch", "isnewer", "getsize", "post", NULL
	};
	int theResult = TCL_OK;
	EOption theOptionIndex;
	static pthread_once_t once = PTHREAD_ONCE_INIT;

	/* TODO: use dispatch_once when we drop Leopard support */
	pthread_once(&once, CurlInit);

	if (objc < 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "option ?arg ...?");
		return TCL_ERROR;
	}

	theResult = Tcl_GetIndexFromObj(
				interp,
				objv[1],
				options,
				"option",
				0,
				(int*) &theOptionIndex);
	if (theResult == TCL_OK) {
		switch (theOptionIndex) {
		case kCurlFetch:
			theResult = CurlFetchCmd(interp, objc, objv);
			break;
		case kCurlIsNewer:
			theResult = CurlIsNewerCmd(interp, objc, objv);
			break;
		case kCurlGetSize:
			theResult = CurlGetSizeCmd(interp, objc, objv);
			break;
		case kCurlPost:
			theResult = CurlPostCmd(interp, objc, objv);
			break;
		}
	}

	return theResult;
}

/**
 * curl init entry point.
 * libcurl will never be cleaned (where should I plug the hook?)
 */
void
CurlInit()
{
	curl_global_init(CURL_GLOBAL_ALL);
}

/* ========================================================================= **
 * Callback function
 * ========================================================================= */
static int CurlProgressHandler(
		tcl_callback_t *callback,
		double dltotal,
		double dlnow,
		double ultotal,
		double ulnow)
{
	if (dltotal == 0.0 && ultotal == 0.0 && dlnow == 0.0 && ulnow == 0.0) {
		/*
		 * We have no idea whether this is an up- or download. Do nothing for now.
		 */
		return 0;
	}

	enum {
		UPLOAD,
		DOWNLOAD
	} transferType;

	double total, now, speed, curtime;

	if (dltotal != 0.0 || dlnow != 0.0) {
		/* This is a download */
		transferType = DOWNLOAD;
		total = dltotal;
		now = dlnow;
	} else {
		/* This is an upload */
		transferType = UPLOAD;
		total = ultotal;
		now = ulnow;
	}

	/* Only send updates once a second */
	curl_easy_getinfo(theHandle, CURLINFO_TOTAL_TIME, &curtime);
	if ((curtime - callback->prevcalltime) < _CURL_MINIMUM_PROGRESS_INTERVAL) {
		return 0;
	}

	if (callback->prevcalltime == 0.0) {
		/* this is the first time we're calling the callback, call start
		 * subcommand first */

		/*
		 * Command string, a space followed "start", another space and "dl" or
		 * "ul" plus the trailing \0.
		 */
		char startCommandBuffer[strlen(callback->proc) + (1 + 5) + (1 + 2) + 1];
		int startLen = 0;

		startLen = snprintf(startCommandBuffer, sizeof(startCommandBuffer), "%s start %s",
				callback->proc, (transferType == DOWNLOAD) ? "dl" : "ul");
		if (startLen < 0 || (size_t) startLen >= sizeof(startCommandBuffer)) {
			/* overflow */
			fprintf(stderr, "pextlib1.0: buffer overflow in " __FILE__ ":%d. Buffer is: %s\n", __LINE__, startCommandBuffer);
			abort();
		}

		if (TCL_ERROR == Tcl_EvalEx(callback->interp, startCommandBuffer, startLen, TCL_EVAL_GLOBAL)) {
			fprintf(stderr, "curl progress callback failed: %s\n", Tcl_GetStringResult(callback->interp));
			return 1;
		}
	}

	callback->prevcalltime = curtime;

	/* Get the average speed from curl */
	if (transferType == DOWNLOAD) {
		curl_easy_getinfo(theHandle, CURLINFO_SPEED_DOWNLOAD, &speed);
	} else {
		curl_easy_getinfo(theHandle, CURLINFO_SPEED_UPLOAD, &speed);
	}

	/*
	 * We need the command string, a space and "update", another space and "dl"
	 * or "ul", three doubles converted to string (see comment below), plus
	 * a space character for separation per argument, so 3 * (1 + LEN_DOUBLE)
	 * plus one character for the null-byte.
	 */
	char commandBuffer[strlen(callback->proc) + (1 + 6) + (1 + 2) + 3 * (1 + 12) + 1];
	int len = 0;

	/*
	 * Format numbers using % .6g format specifier so we can always be sure
	 * what the total length will be: .6g tells us we're using at most
	 * 6 significant digits; that means 6 characters, another one for
	 * a possible decimal point, another 4 for e+XX where 00 <= XX <= 99 for
	 * exponents, and another one for a possible sign (or " " for positive
	 * numbers). In total, the maximum length will be 12 per double formatted.
	 */
	len = snprintf(commandBuffer, sizeof(commandBuffer), "%s update %s % .6g % .6g % .6g",
			callback->proc, (transferType == DOWNLOAD) ? "dl" : "ul", total, now, speed);
	if (len < 0 || (size_t) len >= sizeof(commandBuffer)) {
		/* overflow */
		fprintf(stderr, "pextlib1.0: buffer overflow in " __FILE__ ":%d. Buffer is: %s\n", __LINE__, commandBuffer);
		abort();
	}

	/*
	 * Execute directly rather than compiling to bytecode first - the script is
	 * likely to change in the next call anyway.
	 */
	if (TCL_ERROR == Tcl_EvalEx(callback->interp, commandBuffer, len, TCL_EVAL_GLOBAL)) {
		fprintf(stderr, "curl progress callback failed: %s\n", Tcl_GetStringResult(callback->interp));
		return 1;
	}

	return 0;
}

static void CurlProgressCleanup(
		tcl_callback_t *callback)
{
	/*
	 * Transfer complete, signal the progress callback
	 */
	Tcl_InterpState state;

	/*
	 * Command string, a space followed "finish" plus the trailing \0.
	 */
	char commandBuffer[strlen(callback->proc) + (1 + 6) + 1];
	int len = 0;

	len = snprintf(commandBuffer, sizeof(commandBuffer), "%s finish", callback->proc);
	if (len < 0 || (size_t) len >= sizeof(commandBuffer)) {
		/* overflow */
		fprintf(stderr, "pextlib1.0: buffer overflow in " __FILE__ ":%d. Buffer is: %s\n", __LINE__, commandBuffer);
		abort();
	}

	/* make sure to save and restore the interpreter state so a potential error
	 * message doesn't get lost */
	state = Tcl_SaveInterpState(callback->interp, 0);
	Tcl_EvalEx(callback->interp, commandBuffer, len, TCL_EVAL_GLOBAL);
	Tcl_RestoreInterpState(callback->interp, state);
}
