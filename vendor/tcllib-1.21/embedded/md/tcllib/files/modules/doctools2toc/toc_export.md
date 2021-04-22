
[//000000001]: # (doctools::toc::export \- Documentation tools)
[//000000002]: # (Generated from file 'toc\_export\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::toc::export\(n\) 0\.2\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::toc::export \- Exporting tables of contents

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Concepts](#section2)

  - [API](#section3)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

  - [Export plugin API v2 reference](#section4)

  - [ToC serialization format](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require doctools::toc::export ?0\.2\.1?  
package require Tcl 8\.4  
package require struct::map  
package require doctools::toc::structure  
package require snit  
package require pluginmgr  

[__::doctools::toc::export__ *objectName*](#1)  
[__objectName__ __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __export serial__ *serial* ?*format*?](#4)  
[*objectName* __export object__ *object* ?*format*?](#5)  
[*objectName* __config names__](#6)  
[*objectName* __config get__](#7)  
[*objectName* __config set__ *name* ?*value*?](#8)  
[*objectName* __config unset__ *pattern*\.\.\.](#9)  
[__[export](\.\./\.\./\.\./\.\./index\.md\#export)__ *serial* *configuration*](#10)  

# <a name='description'></a>DESCRIPTION

This package provides a class to manage the plugins for the export of tables of
contents to other formats, i\.e\. their conversion to, for example
*[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)*,
*[HTML](\.\./\.\./\.\./\.\./index\.md\#html)*, etc\.

This is one of the three public pillars the management of tables of contents
resides on\. The other two pillars are

  1. *Importing tables of contents*, and

  1. *[Holding tables of contents](toc\_container\.md)*

For information about the [Concepts](#section2) of tables of contents, and
their parts, see the same\-named section\. For information about the data
structure which is the major input to the manager objects provided by this
package see the section [ToC serialization format](#section5)\.

The plugin system of our class is based on the package
__[pluginmgr](\.\./pluginmgr/pluginmgr\.md)__, and configured to look for
plugins using

  1. the environment variable __DOCTOOLS\_TOC\_EXPORT\_PLUGINS__,

  1. the environment variable __DOCTOOLS\_TOC\_PLUGINS__,

  1. the environment variable __DOCTOOLS\_PLUGINS__,

  1. the path "~/\.doctools/toc/export/plugin"

  1. the path "~/\.doctools/toc/plugin"

  1. the path "~/\.doctools/plugin"

  1. the path "~/\.doctools/toc/export/plugins"

  1. the path "~/\.doctools/toc/plugins"

  1. the path "~/\.doctools/plugins"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\TOC\\EXPORT\\PLUGINS"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\TOC\\PLUGINS"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\PLUGINS"

The last three are used only when the package is run on a machine using
Windows\(tm\) operating system\.

The whole system is delivered with six predefined export plugins, namely

  - doctoc

    See *[doctoc export plugin](export\_doctoc\.md)* for details\.

  - html

    See *html export plugin* for details\.

  - json

    See *json export plugin* for details\.

  - nroff

    See *[nroff export plugin](toc\_export\_nroff\.md)* for details\.

  - text

    See *text export plugin* for details\.

  - wiki

    See *[wiki export plugin](toc\_export\_wiki\.md)* for details\.

Readers wishing to write their own export plugin for some format, i\.e\. *plugin
writer*s reading and understanding the section containing the [Export plugin
API v2 reference](#section4) is an absolute necessity, as it specifies the
interaction between this package and its plugins in detail\.

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

  - <a name='1'></a>__::doctools::toc::export__ *objectName*

    This command creates a new export manager object with an associated Tcl
    command whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The object command will be created under the
    current namespace if the *objectName* is not fully qualified, and in the
    specified namespace otherwise\.

## <a name='subsection2'></a>Object command

All objects created by the __::doctools::toc::export__ command have the
following general form:

  - <a name='2'></a>__objectName__ __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object it is invoked for\.

  - <a name='4'></a>*objectName* __export serial__ *serial* ?*format*?

    This method takes the canonical serialization of a table of contents stored
    in *serial* and converts it to the specified *format*, using the export
    plugin for the format\. An error is thrown if no plugin could be found for
    the format\. The string generated by the conversion process is returned as
    the result of this method\.

    If no format is specified the method defaults to __doctoc__\.

    The specification of what a *canonical* serialization is can be found in
    the section [ToC serialization format](#section5)\.

    The plugin has to conform to the interface specified in section [Export
    plugin API v2 reference](#section4)\.

  - <a name='5'></a>*objectName* __export object__ *object* ?*format*?

    This method is a convenient wrapper around the __export serial__ method
    described by the previous item\. It expects that *object* is an object
    command supporting a __serialize__ method returning the canonical
    serialization of a table of contents\. It invokes that method, feeds the
    result into __export serial__ and returns the resulting string as its
    own result\.

  - <a name='6'></a>*objectName* __config names__

    This method returns a list containing the names of all configuration
    variables currently known to the object\.

  - <a name='7'></a>*objectName* __config get__

    This method returns a dictionary containing the names and values of all
    configuration variables currently known to the object\.

  - <a name='8'></a>*objectName* __config set__ *name* ?*value*?

    This method sets the configuration variable *name* to the specified
    *value* and returns the new value of the variable\.

    If no value is specified it simply returns the current value, without
    changing it\.

    Note that while the user can set the predefined configuration variables
    __user__ and __format__ doing so will have no effect, these values
    will be internally overridden when invoking an import plugin\.

  - <a name='9'></a>*objectName* __config unset__ *pattern*\.\.\.

    This method unsets all configuration variables matching the specified glob
    *pattern*s\. If no pattern is specified it will unset all currently defined
    configuration variables\.

# <a name='section4'></a>Export plugin API v2 reference

Plugins are what this package uses to manage the support for any output format
beyond the [ToC serialization format](#section5)\. Here we specify the API
the objects created by this package use to interact with their plugins\.

A plugin for this package has to follow the rules listed below:

  1. A plugin is a package\.

  1. The name of a plugin package has the form
     doctools::toc::export::__FOO__, where __FOO__ is the name of the
     format the plugin will generate output for\. This name is also the argument
     to provide to the various __export__ methods of export manager objects
     to get a string encoding a table of contents in that format\.

  1. The plugin can expect that the package
     __doctools::toc::export::plugin__ is present, as indicator that it was
     invoked from a genuine plugin manager\.

  1. A plugin has to provide one command, with the signature shown below\.

       - <a name='10'></a>__[export](\.\./\.\./\.\./\.\./index\.md\#export)__ *serial* *configuration*

         Whenever an export manager of
         __[doctools::toc](\.\./doctools/doctoc\.md)__ has to generate
         output for a table of contents it will invoke this command\.

           * string *serial*

             This argument will contain the *canonical* serialization of the
             table of contents for which to generate the output\. The
             specification of what a *canonical* serialization is can be found
             in the section [ToC serialization format](#section5)\.

           * dictionary *configuration*

             This argument will contain the current configuration to apply to
             the generation, as a dictionary mapping from variable names to
             values\.

             The following configuration variables have a predefined meaning all
             plugins have to obey, although they can ignore this information at
             their discretion\. Any other other configuration variables
             recognized by a plugin will be described in the manpage for that
             plugin\.

               + user

                 This variable is expected to contain the name of the user
                 owning the process invoking the plugin\.

               + format

                 This variable is expected to contain the name of the format
                 whose plugin is invoked\.

               + file

                 This variable, if defined by the user of the table object is
                 expected to contain the name of the input file for which the
                 plugin is generating its output for\.

               + map

                 This variable, if defined by the user of the table object is
                 expected to contain a dictionary mapping from symbolic document
                 ids used in the table entries to actual paths \(or urls\)\. A
                 plugin has to be able to handle the possibility that a document
                 id is without entry in this mapping\.

  1. A single usage cycle of a plugin consists of the invokations of the command
     __[export](\.\./\.\./\.\./\.\./index\.md\#export)__\. This call has to leave
     the plugin in a state where another usage cycle can be run without
     problems\.

# <a name='section5'></a>ToC serialization format

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

# <a name='section6'></a>Bugs, Ideas, Feedback

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

[HTML](\.\./\.\./\.\./\.\./index\.md\#html),
[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc),
[documentation](\.\./\.\./\.\./\.\./index\.md\#documentation),
[export](\.\./\.\./\.\./\.\./index\.md\#export),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[generation](\.\./\.\./\.\./\.\./index\.md\#generation),
[json](\.\./\.\./\.\./\.\./index\.md\#json),
[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[nroff](\.\./\.\./\.\./\.\./index\.md\#nroff),
[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin),
[reference](\.\./\.\./\.\./\.\./index\.md\#reference),
[table](\.\./\.\./\.\./\.\./index\.md\#table), [table of
contents](\.\./\.\./\.\./\.\./index\.md\#table\_of\_contents), [tcler's
wiki](\.\./\.\./\.\./\.\./index\.md\#tcler\_s\_wiki),
[text](\.\./\.\./\.\./\.\./index\.md\#text), [url](\.\./\.\./\.\./\.\./index\.md\#url),
[wiki](\.\./\.\./\.\./\.\./index\.md\#wiki)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
