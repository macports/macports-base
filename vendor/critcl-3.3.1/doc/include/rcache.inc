
The compilation of C code is time-consuming [package critcl] not only
defers it as much as possible, as described in section
[sectref {Runtime Behaviour}], but also caches the results.

[para] This means that on the first use of a [file .critcl] file
[file FOO.tcl] the resulting object file and shared library are saved
into the cache, and on future uses of the same file reused,
i.e. loaded directly without requiring compilation, provided that the
contents of [file FOO.tcl] did not change.

[para] The change detection is based MD5 hashes. A single hash is
computed for each [file .critcl] file, based on hashes for all C code
fragments and configuration options, i.e. everything which affects the
resulting binary.

[para] As long as the input file doesn't change as per the hash a
previously built shared library found in the cache is reused,
bypassing the compilation and link stages.

[para] The command to manage the cache are found in section
[sectref {Result Cache Management}].

Note however that they are useful only to tools based on the package,
like the [manpage {CriTcl Application}]. Package writers have no need
of them.

[para] As a last note, the default directory for the cache is chosen
based on the chosen build target. This means that the cache can be put
on a shared (network) filesystem without having to fear interference
between machines of different architectures.
