[subsection {Custom Types, Support structures}]

The adjunct command [cmd critcl::argtypesupport] is for when the
conversion needs additional definitions, for example a helper
structure.

[para] An example of this can be found among the standard types of
critcl itself, the [type pstring] type. This type provides the C
function with not only the string pointer, but also the string length,
and the [type Tcl_Obj*] this data came from. As [cmd critcl::cproc]'s
calling conventions allow us only one argument for the data of the
parameter a structure is needed to convey these three pieces of
information.

[para] Thus the argument type is defined as

[example {
    critcl::argtype pstring {
        @A.s = Tcl_GetStringFromObj(@@, &(@A.len));
        @A.o = @@;
    } critcl_pstring critcl_pstring

    critcl::argtypesupport pstring {
        typedef struct critcl_pstring {
            Tcl_Obj*    o;
            const char* s;
            int         len;
        } critcl_pstring;
    }
}]

[para] In the case of such a structure being large we may wish to
allocate it on the heap instead of having it taking space on the
stack. If we do that we need another adjunct command,
[cmd critcl::argtyperelease]. This command specifies the code required
to release dynamically allocated resources when the worker function
returns, before the shim returns to the caller in Tcl.

To keep things simple our example is synthetic, a modification of
[const pstring] above, to demonstrate the technique. An actual, but
more complex example is the code to support the variadic [arg args]
argument of [cmd critcl::cproc].

[example {
    critcl::argtype pstring {
        @A = (critcl_pstring*) ckalloc(sizeof(critcl_pstring));
        @A->s = Tcl_GetStringFromObj(@@, &(@A->len));
        @A->o = @@;
    } critcl_pstring* critcl_pstring*

    critcl::argtypesupport pstring {
        typedef struct critcl_pstring {
            Tcl_Obj*    o;
            const char* s;
            int         len;
        } critcl_pstring;
    }

    critcl::argtyperelease pstring {
        ckfree ((char*)) @A);
    }
}]

Note, the above example shows only the most simple case of an
allocated argument, with a conversion that cannot fail (namely, string
retrieval). If the conversion can fail then either the allocation has
to be defered to happen only on successful conversion, or the
conversion code has to release the allocated memory itself in the
failure path, because it will never reach the code defined via
[cmd critcl::argtyperelease] in that case.
