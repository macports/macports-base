[comment {
	 Standard result types for use with
	 cproc and cconst.
}]

Before going into the details first a quick overview:

[include rtypes_table.inc]

And now the details:

[list_begin definitions]
[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def Tcl_Obj*]
[def object]

If the returned [type Tcl_Obj*] is [const NULL], the Tcl return code
is [const TCL_ERROR] and the function should [uri \
	https://www.tcl-lang.org/man/tcl/TclLib/SetResult.htm \
	{set an error mesage}]
as the interpreter result.  Otherwise, the returned [type Tcl_Obj*] is
set as the interpreter result.

[para] Note that setting an error message requires the function body
to have access to the interpreter the function is running in. See the
argument type [type Tcl_Interp*] for the details on how to make that
happen.

[para] Note further that the returned [type Tcl_Obj*] should have a
reference count greater than [const 0]. This is because the converter
decrements the reference count to release possession after setting the
interpreter result. It assumes that the function incremented the
reference count of the returned [type Tcl_Obj*].

If a [type Tcl_Obj*] with a reference count of [const 0] were
returned, the reference count would become [const 1] when set as the
interpreter result, and immediately thereafter be decremented to
[const 0] again, causing the memory to be freed.  The system is then
likely to crash at some point after the return due to reuse of the
freed memory.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def Tcl_Obj*0]
[def object0]

Like [const Tcl_Obj*] except that this conversion assumes that the
returned value has a reference count of [const 0] and
[emph {does not}] decrement it. Returning a value whose reference
count is greater than [const 0] is therefore likely to cause a memory
leak.

[para] Note that setting an error message requires the function body
to have access to the interpreter the function is running in. See the
argument type [type Tcl_Interp*] for the details on how to make that
happen.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def new-channel]

A [type String] Tcl_Obj holding the name of the returned
[type Tcl_Channel] is set as the interpreter result.

The channel is further assumed to be [strong new], and therefore
registered with the interpreter to make it known.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def known-channel]

A [type String] Tcl_Obj holding the name of the returned
[type Tcl_Channel] is set as the interpreter result.

The channel is further assumed to be [strong {already registered}]
with the interpreter.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def return-channel]

This type is a variant of [type new-channel] above.

It varies slightly from it in the registration sequence to be properly
complementary to the argument type [type take-channel].


A [type String] Tcl_Obj holding the name of the returned
[type Tcl_Channel] is set as the interpreter result.

The channel is further assumed to be [strong new], and therefore
registered with the interpreter to make it known.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def char*]
[def vstring]

A [type String] Tcl_Obj holding a [strong copy] of the returned
[type char*] is set as the interpreter result. If the value is
allocated then the function itself and the extension it is a part of
are responsible for releasing the memory when the data is not in use
any longer.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def {const char*}]

Like [const char*] above, except that the returned string is
[const const]-qualified.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def string]
[def dstring]

The returned [type char*] is directly set as the interpreter result
[strong {without making a copy}].  Therefore it must be dynamically
allocated via [fun Tcl_Alloc]. Release happens automatically when the
Interpreter finds that the value is not required any longer.


[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def double]
[def float]

The returned [type double] or [type float] is converted to a [type Double]
Tcl_Obj and set as the interpreter result.


[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def boolean]
[def bool]

The returned [type int] value is converted to an [type Int] Tcl_Obj and set as
the interpreter result.


[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def int]

The returned [type int] value is converted to an [type Int] Tcl_Obj and set as
the interpreter result.


[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def long]

The returned [type {long int}] value is converted to a [type Long] Tcl_Obj and
set as the interpreter result.


[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def wideint]

The returned [type Tcl_WideInt] value is converted to a [type WideInt] Tcl_Obj
and set as the interpreter result.


[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def ok]

The returned [type int] value becomes the Tcl return code.

The interpreter result is left untouched and can be set by the
function if desired. Note that doing this requires the function body
to have access to the interpreter the function is running in. See the
argument type [type Tcl_Interp*] for the details on how to make that
happen.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def void]

The function does not return a value.

The interpreter result is left untouched and can be set by the function if
desired.

[list_end]
