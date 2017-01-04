# sha256c.tcl
# - Copyright (C) 2005 Pat Thoyts <patthoyts@users.sourceforge.net>
# - Copyright (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#   (Rewriting the sha1c wrapper to 256).
#
# Wrapper for the Secure Hashing Algorithm (SHA256)
#
# $Id: sha256c.tcl,v 1.5 2009/05/07 00:35:10 patthoyts Exp $

package require critcl;        # needs critcl
# @sak notprovided sha256c
package provide sha256c 1.0.2
			       
critcl::cheaders sha256.h;     # FreeBSD SHA256 implementation
critcl::csources sha256.c;     # FreeBSD SHA256 implementation

if {$tcl_platform(byteOrder) eq "littleEndian"} {
    set byteOrder 1234
} else {
    set byteOrder 4321
}
critcl::cflags -DTCL_BYTE_ORDER=$byteOrder

namespace eval ::sha2 {
    # Supporting code for the main command.
    catch {
        #critcl::debug memory symbols
    }

    critcl::ccode {
        #include "sha256.h"
        #include <stdlib.h>
        #include <string.h>
        #include <assert.h>
        
        static
        Tcl_ObjType sha256_type; /* fast internal access representation */
        
        static void 
        sha256_free_rep(Tcl_Obj* obj)
        {
            SHA256_CTX* mp = (SHA256_CTX*) obj->internalRep.otherValuePtr;
            free(mp);
        }
        
        static void
        sha256_dup_rep(Tcl_Obj* obj, Tcl_Obj* dup)
        {
            SHA256_CTX* mp = (SHA256_CTX*) obj->internalRep.otherValuePtr;
            dup->internalRep.otherValuePtr = malloc(sizeof *mp);
            memcpy(dup->internalRep.otherValuePtr, mp, sizeof *mp);
            dup->typePtr = &sha256_type;
        }
        
        static void
        sha256_string_rep(Tcl_Obj* obj)
        {
            unsigned char buf[SHA256_HASH_SIZE];
            Tcl_Obj* temp;
            char* str;
            SHA256_CTX dup = *(SHA256_CTX*) obj->internalRep.otherValuePtr;
            
            SHA256Final(&dup, buf);
            
            /* convert via a byte array to properly handle null bytes */
            temp = Tcl_NewByteArrayObj(buf, sizeof buf);
            Tcl_IncrRefCount(temp);
            
            str = Tcl_GetStringFromObj(temp, &obj->length);
            obj->bytes = Tcl_Alloc(obj->length + 1);
            memcpy(obj->bytes, str, obj->length + 1);
            
            Tcl_DecrRefCount(temp);
        }
        
        static int
        sha256_from_any(Tcl_Interp* ip, Tcl_Obj* obj)
        {
            assert(0);
            return TCL_ERROR;
        }
        
        static
        Tcl_ObjType sha256_type = {
            "sha256c", sha256_free_rep, sha256_dup_rep, sha256_string_rep,
            sha256_from_any
        };
    }
    
    critcl::ccommand sha256c_init256 {dummy ip objc objv} {
        SHA256_CTX* mp;
        unsigned char* data;
        int size;
        Tcl_Obj* obj;
        
        if (objc > 1) {
            Tcl_WrongNumArgs(ip, 1, objv, "");
            return TCL_ERROR;
        }
        
	obj = Tcl_NewObj();
	mp = (SHA256_CTX*) malloc(sizeof *mp);
	SHA256Init(mp);
            
	if (obj->typePtr != NULL && obj->typePtr->freeIntRepProc != NULL) {
	    obj->typePtr->freeIntRepProc(obj);
	}
            
	obj->internalRep.otherValuePtr = mp;
	obj->typePtr = &sha256_type;
        
        Tcl_InvalidateStringRep(obj);        
        Tcl_SetObjResult(ip, obj);
        return TCL_OK;
    }

    critcl::ccommand sha256c_init224 {dummy ip objc objv} {
        SHA256_CTX* mp;
        unsigned char* data;
        int size;
        Tcl_Obj* obj;
        
        if (objc > 1) {
            Tcl_WrongNumArgs(ip, 1, objv, "");
            return TCL_ERROR;
        }
        
	obj = Tcl_NewObj();
	mp = (SHA256_CTX*) malloc(sizeof *mp);
	SHA224Init(mp);
            
	if (obj->typePtr != NULL && obj->typePtr->freeIntRepProc != NULL) {
	    obj->typePtr->freeIntRepProc(obj);
	}
            
	obj->internalRep.otherValuePtr = mp;
	obj->typePtr = &sha256_type;
        
        Tcl_InvalidateStringRep(obj);        
        Tcl_SetObjResult(ip, obj);
        return TCL_OK;
    }

    critcl::ccommand sha256c_update {dummy ip objc objv} {
        SHA256_CTX* mp;
        unsigned char* data;
        int size;
        Tcl_Obj* obj;
        
        if (objc != 3) {
            Tcl_WrongNumArgs(ip, 1, objv, "data context");
            return TCL_ERROR;
        }
        
	if (objv[2]->typePtr != &sha256_type 
	    && sha256_from_any(ip, objv[2]) != TCL_OK) {
	    return TCL_ERROR;
	}

	obj = objv[2];
	if (Tcl_IsShared(obj)) {
	    obj = Tcl_DuplicateObj(obj);
	}
        
        Tcl_InvalidateStringRep(obj);
        mp = (SHA256_CTX*) obj->internalRep.otherValuePtr;
        
        data = Tcl_GetByteArrayFromObj(objv[1], &size);
        SHA256Update(mp, data, size);
        
        Tcl_SetObjResult(ip, obj);
        return TCL_OK;
    }
}
