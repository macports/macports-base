[section {Changes for version 3.1.16}]
[list_begin enumerated]

[enum] New feature. Extended [cmd critcl::cproc]'s argument handling
       to allow arbitrary mixing of required and optional arguments.

[enum] New feature.
       [emph {Potential Incompatibility}].
[para] Extended [cmd critcl::cproc]'s argument handling to treat an
       argument [const args] as variadic if it is the last argument of
       the procedure.

[enum] New feature. Added two introspection commands,
       [cmd critcl::has-argtype] and [cmd critcl::has-resulttype].
       These enable a user to test if a specific (named) type
       conversion is implemented or not.

[enum] Added new result type [const Tcl_Obj*0], with alias
       [const object0]. The difference to [const Tcl_Obj*] is in
       the reference counting.

[enum] Extended the command [cmd critcl::argtypesupport] with new
       optional argument through which to explicitly specify the
       identifier for guarding against multiple definitions.

[enum] Bugfix: Fixed problem with the implementation of issue #54 (See
       3.1.14). Always create the secondary log file. Otherwise
       end-of-log handling may break, unconditionally assuming its
       existence.

[enum] Bugfix: Fixed problem with the internal change to the hook
       [const HandleDeclAfterBuild]. Corrected the forgotten
       [cmd critcl::cconst].

[enum] Debugging aid: Added comment holding the name of the result
       type when emitting result conversions.

[enum] Bugfix: Fixed issue #60. Unbundled the package directories
       containing multiple packages. All directories under [file lib/]
       now contain exactly one package.

[enum] Bugfix: Fixed issue #62, a few [cmd {dict exists}] commands
       operating on a fixed string instead of a variable.

[enum] Bugfix: Fixed issue #56. Release builders are reminded to run
       the tests.

[enum] Bugfix: Fixed issue #55. For FreeBSD critcl's platform package
       now identifies the Kernel ABI version. Initialization of the
       cache directory now also uses [cmd platform::identify] for the
       default path, instead of [cmd platform::generic].

[enum] Bugfix: Fixed issue #58. Simplified the setup and use of
       md5. CriTcl now makes use of its own package for md5, using
       itself to built it. There is no chicken/egg problem with this
       as the [option -pkg] mode used for this does not use md5. That
       is limited to mode [term {compile & run}].

[list_end]
