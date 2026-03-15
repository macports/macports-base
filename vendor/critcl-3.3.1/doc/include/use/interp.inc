[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Reread the example in the [sectref {Errors And Messages} previous] section.

[enum] Note the type [type Tcl_Interp*] used for the first argument.

[enum] This type is special.

[enum] An argument of this type has to be the first argument of a function.

[enum] Using it tells [vset critcl] that the function needs access to the Tcl interpreter
calling it. It then arranges for that to happen in the generated C code.

[para] Using functions from Tcl's public C API taking an interpreter argument in the
function body is a situation where this is needed.

[enum] [emph {This special argument is not visible at the script level}].

[enum] [emph {This special argument is not an argument of the Tcl command for the function}].

[enum] In our example the [cmd sqrt] command is called with a single argument.

[enum] The name of the argument can be freely chosen. It is the type which is important
and triggers the special behaviour.

My prefered names are [var ip] and [var interp].

[list_end]
