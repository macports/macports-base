
[//000000001]: # (doctools::idx \- Documentation tools)
[//000000002]: # (Generated from file 'idx\_container\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::idx\(n\) 2 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::idx \- Holding keyword indices

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Concepts](#section2)

  - [API](#section3)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

  - [Keyword index serialization format](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require doctools::idx ?2?  
package require Tcl 8\.4  
package require doctools::idx::structure  
package require snit  

[__::doctools::idx__ *objectName*](#1)  
[__objectName__ __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __key add__ *name*](#4)  
[*objectName* __key remove__ *name*](#5)  
[*objectName* __key references__ *name*](#6)  
[*objectName* __keys__](#7)  
[*objectName* __reference add__ *type* *key* *name* *label*](#8)  
[*objectName* __reference remove__ *name*](#9)  
[*objectName* __reference label__ *name*](#10)  
[*objectName* __reference keys__ *name*](#11)  
[*objectName* __reference type__ *name*](#12)  
[*objectName* __references__](#13)  
[*objectName* __title__](#14)  
[*objectName* __title__ *text*](#15)  
[*objectName* __label__](#16)  
[*objectName* __label__ *text*](#17)  
[*objectName* __importer__](#18)  
[*objectName* __importer__ *object*](#19)  
[*objectName* __exporter__](#20)  
[*objectName* __exporter__ *object*](#21)  
[*objectName* __deserialize =__ *data* ?*format*?](#22)  
[*objectName* __deserialize \+=__ *data* ?*format*?](#23)  
[*objectName* __serialize__ ?*format*?](#24)  

# <a name='description'></a>DESCRIPTION

This package provides a class to contain and programmatically manipulate keyword
indices

This is one of the three public pillars the management of keyword indices
resides on\. The other two pillars are

  1. *[Exporting keyword indices](idx\_export\.md)*, and

  1. *[Importing keyword indices](idx\_import\.md)*

For information about the [Concepts](#section2) of keyword indices, and
their parts, see the same\-named section\. For information about the data
structure which is used to encode keyword indices as values see the section
[Keyword index serialization format](#section4)\. This is the only format
directly known to this class\. Conversions from and to any other format are
handled by export and import manager objects\. These may be attached to a
container, but do not have to be, it is merely a convenience\.

# <a name='section2'></a>Concepts

  1. A *[keyword index](\.\./\.\./\.\./\.\./index\.md\#keyword\_index)* consists of a
     \(possibly empty\) set of *[keywords](\.\./\.\./\.\./\.\./index\.md\#keywords)*\.

  1. Each keyword in the set is identified by its name\.

  1. Each keyword has a \(possibly empty\) set of *references*\.

  1. A reference can be associated with more than one keyword\.

  1. A reference not associated with at least one keyword is not possible
     however\.

  1. Each reference is identified by its target, specified as either an url or
     symbolic filename, depending on the type of reference \(__url__, or
     __manpage__\)\.

  1. The type of a reference \(url, or manpage\) depends only on the reference
     itself, and not the keywords it is associated with\.

  1. In addition to a type each reference has a descriptive label as well\. This
     label depends only on the reference itself, and not the keywords it is
     associated with\.

A few notes

  1. Manpage references are intended to be used for references to the documents
     the index is made for\. Their target is a symbolic file name identifying the
     document, and export plugins may replace symbolic with actual file names,
     if specified\.

  1. Url references are intended on the othre hand are inteded to be used for
     links to anything else, like websites\. Their target is an url\.

  1. While url and manpage references share a namespace for their identifiers,
     this should be no problem, given that manpage identifiers are symbolic
     filenames and as such they should never look like urls, the identifiers for
     url references\.

# <a name='section3'></a>API

## <a name='subsection1'></a>Package commands

  - <a name='1'></a>__::doctools::idx__ *objectName*

    This command creates a new container object with an associated Tcl command
    whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The object command will be created under the
    current namespace if the *objectName* is not fully qualified, and in the
    specified namespace otherwise\.

## <a name='subsection2'></a>Object command

All objects created by the __::doctools::idx__ command have the following
general form:

  - <a name='2'></a>__objectName__ __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object it is invoked for\.

  - <a name='4'></a>*objectName* __key add__ *name*

    This method adds the keyword *name* to the index\. If the keyword is
    already known nothing is done\. The result of the method is the empty string\.

  - <a name='5'></a>*objectName* __key remove__ *name*

    This method removes the keyword *name* from the index\. If the keyword is
    already gone nothing is done\. Any references for whom this keyword was the
    last association are removed as well\. The result of the method is the empty
    string\.

  - <a name='6'></a>*objectName* __key references__ *name*

    This method returns a list containing the names of all references associated
    with the keyword *name*\. An error is thrown in the keyword is not known to
    the index\. The order of the references in the list is undefined\.

  - <a name='7'></a>*objectName* __keys__

    This method returns a list containing the names of all keywords known to the
    index\. The order of the keywords in the list is undefined\.

  - <a name='8'></a>*objectName* __reference add__ *type* *key* *name* *label*

    This method adds the reference *name* to the index and associates it with
    the keyword *key*\. The other two arguments hold the *type* and *label*
    of the reference, respectively\. The type has to match the stored
    information, should the reference exist already, i\.e\. this information is
    immutable after the reference is known\. The only way to change it is delete
    and recreate the reference\. The label on the other hand is automatically
    updated to the value of the argument, overwriting any previously stored
    information\. Should the reference exists already it is simply associated
    with the *key*\. If that is true already as well nothing is done, but the
    *label* updated to the new value\. The result of the method is the empty
    string\.

    The *type* argument has be to one of __manpage__ or __url__\.

  - <a name='9'></a>*objectName* __reference remove__ *name*

    The reference *name* is removed from the index\. All associations with
    keywords are released and the relevant reference labels removed\. The result
    of the method is the empty string\.

  - <a name='10'></a>*objectName* __reference label__ *name*

    This method returns the label associated with the reference *name*\. An
    error is thrown if the reference is not known\.

  - <a name='11'></a>*objectName* __reference keys__ *name*

    This method returns a list containing the names of all keywords associated
    with the reference *name*\. An error is thrown in the reference is not
    known to the index\. The order of the keywords in the list is undefined\.

  - <a name='12'></a>*objectName* __reference type__ *name*

    This method returns the type of the reference *name*\. An error is thrown
    in the reference is not known to the index\.

  - <a name='13'></a>*objectName* __references__

    This method returns a list containing the names of all references known to
    the index\. The order of the references in the list is undefined\.

  - <a name='14'></a>*objectName* __title__

    Returns the currently defined title of the keyword index\.

  - <a name='15'></a>*objectName* __title__ *text*

    Sets the title of the keyword index to *text*, and returns it as the
    result of the command\.

  - <a name='16'></a>*objectName* __label__

    Returns the currently defined label of the keyword index\.

  - <a name='17'></a>*objectName* __label__ *text*

    Sets the label of the keyword index to *text*, and returns it as the
    result of the command\.

  - <a name='18'></a>*objectName* __importer__

    Returns the import manager object currently attached to the container, if
    any\.

  - <a name='19'></a>*objectName* __importer__ *object*

    Attaches the *object* as import manager to the container, and returns it
    as the result of the command\. Note that the *object* is *not* put into
    ownership of the container\. I\.e\., destruction of the container will *not*
    destroy the *object*\.

    It is expected that *object* provides a method named __import text__
    which takes a text and a format name, and returns the canonical
    serialization of the keyword index contained in the text, assuming the given
    format\.

  - <a name='20'></a>*objectName* __exporter__

    Returns the export manager object currently attached to the container, if
    any\.

  - <a name='21'></a>*objectName* __exporter__ *object*

    Attaches the *object* as export manager to the container, and returns it
    as the result of the command\. Note that the *object* is *not* put into
    ownership of the container\. I\.e\., destruction of the container will *not*
    destroy the *object*\.

    It is expected that *object* provides a method named __export object__
    which takes the container and a format name, and returns a text encoding
    keyword index stored in the container, in the given format\. It is further
    expected that the *object* will use the container's method
    __serialize__ to obtain the serialization of the keyword index from
    which to generate the text\.

  - <a name='22'></a>*objectName* __deserialize =__ *data* ?*format*?

    This method replaces the contents of the index object with the index
    contained in the *data*\. If no *format* was specified it is assumed to
    be the regular serialization of a keyword index\.

    Otherwise the object will use the attached import manager to convert the
    data from the specified format to a serialization it can handle\. In that
    case an error will be thrown if the container has no import manager attached
    to it\.

    The result of the method is the empty string\.

  - <a name='23'></a>*objectName* __deserialize \+=__ *data* ?*format*?

    This method behaves like __deserialize =__ in its essentials, except
    that it merges the keyword index in the *data* to its contents instead of
    replacing it\. The method will throw an error if merging is not possible,
    i\.e\. would produce an invalid index\. The existing content is left unchanged
    in that case\.

    The result of the method is the empty string\.

  - <a name='24'></a>*objectName* __serialize__ ?*format*?

    This method returns the keyword index contained in the object\. If no
    *format* is not specified the returned result is the canonical
    serialization of its contents\.

    Otherwise the object will use the attached export manager to convert the
    data to the specified format\. In that case an error will be thrown if the
    container has no export manager attached to it\.

# <a name='section4'></a>Keyword index serialization format

Here we specify the format used by the doctools v2 packages to serialize keyword
indices as immutable values for transport, comparison, etc\.

We distinguish between *regular* and *canonical* serializations\. While a
keyword index may have more than one regular serialization only exactly one of
them will be *canonical*\.

  - regular serialization

      1. An index serialization is a nested Tcl dictionary\.

      1. This dictionary holds a single key, __doctools::idx__, and its
         value\. This value holds the contents of the index\.

      1. The contents of the index are a Tcl dictionary holding the title of the
         index, a label, and the keywords and references\. The relevant keys and
         their values are

           * __title__

             The value is a string containing the title of the index\.

           * __label__

             The value is a string containing a label for the index\.

           * __keywords__

             The value is a Tcl dictionary, using the keywords known to the
             index as keys\. The associated values are lists containing the
             identifiers of the references associated with that particular
             keyword\.

             Any reference identifier used in these lists has to exist as a key
             in the __references__ dictionary, see the next item for its
             definition\.

           * __references__

             The value is a Tcl dictionary, using the identifiers for the
             references known to the index as keys\. The associated values are
             2\-element lists containing the type and label of the reference, in
             this order\.

             Any key here has to be associated with at least one keyword, i\.e\.
             occur in at least one of the reference lists which are the values
             in the __keywords__ dictionary, see previous item for its
             definition\.

      1. The *[type](\.\./\.\./\.\./\.\./index\.md\#type)* of a reference can be one
         of two values,

           * __manpage__

             The identifier of the reference is interpreted as symbolic file
             name, referring to one of the documents the index was made for\.

           * __url__

             The identifier of the reference is interpreted as an url, referring
             to some external location, like a website, etc\.

  - canonical serialization

    The canonical serialization of a keyword index has the format as specified
    in the previous item, and then additionally satisfies the constraints below,
    which make it unique among all the possible serializations of the keyword
    index\.

      1. The keys found in all the nested Tcl dictionaries are sorted in
         ascending dictionary order, as generated by Tcl's builtin command
         __lsort \-increasing \-dict__\.

      1. The references listed for each keyword of the index, if any, are listed
         in ascending dictionary order of their *labels*, as generated by
         Tcl's builtin command __lsort \-increasing \-dict__\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *doctools* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[HTML](\.\./\.\./\.\./\.\./index\.md\#html), [TMML](\.\./\.\./\.\./\.\./index\.md\#tmml),
[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion), [docidx
markup](\.\./\.\./\.\./\.\./index\.md\#docidx\_markup),
[documentation](\.\./\.\./\.\./\.\./index\.md\#documentation),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[generation](\.\./\.\./\.\./\.\./index\.md\#generation),
[index](\.\./\.\./\.\./\.\./index\.md\#index), [json](\.\./\.\./\.\./\.\./index\.md\#json),
[keyword index](\.\./\.\./\.\./\.\./index\.md\#keyword\_index),
[latex](\.\./\.\./\.\./\.\./index\.md\#latex),
[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[nroff](\.\./\.\./\.\./\.\./index\.md\#nroff),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin),
[reference](\.\./\.\./\.\./\.\./index\.md\#reference), [tcler's
wiki](\.\./\.\./\.\./\.\./index\.md\#tcler\_s\_wiki),
[text](\.\./\.\./\.\./\.\./index\.md\#text), [url](\.\./\.\./\.\./\.\./index\.md\#url),
[wiki](\.\./\.\./\.\./\.\./index\.md\#wiki)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
