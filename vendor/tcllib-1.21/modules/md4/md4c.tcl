# md4c.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This provides a C implementation of MD4 using the sample code from RFC1320
# and wrapping this up in a Tcl package.
#
# The tcl interface code is based upon the md5c code from critcl by JCW.
#
# INSTALLATION
# ------------
# This package uses critcl (http://wiki.tcl.tk/critcl). To build do:
#  critcl -libdir <your-tcl-lib-dir> -pkg md4c md4c
#
# $Id: md4c.tcl,v 1.6 2009/05/06 22:57:50 patthoyts Exp $

package require critcl
# @sak notprovided md4c
package provide md4c 1.1.0

critcl::cheaders md4.h
critcl::csources md4.c

namespace eval ::md4 {

    critcl::ccode {
        #include <string.h>
        #include "md4.h"

        /*
         * define a Tcl object type for the MD4 state 
         */
        static Tcl_ObjType md4_type;
    
        static void md4_free_rep(Tcl_Obj *obj)
        {
            MD4_CTX *ctx = (MD4_CTX *)obj->internalRep.otherValuePtr;
            Tcl_Free((char *)ctx);
        }

        static void md4_dup_rep(Tcl_Obj *obj, Tcl_Obj *dup)
        {
            MD4_CTX *ctx = (MD4_CTX *)obj->internalRep.otherValuePtr;
            dup->internalRep.otherValuePtr = (MD4_CTX *)Tcl_Alloc(sizeof(MD4_CTX));
            memcpy(dup->internalRep.otherValuePtr, ctx, sizeof(MD4_CTX));
            dup->typePtr = &md4_type;
        }

        static void md4_string_rep(Tcl_Obj* obj)
        {
            unsigned char buf[16];
            Tcl_Obj* temp;
            char* str;
            MD4_CTX *dup = (MD4_CTX *)obj->internalRep.otherValuePtr;
            
            MD4Final(buf, dup);
            
            /* convert via a byte array to properly handle null bytes */
            temp = Tcl_NewByteArrayObj(buf, sizeof buf);
            Tcl_IncrRefCount(temp);
            
            str = Tcl_GetStringFromObj(temp, &obj->length);
            obj->bytes = Tcl_Alloc(obj->length + 1);
            memcpy(obj->bytes, str, obj->length + 1);
            
            Tcl_DecrRefCount(temp);
        }
    
        static int md4_from_any(Tcl_Interp* interp, Tcl_Obj* obj)
        {
            /* assert(0); */
            return TCL_ERROR;
        }
        
        static Tcl_ObjType md4_type = {
            "md4c", md4_free_rep, md4_dup_rep, md4_string_rep, md4_from_any
        };

    }

    critcl::ccommand md4c {dummy interp objc objv} {
        MD4_CTX *ctx;
        unsigned char *data;
        int size;
        Tcl_Obj *obj;
        
        if (objc < 2 || objc > 3) {
            Tcl_WrongNumArgs(interp, 1, objv, "data ?context?");
            return TCL_ERROR;
        }
        
        if (objc == 3) {
            if (objv[2]->typePtr != &md4_type 
                && md4_from_any(interp, objv[2]) != TCL_OK) {
                return TCL_ERROR;
            }
            obj = objv[2];
            if (Tcl_IsShared(obj)) {
                obj = Tcl_DuplicateObj(obj);
            }
        } else {
            ctx = (MD4_CTX *)Tcl_Alloc(sizeof(MD4_CTX));
            MD4Init(ctx);
            obj = Tcl_NewObj();
	    Tcl_InvalidateStringRep(obj);
            obj->internalRep.otherValuePtr = ctx;
            obj->typePtr = &md4_type;
        }
    
        ctx = (MD4_CTX *)obj->internalRep.otherValuePtr;
        data = Tcl_GetByteArrayFromObj(objv[1], &size);
        MD4Update(ctx, data, size);
        Tcl_SetObjResult(interp, obj);

        return TCL_OK;
    }
}

# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
