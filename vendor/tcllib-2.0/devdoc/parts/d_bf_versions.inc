In Tcllib all changes to a package have to come with an increment of
its version number. What part is incremented (patchlevel, minor, major
version) depends on the kind of change made. With multiple changes in
a commit the highest "wins".

[para] When working in a development branch the version change can be
       deferred until it is time to merge, and then has to cover all
       the changes in the branch.

[para] Below a list of the kinds of changes and their associated
       version increments:

[list_begin definitions]
[def [term {D - documentation}]] No increment
[def [term {T - testsuite}]] No increment
[def [term {B - bugfix}]] Patchlevel
[def [term {I - implementation tweak}]] Patchlevel
[def [term {P - performance tweak}]] Patchlevel
[def [term {E - backward-compatible extension}]] Minor
[def [term {API - incompatible change}]] Major
[list_end]

[para] Note that a commit containing a version increment has to
       mention the new version number in its commit message, as well
       as the kind of change which caused it.

[para] Note further that the version number of a package currently
       exists in three places. An increment has to update all of them:

[list_begin enumerated]
[enum] The package implementation.
[enum] The package index ([file pkgIndex.tcl])
[enum] The package documentation.
[list_end]

[para] The [file sak.tcl] command [cmd {validate version}] helps
       finding discrepancies between the first two.

       All the other [cmd validate] methods are also of interest to
       any developer. Invoke it with

       [example { sak.tcl help validate }]

       to see their documentation.
