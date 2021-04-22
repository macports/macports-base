
[//000000001]: # (throw \- Forward compatibility implementation of \[throw\])
[//000000002]: # (Generated from file 'tcllib\_throw\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2015 Miguel Martínez López, BSD licensed)
[//000000004]: # (throw\(n\) 1 tcllib "Forward compatibility implementation of \[throw\]")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

throw \- throw \- Throw an error exception with a message

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
package require throw ?1?  

[__::throw__ *error\_code* *error\_message*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a forward\-compatibility implementation of Tcl 8\.6's throw
command \(TIP 329\), for Tcl 8\.5\. The code was directly pulled from Tcl 8\.6
revision ?, when try/finally was implemented as Tcl procedure instead of in C\.

  - <a name='1'></a>__::throw__ *error\_code* *error\_message*

    throw is merely a reordering of the arguments of the error command\. It
    throws an error with the indicated error code and error message\.

# <a name='section2'></a>EXAMPLES

> __throw__ \{MYERROR CODE\} "My error message"

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

error\(n\)

# <a name='keywords'></a>KEYWORDS

[error](\.\./\.\./\.\./\.\./index\.md\#error),
[return](\.\./\.\./\.\./\.\./index\.md\#return),
[throw](\.\./\.\./\.\./\.\./index\.md\#throw)

# <a name='category'></a>CATEGORY

Utility

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2015 Miguel Martínez López, BSD licensed
