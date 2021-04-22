# md5c.tcl - 
#
# Wrapper for RSA's Message Digest in C
#
# Written by Jean-Claude Wippler <jcw@equi4.com>
#
# $Id: md5c.tcl,v 1.5 2009/05/06 22:46:10 patthoyts Exp $

package require critcl;                 # needs critcl
# @sak notprovided md5c
package provide md5c 0.12;              # 

critcl::cheaders md5.h;                 # The RSA header file
critcl::csources md5.c;                 # The RSA MD5 implementation.

namespace eval ::md5 {

    critcl::ccode {
        #include <string.h>
        #include "md5.h"
        #include <assert.h>

        static
        Tcl_ObjType md5_type; /* fast internal access representation */
        
        static void 
        md5_free_rep(Tcl_Obj *obj)
        {
            MD5_CTX *mp = (MD5_CTX *) obj->internalRep.otherValuePtr;
            Tcl_Free((char*)mp);
        }
        
        static void
        md5_dup_rep(Tcl_Obj *obj, Tcl_Obj *dup)
        {
            MD5_CTX *mp = (MD5_CTX *) obj->internalRep.otherValuePtr;
            dup->internalRep.otherValuePtr = Tcl_Alloc(sizeof *mp);
            memcpy(dup->internalRep.otherValuePtr, mp, sizeof *mp);
            dup->typePtr = &md5_type;
        }
        
        static void
        md5_string_rep(Tcl_Obj *obj)
        {
            unsigned char buf[16];
            Tcl_Obj *temp;
            char *str;
            MD5_CTX dup = *(MD5_CTX *) obj->internalRep.otherValuePtr;
            
            MD5Final(buf, &dup);
            
            /* convert via a byte array to properly handle null bytes */
            temp = Tcl_NewByteArrayObj(buf, sizeof buf);
            Tcl_IncrRefCount(temp);
            
            str = Tcl_GetStringFromObj(temp, &obj->length);
            obj->bytes = Tcl_Alloc(obj->length + 1);
            memcpy(obj->bytes, str, obj->length + 1);
            
            Tcl_DecrRefCount(temp);
        }
        
        static int
        md5_from_any(Tcl_Interp* ip, Tcl_Obj* obj)
        {
            assert(0);
            return TCL_ERROR;
        }
        
        static
        Tcl_ObjType md5_type = {
            "md5c", md5_free_rep, md5_dup_rep, md5_string_rep, md5_from_any
        };
    }
    
    critcl::ccommand md5c {dummy ip objc objv} {
        MD5_CTX *mp;
        unsigned char *data;
        int size;
        Tcl_Obj *obj;
        
        if (objc < 2 || objc > 3) {
            Tcl_WrongNumArgs(ip, 1, objv, "data ?context?");
            return TCL_ERROR;
        }
        
        if (objc == 3) {
            if (objv[2]->typePtr != &md5_type && md5_from_any(ip, objv[2]) != TCL_OK) {
                return TCL_ERROR;
            }
            obj = objv[2];
            if (Tcl_IsShared(obj)) {
                obj = Tcl_DuplicateObj(obj);
            }
        } else {
            mp = (MD5_CTX *)Tcl_Alloc(sizeof *mp);
            MD5Init(mp);
            obj = Tcl_NewObj();
            Tcl_InvalidateStringRep(obj);
            obj->internalRep.otherValuePtr = mp;
            obj->typePtr = &md5_type;
        }
        
        mp = (MD5_CTX *) obj->internalRep.otherValuePtr;
        data = Tcl_GetByteArrayFromObj(objv[1], &size);
        MD5Update(mp, data, size);
        Tcl_SetObjResult(ip, obj);
        
        return TCL_OK;
    }
}

if {[info exists pkgtest] && $pkgtest} {

  proc md5c_try {} {
    foreach {msg expected} {
      ""
      "d41d8cd98f00b204e9800998ecf8427e"
      "a"
      "0cc175b9c0f1b6a831c399e269772661"
      "abc"
      "900150983cd24fb0d6963f7d28e17f72"
      "message digest"
      "f96b697d7cb7938d525a2f31aaf161d0"
      "abcdefghijklmnopqrstuvwxyz"
      "c3fcd3d76192e4007dfb496cca67e13b"
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
      "d174ab98d277d9f5a5611c2c9f419d9f"
      "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
      "57edf4a22be3c955ac49da2e2107b67a"
    } {
      puts "testing: ::md5::md5c \"$msg\""
      binary scan [::md5::md5c $msg] H* computed
      puts "computed: $computed"
      if {0 != [string compare $computed $expected]} {
	puts "expected: $expected"
	puts "FAILED"
      }
    }

    foreach len {10 50 100 500 1000 5000 10000} {
      set blanks [format %$len.0s ""]
      puts "input length $len: [time {md5c $blanks} 1000]"
    }
  }

  md5c_try
}
