# rc4c.tcl - Copyright (C) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This provides a critcl C implementation of RC4 
#
# INSTALLATION
# ------------
# This package uses critcl (http://wiki.tcl.tk/critcl). To build do:
#  critcl -libdir <your-tcl-lib-dir> -pkg rc4c rc4c
#
# To build this for tcllib use sak.tcl:
#  tclsh sak.tcl critcl
# generates a tcllibc module.
#
# $Id: rc4c.tcl,v 1.4 2009/05/07 00:14:02 patthoyts Exp $

package require critcl
# @sak notprovided rc4c
package provide rc4c 1.1.0

namespace eval ::rc4 {

    critcl::ccode {
        #include <string.h>

        typedef struct RC4_CTX {
            unsigned char x;
            unsigned char y;
            unsigned char s[256];
        } RC4_CTX;

        /* #define TRACE trace */
        #define TRACE 1 ? ((void)0) : trace

        static void trace(const char *format, ...)
        {
            va_list args;
            va_start(args, format);
            vfprintf(stderr, format, args);
            va_end(args);
        }
        static Tcl_ObjType rc4_type;
    
        static void rc4_free_rep(Tcl_Obj *obj)
        {
            RC4_CTX *ctx = (RC4_CTX *)obj->internalRep.otherValuePtr;
            TRACE("rc4_free_rep(%08x)\n", (long)obj);
            Tcl_Free((char *)ctx);
        }

        static void rc4_dup_rep(Tcl_Obj *obj, Tcl_Obj *dup)
        {
            RC4_CTX *ctx = (RC4_CTX *)obj->internalRep.otherValuePtr;
            TRACE("rc4_dup_rep(%08x,%08x)\n", (long)obj, (long)dup);
            dup->internalRep.otherValuePtr = (RC4_CTX *)Tcl_Alloc(sizeof(RC4_CTX));
            memcpy(dup->internalRep.otherValuePtr, ctx, sizeof(RC4_CTX));
            dup->typePtr = &rc4_type;
        }

        static void rc4_string_rep(Tcl_Obj* obj)
        {
            RC4_CTX *ctx = (RC4_CTX *)obj->internalRep.otherValuePtr;
            Tcl_Obj* tmpObj;
            char* str;
            TRACE("rc4_string_rep(%08x)\n", (long)obj);
            /* convert via a byte array to properly handle null bytes */
            tmpObj = Tcl_NewByteArrayObj((unsigned char *)ctx, sizeof(RC4_CTX));
            Tcl_IncrRefCount(tmpObj);
            
            str = Tcl_GetStringFromObj(tmpObj, &obj->length);
            obj->bytes = Tcl_Alloc(obj->length + 1);
            memcpy(obj->bytes, str, obj->length + 1);
            
            Tcl_DecrRefCount(tmpObj);
        }

        static int rc4_from_any(Tcl_Interp* interp, Tcl_Obj* obj)
        {
            TRACE("rc4_from_any %08x\n", (long)obj);
            return TCL_ERROR;
        }

        static Tcl_ObjType rc4_type = {
            "rc4c", rc4_free_rep, rc4_dup_rep, rc4_string_rep, rc4_from_any
        };
#ifdef __GNUC__
        inline
#elif defined(_MSC_VER)
        __inline
#endif
        void swap (unsigned char *lhs, unsigned char *rhs) {
            unsigned char t = *lhs;
            *lhs = *rhs;
            *rhs = t;
        }
    }

    critcl::ccommand rc4c_init {dummy interp objc objv} {
        RC4_CTX *ctx;
        Tcl_Obj *obj;
        const unsigned char *k;
        int n = 0, i = 0, j = 0, keylen;

        if (objc != 2) {
            Tcl_WrongNumArgs(interp, 1, objv, "keystring");
            return TCL_ERROR;
        }
        
        k = Tcl_GetByteArrayFromObj(objv[1], &keylen);

        obj = Tcl_NewObj();
        ctx = (RC4_CTX *)Tcl_Alloc(sizeof(RC4_CTX));
        ctx->x = 0;
        ctx->y = 0;
        for (n = 0; n < 256; n++)
            ctx->s[n] = n;
        for (n = 0; n < 256; n++) {
            j = (k[i] + ctx->s[n] + j) % 256;
            swap(&ctx->s[n], &ctx->s[j]);
            i = (i + 1) % keylen;
        }
        
        if (obj->typePtr != NULL && obj->typePtr->freeIntRepProc != NULL)
            obj->typePtr->freeIntRepProc(obj);
        obj->internalRep.otherValuePtr = ctx;
        obj->typePtr = &rc4_type;
        Tcl_InvalidateStringRep(obj);
        Tcl_SetObjResult(interp, obj);
        return TCL_OK;
    }

    critcl::ccommand rc4c {dummy interp objc objv} {
        Tcl_Obj *resObj = NULL;
        RC4_CTX *ctx = NULL;
        unsigned char *data, *res, x, y;
        int size, n, i;

        if (objc != 3) {
            Tcl_WrongNumArgs(interp, 1, objv, "key data");
            return TCL_ERROR;
        }

        if (objv[1]->typePtr != &rc4_type
            && rc4_from_any(interp, objv[1]) != TCL_OK) {
            return TCL_ERROR;
        }

        ctx = objv[1]->internalRep.otherValuePtr;
        data = Tcl_GetByteArrayFromObj(objv[2], &size);
        res = (unsigned char *)Tcl_Alloc(size);

        x = ctx->x;
        y = ctx->y;
        for (n = 0; n < size; n++) {
            x = (x + 1) % 256;
            y = (ctx->s[x] + y) % 256;
            swap(&ctx->s[x], &ctx->s[y]);
            i = (ctx->s[x] + ctx->s[y]) % 256;
            res[n] = data[n] ^ ctx->s[i];
        }
        ctx->x = x;
        ctx->y = y;

        resObj = Tcl_NewByteArrayObj(res, size);
        Tcl_SetObjResult(interp, resObj);
        Tcl_Free((char*)res);
        return TCL_OK;
    }
}
