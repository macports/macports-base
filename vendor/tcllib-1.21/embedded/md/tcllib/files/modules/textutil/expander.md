
[//000000001]: # (textutil::expander \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'expander\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; William H\. Duquette, http://www\.wjduquette\.com/expand)
[//000000004]: # (textutil::expander\(n\) 1\.3\.1 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::expander \- Procedures to process templates and expand text\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXPANDER API](#section2)

  - [TUTORIAL](#section3)

      - [Basics](#subsection1)

      - [Embedding Macros](#subsection2)

      - [Writing Macro Commands](#subsection3)

      - [Changing the Expansion Brackets](#subsection4)

      - [Customized Macro Expansion](#subsection5)

      - [Using the Context Stack](#subsection6)

  - [HISTORY](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require textutil::expander ?1\.3\.1?  

[__::textutil::expander__ *expanderName*](#1)  
[*expanderName* __cappend__ *text*](#2)  
[*expanderName* __cget__ *varname*](#3)  
[*expanderName* __cis__ *cname*](#4)  
[*expanderName* __cname__](#5)  
[*expanderName* __cpop__ *cname*](#6)  
[*expanderName* __ctopandclear__](#7)  
[*expanderName* __cpush__ *cname*](#8)  
[*expanderName* __cset__ *varname* *value*](#9)  
[*expanderName* __cvar__ *varname*](#10)  
[*expanderName* __errmode__ *newErrmode*](#11)  
[*expanderName* __evalcmd__ ?*newEvalCmd*?](#12)  
[*expanderName* __expand__ *string* ?*brackets*?](#13)  
[*expanderName* __lb__ ?*newbracket*?](#14)  
[*expanderName* __rb__ ?*newbracket*?](#15)  
[*expanderName* __reset__](#16)  
[*expanderName* __setbrackets__ *lbrack rbrack*](#17)  
[*expanderName* __textcmd__ ?*newTextCmd*?](#18)  
[*expanderName* __where__](#19)  

# <a name='description'></a>DESCRIPTION

The Tcl __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__ command is often used to
support a kind of template processing\. Given a string with embedded variables or
function calls, __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__ will interpolate
the variable and function values, returning the new string:

    % set greeting "Howdy"
    Howdy
    % proc place {} {return "World"}
    % subst {$greeting, [place]!}
    Howdy, World!
    %

By defining a suitable set of Tcl commands,
__[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__ can be used to implement a
markup language similar to HTML\.

The __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__ command is efficient, but it
has three drawbacks for this kind of template processing:

  - There's no way to identify and process the plain text between two embedded
    Tcl commands; that makes it difficult to handle plain text in a
    context\-sensitive way\.

  - Embedded commands are necessarily bracketed by __\[__ and __\]__; it's
    convenient to be able to choose different brackets in special cases\. Someone
    producing web pages that include a large quantity of Tcl code examples might
    easily prefer to use __<<__ and __>>__ as the embedded code
    delimiters instead\.

  - There's no easy way to handle incremental input, as one might wish to do
    when reading data from a socket\.

At present, expander solves the first two problems; eventually it will solve the
third problem as well\.

The following section describes the command API to the expander; this is
followed by the tutorial sections, see [TUTORIAL](#section3)\.

# <a name='section2'></a>EXPANDER API

The __textutil::expander__ package provides only one command, described
below\. The rest of the section is taken by a description of the methods for the
expander objects created by this command\.

  - <a name='1'></a>__::textutil::expander__ *expanderName*

    The command creates a new expander object with an associated Tcl command
    whose name is *expanderName*\. This command may be used to invoke various
    operations on the graph\. If the *expanderName* is not fully qualified it
    is interpreted as relative to the current namespace\. The command has the
    following general form:

    > *expanderName* option ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\.

The following commands are possible for expander objects:

  - <a name='2'></a>*expanderName* __cappend__ *text*

    Appends a string to the output in the current context\. This command should
    rarely be used by macros or application code\.

  - <a name='3'></a>*expanderName* __cget__ *varname*

    Retrieves the value of variable *varname*, defined in the current context\.

  - <a name='4'></a>*expanderName* __cis__ *cname*

    Determines whether or not the name of the current context is *cname*\.

  - <a name='5'></a>*expanderName* __cname__

    Returns the name of the current context\.

  - <a name='6'></a>*expanderName* __cpop__ *cname*

    Pops a context from the context stack, returning all accumulated output in
    that context\. The context must be named *cname*, or an error results\.

  - <a name='7'></a>*expanderName* __ctopandclear__

    Returns the output currently captured in the topmost context and clears that
    buffer\. This is similar to a combination of __cpop__ followed by
    __cpush__, except that internal state \(brackets\) is preserved here\.

  - <a name='8'></a>*expanderName* __cpush__ *cname*

    Pushes a context named *cname* onto the context stack\. The context must be
    popped by __cpop__ before expansion ends or an error results\.

  - <a name='9'></a>*expanderName* __cset__ *varname* *value*

    Sets variable *varname* to *value* in the current context\.

  - <a name='10'></a>*expanderName* __cvar__ *varname*

    Retrieves the internal variable name of context variable *varname*; this
    allows the variable to be passed to commands like __lappend__\.

  - <a name='11'></a>*expanderName* __errmode__ *newErrmode*

    Sets the macro expansion error mode to one of __nothing__,
    __macro__, __error__, or __fail__; the default value is
    __fail__\. The value determines what the expander does if an error is
    detected during expansion of a macro\.

      * __fail__

        The error propagates normally and can be caught or ignored by the
        application\.

      * __error__

        The macro expands into a detailed error message, and expansion
        continues\.

      * __macro__

        The macro expands to itself; that is, it is passed along to the output
        unchanged\.

      * __nothing__

        The macro expands to the empty string, and is effectively ignored\.

  - <a name='12'></a>*expanderName* __evalcmd__ ?*newEvalCmd*?

    Returns the current evaluation command, which defaults to __uplevel
    \#0__\. If specified, *newEvalCmd* will be saved for future use and then
    returned; it must be a Tcl command expecting one additional argument: the
    macro to evaluate\.

  - <a name='13'></a>*expanderName* __expand__ *string* ?*brackets*?

    Expands the input string, replacing embedded macros with their expanded
    values, and returns the expanded string\.

    Note that this method pushes a new \(empty\) context on the stack of contexts
    while it is running, and removes it on return\.

    If *brackets* is given, it must be a list of two strings; the items will
    be used as the left and right macro expansion bracket sequences for this
    expansion only\.

  - <a name='14'></a>*expanderName* __lb__ ?*newbracket*?

    Returns the current value of the left macro expansion bracket; this is for
    use as or within a macro, when the bracket needs to be included in the
    output text\. If *newbracket* is specified, it becomes the new bracket, and
    is returned\.

  - <a name='15'></a>*expanderName* __rb__ ?*newbracket*?

    Returns the current value of the right macro expansion bracket; this is for
    use as or within a macro, when the bracket needs to be included in the
    output text\. If *newbracket* is specified, it becomes the new bracket, and
    is returned\.

  - <a name='16'></a>*expanderName* __reset__

    Resets all expander settings to their initial values\. Unusual results are
    likely if this command is called from within a call to __expand__\.

  - <a name='17'></a>*expanderName* __setbrackets__ *lbrack rbrack*

    Sets the left and right macro expansion brackets\. This command is for use as
    or within a macro, or to permanently change the bracket definitions\. By
    default, the brackets are __\[__ and __\]__, but any non\-empty string
    can be used; for example, __<__ and __>__ or __\(\*__ and
    __\*\)__ or even __Hello,__ and __World\!__\.

  - <a name='18'></a>*expanderName* __textcmd__ ?*newTextCmd*?

    Returns the current command for processing plain text, which defaults to the
    empty string, meaning *identity*\. If specified, *newTextCmd* will be
    saved for future use and then returned; it must be a Tcl command expecting
    one additional argument: the text to process\. The expander object will this
    command for all plain text it encounters, giving the user of the object the
    ability to process all plain text in some standard way before writing it to
    the output\. The object expects that the command returns the processed plain
    text\.

    *Note* that the combination of "__textcmd__ *plaintext*" is run
    through the *evalcmd* for the actual evaluation\. In other words, the
    *textcmd* is treated as a special macro implicitly surrounding all plain
    text in the template\.

  - <a name='19'></a>*expanderName* __where__

    Returns a three\-element list containing the current character position,
    line, and column the expander is at in the processing of the current input
    string\.

# <a name='section3'></a>TUTORIAL

## <a name='subsection1'></a>Basics

To begin, create an expander object:

    % package require textutil::expander
    1.2
    % ::textutil::expander myexp
    ::myexp
    %

The created __::myexp__ object can be used to expand text strings containing
embedded Tcl commands\. By default, embedded commands are delimited by square
brackets\. Note that expander doesn't attempt to interpolate variables, since
variables can be referenced by embedded commands:

    % set greeting "Howdy"
    Howdy
    % proc place {} {return "World"}
    % ::myexp expand {[set greeting], [place]!}
    Howdy, World!
    %

## <a name='subsection2'></a>Embedding Macros

An expander macro is simply a Tcl script embedded within a text string\. Expander
evaluates the script in the global context, and replaces it with its result
string\. For example,

        % set greetings {Howdy Hi "What's up"}
        Howdy Hi "What's up"
        % ::myexp expand {There are many ways to say "Hello, World!":
        [set result {}
        foreach greeting $greetings {
    	append result "$greeting, World!\\n"
        }
        set result]
        And that's just a small sample!}
        There are many ways to say "Hello, World!":
        Howdy, World!
        Hi, World!
        What's up, World!

        And that's just a small sample!
        %

## <a name='subsection3'></a>Writing Macro Commands

More typically, *macro commands* are used to create a markup language\. A macro
command is just a Tcl command that returns an output string\. For example, expand
can be used to implement a generic document markup language that can be
retargeted to HTML or any other output format:

    % proc bold {} {return "<b>"}
    % proc /bold {} {return "</b>"}
    % ::myexp expand {Some of this text is in [bold]boldface[/bold]}
    Some of this text is in <b>boldface</b>
    %

The above definitions of __bold__ and __/bold__ returns HTML, but such
commands can be as complicated as needed; they could, for example, decide what
to return based on the desired output format\.

## <a name='subsection4'></a>Changing the Expansion Brackets

By default, embedded macros are enclosed in square brackets, __\[__ and
__\]__\. If square brackets need to be included in the output, the input can
contain the __lb__ and __rb__ commands\. Alternatively, or if square
brackets are objectionable for some other reason, the macro expansion brackets
can be changed to any pair of non\-empty strings\.

The __setbrackets__ command changes the brackets permanently\. For example,
you can write pseudo\-html by change them to __<__ and __>__:

    % ::myexp setbrackets < >
    % ::myexp expand {<bold>This is boldface</bold>}
    <b>This is boldface</b>

Alternatively, you can change the expansion brackets temporarily by passing the
desired brackets to the __expand__ command:

    % ::myexp setbrackets "\\[" "\\]"
    % ::myexp expand {<bold>This is boldface</bold>} {< >}
    <b>This is boldface</b>
    %

## <a name='subsection5'></a>Customized Macro Expansion

By default, macros are evaluated using the Tcl __uplevel \#0__ command, so
that the embedded code executes in the global context\. The application can
provide a different evaluation command using __evalcmd__; this allows the
application to use a safe interpreter, for example, or even to evaluated
something other than Tcl code\. There is one caveat: to be recognized as valid, a
macro must return 1 when passed to Tcl's "info complete" command\.

For example, the following code "evaluates" each macro by returning the macro
text itself\.

    proc identity {macro} {return $macro}
    ::myexp evalcmd identity

## <a name='subsection6'></a>Using the Context Stack

Often it's desirable to define a pair of macros which operate in some way on the
plain text between them\. Consider a set of macros for adding footnotes to a web
page: one could have implement something like this:

    Dr. Pangloss, however, thinks that this is the best of all
    possible worlds.[footnote "See Candide, by Voltaire"]

The __footnote__ macro would, presumably, assign a number to this footnote
and save the text to be formatted later on\. However, this solution is ugly if
the footnote text is long or should contain additional markup\. Consider the
following instead:

    Dr. Pangloss, however, thinks that this is the best of all
    possible worlds.[footnote]See [bookTitle "Candide"], by
    [authorsName "Voltaire"], for more information.[/footnote]

Here the footnote text is contained between __footnote__ and
__/footnote__ macros, continues onto a second line, and contains several
macros of its own\. This is both clearer and more flexible; however, with the
features presented so far there's no easy way to do it\. That's the purpose of
the context stack\.

All macro expansion takes place in a particular context\. Here, the
__footnote__ macro pushes a new context onto the context stack\. Then, all
expanded text gets placed in that new context\. __/footnote__ retrieves it by
popping the context\. Here's a skeleton implementation of these two macros:

    proc footnote {} {
        ::myexp cpush footnote
    }

    proc /footnote {} {
        set footnoteText [::myexp cpop footnote]

        # Save the footnote text, and return an appropriate footnote
        # number and link.
    }

The __cpush__ command pushes a new context onto the stack; the argument is
the context's name\. It can be any string, but would typically be the name of the
macro itself\. Then, __cpop__ verifies that the current context has the
expected name, pops it off of the stack, and returns the accumulated text\.

Expand provides several other tools related to the context stack\. Suppose the
first macro in a context pair takes arguments or computes values which the
second macro in the pair needs\. After calling __cpush__, the first macro can
define one or more context variables; the second macro can retrieve their values
any time before calling __cpop__\. For example, suppose the document must
specify the footnote number explicitly:

    proc footnote {footnoteNumber} {
        ::myexp cpush footnote
        ::myexp csave num $footnoteNumber
        # Return an appropriate link
    }

    proc /footnote {} {
        set footnoteNumber [::myexp cget num]
        set footnoteText [::myexp cpop footnote]

        # Save the footnote text and its footnoteNumber for future
        # output.
    }

At times, it might be desirable to define macros that are valid only within a
particular context pair; such macros should verify that they are only called
within the correct context using either __cis__ or __cname__\.

# <a name='section4'></a>HISTORY

__expander__ was written by William H\. Duquette; it is a repackaging of the
central algorithm of the expand macro processing tool\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *textutil* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

\[uri, http://www\.wjduquette\.com/expand, regexp,
[split](\.\./\.\./\.\./\.\./index\.md\#split),
[string](\.\./\.\./\.\./\.\./index\.md\#string)

# <a name='keywords'></a>KEYWORDS

[string](\.\./\.\./\.\./\.\./index\.md\#string), [template
processing](\.\./\.\./\.\./\.\./index\.md\#template\_processing), [text
expansion](\.\./\.\./\.\./\.\./index\.md\#text\_expansion)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; William H\. Duquette, http://www\.wjduquette\.com/expand
