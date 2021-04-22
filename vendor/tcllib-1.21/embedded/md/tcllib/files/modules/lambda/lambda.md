
[//000000001]: # (lambda \- Utility commands for anonymous procedures)
[//000000002]: # (Generated from file 'lambda\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011 Andreas Kupries, BSD licensed)
[//000000004]: # (lambda\(n\) 1 tcllib "Utility commands for anonymous procedures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

lambda \- Utility commands for anonymous procedures

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [AUTHORS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require lambda ?1?  

[__::lambda__ *arguments* *body* ?*arg*\.\.\.?](#1)  
[__::lambda@__ *namespace* *arguments* *body* ?*arg*\.\.\.?](#2)  

# <a name='description'></a>DESCRIPTION

This package provides two convenience commands to make the writing of anonymous
procedures, i\.e\. lambdas more
__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__\-like\. Instead of, for example, to
write

    set f {::apply {{x} {
       ....
    }}}

with its deep nesting of braces, or

    set f [list ::apply {{x y} {
       ....
    }} $value_for_x]

with a list command to insert some of the arguments of a partial application,
just write

    set f [lambda {x} {
       ....
    }]

and

    set f [lambda {x y} {
       ....
    } $value_for_x]

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::lambda__ *arguments* *body* ?*arg*\.\.\.?

    The command constructs an anonymous procedure from the list of arguments,
    body script and \(optional\) predefined argument values and returns a command
    prefix representing this anonymous procedure\.

    When invoked the *body* is run in a new procedure scope just underneath
    the global scope, with the arguments set to the values supplied at both
    construction and invokation time\.

  - <a name='2'></a>__::lambda@__ *namespace* *arguments* *body* ?*arg*\.\.\.?

    The command constructs an anonymous procedure from the namespace name, list
    of arguments, body script and \(optional\) predefined argument values and
    returns a command prefix representing this anonymous procedure\.

    When invoked the *body* is run in a new procedure scope in the
    *namespace*, with the arguments set to the values supplied at both
    construction and invokation time\.

# <a name='section3'></a>AUTHORS

Andreas Kupries

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *lambda* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

apply\(n\), proc\(n\)

# <a name='keywords'></a>KEYWORDS

[anonymous procedure](\.\./\.\./\.\./\.\./index\.md\#anonymous\_procedure),
[callback](\.\./\.\./\.\./\.\./index\.md\#callback), [command
prefix](\.\./\.\./\.\./\.\./index\.md\#command\_prefix),
[currying](\.\./\.\./\.\./\.\./index\.md\#currying),
[lambda](\.\./\.\./\.\./\.\./index\.md\#lambda), [partial
application](\.\./\.\./\.\./\.\./index\.md\#partial\_application),
[proc](\.\./\.\./\.\./\.\./index\.md\#proc)

# <a name='category'></a>CATEGORY

Utility

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011 Andreas Kupries, BSD licensed
