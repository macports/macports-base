
Each library [arg FOO] is searched for in the directories listed below, in the order
listed.  The search stops at the first existing path.

Additional notes:

[list_begin itemized]
[item] [var platform] is the placeholder for the target platform of the package.
[item] The extension [file .so] is the placeholder for whatever actual extension is used by the target platform for its shared libraries.
[item] The search is relative to the current working directory.
[list_end]

And now the paths, depending on the exact form of the library name:

[list_begin definitions]
[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[def FOO]
[list_begin enumerated]
[enum] FOO.so
[enum] FOO/FOO.so
[enum] FOO/[var platform]/FOO.so
[list_end]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[def PATH/FOO]
The exact set searched depends on the existence of
directory [file PATH/FOO]. If it exists, critcl searches

[list_begin enumerated]
[enum] FOO.so
[enum] PATH/FOO/FOO.so
[enum] PATH/FOO/[var platform]/FOO.so
[list_end]

Otherwise it searches

[list_begin enumerated]
[enum] FOO.so
[enum] PATH/FOO.so
[enum] PATH/[var platform]/FOO.so
[list_end]

instead.

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[def /PATH/FOO]
Even when specifying FOO with an absolute path the first path searched
is relative to the current working directory.

[list_begin enumerated]
[enum] FOO.so
[enum] /PATH/FOO.so
[enum] /PATH/[var platform]/FOO.so
[list_end]
[list_end]
