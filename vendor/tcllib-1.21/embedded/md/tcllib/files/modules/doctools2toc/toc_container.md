
[//000000001]: # (doctools::toc \- Documentation tools)
[//000000002]: # (Generated from file 'toc\_container\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::toc\(n\) 2 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::toc \- Holding tables of contents

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Concepts](#section2)

  - [API](#section3)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

  - [ToC serialization format](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require doctools::toc ?2?  
package require Tcl 8\.4  
package require doctools::toc::structure  
package require struct::tree  
package require snit  

[__::doctools::toc__ *objectName*](#1)  
[__objectName__ __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __\+ reference__ *id* *label* *docid* *desc*](#4)  
[*objectName* __\+ division__ *id* *label* ?*docid*?](#5)  
[*objectName* __remove__ *id*](#6)  
[*objectName* __up__ *id*](#7)  
[*objectName* __next__ *id*](#8)  
[*objectName* __prev__ *id*](#9)  
[*objectName* __child__ *id* *label* ?*\.\.\.*?](#10)  
[*objectName* __element__ ?*\.\.\.*?](#11)  
[*objectName* __children__ *id*](#12)  
[*objectName* __type__ *id*](#13)  
[*objectName* __full\-label__ *id*](#14)  
[*objectName* __elabel__ *id* ?*newlabel*?](#15)  
[*objectName* __description__ *id* ?*newdesc*?](#16)  
[*objectName* __document__ *id* ?*newdocid*?](#17)  
[*objectName* __title__](#18)  
[*objectName* __title__ *text*](#19)  
[*objectName* __label__](#20)  
[*objectName* __label__ *text*](#21)  
[*objectName* __importer__](#22)  
[*objectName* __importer__ *object*](#23)  
[*objectName* __exporter__](#24)  
[*objectName* __exporter__ *object*](#25)  
[*objectName* __deserialize =__ *data* ?*format*?](#26)  
[*objectName* __deserialize \+=__ *data* ?*format*?](#27)  
[*objectName* __serialize__ ?*format*?](#28)  

# <a name='description'></a>DESCRIPTION

This package provides a class to contain and programmatically manipulate tables
of contents\.

This is one of the three public pillars the management of tables of contents
resides on\. The other two pillars are

  1. *[Exporting tables of contents](toc\_export\.md)*, and

  1. *Importing tables of contents*

For information about the [Concepts](#section2) of tables of contents, and
their parts, see the same\-named section\. For information about the data
structure which is used to encode tables of contents as values see the section
[ToC serialization format](#section4)\. This is the only format directly
known to this class\. Conversions from and to any other format are handled by
export and import manager objects\. These may be attached to a container, but do
not have to be, it is merely a convenience\.

# <a name='section2'></a>Concepts

  1. A *[table of contents](\.\./\.\./\.\./\.\./index\.md\#table\_of\_contents)*
     consists of a \(possibly empty\) list of *elements*\.

  1. Each element in the list is identified by its label\.

  1. Each element is either a
     *[reference](\.\./\.\./\.\./\.\./index\.md\#reference)*, or a *division*\.

  1. Each reference has an associated document, identified by a symbolic id, and
     a textual description\.

  1. Each division may have an associated document, identified by a symbolic id\.

  1. Each division consists consists of a \(possibly empty\) list of *elements*,
     with each element following the rules as specified in item 2 and above\.

A few notes

  1. The above rules span up a tree of elements, with references as the leaf
     nodes, and divisions as the inner nodes, and each element representing an
     entry in the whole table of contents\.

  1. The identifying labels of any element E are unique within their division
     \(or toc\), and the full label of any element E is the list of labels for all
     nodes on the unique path from the root of the tree to E, including E\.

# <a name='section3'></a>API

## <a name='subsection1'></a>Package commands

  - <a name='1'></a>__::doctools::toc__ *objectName*

    This command creates a new container object with an associated Tcl command
    whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The object command will be created under the
    current namespace if the *objectName* is not fully qualified, and in the
    specified namespace otherwise\.

## <a name='subsection2'></a>Object command

All objects created by the __::doctools::toc__ command have the following
general form:

  - <a name='2'></a>__objectName__ __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object it is invoked for\.

  - <a name='4'></a>*objectName* __\+ reference__ *id* *label* *docid* *desc*

    This method adds a new reference element to the table of contents, under the
    element specified via its handle *id*\. This parent element has to be a
    division element, or the root\. An error is thrown otherwise\. The new element
    will be externally identified by its *label*, which has to be be unique
    within the parent element\. An error is thrown otherwise\.

    As a reference element it will refer to a document identified by the
    symbolic *docid*\. This reference must not be the empty string, an error is
    thrown otherwise\. Beyond the label the element also has a longer descriptive
    string, supplied via *desc*\.

    The result of the method is the handle \(id\) of the new element\.

  - <a name='5'></a>*objectName* __\+ division__ *id* *label* ?*docid*?

    This method adds a new division element to the table of contents, under the
    element specified via its handle *id*\. This parent element has to be a
    division element, or the root\. An error is thrown otherwise\. The new element
    will be externally identified by its *label*, which has to be be unique
    within the parent element\. An error is thrown otherwise\.

    As a division element it is can refer to a document, identified by the
    symbolic *docid*, but may choose not to\.

    The result of the method is the handle \(id\) of the new element\.

  - <a name='6'></a>*objectName* __remove__ *id*

    This method removes the element identified by the handle *id* from the
    table of contents\. If the element is a division all of its children, if any,
    are removed as well\. The root element/division of the table of contents
    cannot be removed however, only its children\.

    The result of the method is the empty string\.

  - <a name='7'></a>*objectName* __up__ *id*

    This method returns the handle of the parent for the element identified by
    its handle *id*, or the empty string if *id* referred to the root
    element\.

  - <a name='8'></a>*objectName* __next__ *id*

    This method returns the handle of the right sibling for the element
    identified by its handle *id*, or the handle of the parent if the element
    has no right sibling, or the empty string if *id* referred to the root
    element\.

  - <a name='9'></a>*objectName* __prev__ *id*

    This method returns the handle of the left sibling for the element
    identified by its handle *id*, or the handle of the parent if the element
    has no left sibling, or the empty string if *id* referred to the root
    element\.

  - <a name='10'></a>*objectName* __child__ *id* *label* ?*\.\.\.*?

    This method returns the handle of a child of the element identified by its
    handle *id*\. The child itself is identified by a series of labels\.

  - <a name='11'></a>*objectName* __element__ ?*\.\.\.*?

    This method returns the handle of the element identified by a series of
    labels, starting from the root of the table of contents\. The series of
    labels is allowed to be empty, in which case the handle of the root element
    is returned\.

  - <a name='12'></a>*objectName* __children__ *id*

    This method returns a list containing the handles of all children of the
    element identified by the handle *id*, from first to last, in that order\.

  - <a name='13'></a>*objectName* __type__ *id*

    This method returns the type of the element, either __reference__, or
    __division__\.

  - <a name='14'></a>*objectName* __full\-label__ *id*

    This method is the complement of the method __element__, converting the
    handle *id* of an element into a list of labels full identifying the
    element within the whole table of contents\.

  - <a name='15'></a>*objectName* __elabel__ *id* ?*newlabel*?

    This method queries and/or changes the label of the element identified by
    the handle *id*\. If the argument *newlabel* is present then the label is
    changed to that value\. Regardless of this, the result of the method is the
    current value of the label\.

    If the label is changed the new label has to be unique within the containing
    division, or an error is thrown\.

    Further, of the *id* refers to the root element of the table of contents,
    then using this method is equivalent to using the method *label*, i\.e\. it
    is accessing the global label for the whole table\.

  - <a name='16'></a>*objectName* __description__ *id* ?*newdesc*?

    This method queries and/or changes the description of the element identified
    by the handle *id*\. If the argument *newdesc* is present then the
    description is changed to that value\. Regardless of this, the result of the
    method is the current value of the description\.

    The element this method operates on has to be a reference element, or an
    error will be thrown\.

  - <a name='17'></a>*objectName* __document__ *id* ?*newdocid*?

    This method queries and/or changes the document reference of the element
    identified by the handle *id*\. If the argument *newdocid* is present
    then the description is changed to that value\. Regardless of this, the
    result of the method is the current value of the document reference\.

    Setting the reference to the empty string means unsetting it, and is allowed
    only for division elements\. Conversely, if the result is the empty string
    then the element has no document reference, and this can happen only for
    division elements\.

  - <a name='18'></a>*objectName* __title__

    Returns the currently defined title of the table of contents\.

  - <a name='19'></a>*objectName* __title__ *text*

    Sets the title of the table of contents to *text*, and returns it as the
    result of the command\.

  - <a name='20'></a>*objectName* __label__

    Returns the currently defined label of the table of contents\.

  - <a name='21'></a>*objectName* __label__ *text*

    Sets the label of the table of contents to *text*, and returns it as the
    result of the command\.

  - <a name='22'></a>*objectName* __importer__

    Returns the import manager object currently attached to the container, if
    any\.

  - <a name='23'></a>*objectName* __importer__ *object*

    Attaches the *object* as import manager to the container, and returns it
    as the result of the command\. Note that the *object* is *not* put into
    ownership of the container\. I\.e\., destruction of the container will *not*
    destroy the *object*\.

    It is expected that *object* provides a method named __import text__
    which takes a text and a format name, and returns the canonical
    serialization of the table of contents contained in the text, assuming the
    given format\.

  - <a name='24'></a>*objectName* __exporter__

    Returns the export manager object currently attached to the container, if
    any\.

  - <a name='25'></a>*objectName* __exporter__ *object*

    Attaches the *object* as export manager to the container, and returns it
    as the result of the command\. Note that the *object* is *not* put into
    ownership of the container\. I\.e\., destruction of the container will *not*
    destroy the *object*\.

    It is expected that *object* provides a method named __export object__
    which takes the container and a format name, and returns a text encoding
    table of contents stored in the container, in the given format\. It is
    further expected that the *object* will use the container's method
    __serialize__ to obtain the serialization of the table of contents from
    which to generate the text\.

  - <a name='26'></a>*objectName* __deserialize =__ *data* ?*format*?

    This method replaces the contents of the table object with the table
    contained in the *data*\. If no *format* was specified it is assumed to
    be the regular serialization of a table of contents\.

    Otherwise the object will use the attached import manager to convert the
    data from the specified format to a serialization it can handle\. In that
    case an error will be thrown if the container has no import manager attached
    to it\.

    The result of the method is the empty string\.

  - <a name='27'></a>*objectName* __deserialize \+=__ *data* ?*format*?

    This method behaves like __deserialize =__ in its essentials, except
    that it merges the table of contents in the *data* to its contents instead
    of replacing it\. The method will throw an error if merging is not possible,
    i\.e\. would produce an invalid table\. The existing content is left unchanged
    in that case\.

    The result of the method is the empty string\.

  - <a name='28'></a>*objectName* __serialize__ ?*format*?

    This method returns the table of contents contained in the object\. If no
    *format* is not specified the returned result is the canonical
    serialization of its contents\.

    Otherwise the object will use the attached export manager to convert the
    data to the specified format\. In that case an error will be thrown if the
    container has no export manager attached to it\.

# <a name='section4'></a>ToC serialization format

Here we specify the format used by the doctools v2 packages to serialize tables
of contents as immutable values for transport, comparison, etc\.

We distinguish between *regular* and *canonical* serializations\. While a
table of contents may have more than one regular serialization only exactly one
of them will be *canonical*\.

  - regular serialization

      1. The serialization of any table of contents is a nested Tcl dictionary\.

      1. This dictionary holds a single key, __doctools::toc__, and its
         value\. This value holds the contents of the table of contents\.

      1. The contents of the table of contents are a Tcl dictionary holding the
         title of the table of contents, a label, and its elements\. The relevant
         keys and their values are

           * __title__

             The value is a string containing the title of the table of
             contents\.

           * __label__

             The value is a string containing a label for the table of contents\.

           * __items__

             The value is a Tcl list holding the elements of the table, in the
             order they are to be shown\.

             Each element is a Tcl list holding the type of the item, and its
             description, in this order\. An alternative description would be
             that it is a Tcl dictionary holding a single key, the item type,
             mapped to the item description\.

             The two legal item types and their descriptions are

               + __reference__

                 This item describes a single entry in the table of contents,
                 referencing a single document\. To this end its value is a Tcl
                 dictionary containing an id for the referenced document, a
                 label, and a longer textual description which can be associated
                 with the entry\. The relevant keys and their values are

                   - __id__

                     The value is a string containing the id of the document
                     associated with the entry\.

                   - __label__

                     The value is a string containing a label for this entry\.
                     This string also identifies the entry, and no two entries
                     \(references and divisions\) in the containing list are
                     allowed to have the same label\.

                   - __desc__

                     The value is a string containing a longer description for
                     this entry\.

               + __division__

                 This item describes a group of entries in the table of
                 contents, inducing a hierarchy of entries\. To this end its
                 value is a Tcl dictionary containing a label for the group, an
                 optional id to a document for the whole group, and the list of
                 entries in the group\. The relevant keys and their values are

                   - __id__

                     The value is a string containing the id of the document
                     associated with the whole group\. This key is optional\.

                   - __label__

                     The value is a string containing a label for the group\.
                     This string also identifies the entry, and no two entries
                     \(references and divisions\) in the containing list are
                     allowed to have the same label\.

                   - __items__

                     The value is a Tcl list holding the elements of the group,
                     in the order they are to be shown\. This list has the same
                     structure as the value for the keyword __items__ used
                     to describe the whole table of contents, see above\. This
                     closes the recusrive definition of the structure, with
                     divisions holding the same type of elements as the whole
                     table of contents, including other divisions\.

  - canonical serialization

    The canonical serialization of a table of contents has the format as
    specified in the previous item, and then additionally satisfies the
    constraints below, which make it unique among all the possible
    serializations of this table of contents\.

      1. The keys found in all the nested Tcl dictionaries are sorted in
         ascending dictionary order, as generated by Tcl's builtin command
         __lsort \-increasing \-dict__\.

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
[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion), [doctoc
markup](\.\./\.\./\.\./\.\./index\.md\#doctoc\_markup),
[documentation](\.\./\.\./\.\./\.\./index\.md\#documentation),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[generation](\.\./\.\./\.\./\.\./index\.md\#generation),
[json](\.\./\.\./\.\./\.\./index\.md\#json), [latex](\.\./\.\./\.\./\.\./index\.md\#latex),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[nroff](\.\./\.\./\.\./\.\./index\.md\#nroff),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin),
[reference](\.\./\.\./\.\./\.\./index\.md\#reference),
[table](\.\./\.\./\.\./\.\./index\.md\#table), [table of
contents](\.\./\.\./\.\./\.\./index\.md\#table\_of\_contents), [tcler's
wiki](\.\./\.\./\.\./\.\./index\.md\#tcler\_s\_wiki),
[text](\.\./\.\./\.\./\.\./index\.md\#text), [wiki](\.\./\.\./\.\./\.\./index\.md\#wiki)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
