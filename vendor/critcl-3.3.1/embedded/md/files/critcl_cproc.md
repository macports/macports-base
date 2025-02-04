
[//000000001]: # (critcl\_cproc\_types \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_cproc\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_cproc\_types\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_cproc\_types \- CriTcl cproc Type Reference

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Standard argument types](#section2)

  - [Standard result types](#section3)

  - [Advanced: Adding types](#section4)

  - [Examples](#section5)

      - [A Simple Procedure](#subsection1)

      - [More Builtin Types: Strings](#subsection2)

      - [Custom Types, Introduction](#subsection3)

      - [Custom Types, Semi\-trivial](#subsection4)

      - [Custom Types, Support structures](#subsection5)

      - [Custom Types, Results](#subsection6)

  - [Authors](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require critcl ?3\.3\.1?  

[__::critcl::has\-resulttype__ *name*](#1)  
[__::critcl::resulttype__ *name* *body* ?*ctype*?](#2)  
[__::critcl::resulttype__ *name* __=__ *origname*](#3)  
[__::critcl::has\-argtype__ *name*](#4)  
[__::critcl::argtype__ *name* *body* ?*ctype*? ?*ctypefun*?](#5)  
[__::critcl::argtype__ *name* __=__ *origname*](#6)  
[__::critcl::argtypesupport__ *name* *code* ?*guard*?](#7)  
[__::critcl::argtyperelease__ *name* *code*](#8)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is a breakout of the descriptions for the predefined argument\- and
result\-types usable with the __critcl::cproc__ command, as detailed in the
reference manpage for the __[critcl](critcl\.md)__ package, plus the
information on how to extend the predefined set with custom types\. The breakout
was made to make this information easier to find \(toplevel document vs\. having
to search the large main reference\)\.

Its intended audience are developers wishing to write Tcl packages with embedded
C code\.

# <a name='section2'></a>Standard argument types

Before going into the details first a quick overview:

> CriTcl type      &#124; C type         &#124; Tcl type  &#124; Notes  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> Tcl\_Interp\*      &#124; Tcl\_Interp\*    &#124; n/a       &#124; *Special*, only first  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> Tcl\_Obj\*         &#124; Tcl\_Obj\*       &#124; Any       &#124; *Read\-only*  
> object           &#124;                &#124;           &#124; Alias of __Tcl\_Obj\*__ above  
> list             &#124; critcl\_list    &#124; List      &#124; *Read\-only*  
> \[\], \[\*\]          &#124;                &#124;           &#124; Alias of __list__ above  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> \[N\]              &#124;                &#124;           &#124; Restricted __list__\-types\.  
> type\[\], type\[N\]  &#124;                &#124;           &#124; Length\-limited \(\[\.\.\]\), expected  
> \[\]type, \[N\]type  &#124;                &#124;           &#124; element type, or both\.  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124;  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; Element types can be all known argument  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; types, except for any kind of list\.  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; IOW multi\-dimensional lists are not  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; supported\.  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> char\*            &#124; const char\*    &#124; Any       &#124; *Read\-only*, *string rep*  
> pstring          &#124; critcl\_pstring &#124; Any       &#124; *Read\-only*  
> bytes            &#124; critcl\_bytes   &#124; ByteArray &#124; *Read\-only*  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> int              &#124; int            &#124; Int       &#124;  
> long             &#124; long           &#124; Long      &#124;  
> wideint          &#124; Tcl\_WideInt    &#124; WideInt   &#124;  
> double           &#124; double         &#124; Double    &#124;  
> float            &#124; float          &#124; Double    &#124;  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> X > N            &#124;                &#124;           &#124; For X in __int__ \.\.\. __float__ above\.  
> X >= N           &#124;                &#124;           &#124; The C types are as per the base type X\.  
> X < N            &#124;                &#124;           &#124; N, A, B are expected to be constant integer  
> X <= N           &#124;                &#124;           &#124; numbers for types __int__, __long__,  
> X > A < B        &#124;                &#124;           &#124; and __wideint__\. For types __double__  
> etc\.             &#124;                &#124;           &#124; and __float__ the N, A, and B can be floating  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; point numbers\. Multiple restrictions are  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; fused as much as possible to yield at most  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; both upper and lower limits\.  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> boolean          &#124; int            &#124; Boolean   &#124;  
> bool             &#124;                &#124;           &#124; Alias of __boolean__ above  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> channel          &#124; Tcl\_Channel    &#124; String    &#124; Assumed to be registered  
> unshared\-channel &#124; Tcl\_Channel    &#124; String    &#124; As above, limited to current interpreter  
> take\-channel     &#124; Tcl\_Channel    &#124; String    &#124; As above, C code takes ownership

And now the details:

  - Tcl\_Interp\*

    *Attention*: This is a *special* argument type\. It can *only* be used
    by the *first* argument of a function\. Any other argument using it will
    cause critcl to throw an error\.

    When used, the argument will contain a reference to the current interpreter
    that the function body may use\. Furthermore the argument will *not* be an
    argument of the Tcl command for the function\.

    This is useful when the function has to do more than simply returning a
    value\. Examples would be setting up error messages on failure, or querying
    the interpreter for variables and other data\.

  - Tcl\_Obj\*

  - object

    The function takes an argument of type __Tcl\_Obj\*__\. No argument
    checking is done\. The Tcl level word is passed to the argument as\-is\. Note
    that this value must be treated as *read\-only* \(except for hidden changes
    to its intrep, i\.e\. *shimmering*\)\.

  - pstring

    The function takes an argument of type __critcl\_pstring__ containing the
    original __Tcl\_Obj\*__ reference of the Tcl argument, plus the length of
    the string and a pointer to the character array\.

        typedef struct critcl_pstring {
            Tcl_Obj*    o;
            const char* s;
            int         len;
        } critcl_pstring;

    Note the *const*\. The string is *read\-only*\. Any modification can have
    arbitrary effects, from pulling out the rug under the script because of
    string value and internal representation not matching anymore, up to crashes
    anytime later\.

  - list

  - \[\]

  - \[\*\]

    The function takes an argument of type __critcl\_list__ containing the
    original __Tcl\_Obj\*__ reference of the Tcl argument, plus the length of
    the Tcl list and a pointer to the array of the list elements\.

        typedef struct critcl_list {
            Tcl_Obj*        o;
            Tcl_Obj* const* v;
            int             c;
        } critcl_list;

    The Tcl argument must be convertible to __List__, an error is thrown
    otherwise\.

    Note the *const*\. The list is *read\-only*\. Any modification can have
    arbitrary effects, from pulling out the rug under the script because of
    string value and internal representation not matching anymore, up to crashes
    anytime later\.

    Further note that the system understands a number of more complex
    syntactical forms which all translate into forms of lists under the hood, as
    described by the following points\.

  - \[N\]

    A *list* type with additional checks limiting the length to __N__, an
    integer number greater than zero\.

  - \[\]type

  - type\[\]

    A *list* type whose elements all have to be convertible for *type*\. All
    known types, including user\-defined, are allowed, except for __list__
    and derivates\. In other words, multi\-dimensional lists are not supported\.

    The function will take a structure argument of the general form

        typedef struct critcl_list_... {
            Tcl_Obj* o;
            int      c;
            (Ctype)* v;
        } critcl_list_...;

    where __\(Ctype\)__ represents the C type for values of type __type__\.

  - \[N\]type

  - type\[N\]

    These are __list__ types combining the elements of

        [N]

    and

        []type

    \.

    As an example, the specification of

        int[3] a

    describes argument *a* as a list of exactly 3 elements, all of which have
    to be of type __int__\.

    Note that this example can also be written in the more C\-like form of

        int a[3]

    \. The system will translate this internally to the first shown form\.

  - bytes

    This is the *new* and usable __ByteArray__ type\.

    The function takes an argument of type __critcl\_bytes__ containing the
    original __Tcl\_Obj\*__ reference of the Tcl argument, plus the length of
    the byte array and a pointer to the byte data\.

        typedef struct critcl_bytes {
            Tcl_Obj*             o;
            const unsigned char* s;
            int                len;
        } critcl_list;

    The Tcl argument must be convertible to __ByteArray__, an error is
    thrown otherwise\.

    Note the *const*\. The bytes are *read\-only*\. Any modification can have
    arbitrary effects, from pulling out the rug under the script because of
    string value and internal representation not matching anymore, up to crashes
    anytime later\.

  - char\*

    The function takes an argument of type __const char\*__\. The string
    representation of the Tcl argument is passed in\.

    Note the *const*\. The string is *read\-only*\. Any modification can have
    arbitrary effects, from pulling out the rug under the script because of
    string value and internal representation not matching anymore, up to crashes
    anytime later\.

  - double

    The function takes an argument of type __double__\. The Tcl argument must
    be convertible to __Double__, an error is thrown otherwise\.

  - double > N

  - double >= N

  - double < N

  - double <= N

    These are variants of *double* above, restricting the argument value to
    the shown relation\. An error is thrown for Tcl arguments outside of the
    specified range\.

    The limiter *N* has to be a constant floating point value\.

    It is possible to use multiple limiters\. For example *double > A > B <=
    C*\. The system will fuse them to a single upper/lower limit \(or both\)\.

    The system will reject limits describing an empty range of values, or a
    range containing only a single value\.

  - float

    The function takes an argument of type __float__\. The Tcl argument must
    be convertible to __Double__, an error is thrown otherwise\.

  - float > N

  - float >= N

  - float < N

  - float <= N

    These are variants of *float* above, restricting the argument value to the
    shown relation\. An error is thrown for Tcl arguments outside of the
    specified range\.

    The limiter *N* has to be a constant floating point value\.

    It is possible to use multiple limiters\. For example *float > A > B <= C*\.
    The system will fuse them to a single upper/lower limit \(or both\)\.

    The system will reject limits describing an empty range of values, or a
    range containing only a single value\.

  - boolean

  - bool

    The function takes an argument of type __int__\. The Tcl argument must be
    convertible to __Boolean__, an error is thrown otherwise\.

  - channel

    The function takes an argument of type __Tcl\_Channel__\. The Tcl argument
    must be convertible to type __Channel__, an error is thrown otherwise\.
    The channel is further assumed to be *already registered* with the
    interpreter\.

  - unshared\-channel

    This type is an extension of __channel__ above\. All of the information
    above applies\.

    Beyond that the channel must not be shared by multiple interpreters, an
    error is thrown otherwise\.

  - take\-channel

    This type is an extension of __unshared\-channel__ above\. All of the
    information above applies\.

    Beyond that the code removes the channel from the current interpreter
    without closing it, and disables all pre\-existing event handling for it\.

    With this the function takes full ownership of the channel in question,
    taking it away from the interpreter invoking it\. It is then responsible for
    the lifecycle of the channel, up to and including closing it\.

    Should the system the function is a part of wish to return control of the
    channel back to the interpeter it then has to use the result type
    __return\-channel__\. This will undo the registration changes made by this
    argument type\. *Note* however that the removal of pre\-existing event
    handling done here cannot be undone\.

    *Attention* Removal from the interpreter without closing the channel is
    effected by incrementing the channel's reference count without providing an
    interpreter, before decrementing the same for the current interpreter\. This
    leaves the overall reference count intact without causing Tcl to close it
    when it is removed from the interpreter structures\. At this point the
    channel is effectively a globally\-owned part of the system not associated
    with any interpreter\.

    The complementary result type then runs this sequence in reverse\. And if the
    channel is never returned to Tcl either the function or the system it is a
    part of have to unregister the global reference when they are done with it\.

  - int

    The function takes an argument of type __int__\. The Tcl argument must be
    convertible to __Int__, an error is thrown otherwise\.

  - int > N

  - int >= N

  - int < N

  - int <= N

    These are variants of *int* above, restricting the argument value to the
    shown relation\. An error is thrown for Tcl arguments outside of the
    specified range\.

    The limiter *N* has to be a constant integer value\.

    It is possible to use multiple limiters\. For example *int > A > B <= C*\.
    The system will fuse them to a single upper/lower limit \(or both\)\.

    The system will reject limits describing an empty range of values, or a
    range containing only a single value\.

  - long

    The function takes an argument of type __long int__\. The Tcl argument
    must be convertible to __Long__, an error is thrown otherwise\.

  - long > N

  - long >= N

  - long < N

  - long <= N

    These are variants of *long* above, restricting the argument value to the
    shown relation\. An error is thrown for Tcl arguments outside of the
    specified range\.

    The limiter *N* has to be a constant integer value\.

    It is possible to use multiple limiters\. For example *long > A > B <= C*\.
    The system will fuse them to a single upper/lower limit \(or both\)\.

    The system will reject limits describing an empty range of values, or a
    range containing only a single value\.

  - wideint

    The function takes an argument of type __Tcl\_WideInt__\. The Tcl argument
    must be convertible to __WideInt__, an error is thrown otherwise\.

  - wideint > N

  - wideint >= N

  - wideint < N

  - wideint <= N

    These are variants of *wideint* above, restricting the argument value to
    the shown relation\. An error is thrown for Tcl arguments outside of the
    specified range\.

    The limiter *N* has to be a constant integer value\.

    It is possible to use multiple limiters\. For example *wideint > A > B <=
    C*\. The system will fuse them to a single upper/lower limit \(or both\)\.

    The system will reject limits describing an empty range of values, or a
    range containing only a single value\.

  - void\*

# <a name='section3'></a>Standard result types

Before going into the details first a quick overview:

> CriTcl type    &#124; C type         &#124; Tcl type  &#124; Notes  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> void           &#124; n/a            &#124; n/a       &#124; Always OK\. Body sets result  
> ok             &#124; int            &#124; n/a       &#124; Result code\. Body sets result  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> int            &#124; int            &#124; Int       &#124;  
> boolean        &#124;                &#124;           &#124; Alias of __int__ above  
> bool           &#124;                &#124;           &#124; Alias of __int__ above  
> long           &#124; long           &#124; Long      &#124;  
> wideint        &#124; Tcl\_WideInt    &#124; WideInt   &#124;  
> double         &#124; double         &#124; Double    &#124;  
> float          &#124; float          &#124; Double    &#124;  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> char\*          &#124; char\*          &#124; String    &#124; *Makes a copy*  
> vstring        &#124;                &#124;           &#124; Alias of __char\*__ above  
> const char\*    &#124; const char\*    &#124;           &#124; Behavior of __char\*__ above  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> string         &#124;                &#124; String    &#124; Freeable string set directly  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; *No copy is made*  
> dstring        &#124;                &#124;           &#124; Alias of __string__ above  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; For all below: Null is ERROR  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; Body has to set any message  
> Tcl\_Obj\*       &#124; Tcl\_Obj\*       &#124; Any       &#124; *refcount \-\-*  
> object         &#124;                &#124;           &#124; Alias of __Tcl\_Obj\*__ above  
> Tcl\_Obj\*0      &#124;                &#124; Any       &#124; *refcount unchanged*  
> object0        &#124;                &#124;           &#124; Alias of __Tcl\_Obj\*0__ above  
> \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> known\-channel  &#124; Tcl\_Channel    &#124; String    &#124; Assumes to already be registered  
> new\-channel    &#124; Tcl\_Channel    &#124; String    &#124; New channel, will be registered  
> return\-channel &#124; Tcl\_Channel    &#124; String    &#124; Inversion of take\-channel

And now the details:

  - Tcl\_Obj\*

  - object

    If the returned __Tcl\_Obj\*__ is __NULL__, the Tcl return code is
    __TCL\_ERROR__ and the function should [set an error
    mesage](https://www\.tcl\-lang\.org/man/tcl/TclLib/SetResult\.htm) as the
    interpreter result\. Otherwise, the returned __Tcl\_Obj\*__ is set as the
    interpreter result\.

    Note that setting an error message requires the function body to have access
    to the interpreter the function is running in\. See the argument type
    __Tcl\_Interp\*__ for the details on how to make that happen\.

    Note further that the returned __Tcl\_Obj\*__ should have a reference
    count greater than __0__\. This is because the converter decrements the
    reference count to release possession after setting the interpreter result\.
    It assumes that the function incremented the reference count of the returned
    __Tcl\_Obj\*__\. If a __Tcl\_Obj\*__ with a reference count of __0__
    were returned, the reference count would become __1__ when set as the
    interpreter result, and immediately thereafter be decremented to __0__
    again, causing the memory to be freed\. The system is then likely to crash at
    some point after the return due to reuse of the freed memory\.

  - Tcl\_Obj\*0

  - object0

    Like __Tcl\_Obj\*__ except that this conversion assumes that the returned
    value has a reference count of __0__ and *does not* decrement it\.
    Returning a value whose reference count is greater than __0__ is
    therefore likely to cause a memory leak\.

    Note that setting an error message requires the function body to have access
    to the interpreter the function is running in\. See the argument type
    __Tcl\_Interp\*__ for the details on how to make that happen\.

  - new\-channel

    A __String__ Tcl\_Obj holding the name of the returned
    __Tcl\_Channel__ is set as the interpreter result\. The channel is further
    assumed to be *new*, and therefore registered with the interpreter to make
    it known\.

  - known\-channel

    A __String__ Tcl\_Obj holding the name of the returned
    __Tcl\_Channel__ is set as the interpreter result\. The channel is further
    assumed to be *already registered* with the interpreter\.

  - return\-channel

    This type is a variant of __new\-channel__ above\. It varies slightly from
    it in the registration sequence to be properly complementary to the argument
    type __take\-channel__\. A __String__ Tcl\_Obj holding the name of the
    returned __Tcl\_Channel__ is set as the interpreter result\. The channel
    is further assumed to be *new*, and therefore registered with the
    interpreter to make it known\.

  - char\*

  - vstring

    A __String__ Tcl\_Obj holding a *copy* of the returned __char\*__ is
    set as the interpreter result\. If the value is allocated then the function
    itself and the extension it is a part of are responsible for releasing the
    memory when the data is not in use any longer\.

  - const char\*

    Like __char\*__ above, except that the returned string is
    __const__\-qualified\.

  - string

  - dstring

    The returned __char\*__ is directly set as the interpreter result
    *without making a copy*\. Therefore it must be dynamically allocated via
    __Tcl\_Alloc__\. Release happens automatically when the Interpreter finds
    that the value is not required any longer\.

  - double

  - float

    The returned __double__ or __float__ is converted to a
    __Double__ Tcl\_Obj and set as the interpreter result\.

  - boolean

  - bool

    The returned __int__ value is converted to an __Int__ Tcl\_Obj and
    set as the interpreter result\.

  - int

    The returned __int__ value is converted to an __Int__ Tcl\_Obj and
    set as the interpreter result\.

  - long

    The returned __long int__ value is converted to a __Long__ Tcl\_Obj
    and set as the interpreter result\.

  - wideint

    The returned __Tcl\_WideInt__ value is converted to a __WideInt__
    Tcl\_Obj and set as the interpreter result\.

  - ok

    The returned __int__ value becomes the Tcl return code\. The interpreter
    result is left untouched and can be set by the function if desired\. Note
    that doing this requires the function body to have access to the interpreter
    the function is running in\. See the argument type __Tcl\_Interp\*__ for
    the details on how to make that happen\.

  - void

    The function does not return a value\. The interpreter result is left
    untouched and can be set by the function if desired\.

# <a name='section4'></a>Advanced: Adding types

While the __critcl::cproc__ command understands the most common C types \(as
per the previous 2 sections\), sometimes this is not enough\.

To get around this limitation the commands in this section enable users of
__[critcl](critcl\.md)__ to extend the set of argument and result types
understood by __critcl::cproc__\. In other words, they allow them to define
their own, custom, types\.

  - <a name='1'></a>__::critcl::has\-resulttype__ *name*

    This command tests if the named result\-type is known or not\. It returns a
    boolean value, __true__ if the type is known and __false__
    otherwise\.

  - <a name='2'></a>__::critcl::resulttype__ *name* *body* ?*ctype*?

    This command defines the result type *name*, and associates it with the C
    code doing the conversion \(*body*\) from C to Tcl\. The C return type of the
    associated function, also the C type of the result variable, is *ctype*\.
    This type defaults to *name* if it is not specified\.

    If *name* is already declared an error is thrown\. *Attention\!* The
    standard result type __void__ is special as it has no accompanying
    result variable\. This cannot be expressed by this extension command\.

    The *body*'s responsibility is the conversion of the functions result into
    a Tcl result and a Tcl status\. The first has to be set into the interpreter
    we are in, and the second has to be returned\.

    The C code of *body* is guaranteed to be called last in the wrapper around
    the actual implementation of the __cproc__ in question and has access to
    the following environment:

      * __interp__

        A Tcl\_Interp\* typed C variable referencing the interpreter the result
        has to be stored into\.

      * __rv__

        The C variable holding the result to convert, of type *ctype*\.

    As examples here are the definitions of two standard result types:

            resulttype int {
        	Tcl_SetObjResult(interp, Tcl_NewIntObj(rv));
        	return TCL_OK;
            }

            resulttype ok {
        	/* interp result must be set by cproc body */
        	return rv;
            } int

  - <a name='3'></a>__::critcl::resulttype__ *name* __=__ *origname*

    This form of the __resulttype__ command declares *name* as an alias of
    result type *origname*, which has to be defined already\. If this is not
    the case an error is thrown\.

  - <a name='4'></a>__::critcl::has\-argtype__ *name*

    This command tests if the named argument\-type is known or not\. It returns a
    boolean value, __true__ if the type is known and __false__
    otherwise\.

  - <a name='5'></a>__::critcl::argtype__ *name* *body* ?*ctype*? ?*ctypefun*?

    This command defines the argument type *name*, and associates it with the
    C code doing the conversion \(*body*\) from Tcl to C\. *ctype* is the C
    type of the variable to hold the conversion result and *ctypefun* is the
    type of the function argument itself\. Both types default to *name* if they
    are the empty string or are not provided\.

    If *name* is already declared an error is thrown\.

    *body* is a C code fragment that converts a Tcl\_Obj\* into a C value which
    is stored in a helper variable in the underlying function\.

    *body* is called inside its own code block to isolate local variables, and
    the following items are in scope:

      * __interp__

        A variable of type __Tcl\_Interp\*__ which is the interpreter the code
        is running in\.

      * __@@__

        A placeholder for an expression that evaluates to the __Tcl\_Obj\*__
        to convert\.

      * __@A__

        A placeholder for the name of the variable to store the converted
        argument into\.

    As examples, here are the definitions of two standard argument types:

            argtype int {
        	if (Tcl_GetIntFromObj(interp, @@, &@A) != TCL_OK) return TCL_ERROR;
            }

            argtype float {
        	double t;
        	if (Tcl_GetDoubleFromObj(interp, @@, &t) != TCL_OK) return TCL_ERROR;
        	@A = (float) t;
            }

  - <a name='6'></a>__::critcl::argtype__ *name* __=__ *origname*

    This form of the __argtype__ command declares *name* as an alias of
    argument type *origname*, which has to be defined already\. If this is not
    the case an error is thrown\.

  - <a name='7'></a>__::critcl::argtypesupport__ *name* *code* ?*guard*?

    This command defines a C code fragment for the already defined argument type
    *name* which is inserted before all functions using that type\. Its purpose
    is the definition of any supporting C types needed by the argument type\. If
    the type is used by many functions the system ensures that only the first of
    the multiple insertions of the code fragment is active, and the others
    disabled\. The guard identifier is normally derived from *name*, but can
    also be set explicitly, via *guard*\. This latter allows different custom
    types to share a common support structure without having to perform their
    own guarding\.

  - <a name='8'></a>__::critcl::argtyperelease__ *name* *code*

    This command defines a C code fragment for the already defined argument type
    *name* which is inserted whenever the worker function of a
    __critcl::cproc__ returns to the shim\. It is the responsibility of this
    fragment to unconditionally release any resources the
    __critcl::argtype__ conversion code allocated\. An example of this are
    the *variadic* types for the support of the special, variadic *args*
    argument to __critcl::cproc__'s\. They allocate a C array for the
    collected arguments which has to be released when the worker returns\. This
    command defines the C code for doing that\.

# <a name='section5'></a>Examples

The examples shown here have been drawn from the section "Embedding C" in the
document about *Using CriTcl*\. Please see that document for many more
examples\.

## <a name='subsection1'></a>A Simple Procedure

Starting simple, let us assume that the Tcl code in question is something like

    proc math {x y z} {
        return [expr {(sin($x)*rand())/$y**log($z)}]
    }

with the expression pretending to be something very complex and slow\. Converting
this to C we get:

    critcl::cproc math {double x double y double z} double {
        double up   = rand () * sin (x);
        double down = pow(y, log (z));
        return up/down;
    }

Notable about this translation:

  1. All the arguments got type information added to them, here "double"\. Like
     in C the type precedes the argument name\. Other than that it is pretty much
     a Tcl dictionary, with keys and values swapped\.

  1. We now also have to declare the type of the result, here "double", again\.

  1. The reference manpage lists all the legal C types supported as arguments
     and results\.

While the above example was based on type __double__ for both arguments and
result we have a number of additional types in the same category, i\.e\. simple
types\. These are:

> CriTcl type &#124; C type         &#124; Tcl type  &#124; Notes  
> \-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> bool        &#124;                &#124;           &#124; Alias of __boolean__ below  
> boolean     &#124; int            &#124; Boolean   &#124;  
> double      &#124; double         &#124; Double    &#124;  
> float       &#124; float          &#124; Double    &#124;  
> int         &#124; int            &#124; Int       &#124;  
> long        &#124; long           &#124; Long      &#124;  
> wideint     &#124; Tcl\_WideInt    &#124; WideInt   &#124;

A slightly advanced form of these simple types are a limited set of constraints
on the argument value\. Note that __bool__ and alias do not support this\.

    critcl::cproc sqrt {{double >= 0} x} double {
        return sqrt(x);
    }

In the example above CriTcl's argument handling will reject calling the command
with a negative number, without ever invoking the C code\.

These constraints are called *limited* because only __0__ and __1__
can be used as the borders, although all the operators __<__, __<=__,
__>__, and __>=__ are possible\. It is also not possible to combine
restrictions\.

## <a name='subsection2'></a>More Builtin Types: Strings

Given that "Everything is a String" is a slogan of Tcl the ability of
__cproc__s to receive strings as arguments, and return them as results is
quite important\.

We actually have a variety of builtin string types, all alike, yet different\.

For arguments we have:

> CriTcl type &#124; C type         &#124; Tcl type  &#124; Notes  
> \-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> char\*       &#124; const char\*    &#124; Any       &#124; *Read\-only*, *string rep*  
> pstring     &#124; critcl\_pstring &#124; Any       &#124; *Read\-only*  
> bytes       &#124; critcl\_bytes   &#124; ByteArray &#124; *Read\-only*

In C

        critcl::cproc takeStrings {
            char*   cstring
    	pstring pstring
    	bytes   barray
        } void {
            printf ("len %d = %s\n", strlen(cstring), cstring);
    	printf ("len %d = %s\n", pstring.len, pstring.s);
    	printf ("len %d = %s\n", barray.len, barray.s);
            return; // void result, no result
        }

Notable about the above:

  1. The __cstring__ is a plain __const char\*__\. It *points directly*
     into the __Tcl\_Obj\*__ holding the argument in the script\.

  1. The __pstring__ is a slight extension to that\. The value is actually a
     structure containing the string pointer like __cstring__ \(field
     __\.s__\), the length of the string \(field __\.len__\), and a pointer
     to the __Tcl\_Obj\*__ these came from\.

  1. The last, __barray__ is like __pstring__, however it has ensured
     that the __Tcl\_Obj\*__ is a Tcl ByteArray, i\.e\. binary data\.

Treat all of them as *Read Only*\. Do not modify ever\.

On the other side, string results, we have:

> CriTcl type   &#124; C type         &#124; Tcl type  &#124; Notes  
> \-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> char\*         &#124; char\*          &#124; String    &#124; *Makes a copy*  
> vstring       &#124;                &#124;           &#124; Alias of __char\*__ above  
> const char\*   &#124; const char\*    &#124;           &#124; Behavior of __char\*__ above  
> \-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\- &#124; \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> string        &#124; char\*          &#124; String    &#124; Freeable string set directly  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124;                &#124;           &#124; *No copy is made*  
> dstring       &#124;                &#124;           &#124; Alias of __string__ above

        critcl::cproc returnCString {} char* {
            return "a string";
        }
        critcl::cproc returnString {} string {
            char* str = Tcl_Alloc (200);
    	sprintf (str, "hello world");
            return str;
        }

Notable about the above:

  1. The type __char\*__ is best used for static strings, or strings in some
     kind fixed buffer\.

     CriTcl's translation layer makes a copy of it for the result of the
     command\. While it is possible to return heap\-allocated strings it is the C
     code who is responsible for freeing such at some point\. If that is not done
     they will leak\.

  1. The type __string__ on the other hand is exactly for returning strings
     allocated with __Tcl\_Alloc__ and associates\.

     For these the translation layer makes no copy at all, and sets them
     directly as the result of the command\. A *very important effect* of this
     is that the ownership of the string pointer moves from the function to Tcl\.

     *Tcl* will release the allocated memory when it does not need it any
     longer\. The C code has no say in that\.

## <a name='subsection3'></a>Custom Types, Introduction

When writing bindings to external libraries __critcl::cproc__ is usually the
most convenient way of writing the lower layers\. This is however hampered by the
fact that critcl on its own only supports a few standard \(arguably the most
import\) standard types, whereas the functions we wish to bind most certainly
will use much more, specific to the library's function\.

The critcl commands __argtype__, __resulttype__ and their adjuncts are
provided to help here, by allowing a developer to extend critcl's type system
with custom conversions\.

This and the three following sections will demonstrate this, from trivial to
complex\.

The most trivial use is to create types which are aliases of existing types,
standard or other\. As an alias it simply copies and uses the conversion code
from the referenced types\.

Our example is pulled from an incomplete project of mine, a binding to *Jeffrey
Kegler*'s *libmarpa* library managing Earley parsers\. Several custom types
simply reflect the typedef's done by the library, to make the
__critcl::cproc__s as self\-documenting as the underlying library functions
themselves\.

    critcl::argtype Marpa_Symbol_ID     = int
    critcl::argtype Marpa_Rule_ID       = int
    critcl::argtype Marpa_Rule_Int      = int
    critcl::argtype Marpa_Rank          = int
    critcl::argtype Marpa_Earleme       = int
    critcl::argtype Marpa_Earley_Set_ID = int

    ...

    method sym-rank: proc {
        Marpa_Symbol_ID sym
        Marpa_Rank      rank
    } Marpa_Rank {
        return marpa_g_symbol_rank_set (instance->grammar, sym, rank);
    }

    ...

## <a name='subsection4'></a>Custom Types, Semi\-trivial

A more involved custom argument type would be to map from Tcl strings to some
internal representation, like an integer code\.

The first example is taken from the __tclyaml__ package, a binding to the
__libyaml__ library\. In a few places we have to map readable names for block
styles, scalar styles, etc\. to the internal enumeration\.

    critcl::argtype yaml_sequence_style_t {
        if (!encode_sequence_style (interp, @@, &@A)) return TCL_ERROR;
    }

    ...

    critcl::ccode {
        static const char* ty_block_style_names [] = {
            "any", "block", "flow", NULL
        };

        static int
        encode_sequence_style (Tcl_Interp* interp, Tcl_Obj* style,
                               yaml_sequence_style_t* estyle)
        {
            int value;
            if (Tcl_GetIndexFromObj (interp, style, ty_block_style_names,
                                     "sequence style", 0, &value) != TCL_OK) {
                return 0;
            }
            *estyle = value;
            return 1;
        }
    }

    ...

    method sequence_start proc {
        pstring anchor
        pstring tag
        int implicit
        yaml_sequence_style_t style
    } ok {
        /* Syntax: <instance> seq_start <anchor> <tag> <implicit> <style> */
        ...
    }

    ...

It should be noted that this code precedes the advent of the supporting
generator package __[critcl::emap](critcl\_emap\.md)__\. using the
generator the definition of the mapping becomes much simpler:

    critcl::emap::def yaml_sequence_style_t {
        any   0
        block 1
        flow  2
    }

Note that the generator will not only provide the conversions, but also define
the argument and result types needed for their use by __critcl::cproc__\.
Another example of such a semi\-trivial argument type can be found in the
__CRIMP__ package, which defines a __Tcl\_ObjType__ for *image* values\.
This not only provides a basic argument type for any image, but also derived
types which check that the image has a specific format\. Here we see for the
first time non\-integer arguments, and the need to define the C types used for
variables holding the C level value, and the type of function parameters \(Due to
C promotion rules we may need different types\)\.

    critcl::argtype image {
        if (crimp_get_image_from_obj (interp, @@, &@A) != TCL_OK) {
            return TCL_ERROR;
        }
    } crimp_image* crimp_image*

    ...

        set map [list <<type>> $type]
        critcl::argtype image_$type [string map $map {
            if (crimp_get_image_from_obj (interp, @@, &@A) != TCL_OK) {
                return TCL_ERROR;
            }
            if (@A->itype != crimp_imagetype_find ("crimp::image::<<type>>")) {
                Tcl_SetObjResult (interp,
                                  Tcl_NewStringObj ("expected image type <<type>>",
                                                    -1));
                return TCL_ERROR;
            }
        }] crimp_image* crimp_image*

    ...

## <a name='subsection5'></a>Custom Types, Support structures

The adjunct command __critcl::argtypesupport__ is for when the conversion
needs additional definitions, for example a helper structure\.

An example of this can be found among the standard types of critcl itself, the
__pstring__ type\. This type provides the C function with not only the string
pointer, but also the string length, and the __Tcl\_Obj\*__ this data came
from\. As __critcl::cproc__'s calling conventions allow us only one argument
for the data of the parameter a structure is needed to convey these three pieces
of information\.

Thus the argument type is defined as

    critcl::argtype pstring {
        @A.s = Tcl_GetStringFromObj(@@, &(@A.len));
        @A.o = @@;
    } critcl_pstring critcl_pstring

    critcl::argtypesupport pstring {
        typedef struct critcl_pstring {
            Tcl_Obj*    o;
            const char* s;
            int         len;
        } critcl_pstring;
    }

In the case of such a structure being large we may wish to allocate it on the
heap instead of having it taking space on the stack\. If we do that we need
another adjunct command, __critcl::argtyperelease__\. This command specifies
the code required to release dynamically allocated resources when the worker
function returns, before the shim returns to the caller in Tcl\. To keep things
simple our example is synthetic, a modification of __pstring__ above, to
demonstrate the technique\. An actual, but more complex example is the code to
support the variadic *args* argument of __critcl::cproc__\.

    critcl::argtype pstring {
        @A = (critcl_pstring*) ckalloc(sizeof(critcl_pstring));
        @A->s = Tcl_GetStringFromObj(@@, &(@A->len));
        @A->o = @@;
    } critcl_pstring* critcl_pstring*

    critcl::argtypesupport pstring {
        typedef struct critcl_pstring {
            Tcl_Obj*    o;
            const char* s;
            int         len;
        } critcl_pstring;
    }

    critcl::argtyperelease pstring {
        ckfree ((char*)) @A);
    }

Note, the above example shows only the most simple case of an allocated
argument, with a conversion that cannot fail \(namely, string retrieval\)\. If the
conversion can fail then either the allocation has to be defered to happen only
on successful conversion, or the conversion code has to release the allocated
memory itself in the failure path, because it will never reach the code defined
via __critcl::argtyperelease__ in that case\.

## <a name='subsection6'></a>Custom Types, Results

All of the previous sections dealt with argument conversions, i\.e\. going from
Tcl into C\. Custom result types are for the reverse direction, from C to Tcl\.
This is usually easier, as most of the time errors should not be possible\.
Supporting structures, or allocating them on the heap are not really required
and therefore not supported\.

The example of a result type shown below was pulled from __KineTcl__\. It is
a variant of the builtin result type __Tcl\_Obj\*__, aka __object__\. The
builtin conversion assumes that the object returned by the function has a
refcount of 1 \(or higher\), with the function having held the reference, and
releases that reference after placing the value into the interp result\. The
conversion below on the other hand assumes that the value has a refcount of 0
and thus that decrementing it is forbidden, lest it be released much to early,
and crashing the system\.

    critcl::resulttype KTcl_Obj* {
        if (rv == NULL) { return TCL_ERROR; }
        Tcl_SetObjResult(interp, rv);
        /* No refcount adjustment */
        return TCL_OK;
    } Tcl_Obj*

This type of definition is also found in __Marpa__ and recent hacking
hacking on __CRIMP__ introduced it there as well\. Which is why this
definition became a builtin type starting with version 3\.1\.16, under the names
__Tcl\_Obj\*0__ and __object0__\.

Going back to errors and their handling, of course, if a function we are
wrapping signals them in\-band, then the conversion of such results has to deal
with that\. This happens for example in __KineTcl__, where we find

    critcl::resulttype XnStatus {
        if (rv != XN_STATUS_OK) {
            Tcl_AppendResult (interp, xnGetStatusString (rv), NULL);
            return TCL_ERROR;
        }
        return TCL_OK;
    }

    critcl::resulttype XnDepthPixel {
        if (rv == ((XnDepthPixel) -1)) {
            Tcl_AppendResult (interp,
                              "Inheritance error: Not a depth generator",
                              NULL);
            return TCL_ERROR;
        }
        Tcl_SetObjResult (interp, Tcl_NewIntObj (rv));
        return TCL_OK;
    }

# <a name='section6'></a>Authors

Jean Claude Wippler, Steve Landers, Andreas Kupries

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report them at
[https://github\.com/andreas\-kupries/critcl/issues](https://github\.com/andreas\-kupries/critcl/issues)\.
Ideas for enhancements you may have for either package, application, and/or the
documentation are also very welcome and should be reported at
[https://github\.com/andreas\-kupries/critcl/issues](https://github\.com/andreas\-kupries/critcl/issues)
as well\.

# <a name='keywords'></a>KEYWORDS

[C code](\.\./index\.md\#c\_code), [Embedded C
Code](\.\./index\.md\#embedded\_c\_code), [calling C code from
Tcl](\.\./index\.md\#calling\_c\_code\_from\_tcl), [code
generator](\.\./index\.md\#code\_generator), [compile &
run](\.\./index\.md\#compile\_run), [compiler](\.\./index\.md\#compiler),
[dynamic code generation](\.\./index\.md\#dynamic\_code\_generation), [dynamic
compilation](\.\./index\.md\#dynamic\_compilation), [generate
package](\.\./index\.md\#generate\_package), [linker](\.\./index\.md\#linker),
[on demand compilation](\.\./index\.md\#on\_demand\_compilation), [on\-the\-fly
compilation](\.\./index\.md\#on\_the\_fly\_compilation)

# <a name='category'></a>CATEGORY

Glueing/Embedded C code

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; Jean\-Claude Wippler  
Copyright &copy; Steve Landers  
Copyright &copy; 2011\-2024 Andreas Kupries
