# base32hexc.tcl --
#
#       Implementation of a base32 (extended hex) de/encoder for Tcl.
#
# Public domain
#
# RCS: @(#) $Id: base32hex_c.tcl,v 1.3 2008/01/28 22:58:18 andreas_kupries Exp $

package require critcl
package require Tcl 8.4

namespace eval ::base32::hex {
    # Supporting code for the main command.
    catch {
	#critcl::cheaders -g
	#critcl::debug memory symbols
    }

    # Main commands, encoder & decoder

    critcl::ccommand critcl_encode {dummy interp objc objv} {
      /* Syntax -*- c -*-
       * critcl_encode string
       */

      unsigned char* buf;
      int           nbuf;

      unsigned char* out;
      unsigned char* at;
      int           nout;

      /*
       * The array used for encoding
       */                     /* 123456789 123456789 123456789 12 */
      static const char map[] = "0123456789ABCDEFGHIJKLMNOPQRSTUV";

#define USAGEE "bitstring"

      if (objc != 2) {
        Tcl_WrongNumArgs (interp, 1, objv, USAGEE);
        return TCL_ERROR;
      }

      buf  = Tcl_GetByteArrayFromObj (objv[1], &nbuf);
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

      Tcl_SetObjResult (interp, Tcl_NewStringObj ((char*)out, nout));
      Tcl_Free ((char*) out);
      return TCL_OK;
    }


    critcl::ccommand critcl_decode {dummy interp objc objv} {
      /* Syntax -*- c -*-
       * critcl_decode estring
       */

      unsigned char* buf;
      int           nbuf;

      unsigned char* out;
      unsigned char* at;
      unsigned char  x [8];
      int           nout;

      int i, j, a, pad, nx;

      /*
       * An array for translating single base-32 characters into a value.
       * Disallowed input characters have a value of 64.  Upper and lower
       * case is the same. Only 128 chars, as everything above char(127)
       * is 64.
       */
      static const char map [] = {
	/* \00 */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* DLE */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* SPC */ 64, 64, 64, 64, 64, 64, 64, 64,  64, 64, 64, 64, 64, 64, 64, 64, 
	/* '0' */  0,  1,  2,  3,  4,  5,  6,  7,   8,  9, 64, 64, 64, 64, 64, 64, 
	/* '@' */ 64, 10, 11, 12, 13, 14, 15, 16,  17, 18, 19, 20, 21, 22, 23, 24,
	/* 'P' */ 25, 26, 27, 28, 29, 30, 31, 64,  64, 64, 64, 64, 64, 64, 64, 64,
	/* '`' */ 64, 10, 11, 12, 13, 14, 15, 16,  17, 18, 19, 20, 21, 22, 23, 24,
	/* 'p' */ 25, 26, 27, 28, 29, 30, 31, 64,  64, 64, 64, 64, 64, 64, 64, 64
      };

#define USAGED "estring"

      if (objc != 2) {
        Tcl_WrongNumArgs (interp, 1, objv, USAGED);
        return TCL_ERROR;
      }

      buf = (unsigned char*) Tcl_GetStringFromObj (objv[1], &nbuf);

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

      Tcl_SetObjResult (interp, Tcl_NewByteArrayObj (out, at-out));
      Tcl_Free ((char*) out);
      return TCL_OK;
    }
}

# ### ### ### ######### ######### #########
## Ready
