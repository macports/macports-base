[comment {-*- mode: tcl ; fill-column: 90 -*-}]
[comment {
    Standard argument types for use with cproc and cclass methods.
}]


Before going into the details first a quick overview:

[include atypes_table.inc]

And now the details:

[list_begin definitions]
[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]

[def Tcl_Interp*]

[strong Attention]: This is a [strong special] argument type. It can
[strong only] be used by the [strong first] argument of a function.
Any other argument using it will cause critcl to throw an error.

[para] When used, the argument will contain a reference to the current
interpreter that the function body may use. Furthermore the argument
will [strong not] be an argument of the Tcl command for the function.

[para] This is useful when the function has to do more than simply
returning a value. Examples would be setting up error messages on
failure, or querying the interpreter for variables and other data.

[def Tcl_Obj*]
[def object]

The function takes an argument of type [type Tcl_Obj*].
No argument checking is done.
The Tcl level word is passed to the argument as-is.

Note that this value must be treated as [strong read-only] (except for
hidden changes to its intrep, i.e. [term shimmering]).

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def pstring]

The function takes an argument of type [type critcl_pstring]
containing the original [type Tcl_Obj*] reference of the Tcl argument,
plus the length of the string and a pointer to the character array.

[example {
typedef struct critcl_pstring {
    Tcl_Obj*    o;
    const char* s;
    int         len;
} critcl_pstring;
}]

Note the [strong const]. The string is [strong read-only]. Any
modification can have arbitrary effects, from pulling out the rug
under the script because of string value and internal representation
not matching anymore, up to crashes anytime later.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def list]
[def {[]}]
[def {[*]}]

The function takes an argument of type [type critcl_list] containing the original [type Tcl_Obj*]
reference of the Tcl argument, plus the length of the Tcl list and a pointer to the array of the
list elements.

[example {
typedef struct critcl_list {
    Tcl_Obj*        o;
    Tcl_Obj* const* v;
    int             c;
} critcl_list;
}]

The Tcl argument must be convertible to [type List], an error is thrown otherwise.

[para] Note the [strong const]. The list is [strong read-only].  Any modification can have arbitrary
effects, from pulling out the rug under the script because of string value and internal
representation not matching anymore, up to crashes anytime later.

[para] Further note that the system understands a number of more complex syntactical forms which all
translate into forms of lists under the hood, as described by the following points.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def {[N]}]

A [term list] type with additional checks limiting the length to [const N], an integer
number greater than zero.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def {[]type}]
[def {type[]}]

A [term list] type whose elements all have to be convertible for [term type]. All known
types, including user-defined, are allowed, except for [type list] and derivates. In other
words, multi-dimensional lists are not supported.

[para] The function will take a structure argument of the general form

[example {
typedef struct critcl_list_... {
    Tcl_Obj* o;
    int      c;
    (Ctype)* v;
} critcl_list_...;
}]

where [const (Ctype)] represents the C type for values of type [type type].

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def {[N]type}]
[def {type[N]}]

These are [type list] types combining the elements of [example {[N]}] and
[example {[]type}].

[para] As an example, the specification of [example {int[3] a}] describes argument [arg a]
as a list of exactly 3 elements, all of which have to be of type [type int].

[para] Note that this example can also be written in the more C-like form of
[example {int a[3]}]. The system will translate this internally to the first shown form.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def bytes]

This is the [emph new] and usable [type ByteArray] type.

[para] The function takes an argument of type [type critcl_bytes]
containing the original [type Tcl_Obj*] reference of the Tcl argument,
plus the length of the byte array and a pointer to the byte data.

[example {
typedef struct critcl_bytes {
    Tcl_Obj*             o;
    const unsigned char* s;
    int                len;
} critcl_list;
}]

The Tcl argument must be convertible to [type ByteArray], an error is
thrown otherwise.

[para] Note the [strong const]. The bytes are [strong read-only].  Any
modification can have arbitrary effects, from pulling out the rug
under the script because of string value and internal representation
not matching anymore, up to crashes anytime later.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def char*]

The function takes an argument of type [type {const char*}].
The string representation of the Tcl argument is passed in.

[para] Note the [strong const]. The string is [strong read-only]. Any
modification can have arbitrary effects, from pulling out the rug
under the script because of string value and internal representation
not matching anymore, up to crashes anytime later.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def double]

The function takes an argument of type [type double].

The Tcl argument must be convertible to [type Double], an error is thrown otherwise.

[def {double > N}]
[def {double >= N}]
[def {double < N}]
[def {double <= N}]

These are variants of [term double] above, restricting the argument value to the shown relation.

An error is thrown for Tcl arguments outside of the specified range.

