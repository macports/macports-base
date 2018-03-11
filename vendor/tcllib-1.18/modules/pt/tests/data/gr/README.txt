This directory contains the test cases for
	pt_pgen.test,
via	tests/pt_pgen.tests

Organization:

* def/<n>_<foo>
	Primary test cases.

Per primary test case FOO we have

* ok-FOO
	Test inputs which result in a sucessful parse.
	We must have files here.

* ok-FOO-res
	Per test input file TIF in ok-FOO we have an associated result
	file here, also named TIF, containing the output of the
	parser, i.e. the generated AST, in raw form, on that input.

* fail-FOO
	Test inputs which result in a failed parse.
	This directory can be empty or missing.
	Because some expressions (X*, X?) cannot fail.

	NOTE: If an expression can fail, please create test cases
	which demonstrate this.

* fail-FOO-<backend>-res
	Per test input file TIF in fail-FOO we have an associated
	result file here, also named TIF, containing the error thrown
	by the parser (implemented via <backend>) on that input.

Possible <backend>s are:

	container	Parser is the PEG interpreter. Plain Tcl,
			possibly accelerated through C-level
			implementations for stacks and the like.

	critcl		Fully C-based parser, embedded in Critcl.

	oo		Premade parser with a Tcl runtime using the
			TclOO object system. Possibly accelerated
			through C-level implementations for stacks and
			the like.

	snit		Premade parser with a Tcl runtime using the
			snit object system. Possibly accelerated
			through C-level implementations for stacks and
			the like.
