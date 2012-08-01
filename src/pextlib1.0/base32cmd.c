/*
 * base32cmd.c
 * $Id$
 *
 * Copyright (c) 2010 The MacPorts Project
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

#include <ctype.h>
#include <string.h>

#include <tcl.h>

#include "base32cmd.h"

/* This package provides commands for encoding and decoding of hexstrings
   into and out of the standard base32 encoding as specified in RFC 4648.

   Based on public domain base32 code from tcllib, by Andreas Kupries */

#undef BASE32HEX

static __inline__ int hex2dec(int data)
{
  if (data >= '0' && data <= '9')
    return (data - '0');
  else if (data >= 'a' && data <= 'f')
    return (data - 'a' + 10);
  else if (data >= 'A' && data <= 'F')
    return (data - 'A' + 10);
  else
    return 0;
}

int Base32EncodeCmd(ClientData dummy UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
      unsigned char* digest;
      int           ndigest;
      unsigned char* buf;
      int           nbuf;

      unsigned char* start;
      unsigned char* out;
      unsigned char* at;
      int           nout;

	  Tcl_Obj *tcl_result;
      int i;

      /*
       * The array used for encoding
       */                     /* 123456789 123456789 123456789 12 */
#ifdef BASE32HEX
      static const char map[] = "0123456789ABCDEFGHIJKLMNOPQRSTUV";
#else
      static const char map[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
#endif

      static const char odd_message[] = "string has odd number of chars";
      static const char hex_message[] = "invalid hexadecimal character";

#define USAGEE "hexstring"

      if (objc != 2) {
        Tcl_WrongNumArgs (interp, 1, objv, USAGEE);
        return TCL_ERROR;
      }

      digest = Tcl_GetByteArrayFromObj (objv[1], &ndigest);
      if (ndigest & 1) {
		tcl_result = Tcl_NewStringObj(odd_message, sizeof(odd_message) - 1);
		Tcl_SetObjResult(interp, tcl_result);
      	return TCL_ERROR;
      }
      for (i = 0; i < ndigest; i++) {
      	if (!isxdigit(digest[i])) {
		    tcl_result = Tcl_NewStringObj(hex_message, sizeof(hex_message) - 1);
		    Tcl_SetObjResult(interp, tcl_result);
      	    return TCL_ERROR;
      	}
      }
      nbuf = ndigest / 2;
      buf = (unsigned char*) Tcl_Alloc (nbuf*sizeof(char));

      for (i = 0; i < nbuf; i++) {
        buf[i] = (hex2dec(digest[i+i]) << 4) | (hex2dec(digest[i+i+1]));
      }

      start = buf;

      nout = ((nbuf+4)/5)*8;
      out  = (unsigned char*) Tcl_Alloc (nout*sizeof(char));

      for (at = out; nbuf >= 5; nbuf -= 5, buf += 5) {
	*(at++) = map [         (buf[0]>>3)                ];
	*(at++) = map [ 0x1f & ((buf[0]<<2) | (buf[1]>>6)) ];
	*(at++) = map [ 0x1f &  (buf[1]>>1)                ];
	*(at++) = map [ 0x1f & ((buf[1]<<4) | (buf[2]>>4)) ];
	*(at++) = map [ 0x1f & ((buf[2]<<1) | (buf[3]>>7)) ];
	*(at++) = map [ 0x1f &  (buf[3]>>2)                ];
	*(at++) = map [ 0x1f & ((buf[3]<<3) | (buf[4]>>5)) ];
	*(at++) = map [ 0x1f &  (buf[4])                   ];
      }
      if (nbuf > 0) {
	/* Process partials at end. */
	switch (nbuf) {
	case 1:
	  /* |01234567|		 2, padding 6
	   *  xxxxx
	   *       xxx 00
	   */

	  *(at++) = map [        (buf[0]>>3) ];
	  *(at++) = map [ 0x1f & (buf[0]<<2) ];
	  *(at++) = '=';
	  *(at++) = '=';
	  *(at++) = '=';
	  *(at++) = '=';
	  *(at++) = '=';
	  *(at++) = '=';
	  break;
	case 2: /* x3/=4 */
	  /* |01234567|01234567|	 4, padding 4
	   *  xxxxx
	   *       xxx xx
	   *             xxxxx
	   *                  x 0000
	   */

	  *(at++) = map [         (buf[0]>>3)                ];
	  *(at++) = map [ 0x1f & ((buf[0]<<2) | (buf[1]>>6)) ];
	  *(at++) = map [ 0x1f &  (buf[1]>>1)                ];
	  *(at++) = map [ 0x1f &  (buf[1]<<4)                ];
	  *(at++) = '=';
	  *(at++) = '=';
	  *(at++) = '=';
	  *(at++) = '=';
	  break;
	case 3:
	  /* |01234567|01234567|01234567|	 5, padding 3
	   *  xxxxx
	   *       xxx xx
	   *             xxxxx
	   *                  x xxxx
	   *                        xxxx 0
	   */

	  *(at++) = map [         (buf[0]>>3)                ];
	  *(at++) = map [ 0x1f & ((buf[0]<<2) | (buf[1]>>6)) ];
	  *(at++) = map [ 0x1f &  (buf[1]>>1)                ];
	  *(at++) = map [ 0x1f & ((buf[1]<<4) | (buf[2]>>4)) ];
	  *(at++) = map [ 0x1f &  (buf[2]<<1)                ];
	  *(at++) = '=';
	  *(at++) = '=';
	  *(at++) = '=';
	  break;
	case 4:
	  /* |01234567|01234567|01234567|012334567|	 7, padding 1
	   *  xxxxx
	   *       xxx xx
	   *             xxxxx
	   *                  x xxxx
	   *                        xxxx
	   *                             xxxxx
	   *                                  xxxx 0
	   */

	  *(at++) = map [         (buf[0]>>3)                ];
	  *(at++) = map [ 0x1f & ((buf[0]<<2) | (buf[1]>>6)) ];
	  *(at++) = map [ 0x1f &  (buf[1]>>1)                ];
	  *(at++) = map [ 0x1f & ((buf[1]<<4) | (buf[2]>>4)) ];
	  *(at++) = map [ 0x1f & ((buf[2]<<1) | (buf[3]>>7)) ];
	  *(at++) = map [ 0x1f &  (buf[3]>>2)                ];
	  *(at++) = map [ 0x1f &  (buf[3]<<3)                ];
	  *(at++) = '=';
	  break;
	}
      }

      Tcl_SetObjResult (interp, Tcl_NewStringObj ((char *) out, nout));
      Tcl_Free ((char*) out);
      Tcl_Free ((char*) start);
      return TCL_OK;
    }


int Base32DecodeCmd(ClientData dummy UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
      unsigned char* buf;
      int           nbuf;
      unsigned char* digest;
      int           ndigest;

      unsigned char* out;
      unsigned char* at;
      unsigned char  x [8];
      int           nout;

      int i, j, a, pad;

      /*
       * An array for translating single base-32 characters into a value.
       * Disallowed input characters have a value of 64.  Upper and lower
       * case is the same. Only 128 chars, as everything above char(127)
       * is 64.
       */
      static const char map [] = {
#ifdef BASE32HEX
	/* \00 */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* DLE */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* SPC */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* '0' */  0,  1,  2,  3,  4,  5,  6,  7,   8,  9, 64, 64, 64, 64, 64, 64, 
	/* '@' */ 64, 10, 11, 12, 13, 14, 15, 16,  17, 18, 19, 20, 21, 22, 23, 24,
	/* 'P' */ 25, 26, 27, 28, 29, 30, 31, 64,  64, 64, 64, 64, 64, 64, 64, 64,
	/* '`' */ 64, 10, 11, 12, 13, 14, 15, 16,  17, 18, 19, 20, 21, 22, 23, 24,
	/* 'p' */ 25, 26, 27, 28, 29, 30, 31, 64,  64, 64, 64, 64, 64, 64, 64, 64
#else
	/* \00 */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* DLE */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* SPC */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* '0' */ 64, 64, 26, 27, 28, 29, 30, 31,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* '@' */ 64,  0,  1,  2,  3,  4,  5,  6,   7,  8,  9, 10, 11, 12, 13, 14,
	/* 'P' */ 15, 16, 17, 18, 19, 20, 21, 22,  23, 24, 25, 64, 64, 64, 64, 64,
	/* '`' */ 64,  0,  1,  2,  3,  4,  5,  6,   7,  8,  9, 10, 11, 12, 13, 14,
	/* 'p' */ 15, 16, 17, 18, 19, 20, 21, 22,  23, 24, 25, 64, 64, 64, 64, 64
#endif
      };

    static const char hex[]="0123456789abcdef";

#define USAGED "estring"

      if (objc != 2) {
        Tcl_WrongNumArgs (interp, 1, objv, USAGED);
        return TCL_ERROR;
      }

      buf = (unsigned char *) Tcl_GetStringFromObj (objv[1], &nbuf);

      if (nbuf % 8) {
	Tcl_SetObjResult (interp, Tcl_NewStringObj ("Length is not a multiple of 8", -1));
        return TCL_ERROR;
      }

      nout = (nbuf/8)*5 *TCL_UTF_MAX;
      out  = (unsigned char*) Tcl_Alloc (nout*sizeof(char));

#define HIGH(x) (((x) & 0x80) != 0)
#define BADC(x) ((x) == 64)
#define BADCHAR(a,j) (HIGH ((a)) || BADC (x [(j)] = map [(a)]))

      for (pad = 0, i=0, at = out; i < nbuf; i += 8, buf += 8){
	for (j=0; j < 8; j++){
	  a = buf [j];

	  if (a == '=') {
	    x[j] = 0;
	    pad++;
	    continue;
	  } else if (pad) {
	    char     msg [120];
	    sprintf (msg,
		     "Invalid character at index %d: \"=\" (padding found in the middle of the input)",
		     j-1);
	    Tcl_Free ((char*) out);
	    Tcl_SetObjResult (interp, Tcl_NewStringObj (msg, -1));
	    return TCL_ERROR;
	  }

	  if (BADCHAR (a,j)) {
	    char     msg [100];
	    sprintf (msg,"Invalid character at index %d: \"%c\"",j,a);
	    Tcl_Free ((char*) out);
	    Tcl_SetObjResult (interp, Tcl_NewStringObj (msg, -1));
	    return TCL_ERROR;
	  }
	}

	*(at++) = (x[0]<<3) | (x[1]>>2)            ;
	*(at++) = (x[1]<<6) | (x[2]<<1) | (x[3]>>4);
	*(at++) = (x[3]<<4) | (x[4]>>1)            ;
	*(at++) = (x[4]<<7) | (x[5]<<2) | (x[6]>>3);
	*(at++) = (x[6]<<5) | x[7]                 ;
      }

      if (pad) {
	if (pad == 1) {
	  at -= 1;
	} else if (pad == 3) {
	  at -= 2;
	} else if (pad == 4) {
	  at -= 3;
	} else if (pad == 6) {
	  at -= 4;
	} else {
	  char     msg [100];
	  sprintf (msg,"Invalid padding of length %d",pad);
	  Tcl_Free ((char*) out);
	  Tcl_SetObjResult (interp, Tcl_NewStringObj (msg, -1));
	  return TCL_ERROR;
	}
      }

      nout = at-out;
      ndigest = nout * 2;
      digest = (unsigned char*) Tcl_Alloc (ndigest*sizeof(char)+1);

      for (i = 0; i < nout; i++) {
        digest[i+i] = hex[out[i] >> 4];	
        digest[i+i+1] = hex[out[i] & 0x0f];
      }	
      digest[i+i] = '\0';

      Tcl_SetObjResult (interp, Tcl_NewByteArrayObj (digest, ndigest));
      Tcl_Free ((char*) out);
      Tcl_Free ((char*) digest);
      return TCL_OK;
    }

