[comment {-*- mode: tcl ; fill-column: 90 -*-}]

When the set of predefined result types is not enough the oldest way of handling the
situation is falling back to the structures used by Tcl to manage values, i.e.
[type Tcl_Obj*].

[para] Two builtin types are provided for this, to handle different reference counting
requirements.

[list_begin enumerated]

[enum][vset base][example {
    critcl::cproc twice {double x} object0 {
	return Tcl_NewDoubleObj(2*x);
    }
}][vset rebuild]

[enum] With [type object0] the translation layer assumes that the returned [type Tcl_Obj*]
value has a reference count of [const 0]. I.e. a value which is unowned and unshared.

[para] This value is passed directly to Tcl for its use, without any changes. Tcl
increments the reference count and thus takes ownership. The value is still unshared.

[para] It would be extremely detrimental if the translation layer had decremented the
reference count before passing the value. This action would release the memory and then
leave Tcl with a dangling pointer and the associated memory corruption bug to come.

[enum] The situation changes when the C code returns a [type Tcl_Obj*] value with a
reference count greater than [const 0]. I.e. at least owned (by the C code), and possibly
even shared.

There are some object constructors and/or mutators in the public Tcl API which do that,
although I do not recall their names. The example below simulates this situation by
explicitly incrementing the reference count before returning the value.

[enum] In this case use the type [type object] (without the trailing [const 0]).

[enum] Edit the file [file example.tcl] and replace the definition of [cmd twice] with

[example {
    critcl::cproc twice {double x} object {
	Tcl_Obj* result = Tcl_NewDoubleObj(2*x);
	Tcl_IncrRefCount (result);
	return result;
    }
}][vset rebuild]

[enum] After handing the value to Tcl, with the associated incremented reference count,
the translation layer decrements the reference count, invalidating the C code's ownership
and leaving the final reference count the same.

[para] Note, the order matters. If the value has only one reference then decrementing it
before Tcl increments it would again release the value, and again leave Tcl with a
dangling pointer.

[para] Also, not decrementing the reference count at all causes the inverse problem to the
memory corruption issues of before, memory leaks.

[enum] [strong Note] that both types transfer ownership of the value. Their difference is
just in the reference count of the value coming out of the function, and the (non-)actions
having to be (not) taken to effect said transfer without causing memory issues.

[list_end]
