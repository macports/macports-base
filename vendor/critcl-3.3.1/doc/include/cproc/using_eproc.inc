[subsection {A Simple Procedure}]

Starting simple, let us assume that the Tcl code in question is
something like

[example {
    proc math {x y z} {
        return [expr {(sin($x)*rand())/$y**log($z)}]
    }
}]

with the expression pretending to be something very complex and
slow. Converting this to C we get:

[example {
    critcl::cproc math {double x double y double z} double {
        double up   = rand () * sin (x);
        double down = pow(y, log (z));
        return up/down;
    }
}]

Notable about this translation:

[list_begin enumerated]
[enum] All the arguments got type information added to them, here
       "double".  Like in C the type precedes the argument name. Other
       than that it is pretty much a Tcl dictionary, with keys and
       values swapped.
[enum] We now also have to declare the type of the result, here
       "double", again.
[enum] The reference manpage lists all the legal C types supported as
       arguments and results.
[list_end]

[para] While the above example was based on type [type double] for
both arguments and result we have a number of additional types in the
same category, i.e. simple types. These are:

[example_begin]
CriTcl type | C type         | Tcl type  | Notes
----------- | -------------- | --------- | ------------------------------
bool        |                |           | Alias of [type boolean] below
boolean     | int            | Boolean   |
double      | double         | Double    |
float       | float          | Double    |
int         | int            | Int       |
long        | long           | Long      |
wideint     | Tcl_WideInt    | WideInt   |
[example_end]

[para] A slightly advanced form of these simple types are a limited
set of constraints on the argument value. Note that [type bool] and
alias do not support this.

[example {
    critcl::cproc sqrt {{double >= 0} x} double {
        return sqrt(x);
    }
}]

[para] In the example above CriTcl's argument handling will reject
calling the command with a negative number, without ever invoking the
C code.

[para] These constraints are called [strong limited] because only
[const 0] and [const 1] can be used as the borders, although all the
operators [const <], [const <=], [const >], and [const >=] are
possible. It is also not possible to combine restrictions.
