
Testsuites in Tcllib are based on Tcl's standard test package
[package tcltest], plus utilities found in the directory
[file modules/devtools]

[para] Tcllib developers invoke the suites through the
[cmd {test run}] method of the [file sak.tcl] tool, with other methods
of [cmd test] providing management operations, for example setting a
list of standard Tcl shells to use.

[comment {===================================================================}]
[subsection {Invoke the testsuites of a specific module}]

Invoke either

[example {  ./sak.tcl test run foo }]

or

[example {  ./sak.tcl test run modules/foo }]

to invoke the testsuites found in a specific module [file foo].

[comment {===================================================================}]
[subsection {Invoke the testsuites of all modules}]

Invoke the tool without a module name, i.e.

[example {  ./sak.tcl test run }]

to invoke the testsuites of all modules.

[comment {===================================================================}]
[subsection {Detailed Test Logs}]

In all the previous examples the test runner will write a combination
of progress display and testsuite log to the standard output, showing
for each module only the tests that passed or failed and how many of
each in a summary at the end.

[para] To get a detailed log, it is necessary to invoke the test
runner with additional options.

[para] For one:

[example {
   ./sak.tcl test run --log LOG foo
}]

While this shows the same short log on the terminal as before, it also
writes a detailed log to the file [file LOG.log], and excerpts to
other files ([file LOG.summary], [file LOG.failures], etc.).

[para] For two:

[example {
  ./sak.tcl test run -v foo
}]

This writes the detailed log to the standard output, instead of the
short log.

[para] Regardless of form, the detailed log contains a list of all test
cases executed, which failed, and how they failed (expected versus
actual results).

[comment {===================================================================}]
[subsection {Shell Selection}]

By default the test runner will use all the Tcl shells specified via
[cmd {test add}] to invoke the specified testsuites, if any. If no
such are specified it will fall back to the Tcl shell used to run the
tool itself.

[para] Use option [option --shell] to explicitly specify the Tcl shell
to use, like

[example {
  ./sak.tcl test run --shell /path/to/tclsh ...
}]

[comment {===================================================================}]
[subsection Help]

Invoke the tool as

[example {  ./sak.tcl help test }]

to see the detailed help for all methods of [cmd test], and the
associated options.
