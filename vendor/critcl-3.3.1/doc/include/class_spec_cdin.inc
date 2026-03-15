
This section documents the various interactions between the
specification commands. While these are are all documented with the
individual commands here they are pulled together to see at a glance.

[list_begin enum]
[comment {- - -- --- ----- -------- ------------- ---------------------}]

[enum]	If you are using the command [cmd type] to specify an external
	C type to use for the instance structure you are subject to
	the following constraints and rules:

[list_begin enum]
[enum]	You cannot define your own instance variables.
[enum]	You cannot define your own class variables.
[enum]	You cannot use [cmd method_introspection].
[enum]	You have to allocate and release the instance structure on your
	own, through [cmd constructor] and [cmd destructor] code blocks.
[list_end]
[comment {-- type done}]
[comment {- - -- --- ----- -------- ------------- ---------------------}]

[enum]	If you declare class variables you are subject to the
	following constraints and rules:

[list_begin enum]
[enum]	You cannot use [cmd type].
[enum]	The system generates an instance variable [const class] for
	you, which points from instance to class structure. This makes
	you also subject to the rules below, for instance variables.
[list_end]
[comment {-- class variable done}]
[comment {- - -- --- ----- -------- ------------- ---------------------}]

[enum]	If you declare instance variables (possibly automatic, see
	above) you are subject to following constraints and rules:

[list_begin enum]
[enum]	You cannot use [cmd type].
[enum]	The system generates and manages an instance variable
	[const cmd] for you, which holds the Tcl_Command token
	of the instance command.
[enum]	The system generates an instance method [const destroy] for
	you.
[enum]	The system manages allocation and release of the instance
	structure for you. You have to care only about the instance
	variables themselves.
[list_end]
[comment {-- instance variable done}]
[comment {- - -- --- ----- -------- ------------- ---------------------}]

[list_end]
