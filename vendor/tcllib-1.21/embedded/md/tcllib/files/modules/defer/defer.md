
[//000000001]: # (defer \- Defered execution ala Go)
[//000000002]: # (Generated from file 'defer\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2017, Roy Keene)
[//000000004]: # (defer\(n\) 1 tcllib "Defered execution ala Go")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

defer \- Defered execution

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLES](#section3)

  - [REFERENCES](#section4)

  - [AUTHORS](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require defer ?1?  

[__::defer::defer__ ?*command*? ?*arg1*? ?*arg2*? ?*argN\.\.\.*?](#1)  
[__::defer::with__ *variableList* *script*](#2)  
[__::defer::autowith__ *script*](#3)  
[__::defer::cancel__ ?*id\.\.\.*?](#4)  

# <a name='description'></a>DESCRIPTION

The __defer__ commands allow a developer to schedule actions to happen as
part of the current variable scope terminating\. This is most useful for dealing
with cleanup activities\. Since the defered actions always execute, and always
execute in the reverse order from which the defer statements themselves execute,
the programmer can schedule the cleanup of a resource \(for example, a channel\)
as soon as that resource is acquired\. Then, later if the procedure or lambda
ends, either due to an error, or an explicit return, the cleanup of that
resource will always occur\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::defer::defer__ ?*command*? ?*arg1*? ?*arg2*? ?*argN\.\.\.*?

    Defers execution of some code until the current variable scope ends\. Each
    argument is concatencated together to form the script to execute at deferal
    time\. Multiple defer statements may be used, they are executed in the order
    of last\-in, first\-out\. The return value is an identifier which can be used
    later with __defer::cancel__

  - <a name='2'></a>__::defer::with__ *variableList* *script*

    Defers execution of a script while copying the current value of some
    variables, whose names specified in *variableList*, into the script\. The
    script acts like a lambda but executes at the same level as the
    __defer::with__ call\. The return value is the same as
    __::defer::defer__

  - <a name='3'></a>__::defer::autowith__ *script*

    The same as __::defer::with__ but uses all local variables in the
    variable list\.

  - <a name='4'></a>__::defer::cancel__ ?*id\.\.\.*?

    Cancels the execution of a defered action\. The *id* argument is the
    identifier returned by __::defer::defer__, __::defer::with__, or
    __::defer::autowith__\. Any number of arguments may be supplied, and all
    of the IDs supplied will be cancelled\.

# <a name='section3'></a>EXAMPLES

    package require defer 1
    apply {{} {
    	set fd [open /dev/null]
    	defer::defer close $fd
    }}

# <a name='section4'></a>REFERENCES

# <a name='section5'></a>AUTHORS

Roy Keene

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *defer* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[cleanup](\.\./\.\./\.\./\.\./index\.md\#cleanup),
[golang](\.\./\.\./\.\./\.\./index\.md\#golang)

# <a name='category'></a>CATEGORY

Utility

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2017, Roy Keene
