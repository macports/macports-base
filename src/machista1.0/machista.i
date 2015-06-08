// vim:ft=c:tw=80:expandtab
%module machista

%{
#include <tcl.h>
#include "libmachista.h"
%}

%inline %{
#ifdef __MACH__
    #include <mach-o/arch.h>
#endif
    #include <inttypes.h>
    #include <stdint.h>
%}

%include "typemaps.i"

%rename(SUCCESS) MACHO_SUCCESS;
#define MACHO_SUCCESS   (0x00)

%rename(EFILE) MACHO_EFILE;
#define MACHO_EFILE     (0x01)

%rename(EMMAP) MACHO_EMMAP;
#define MACHO_EMMAP     (0x02)

%rename(EMEM) MACHO_EMEM;
#define MACHO_EMEM      (0x04)

%rename(ERANGE) MACHO_ERANGE;
#define MACHO_ERANGE    (0x08)

%rename(EMAGIC) MACHO_EMAGIC;
#define MACHO_EMAGIC    (0x10)

typedef unsigned int uint32_t;
typedef int cpu_type_t;

/**
 * We don't want users to create their own macho_handle, macho_loadcmd or
 * macho_arch structures, so we disable generation of default con- and
 * destructor
 * One might think we would want users to create their own macho structures or
 * at least pointers to such structures in order to be able to call
 * macho_parse_file, but we can also do this in a typemap for the const struct
 * macho **-argument and can thus disable constructors for struct macho.
 */
%nodefaultctor;
%nodefaultdtor;

/**
 * blind handle structure
 * ideally, SWIG shouldn't create any functions for this type. We could probably
 * leave it out then, but I guess it doesn't hurt telling SWIG it's there (maybe
 * it does some type checking)
 */
struct macho_handle {};

/**
 * macho_loadcmd structure
 * Since we don't want SWIG to fiddle with the allocated memory present in this
 * structure, we define all fields as immutable using %immutable.
 */
struct macho_loadcmd {
    %immutable;
    char                 *mlt_install_name;
    uint32_t              mlt_type;
    uint32_t              mlt_comp_version;
    uint32_t              mlt_version;
    struct macho_loadcmd *next;
};

/**
 * macho_arch structure
 * Since we don't want SWIG to fiddle with the allocated memory present in this
 * structure, we define all fields as immutable using %immutable.
 */
struct macho_arch {
    %immutable;
    char                 *mat_install_name;
    char                 *mat_rpath;
    cpu_type_t            mat_arch;
    uint32_t              mat_comp_version;
    uint32_t              mat_version;
    struct macho_loadcmd *mat_loadcmds;
    struct macho_arch    *next;
};

/**
 * macho structure
 * We don't want users to be able to change anything in here either, because
 * this is all allocated memory and will be cached by libmachista and later
 * free()'d on macho_destroy_handle. Because of this, we use the %immutable
 * modifier as above.
 */
struct macho {
    %immutable;
    struct macho_arch    *mt_archs; 
};

%clearnodefaultdtor;
%clearnodefaultctor;


// creating and destroying handles
/**
 * Allow users to create and destroy macho_handle structures. The users (and
 * SWIG) do not know anything about the contents of this structure.
 */
%rename(create_handle) macho_create_handle;
struct macho_handle *macho_create_handle(void);

%rename(destroy_handle) macho_destroy_handle;
void macho_destroy_handle(struct macho_handle *INPUT);

/**
 * Parse a file using libmachista
 * handle and filename are simple parameters and used as input parameter.
 * However, **result is meant to be an output parameter, and is thus declared as
 * such using the OUTPUT keyword, causing it to be returned as second parameter
 * of a list.
 * Also, we need to provide a valid address of a pointer for macho_parse_file to
 * write to. We could have the user to this, but instead use a typemap to create
 * said pointer and pass a pointer to it to macho_parse_file. Using numinputs=0
 * causes SIWG to stop expecting the parameter when calling from Tcl.
 */
%typemap(argout) const struct macho **result {
    Tcl_ListObjAppendElement(interp, $result, SWIG_NewInstanceObj(SWIG_as_voidptr(*$1), $descriptor(struct macho *), 0));
}
%typemap(in, numinputs=0) const struct macho ** (struct macho *res) {
    $1 = &res;
}
%rename(parse_file) macho_parse_file;
int macho_parse_file(struct macho_handle *handle, const char *filename, const struct macho **result);

/**
 * Returns an error string for the error code returned by macho_parse_file. This
 * is not an allocated string and must thus not be free()'d after copying it to
 * Tcl.
 */
%rename(strerror) macho_strerror;
const char *macho_strerror(int err);

/**
 * map macho_get_arch_name()
 * The memory for the returned char * comes from NXGetArchInfoFromCpuType(),
 * which is documentet in arch(3), without ever mentioning any memory issues. I
 * assume it's static memory, that should not be free()'d.
 */
%rename(get_arch_name) macho_get_arch_name;
const char *macho_get_arch_name(cpu_type_t);

/**
 * map macho_format_dylib_version()
 * Since this function internally allocates the result and returns an allocated
 * pointer, it needs to be free()'d after usage (in this case usage is
 * conversion to a Tcl String). We can do that using a ret typemap:
 */
%typemap(ret) char * {
    free($1);
}
%rename(format_dylib_version) macho_format_dylib_version;
char *macho_format_dylib_version(uint32_t);

