
[//000000001]: # (lazyset \- Lazy evaluation for variables and arrays)
[//000000002]: # (Generated from file 'lazyset\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2018 Roy Keene)
[//000000004]: # (lazyset\(n\) 1 tcllib "Lazy evaluation for variables and arrays")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

lazyset \- Lazy evaluation

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLES](#section3)

  - [AUTHORS](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require lazyset ?1?  

[__::lazyset::variable__ ?*\-array boolean*? ?*\-appendArgs boolean*? *variableName* *commandPrefix*](#1)  

# <a name='description'></a>DESCRIPTION

The __lazyset__ package provides a mechanism for deferring execution of code
until a specific variable or any index of an array is referenced\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::lazyset::variable__ ?*\-array boolean*? ?*\-appendArgs boolean*? *variableName* *commandPrefix*

    Arrange for the code specified as *commandPrefix* to be executed when the
    variable whose name is specified by *variableName* is read for the first
    time\. If the optional argument *\-array boolean* is specified as true, then
    the variable specified as *variableName* is treated as an array and
    attempting to read any index of the array causes that index to be set by the
    *commandPrefix* as they are read\. If the optional argument *\-appendArgs
    boolean* is specified as false, then the variable name and subnames are not
    appended to the *commandPrefix* before it is evaluated\. If the argument
    *\-appendArgs boolean* is not specified or is specified as true then 1 or 2
    additional arguments are appended to the *commandPrefix*\. If *\-array
    boolean* is specified as true, then 2 arguments are appended corresponding
    to the name of the variable and the index, otherwise 1 argument is appended
    containing the name of variable\. The *commandPrefix* code is run in the
    same scope as the variable is read\.

# <a name='section3'></a>EXAMPLES

    ::lazyset::variable page {apply {{name} {
    	package require http
    	set token [http::geturl http://www.tcl.tk/]
    	set data [http::data $token]
    	return $data
    }}}

    puts $page

    ::lazyset::variable -array true page {apply {{name index} {
    	package require http
    	set token [http::geturl $index]
    	set data [http::data $token]
    	return $data
    }}}

    puts $page(http://www.tcl.tk/)

    ::lazyset::variable -appendArgs false simple {
    	return -level 0 42
    }

    puts $simple

# <a name='section4'></a>AUTHORS

Roy Keene

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *utility* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='category'></a>CATEGORY

Utility

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2018 Roy Keene