[para] The limiter [arg N] has to be a constant floating point value.

[para] It is possible to use multiple limiters.

For example [term {double > A > B <= C}].

The system will fuse them to a single upper/lower limit (or both).

[para] The system will reject limits describing an empty range of values, or a range containing only
a single value.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def float]

The function takes an argument of type [type float].

The Tcl argument must be convertible to [type Double], an error is thrown otherwise.

[def {float > N}]
[def {float >= N}]
[def {float < N}]
[def {float <= N}]

These are variants of [term float] above, restricting the argument value to the shown relation.

An error is thrown for Tcl arguments outside of the specified range.

[para] The limiter [arg N] has to be a constant floating point value.

[para] It is possible to use multiple limiters.

For example [term {float > A > B <= C}].

The system will fuse them to a single upper/lower limit (or both).

[para] The system will reject limits describing an empty range of values, or a range containing only
a single value.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def boolean]
[def bool]

The function takes an argument of type [type int].

The Tcl argument must be convertible to [type Boolean], an error is
thrown otherwise.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def channel]

The function takes an argument of type [type Tcl_Channel].

The Tcl argument must be convertible to type [type Channel], an error
is thrown otherwise.

The channel is further assumed to be [strong {already registered}]
with the interpreter.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def unshared-channel]

This type is an extension of [type channel] above.

All of the information above applies.

[para] Beyond that the channel must not be shared by multiple
interpreters, an error is thrown otherwise.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def take-channel]

This type is an extension of [type unshared-channel] above.

All of the information above applies.

[para] Beyond that the code removes the channel from the current
interpreter without closing it, and disables all pre-existing event
handling for it.

[para] With this the function takes full ownership of the channel in
question, taking it away from the interpreter invoking it. It is then
responsible for the lifecycle of the channel, up to and including
closing it.

[para] Should the system the function is a part of wish to return
control of the channel back to the interpeter it then has to use the
result type [type return-channel]. This will undo the registration
changes made by this argument type.

[strong Note] however that the removal of pre-existing event handling
done here cannot be undone.

[para] [strong Attention] Removal from the interpreter without closing
the channel is effected by incrementing the channel's reference count
without providing an interpreter, before decrementing the same for the
current interpreter. This leaves the overall reference count intact
without causing Tcl to close it when it is removed from the
interpreter structures. At this point the channel is effectively a
globally-owned part of the system not associated with any interpreter.

[para] The complementary result type then runs this sequence in
reverse. And if the channel is never returned to Tcl either the
function or the system it is a part of have to unregister the global
reference when they are done with it.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def int]

The function takes an argument of type [type int].

The Tcl argument must be convertible to [type Int], an error is thrown otherwise.

[def {int > N}]
[def {int >= N}]
[def {int < N}]
[def {int <= N}]

These are variants of [term int] above, restricting the argument value to the shown
relation.

An error is thrown for Tcl arguments outside of the specified range.

[para] The limiter [arg N] has to be a constant integer value.

[para] It is possible to use multiple limiters.

For example [term {int > A > B <= C}].

The system will fuse them to a single upper/lower limit (or both).

[para] The system will reject limits describing an empty range of values, or a range
containing only a single value.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def long]

The function takes an argument of type [type {long int}].

The Tcl argument must be convertible to [type Long], an error is thrown otherwise.

[def {long > N}]
[def {long >= N}]
[def {long < N}]
[def {long <= N}]

These are variants of [term long] above, restricting the argument value to the shown
relation.

An error is thrown for Tcl arguments outside of the specified range.

[para] The limiter [arg N] has to be a constant integer value.

[para] It is possible to use multiple limiters.

For example [term {long > A > B <= C}].

The system will fuse them to a single upper/lower limit (or both).

[para] The system will reject limits describing an empty range of values, or a range
containing only a single value.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def wideint]

The function takes an argument of type [type Tcl_WideInt].

The Tcl argument must be convertible to [type WideInt], an error is thrown otherwise.

[def {wideint > N}]
[def {wideint >= N}]
[def {wideint < N}]
[def {wideint <= N}]

These are variants of [term wideint] above, restricting the argument value to the shown
relation.

An error is thrown for Tcl arguments outside of the specified range.

[para] The limiter [arg N] has to be a constant integer value.

[para] It is possible to use multiple limiters.

For example [term {wideint > A > B <= C}].

The system will fuse them to a single upper/lower limit (or both).

[para] The system will reject limits describing an empty range of values, or a range
containing only a single value.

[comment {% % %% %%% %%%%% %%%%%%%% %%%%%%%%%%%%%}]
[def void*]

[list_end]
