# -*- tcl -*-
# Critcl support, absolutely necessary.
package require critcl

# Bail out early if the compile environment is not suitable.
if {![lb]critcl::compiling[rb]} {
    error "Unable to build project, no proper compiler found."
}

# Information for the teapot.txt meta data file put into a generated package.
# Free form strings.
critcl::license {Andreas Kupries} {Under a BSD license}

critcl::summary {The second CriTcl-based package}

critcl::description {
    This package is the second example of a CriTcl-based package. It contains all the
    necessary and conventionally useful pieces for wrapping an external library.
}

critcl::subject {external library usage} example {critcl package}
critcl::subject {wrapping external library}

# Minimal Tcl version the package should load into.
critcl::tcl 8.6

# Locations for headers and shared library of the library to wrap.
# Required only for non-standard locations, i.e. where CC is not searching by default.
critcl::cheaders   -I/usr/include
critcl::clibraries -L/usr/lib/x86_64-linux-gnu
critcl::clibraries -lzstd

# Import library API, i.e. headers.
critcl::include zstd.h

# ## #### ######### ################ #########################
## (De)compression using Zstd
## Data to (de)compress is passed in and returned as Tcl byte arrays.

critcl::cproc compress {
    Tcl_Interp* ip
    bytes       data
    int         {level ZSTD_CLEVEL_DEFAULT}
} object0 {
    /* critcl_bytes data; (.s, .len, .o) */
    Tcl_Obj* error_message;

    int max = ZSTD_maxCLevel();
    if ((level < 1) || (level > max)) {
	error_message = Tcl_ObjPrintf ("level must be integer between 1 and %d", max);
	goto err;
    }

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

critcl::cproc decompress {
    Tcl_Interp*  ip
    bytes        data
} object0 {
    Tcl_Obj* error_message;

    size_t dest_sz = ZSTD_getDecompressedSize (data.s, data.len);
    if (dest_sz == 0) {
        error_message = Tcl_NewStringObj("invalid data", -1);
	goto err;
    }

    void* dest_buf = Tcl_Alloc (dest_sz);
    if (!dest_buf) {
	error_message = Tcl_NewStringObj("failed to allocate decompression buffer", -1);
	goto err;
    }

    size_t decompressed_size = ZSTD_decompress (dest_buf, dest_sz,
						data.s,   data.len);
    if (decompressed_size != dest_sz) {
	Tcl_Free (dest_buf);
        error_message = Tcl_ObjPrintf("zstd decoding error: %s",
				      ZSTD_getErrorName (decompressed_size));
	goto err;
    }

    Tcl_Obj* decompressed = Tcl_NewByteArrayObj (dest_buf, dest_sz);
    Tcl_Free (dest_buf);

    return decompressed;

  err:
    Tcl_SetObjResult (ip, error_message);
    return 0;
}

# ## #### ######### ################ #########################

# Forcing compilation, link, and loading now.
critcl::msg -nonewline { Building ...}
if {![lb]critcl::load[rb]} {
    error "Building and loading the project failed."
}

# Name and version the package. Just like for every kind of Tcl package.
package provide critcl-example 1
