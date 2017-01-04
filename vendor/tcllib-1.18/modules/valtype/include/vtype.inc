[comment {-*- tcl -*- --- !doctools ---}]
[manpage_begin valtype::[vset PACKAGE] n [vset VERSION]]
[copyright {2011 Andreas Kupries <andreas_kupries@users.sourceforge.net>}]
[titledesc "Validation for [vset NAME]"]
[moddesc {Validation types}]
[category {Validation, Type checking}]
[keywords Validation Checking Testing {Type checking}]
[keywords {Value checking} isA]
[include [vset KEYWORDS].inc]
[require Tcl 8.5]
[require snit 2]
[require valtype::common]
[include [vset REQUIRE].inc]
[require valtype::[vset PACKAGE] [opt [vset VERSION]]]
[description]

This package implements a snit validation type for [vset A] [vset NAME].

[para]

A validation type is an object that can be used to validate Tcl values
of a particular kind.  For example, [cmd snit::integer], a validation
type defined by the [package snit] package is used to validate that a
Tcl value is an integer.

[para]

Every validation type has a [method validate] method which is used to
do the validation. This method must take a single argument, the value
to be validated; further, it must do nothing if the value is valid,
but throw an error if the value is invalid:

[example_begin]
    valtype::[vset PACKAGE] validate [vset OK] ;# Does nothing
    valtype::[vset PACKAGE] validate [vset BAD] ;# Throws an error (bad [vset NAMEX]).
[example_end]

[para]

The [method validate] method will always return the validated value on
success, and throw the [cmd -errorcode] INVALID on error, possibly
with additional elements which provide more details about the problem.

[section API]

The API provided by this package satisfies the specification
of snit validation types found in the documentation of
[manpage {Snit's Not Incr Tcl}].

[list_begin definitions]

[call [cmd valtype::[vset PACKAGE]] [method validate] [arg value]]

This method validates the [arg value] and returns it, possibly in a
canonical form, if it passes. If the value does not pass the
validation an error is thrown.

[call [cmd valtype::[vset PACKAGE]] [method checkdigit] [arg value]]

This method computes a check digit for the [arg value]. Before doing
so it is validated, except for a checkdigit. If the value does not
pass the validation no check digit is calculated and an error is
thrown instead.

[include [vset METHODS].inc]
[list_end]


[section {Error Codes}]

As said in the package description, the errors thrown by the commands
of this package in response to input validation failures use the
[cmd -errorcode] INVALID to distinguish themselves from package
internal errors.

[para] To provide more detailed information about why the validation
failed the [cmd -errorCode] goes actually beyond that.

First, it will contain a code detailing the type itself. Here this is
[const [vset CODE]]. This is then followed by values detailing the
reason for the failure. The full set of [cmd -errorCode]s which can
be thrown by this package are:

[list_begin definitions]
[def "INVALID [vset CODE] CHARACTER"]

The input value contained one or more bad characters, i.e. characters
which must not occur in the input for it to be [vset A] [vset NAME].

[def "INVALID [vset CODE] CHECK-DIGIT"]

The check digit of the input value is wrong. This usually signals a
data-entry error, with digits transposed, forgotten, etc. Of course,
th input may be an outright fake too.


[include [vset CODES].inc]
[list_end]

[vset CATEGORY valtype]
[include ../../doctools2base/include/feedback.inc]
[manpage_end]
