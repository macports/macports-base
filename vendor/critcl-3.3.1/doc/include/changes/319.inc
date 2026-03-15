[section {Changes for version 3.1.9}]
[list_begin enumerated]

[enum]	Fixed issue #27. Added missing platform definitions for
	various alternate linux and OS X targets.

[enum]	Fixed issue #28. Added missing -mXX flags for linking at the
	linux-{32,64}-* targets.

[enum]	Fixed issue #29. Replaced the use of raw "cheaders"
	information in the processing of "cdefines" with the proper
	include directives derived from it.

[enum]	Fixed the issue behind rejected pull request #30 by Andrew
	Shadura. Dynamically extract the stubs variable declarations
	from the Tcl header files and generate matching variable
	definitions for use in the package code. The generated code
	will now be always consistent with the headers, even when
	critcl's own copy of them is replaced by system headers.

[enum]	Fixed issue #31. Accepted patch by Andrew Shadura, with
	changes (comments), for easier integration of critcl with
	OS package systems, replacing critcl's copies of Tcl headers
	with their own.

[enum]	Fixed issue #32. Merged pull request by Andrew Shadura.
	Various typos in documentation and comments.

[enum]	Fixed issue #34. Handle files starting with a dot better.

[list_end]
