[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum][vset ebase] Replace the entire [cmd compress] function with [example {
    critcl::argtype zstd_compression_level {
        /* argtype: `int` */
        if (Tcl_GetIntFromObj (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
        /* additional validation */    
        int max = ZSTD_maxCLevel();
        if ((@A < 1) || (@A > max)) {
            Tcl_SetObjResult (interp,
                Tcl_ObjPrintf ("zstd compression level must be integer between 1 and %d", max));
            return TCL_ERROR;
        }
        /* @@: current objv[] element
        ** @A: name of argument variable for transfer to C function
        ** interp: predefined variable, access to current interp - error messages, etc.
        */
    } int int ;# C types of transfer variable and function argument.

    critcl::cproc compress {
        Tcl_Interp*            ip
        bytes                  data
        zstd_compression_level {level ZSTD_CLEVEL_DEFAULT}
    } object0 {
        /* critcl_bytes data; (.s, .len, .o) */
        /* int level; validated to be in range 1...ZSTD_maxCLevel() */

        Tcl_Obj* error_message;

        size_t dest_sz  = ZSTD_compressBound (data.len);
        void*  dest_buf = Tcl_Alloc(dest_sz);

        if (!dest_buf) {
            error_message = Tcl_NewStringObj ("can't allocate memory to compress data", -1);
            goto err;
        }

        size_t compressed_size = ZSTD_compress (dest_buf, dest_sz,
                                                data.s,   data.len,
                                                level);
        if (ZSTD_isError (compressed_size)) {
            Tcl_Free(dest_buf);
            error_message = Tcl_ObjPrintf ("zstd encoding error: %s",
                                           ZSTD_getErrorName (compressed_size));
            goto err;
        }

        Tcl_Obj* compressed = Tcl_NewByteArrayObj (dest_buf, compressed_size);
        Tcl_Free (dest_buf);

        return compressed;
    err:
        Tcl_SetObjResult (ip, error_message);
        return 0;
    }
}][vset rebuild]

[para] In the original example the [arg level] argument of the function was validated in
the function itself.

This may detract from the funtionality of interest itself, especially if there are lots of
arguments requiring validation.

If the same kind of argument is used in multiple places this causes code duplication in
the functions as well.

[para] Use a custom argument type as defined by the modification to move this kind of
validation out of the function, and enhance readability.

[para] Code duplication however is only partially adressed.

While there is no duplication in the visible definitions the C code of the new argument
type is replicated for each use of the type.

[enum] Now replace the [cmd argtype] definition with
[example {
    critcl::code {
        int GetCompressionLevel (Tcl_Interp* interp, Tcl_Obj* obj, int* level)
        {
            if (Tcl_GetIntFromObj (interp, obj, level) != TCL_OK) return TCL_ERROR;

            int max = ZSTD_maxCLevel();
            if ((*level < 1) || (*level > max)) {
                Tcl_SetObjResult (interp,
                    Tcl_ObjPrintf ("zstd compression level must be integer between 1 and %d", max));
                return TCL_ERROR;
            }
            return TCL_OK;
        }
    }

    critcl::argtype zstd_compression_level {
        if (GetCompressionLevel (@@, &@A) != TCL_OK) return TCL_ERROR;
    } int int
}][vset rebuild]

[para] Now only the calls to the new validation function are replicated.

The function itself exists only once.

[list_end]
