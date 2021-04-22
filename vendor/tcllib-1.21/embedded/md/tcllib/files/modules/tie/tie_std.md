
[//000000001]: # (tie \- Tcl Data Structures)
[//000000002]: # (Generated from file 'tie\_std\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008\-2021 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tie\(n\) 1\.2 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tie \- Array persistence, standard data sources

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require tie::std::log ?1\.1?  
package require tie::std::array ?1\.1?  
package require tie::std::rarray ?1\.1?  
package require tie::std::file ?1\.1?  
package require tie::std::growfile ?1\.1?  
package require tie::std::dsource ?1\.1?  

# <a name='description'></a>DESCRIPTION

The packages listed as requirements for this document are internal packages
providing the standard data sources of package __[tie](tie\.md)__, as
described in section *STANDARD DATA SOURCE TYPES* of
__[tie](tie\.md)__'s documentation\.

They are automatically loaded and registered by __[tie](tie\.md)__ when
it itself is requested, and as such there is no need to request them on their
own, although it is possible to do so\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *tie* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[array](\.\./\.\./\.\./\.\./index\.md\#array),
[database](\.\./\.\./\.\./\.\./index\.md\#database),
[file](\.\./\.\./\.\./\.\./index\.md\#file),
[metakit](\.\./\.\./\.\./\.\./index\.md\#metakit),
[persistence](\.\./\.\./\.\./\.\./index\.md\#persistence),
[tie](\.\./\.\./\.\./\.\./index\.md\#tie), [untie](\.\./\.\./\.\./\.\./index\.md\#untie)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008\-2021 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
