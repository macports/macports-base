/*
 * curl.c
 * $Id$
 *
 * Copyright (c) 2005 Paul Guyot, The MacPorts Project.
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

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <errno.h>

#if HAVE_STRING_H
#include <string.h>
#endif

#ifdef HAVE_UTIME_H
#include <utime.h>
#endif

#include <curl/curl.h>

#include <tcl.h>
#include <tclDecls.h>

#include "curl.h"

/* Avoid a warning with Tcl < 8.4, even if Tcl_GetIndexFromObj's tablePtr
probably isn't modified. */
#if (TCL_MAJOR_VERSION > 8) || (TCL_MINOR_VERSION >= 4)
typedef CONST char* tableEntryString;
#else
typedef char* tableEntryString;
#endif

/*
 * Some compiled-in constants that we may wish to change later, given more
 * empirical data.  These represent "best guess" values for now.
 */
#define _CURL_CONNECTION_TIMEOUT	((long)(5 * 60))	/* 5 minutes */
#define _CURL_MINIMUM_XFER_SPEED	((long)1024)		/* 1Kb/sec */
#define _CURL_MINIMUM_XFER_TIMEOUT	((long)(10 * 60))	/* 10 minutes */

/* ========================================================================= **
 * Definitions
 * ========================================================================= */
#pragma mark Definitions

/* ------------------------------------------------------------------------- **
 * Prototypes
 * ------------------------------------------------------------------------- */
int SetResultFromCurlErrorCode(Tcl_Interp* interp, CURLcode inErrorCode);
int CurlFetchCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int CurlIsNewerCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);

/* ========================================================================= **
 * Entry points
 * ========================================================================= */
#pragma mark -
#pragma mark Entry points

/**
 * Set the result if a libcurl error occurred return TCL_ERROR.
 * Otherwise, set the result to "" and return TCL_OK.
 *
 * @param interp		pointer to the interpreter.
 * @param inErrorCode	code of the error.
 * @return TCL_OK if inErrorCode is 0, TCL_ERROR otherwise.
 */
int
SetResultFromCurlErrorCode(Tcl_Interp* interp, CURLcode inErrorCode)
{
	int theResult;

	switch(inErrorCode)
	{
		case CURLE_OK:
			Tcl_SetResult(interp, "", TCL_STATIC);
			theResult = TCL_OK;
			break;
		
		default:
#ifdef HAVE_CURL_EASY_STRERROR
			Tcl_SetResult(interp, (char*) curl_easy_strerror(inErrorCode), TCL_VOLATILE);
#else
			{
				char theErrorString[512];
				(void) snprintf(theErrorString, sizeof(theErrorString),
					"curl error %i", inErrorCode);
				Tcl_SetResult(interp, theErrorString, TCL_VOLATILE);				
			}
#endif
			theResult = TCL_ERROR;
	}
	
	return theResult;
}

