
The standard format used for documentation of packages and other
things in Tcllib is [term doctools].

Its supporting packages are a part of Tcllib, see the directories
[file modules/doctools] and [file modules/dtplite]. The latter is
an application package, with the actual application
[file apps/dtplite] a light wrapper around it.

[para] Tcllib developers gain access to these through the [cmd doc]
method of the [file sak.tcl] tool, another (internal) wrapper around
the [file modules/dtplite] application package.

[comment {===================================================================}]
[subsection {Generate documentation for a specific module}]

Invoke either

[example {  ./sak.tcl doc html foo }]

or

[example {  ./sak.tcl doc html modules/foo }]

to generate HTML for the documentation found in the module [file foo].

Instead of [const html] any other supported format can be used here,
of course.

[para] The generated formatted documentation will be placed into a
directory [file doc] in the current working directory.

[comment {===================================================================}]
[subsection {Generate documentation for all modules}]

Invoke the tool without a module name, i.e.

[example {  ./sak.tcl doc html }]

to generate HTML for the documentation found in all modules.

Instead of [const html] any other supported format can be used here,
of course.

[para] The generated formatted documentation will be placed into a
directory [file doc] in the current working directory.

[comment {===================================================================}]
[subsection {Available output formats, help}]

Invoke the tool as

[example {  ./sak.tcl help doc }]

to see the entire set of supported output formats which can be
generated.

[comment {===================================================================}]
[subsection {Validation without output}]

Note the special format [const validate].

[para] Using this value as the name of the format to generate forces
the tool to simply check that the documentation is syntactically
correct, without generating actual output.

[para] Invoke it as either

[example {  ./sak.tcl doc validate (modules/)foo }]

or

[example {  ./sak.tcl doc validate }]

to either check the packages of a specific module or check all of
them.
