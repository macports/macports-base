This section is for developers of extensions not based on critcl, yet
also wishing to interface with stubs as they are understood and used
by critcl, either by exporting their own stubs table to a
critcl-based extension, or importing a stubs table of a critcl-based
extension into their own.

[para] To this end we describe the stubs table information of a
package [package foo].

[list_begin enumerated]
[enum] Note that the differences in the capitalization of "foo",
"Foo", "FOO", etc. below demonstrate how to capitalize the actual
package name in each context.

[enum] All relevant files must be available in a sub-directory
[file foo] which can be found on the include search paths.

[enum] The above directory may contain a file [file foo.decls]. If
	present it is assumed to contain the external representation
	of the stubs table the headers mentioned in the following
	items are based on.
[para] critcl is able to use such a file to give the importing package
	programmatic access to the imported API, for automatic code
	generation and the like.

[enum] The above directory must contain a header file
[file fooDecls.h]. This file [emph declares] the exported API.
It is used by both exporting and importing packages. It is usually
generated and must contain (in the order specified):

[list_begin enumerated]
[enum] the declarations of the exported, i.e. public, functions of
	[package foo],

[enum] the declaration of structure "FooStubs" for the stub table,

[enum] the C preprocessor macros which route the invocations of the
	public functions through the stubs table.
[para] These macros must be defined if, and only if, the C preprocessor
	macro USE_FOO_STUBS is defined. Package [package foo] does not
	define this macro, as it is allowed to use the exported
	functions directly. All importing packages however must define
	this macro, to ensure that they do [emph not] use any of the
	exported functions directly, but only through the stubs table.

[enum] If the exported functions need additional types for their proper
	declaration then these types should be put into a separate
	header file (of arbitrary name) and [file fooDecls.h] should
	contain an #include directive to this header at the top.
[list_end]

[para] A very reduced, yet also complete example, from a package for
low-level random number generator functions can be found at the end of
this section.

[enum] The above directory must contain a header file
[file fooStubLib.h]. This file [emph defines] everything needed to use
the API of [package foo]. Consequently it is used only by importing
packages. It is usually generated and must contain (in the order
specified):

[list_begin enumerated]
[enum] An #include directive for [file tcl.h], with USE_TCL_STUBS
	surely defined.

[enum] An #include directive for [file fooDecls.h], with USE_FOO_STUBS
	surely defined.

[enum] A [emph definition] of the stubs table variable, i.e.
	[example {const FooStubs* fooStubsPtr;}]

[enum] A [emph definition] of the stubs initializer function, like
	[example {char *
Foo_InitStubs(Tcl_Interp *interp, CONST char *version, int exact)
{
    /*
     * Boiler plate C code initalizing the stubs table variable,
     * i.e. "fooStubsPtr".
     */

    CONST char *actualVersion;

    actualVersion = Tcl_PkgRequireEx(interp, "foo", version,
				     exact, (ClientData *) &fooStubsPtr);

    if (!actualVersion) {
	return NULL;
    }

    if (!fooStubsPtr) {
	Tcl_SetResult(interp,
		      "This implementation of Foo does not support stubs",
		      TCL_STATIC);
	return NULL;
    }

    return (char*) actualVersion;
}}]
[list_end]

This header file must be included by an importing package
[emph {exactly once}], so that it contains only one definition of both
stubs table and stubs initializer function.

[para] The importing package's initialization function must further
contain a statement like
[example {if (!Foo_InitStubs (ip, "1", 0)) {
    return TCL_ERROR;
}}]
which invokes [package foo]'s stubs initializer function to set the
local stub table up.

[para] For a complete example of such a header file see below, at the
end of this section.

[enum] The last item above, about [file fooStubLib.h] [emph differs]
	from the regular stub stable system used by Tcl. The regular
	system assumes that a static library [file libfoostub.a] was
	installed by package [package foo], and links it.

[para] IMVHO critcl's approach is simpler, using [emph only] header
	files found in a single location, vs. header files and static
	library found in multiple, different locations.

[para] A second simplification is that we avoid having to extend
	critcl's compiler backend with settings for the creation of
	static libraries.
[list_end]


Below is a complete set of example header files, reduced, yet still
complete, from a package for low-level random number generator
functions:

[list_begin definitions]
[def [file rngDecls.h]:]
[example {
#ifndef rng_DECLS_H
#define rng_DECLS_H

#include <tcl.h>

/*
 * Exported function declarations:
 */

/* 0 */
EXTERN void rng_bernoulli(double p, int*v);

typedef struct RngStubs {
    int magic;
    const struct RngStubHooks *hooks;

    void (*rng_bernoulli) (double p, int*v); /* 0 */
} RngStubs;

#ifdef __cplusplus
extern "C" {
#endif
extern const RngStubs *rngStubsPtr;
#ifdef __cplusplus
}
#endif

#if defined(USE_RNG_STUBS)

/*
 * Inline function declarations:
 */

#define rng_bernoulli \
	(rngStubsPtr->rng_bernoulli) /* 0 */

#endif /* defined(USE_RNG_STUBS) */
#endif /* rng_DECLS_H */

}]

[def [file rngStubLib.h]:]
[example {
/*
 * rngStubLib.c --
 *
 * Stub object that will be statically linked into extensions that wish
 * to access rng.
 */

#ifndef USE_TCL_STUBS
#define USE_TCL_STUBS
#endif
#undef  USE_TCL_STUB_PROCS

#include <tcl.h>

#ifndef USE_RNG_STUBS
#define USE_RNG_STUBS
#endif
#undef  USE_RNG_STUB_PROCS

#include "rngDecls.h"

/*
 * Ensure that Rng_InitStubs is built as an exported symbol.  The other stub
 * functions should be built as non-exported symbols.
 */

#undef  TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLEXPORT

const RngStubs* rngStubsPtr;

/*
 *----------------------------------------------------------------------
 *
 * Rng_InitStubs --
 *
 * Checks that the correct version of Rng is loaded and that it
 * supports stubs. It then initialises the stub table pointers.
 *
 * Results:
 *  The actual version of Rng that satisfies the request, or
 *  NULL to indicate that an error occurred.
 *
 * Side effects:
 *  Sets the stub table pointers.
 *
 *----------------------------------------------------------------------
 */

#ifdef Rng_InitStubs
#undef Rng_InitStubs
#endif

char *
Rng_InitStubs(Tcl_Interp *interp, CONST char *version, int exact)
{
    CONST char *actualVersion;

    actualVersion = Tcl_PkgRequireEx(interp, "rng", version,
				     exact, (ClientData *) &rngStubsPtr);
    if (!actualVersion) {
	return NULL;
    }

    if (!rngStubsPtr) {
	Tcl_SetResult(interp,
		      "This implementation of Rng does not support stubs",
		      TCL_STATIC);
	return NULL;
    }

    return (char*) actualVersion;
}
}]
[list_end]