/**
 * curl fetch subcommand entry point.
 *
 * syntax: curl fetch [-v] [--disable-epsv] [--ignore-ssl-cert] [--remote-time] [-u userpass] [--effective-url lasturlvar] url filename
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CurlFetchCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;
	CURL* theHandle = NULL;
	FILE* theFile = NULL;

	do {
		long theResponseCode = 0;
		int noprogress = 1;
		int useepsv = 1;
		int ignoresslcert = 0;
		int remotetime = 0;
		const char* theUserPassString = NULL;
		const char* effectiveURLVarName = NULL;
		char* effectiveURL = NULL;
		char* userAgent = PACKAGE_STRING " libcurl/" LIBCURL_VERSION;
		int optioncrsr;
		int lastoption;
		const char* theURL;
		const char* theFilePath;
		long theFileTime = 0;
		CURLcode theCurlCode;
		struct curl_slist *headers = NULL;
		
		/* we might have options and then the url and the file */
		/* let's process the options first */
		
		optioncrsr = 2;
		lastoption = objc - 3;
		while (optioncrsr <= lastoption) {
			/* get the option */
			const char* theOption = Tcl_GetString(objv[optioncrsr]);
			
			if (strcmp(theOption, "-v") == 0) {
				noprogress = 0;
			} else if (strcmp(theOption, "--disable-epsv") == 0) {
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
			} else {
				char theErrorString[512];
				(void) snprintf(theErrorString, sizeof(theErrorString),
					"curl fetch: unknown option %s", theOption);
				Tcl_SetResult(interp, theErrorString, TCL_VOLATILE);
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
		theFile = fopen( theFilePath, "w" );
		if (theFile == NULL) {
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
                        break;
		}

		/* Create the CURL handle */
		theHandle = curl_easy_init();
		
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

		/* Clear the Pragma: no-cache header */
		headers = curl_slist_append(headers, "Pragma:");
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_HTTPHEADER, headers);
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
		(void) fclose( theFile );
		theFile = NULL;
		
#if LIBCURL_VERSION_NUM == 0x070d01 /* work around broken Tiger version of cURL */
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
			theFile = fopen( theFilePath, "r");
			if (theFile == NULL) {
				Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
				theResult = TCL_ERROR;
				break;
			}
			if ( (p = fgets(buf, BUFSIZ, theFile)) != NULL) {
				/* skip stray header escaping into output */
				if (strncmp(p, "Last-Modified:", 14) != 0)
					rewind(theFile);
			}
			while ( (size = fread(buf, 1, BUFSIZ, theFile)) > 0) {
				fwrite(buf, 1, size, fp);
			}
			(void) fclose( theFile );
			theFile = NULL;
			fclose(fp);
			if (rename(tmp, theFilePath) != 0) {
				Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
				theResult = TCL_ERROR;
				break;
			}
		}
#endif

#ifdef HAVE_UTIME_H
		if (remotetime) {
			theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_FILETIME, &theFileTime);
			if (theFileTime > 0) {
				struct utimbuf times;
				times.actime = (time_t)theFileTime;
				times.modtime = (time_t)theFileTime;
				utime(theFilePath, &times); /* set the time we got */
			}
		}
