
[//000000001]: # (control \- Tcl Control Flow Commands)
[//000000002]: # (Generated from file 'control\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (control\(n\) 0\.1\.3 tcllib "Tcl Control Flow Commands")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

control \- Procedures for control flow structures\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [LIMITATIONS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require control ?0\.1\.3?  

[__control::control__ *command* *option* ?*arg arg \.\.\.*?](#1)  
[__control::assert__ *expr* ?*arg arg \.\.\.*?](#2)  
[__control::do__ *body* ?*option test*?](#3)  
[__control::no\-op__ ?*arg arg \.\.\.*?](#4)  

# <a name='description'></a>DESCRIPTION

The __control__ package provides a variety of commands that provide
additional flow of control structures beyond the built\-in ones provided by Tcl\.
These are commands that in many programming languages might be considered
*keywords*, or a part of the language itself\. In Tcl, control flow structures
are just commands like everything else\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__control::control__ *command* *option* ?*arg arg \.\.\.*?

    The __control__ command is used as a configuration command for
    customizing the other public commands of the control package\. The
    *command* argument names the command to be customized\. The set of valid
    *option* and subsequent arguments are determined by the command being
    customized, and are documented with the command\.

  - <a name='2'></a>__control::assert__ *expr* ?*arg arg \.\.\.*?

    When disabled, the __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__ command
    behaves exactly like the __[no\-op](\.\./\.\./\.\./\.\./index\.md\#no\_op)__
    command\.

    When enabled, the __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__ command
    evaluates *expr* as an expression \(in the same way that __expr__
    evaluates its argument\)\. If evaluation reveals that *expr* is not a valid
    boolean expression \(according to \[__string is boolean \-strict__\]\), an
    error is raised\. If *expr* evaluates to a true boolean value \(as
    recognized by __if__\), then
    __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__ returns an empty string\.
    Otherwise, the remaining arguments to
    __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__ are used to construct a
    message string\. If there are no arguments, the message string is "assertion
    failed: $expr"\. If there are arguments, they are joined by
    __[join](\.\./\.\./\.\./\.\./index\.md\#join)__ to form the message string\.
    The message string is then appended as an argument to a callback command,
    and the completed callback command is evaluated in the global namespace\.

    The __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__ command can be
    customized by the __control__ command in two ways:

    \[__control::control assert enabled__ ?*boolean*?\] queries or sets
    whether __control::assert__ is enabled\. When called without a
    *boolean* argument, a boolean value is returned indicating whether the
    __control::assert__ command is enabled\. When called with a valid boolean
    value as the *boolean* argument, the __control::assert__ command is
    enabled or disabled to match the argument, and an empty string is returned\.

    \[__control::control assert callback__ ?*command*?\] queries or sets the
    callback command that will be called by an enabled
    __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__ on assertion failure\. When
    called without a *command* argument, the current callback command is
    returned\. When called with a *command* argument, that argument becomes the
    new assertion failure callback command\. Note that an assertion failure
    callback command is always defined, even when
    __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__ is disabled\. The default
    callback command is \[__return \-code error__\]\.

    Note that __control::assert__ has been written so that in combination
    with \[__namespace import__\], it is possible to use enabled
    __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__ commands in some
    namespaces and disabled __[assert](\.\./\.\./\.\./\.\./index\.md\#assert)__
    commands in other namespaces at the same time\. This capability is useful so
    that debugging efforts can be independently controlled module by module\.

        % package require control
        % control::control assert enabled 1
        % namespace eval one namespace import ::control::assert
        % control::control assert enabled 0
        % namespace eval two namespace import ::control::assert
        % one::assert {1 == 0}
        assertion failed: 1 == 0
        % two::assert {1 == 0}

  - <a name='3'></a>__control::do__ *body* ?*option test*?

    The __[do](\.\./\.\./\.\./\.\./index\.md\#do)__ command evaluates the script
    *body* repeatedly *until* the expression *test* becomes true or as
    long as \(*while*\) *test* is true, depending on the value of *option*
    being __until__ or __while__\. If *option* and *test* are omitted
    the body is evaluated exactly once\. After normal completion,
    __[do](\.\./\.\./\.\./\.\./index\.md\#do)__ returns an empty string\.
    Exceptional return codes \(__break__, __continue__,
    __[error](\.\./\.\./\.\./\.\./index\.md\#error)__, etc\.\) during the evaluation
    of *body* are handled in the same way the __while__ command handles
    them, except as noted in [LIMITATIONS](#section3), below\.

  - <a name='4'></a>__control::no\-op__ ?*arg arg \.\.\.*?

    The __[no\-op](\.\./\.\./\.\./\.\./index\.md\#no\_op)__ command takes any number
    of arguments and does nothing\. It returns an empty string\.

# <a name='section3'></a>LIMITATIONS

Several of the commands provided by the __control__ package accept arguments
that are scripts to be evaluated\. Due to fundamental limitations of Tcl's
__catch__ and __[return](\.\./\.\./\.\./\.\./index\.md\#return)__ commands, it
is not possible for these commands to properly evaluate the command \[__return
\-code $code__\] within one of those script arguments for any value of *$code*
other than *ok*\. In this way, the commands of the __control__ package are
limited as compared to Tcl's built\-in control flow commands \(such as __if__,
__while__, etc\.\) and those control flow commands that can be provided by
packages coded in C\. An example of this difference:

    % package require control
    % proc a {} {while 1 {return -code error a}}
    % proc b {} {control::do {return -code error b} while 1}
    % catch a
    1
    % catch b
    0

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *control* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

break, continue, expr, if, [join](\.\./\.\./\.\./\.\./index\.md\#join), namespace,
[return](\.\./\.\./\.\./\.\./index\.md\#return),
[string](\.\./\.\./\.\./\.\./index\.md\#string), while

# <a name='keywords'></a>KEYWORDS

[assert](\.\./\.\./\.\./\.\./index\.md\#assert),
[control](\.\./\.\./\.\./\.\./index\.md\#control), [do](\.\./\.\./\.\./\.\./index\.md\#do),
[flow](\.\./\.\./\.\./\.\./index\.md\#flow), [no\-op](\.\./\.\./\.\./\.\./index\.md\#no\_op),
[structure](\.\./\.\./\.\./\.\./index\.md\#structure)

# <a name='category'></a>CATEGORY

Programming tools
