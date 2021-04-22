
[//000000001]: # (try \- Forward compatibility implementation of \[try\])
[//000000002]: # (Generated from file 'tcllib\_try\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 Donal K\. Fellows, BSD licensed)
[//000000004]: # (try\(n\) 1 tcllib "Forward compatibility implementation of \[try\]")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

try \- try \- Trap and process errors and exceptions

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXAMPLES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require try ?1?  

[__::try__ *body* ?*handler\.\.\.*? ?__finally__ *script*?](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a forward\-compatibility implementation of Tcl 8\.6's
try/finally command \(TIP 329\), for Tcl 8\.5\. The code was directly pulled from
Tcl 8\.6 revision ?, when try/finally was implemented as Tcl procedure instead of
in C\.

  - <a name='1'></a>__::try__ *body* ?*handler\.\.\.*? ?__finally__ *script*?

    This command executes the script *body* and, depending on what the outcome
    of that script is \(normal exit, error, or some other exceptional result\),
    runs a handler script to deal with the case\. Once that has all happened, if
    the __finally__ clause is present, the *script* it includes will be
    run and the result of the handler \(or the *body* if no handler matched\) is
    allowed to continue to propagate\. Note that the __finally__ clause is
    processed even if an error occurs and irrespective of which, if any,
    *handler* is used\.

    The *handler* clauses are each expressed as several words, and must have
    one of the following forms:

      * __on__ *code variableList script*

        This clause matches if the evaluation of *body* completed with the
        exception code *code*\. The *code* may be expressed as an integer or
        one of the following literal words: __ok__, __error__,
        __return__, __break__, or __continue__\. Those literals
        correspond to the integers 0 through 4 respectively\.

      * __trap__ *pattern variableList script*

        This clause matches if the evaluation of *body* resulted in an error
        and the prefix of the __\-errorcode__ from the interpreter's status
        dictionary is equal to the *pattern*\. The number of prefix words taken
        from the __\-errorcode__ is equal to the list\-length of *pattern*,
        and inter\-word spaces are normalized in both the __\-errorcode__ and
        *pattern* before comparison\.

        The *variableList* word in each *handler* is always interpreted as a
        list of variable names\. If the first word of the list is present and
        non\-empty, it names a variable into which the result of the evaluation
        of *body* \(from the main __try__\) will be placed; this will
        contain the human\-readable form of any errors\. If the second word of the
        list is present and non\-empty, it names a variable into which the
        options dictionary of the interpreter at the moment of completion of
        execution of *body* will be placed\.

        The *script* word of each *handler* is also always interpreted the
        same: as a Tcl script to evaluate if the clause is matched\. If
        *script* is a literal __\-__ and the *handler* is not the last
        one, the *script* of the following *handler* is invoked instead
        \(just like with the __switch__ command\)\.

        Note that *handler* clauses are matched against in order, and that the
        first matching one is always selected\. At most one *handler* clause
        will selected\. As a consequence, an __on error__ will mask any
        subsequent __trap__ in the __try__\. Also note that __on
        error__ is equivalent to __trap \{\}__\.

        If an exception \(i\.e\. any non\-__ok__ result\) occurs during the
        evaluation of either the *handler* or the __finally__ clause, the
        original exception's status dictionary will be added to the new
        exception's status dictionary under the __\-during__ key\.

# <a name='section2'></a>EXAMPLES

Ensure that a file is closed no matter what:

> set f \[open /some/file/name a\]  
> __try__ \{  
> &nbsp;&nbsp;&nbsp;&nbsp;puts \\$f "some message"  
> &nbsp;&nbsp;&nbsp;&nbsp;\# \.\.\.  
> \} __finally__ \{  
> &nbsp;&nbsp;&nbsp;&nbsp;close \\$f  
> \}

Handle different reasons for a file to not be openable for reading:

> __try__ \{  
> &nbsp;&nbsp;&nbsp;&nbsp;set f \[open /some/file/name\]  
> \} __trap__ \{POSIX EISDIR\} \{\} \{  
> &nbsp;&nbsp;&nbsp;&nbsp;puts "failed to open /some/file/name: it's a directory"  
> \} __trap__ \{POSIX ENOENT\} \{\} \{  
> &nbsp;&nbsp;&nbsp;&nbsp;puts "failed to open /some/file/name: it doesn't exist"  
> \}

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *try* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

catch\(n\), error\(n\), return\(n\), [throw\(n\)](tcllib\_throw\.md)

# <a name='keywords'></a>KEYWORDS

[cleanup](\.\./\.\./\.\./\.\./index\.md\#cleanup),
[error](\.\./\.\./\.\./\.\./index\.md\#error),
[exception](\.\./\.\./\.\./\.\./index\.md\#exception),
[final](\.\./\.\./\.\./\.\./index\.md\#final), [resource
management](\.\./\.\./\.\./\.\./index\.md\#resource\_management)

# <a name='category'></a>CATEGORY

Utility

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008 Donal K\. Fellows, BSD licensed
