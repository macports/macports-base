
Each [file .critcl] file is backed by a single private [file .c] file
containing that code, plus the boilerplate necessary for its
compilation and linking as a single shared library.

[para] The [sectref {Advanced: Embedded C Code} {Embedded C Code}]
fragments appear in that file in the exact same order they were
defined in the [file .critcl] file, with one exception. The C code
provided via [cmd critcl::cinit] is put after all other fragments.

In other words all fragments have access to the symbols defined by
earlier fragments, and the [cmd critcl::cinit] fragment has access to
all, regardless of its placement in the [file .critcl] file.

[para] Note: A [emph limitation] of the current system is the near
impossibility of C level access between different critcl-based
packages. The issue is not the necessity of writing and sharing the
proper [syscmd extern] statements, but that the management (export and
import) of package-specific stubs-tables is not supported. This means
that dependent parts have to be forcibly loaded before their user,
with all that entails. See section [sectref {Runtime Behaviour}] for
the relevant critcl limitation, and remember that many older platforms
do not support the necessary resolution of symbols, the reason why
stubs were invented for Tcl in the first place.
