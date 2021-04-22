# md5cryptc.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This is a critcl-based wrapper to provide a Tcl implementation of the md5crypt
# function. The C code here is based upon the OpenBSD source, which is in turn
# derived from the original implementation by Poul-Henning Kamp
#
# The original C source license reads:
#/*
# * ----------------------------------------------------------------------------
# * "THE BEER-WARE LICENSE" (Revision 42):
# * <phk@login.dknet.dk> wrote this file.  As long as you retain this notice you
# * can do whatever you want with this stuff. If we meet some day, and you think
# * this stuff is worth it, you can buy me a beer in return.   Poul-Henning Kamp
# * ----------------------------------------------------------------------------
# */
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------


package require critcl
# @sak notprovided md5cryptc
package provide md5cryptc 1.0

critcl::cheaders ../md5/md5.h
#critcl::csources ../md5/md5.c

namespace eval ::md5crypt {
    critcl::ccode {
#include <string.h>
#include "md5.h"
#ifdef _MSC_VER
#define snprintf _snprintf
#endif
        static unsigned char itoa64[] =
            "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        
        static void to64(char *s, unsigned int v, int n)
        {
            while (--n >= 0) {
                *s++ = itoa64[v&0x3f];
                v >>= 6;
            }
        }
        
        static void dump(const char *s, unsigned int len) 
        {
            unsigned int i;
            for (i = 0; i < len; i++)
                printf("%02X", s[i]&0xFF);
            putchar('\n');
        }
        
        static char * md5crypt(const char *pw,
                               const char *salt,
                               const char *magic)
        {
            static char     passwd[120], *p;
            static const unsigned char *sp,*ep;
            unsigned char	final[16];
            int sl,pl,i;
            MD5_CTX	ctx,ctx1;
            unsigned long l;
            
            /* Refine the Salt first */
            sp = (const unsigned char *)salt;
            
            /* If it starts with the magic string, then skip that */
            if(!strncmp((const char *)sp,(const char *)magic,strlen((const char *)magic)))
                sp += strlen((const char *)magic);
            
            /* It stops at the first '$', max 8 chars */
            for(ep=sp;*ep && *ep != '$' && ep < (sp+8);ep++)
                continue;
            
            /* get the length of the true salt */
            sl = ep - sp;
            
            MD5Init(&ctx);
            
            /* The password first, since that is what is most unknown */
            MD5Update(&ctx,(unsigned char *)pw,strlen(pw));
            
            /* Then our magic string */
            MD5Update(&ctx,(unsigned char *)magic,strlen((const char *)magic));
            
            /* Then the raw salt */
            MD5Update(&ctx,(unsigned char*)sp,sl);
            
            /* Then just as many characters of the MD5(pw,salt,pw) */
            MD5Init(&ctx1);
            MD5Update(&ctx1,(unsigned char *)pw,strlen(pw));
            MD5Update(&ctx1,(unsigned char *)sp,sl);
            MD5Update(&ctx1,(unsigned char *)pw,strlen(pw));
            MD5Final(final,&ctx1);
            
            for(pl = strlen(pw); pl > 0; pl -= 16) {
                int tl = pl > 16 ? 16 : pl;
                MD5Update(&ctx,final,pl>16 ? 16 : pl);
            }
            
            /* Don't leave anything around in vm they could use. */
            memset(final,0,sizeof final);
            
            /* Then something really weird... */
            for (i = strlen(pw); i ; i >>= 1) {
                if(i&1)
                    MD5Update(&ctx, final, 1);
                else
                    MD5Update(&ctx, (unsigned char *)pw, 1);
            }
            
            /* Now make the output string */
            snprintf(passwd, sizeof(passwd), "%s%.*s$", (char *)magic,
                    sl, (const char *)sp);
            
            MD5Final(final,&ctx);
            
            /*
             * and now, just to make sure things don't run too fast
             * On a 60 Mhz Pentium this takes 34 msec, so you would
             * need 30 seconds to build a 1000 entry dictionary...
             */
            for(i=0;i<1000;i++) {
                MD5Init(&ctx1);
                if(i & 1)
                    MD5Update(&ctx1,(unsigned char *)pw,strlen(pw));
                else
                    MD5Update(&ctx1,final,16);
                
                if(i % 3)
                    MD5Update(&ctx1,(unsigned char *)sp,sl);
                
                if(i % 7)
                    MD5Update(&ctx1,(unsigned char *)pw,strlen(pw));
                
                if(i & 1)
                    MD5Update(&ctx1,final,16);
                else
                    MD5Update(&ctx1,(unsigned char *)pw,strlen(pw));
                MD5Final(final,&ctx1);
            }

            p = passwd + strlen(passwd);
            
            l = (final[ 0]<<16) | (final[ 6]<<8) | final[12]; to64(p,l,4); p += 4;
            l = (final[ 1]<<16) | (final[ 7]<<8) | final[13]; to64(p,l,4); p += 4;
            l = (final[ 2]<<16) | (final[ 8]<<8) | final[14]; to64(p,l,4); p += 4;
            l = (final[ 3]<<16) | (final[ 9]<<8) | final[15]; to64(p,l,4); p += 4;
            l = (final[ 4]<<16) | (final[10]<<8) | final[ 5]; to64(p,l,4); p += 4;
            l =		       final[11]		; to64(p,l,2); p += 2;
            *p = '\0';
            
            /* Don't leave anything around in vm they could use. */
            memset(final,0,sizeof final);
            
            return passwd;
        }            
    }
    critcl::cproc to64_c {Tcl_Interp* interp int v int n} ok {
        char s[5];
        to64(s, (unsigned int)v, n); 
        Tcl_SetObjResult(interp, Tcl_NewStringObj(s, n));
        return TCL_OK;
    }

    critcl::cproc md5crypt_c {Tcl_Interp* interp char* magic char* pw char* salt} ok {
        char* s = md5crypt(pw, salt, magic);
        Tcl_SetObjResult(interp, Tcl_NewStringObj(s, strlen(s)));
        return TCL_OK;
    }
}
