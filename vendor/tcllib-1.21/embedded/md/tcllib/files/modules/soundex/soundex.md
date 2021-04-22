
[//000000001]: # (soundex \- Soundex)
[//000000002]: # (Generated from file 'soundex\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; ????, Algorithm: Donald E\. Knuth)
[//000000004]: # (Copyright &copy; 2003, Documentation: Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (Copyright &copy; 1998, Tcl port: Evan Rempel <erempel@uvic\.ca>)
[//000000006]: # (soundex\(n\) 1\.0 tcllib "Soundex")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

soundex \- Soundex

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXAMPLES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require soundex ?1\.0?  

[__::soundex::knuth__ *string*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides soundex algorithms which allow the comparison of words
based on their phonetic likeness\.

Currently only an algorithm by Knuth is provided, which is tuned to english
names and words\.

  - <a name='1'></a>__::soundex::knuth__ *string*

    Computes the soundex code of the input *string* using Knuth's algorithm
    and returns it as the result of the command\.

# <a name='section2'></a>EXAMPLES

    % ::soundex::knuth Knuth
    K530

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *soundex* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[knuth](\.\./\.\./\.\./\.\./index\.md\#knuth),
[soundex](\.\./\.\./\.\./\.\./index\.md\#soundex), [text
comparison](\.\./\.\./\.\./\.\./index\.md\#text\_comparison), [text
likeness](\.\./\.\./\.\./\.\./index\.md\#text\_likeness)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; ????, Algorithm: Donald E\. Knuth  
Copyright &copy; 2003, Documentation: Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 1998, Tcl port: Evan Rempel <erempel@uvic\.ca>