#endif /*HAVE_UTIME_H*/
		
		/* free header memory */
		curl_slist_free_all(headers);

		/* If --effective-url option was given, set given variable name to last effective url used by curl */
		if (effectiveURLVarName != NULL) {
			theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_EFFECTIVE_URL, &effectiveURL);
			Tcl_SetVar(interp, effectiveURLVarName,
				(effectiveURL == NULL || theCurlCode != CURLE_OK) ? "" : effectiveURL,
				0);
		}
		
		/* check everything went fine */
		theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_HTTP_CODE, &theResponseCode);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}
		
		/* we need something between 200 (incl.) and 300 (excl.).*/
		/* (actually, we sometimes get 0 from GNU FTP servers) */
		if (((theResponseCode != 0)  && (theResponseCode < 200))
			|| (theResponseCode >= 300)) {
			char theErrorString[512];
			(void) snprintf(theErrorString, sizeof(theErrorString),
				"Download failed (code = %li)", theResponseCode);
			Tcl_SetResult(interp, theErrorString, TCL_VOLATILE);
			theResult = TCL_ERROR;
			break;
		}
		
		/* clean up */
		curl_easy_cleanup( theHandle );
		theHandle = NULL;
    } while (0);
    
    if (theHandle != NULL) {
    	curl_easy_cleanup( theHandle );
    }
    if (theFile != NULL) {
    	fclose( theFile );
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
	CURL* theHandle = NULL;
	FILE* theFile = NULL;

	do {
		long theResponseCode = 0;
		const char* theURL;
		CURLcode theCurlCode;
		long theModDate;
		long userModDate;
				
		/*	first (second) parameter is the url,
			second (third) parameter is the date */
		if (objc != 4) {
			Tcl_WrongNumArgs(interp, 1, objv, "isnewer url date");
			theResult = TCL_ERROR;
			break;
		}

		/* Retrieve the url */
		theURL = Tcl_GetString(objv[2]);

		/* Get the date */
		theResult = Tcl_GetLongFromObj(interp, objv[3], &userModDate);
		if (theResult != TCL_OK) {
			break;
		}
		
		/* Open the file (dev/null) */
		theFile = fopen( "/dev/null", "a" );
		if (theFile == NULL) {
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
                        break;
		}

		/* Create the CURL handle */
		theHandle = curl_easy_init();
		
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

		/* -f option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FAILONERROR, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout on connections */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_TIMEOUT, _CURL_CONNECTION_TIMEOUT);
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
		(void) fclose( theFile );
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
	
			/* clean up */
			curl_easy_cleanup( theHandle );
			theHandle = NULL;
	
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
    
    if (theHandle != NULL) {
    	curl_easy_cleanup( theHandle );
    }
    if (theFile != NULL) {
    	fclose( theFile );
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
	CURL* theHandle = NULL;
	FILE* theFile = NULL;

	do {
		char theSizeString[32];
		const char* theURL;
		CURLcode theCurlCode;
		double theFileSize;
				
		/*	first (second) parameter is the url */
		if (objc != 3) {
			Tcl_WrongNumArgs(interp, 1, objv, "getsize url");
			theResult = TCL_ERROR;
			break;
		}

		/* Retrieve the url */
		theURL = Tcl_GetString(objv[2]);

		/* Open the file (dev/null) */
		theFile = fopen( "/dev/null", "a" );
		if (theFile == NULL) {
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
                        break;
		}

		/* Create the CURL handle */
		theHandle = curl_easy_init();
		
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

		/* -f option */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_FAILONERROR, 1);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}

		/* set timeout on connections */
		theCurlCode = curl_easy_setopt(theHandle, CURLOPT_TIMEOUT, _CURL_CONNECTION_TIMEOUT);
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
		(void) fclose( theFile );
		theFile = NULL;

		theFileSize = 0.0;

		/* get the file size */
		theCurlCode = curl_easy_getinfo(theHandle, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &theFileSize);
		if (theCurlCode != CURLE_OK) {
			theResult = SetResultFromCurlErrorCode(interp, theCurlCode);
			break;
		}
	
		/* clean up */
		curl_easy_cleanup( theHandle );
		theHandle = NULL;

		(void) snprintf(theSizeString, sizeof(theSizeString),
			"%.0f", theFileSize);
		Tcl_SetResult(interp, theSizeString, TCL_VOLATILE);
    } while (0);
    
    if (theHandle != NULL) {
    	curl_easy_cleanup( theHandle );
    }
    if (theFile != NULL) {
    	fclose( theFile );
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
    	kCurlGetSize
    } EOption;
    
	static tableEntryString options[] = {
		"fetch", "isnewer", "getsize", NULL
	};
	int theResult = TCL_OK;
    EOption theOptionIndex;

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
		switch (theOptionIndex)
		{
			case kCurlFetch:
				theResult = CurlFetchCmd(interp, objc, objv);
				break;

			case kCurlIsNewer:
				theResult = CurlIsNewerCmd(interp, objc, objv);
				break;

			case kCurlGetSize:
				theResult = CurlGetSizeCmd(interp, objc, objv);
				break;
		}
	}
	
	return theResult;
}

/**
 * curl init entry point.
 *
 * @param interp		current interpreter
 */
int
CurlInit(Tcl_Interp* interp)
{
	CURLcode theCurlCode = curl_global_init(CURL_GLOBAL_ALL);
	return SetResultFromCurlErrorCode(interp, theCurlCode);
}

/* ============================================================== **
** As of next Thursday, UNIX will be flushed in favor of TOPS-10. **
** Please update your programs.                                   **
** ============================================================== */
