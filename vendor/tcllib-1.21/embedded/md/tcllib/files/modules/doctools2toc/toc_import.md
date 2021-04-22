
[//000000001]: # (doctools::toc::import \- Documentation tools)
[//000000002]: # (Generated from file 'toc\_import\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::toc::import\(n\) 0\.2\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::toc::import \- Importing keyword indices

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Concepts](#section2)

  - [API](#section3)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

  - [Import plugin API v2 reference](#section4)

  - [ToC serialization format](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require doctools::toc::import ?0\.2\.1?  
package require Tcl 8\.4  
package require struct::map  
package require doctools::toc::structure  
package require snit  
package require pluginmgr  

[__::doctools::toc::import__ *objectName*](#1)  
[__objectName__ __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __import text__ *text* ?*format*?](#4)  
[*objectName* __import file__ *path* ?*format*?](#5)  
[*objectName* __import object text__ *object* *text* ?*format*?](#6)  
[*objectName* __import object file__ *object* *path* ?*format*?](#7)  
[*objectName* __config names__](#8)  
[*objectName* __config get__](#9)  
[*objectName* __config set__ *name* ?*value*?](#10)  
[*objectName* __config unset__ *pattern*\.\.\.](#11)  
[*objectName* __includes__](#12)  
[*objectName* __include add__ *path*](#13)  
[*objectName* __include remove__ *path*](#14)  
[*objectName* __include clear__](#15)  
[__IncludeFile__ *currentfile* *path*](#16)  
[__[import](\.\./\.\./\.\./\.\./index\.md\#import)__ *text* *configuration*](#17)  

# <a name='description'></a>DESCRIPTION

This package provides a class to manage the plugins for the import of tables of
contents from other formats, i\.e\. their conversion from, for example
*[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)*,
*[json](\.\./\.\./\.\./\.\./index\.md\#json)*, etc\.

This is one of the three public pillars the management of tables of contents
resides on\. The other two pillars are

  1. *[Exporting tables of contents](toc\_export\.md)*, and

  1. *[Holding tables of contents](toc\_container\.md)*

For information about the [Concepts](#section2) of tables of contents, and
their parts, see the same\-named section\. For information about the data
structure which is the major output of the manager objects provided by this
package see the section [ToC serialization format](#section5)\.

The plugin system of our class is based on the package
__[pluginmgr](\.\./pluginmgr/pluginmgr\.md)__, and configured to look for
plugins using

  1. the environment variable __DOCTOOLS\_TOC\_IMPORT\_PLUGINS__,

  1. the environment variable __DOCTOOLS\_TOC\_PLUGINS__,

  1. the environment variable __DOCTOOLS\_PLUGINS__,

  1. the path "~/\.doctools/toc/import/plugin"

  1. the path "~/\.doctools/toc/plugin"

  1. the path "~/\.doctools/plugin"

  1. the path "~/\.doctools/toc/import/plugins"

  1. the path "~/\.doctools/toc/plugins"

  1. the path "~/\.doctools/plugins"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\TOC\\IMPORT\\PLUGINS"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\TOC\\PLUGINS"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\PLUGINS"

The last three are used only when the package is run on a machine using
Windows\(tm\) operating system\.

The whole system is delivered with two predefined import plugins, namely

  - doctoc

    See *[doctoc import plugin](import\_doctoc\.md)* for details\.

  - json

    See *json import plugin* for details\.

Readers wishing to write their own import plugin for some format, i\.e\. *plugin
writer*s reading and understanding the section containing the [Import plugin
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

  - <a name='1'></a>__::doctools::toc::import__ *objectName*

    This command creates a new import manager object with an associated Tcl
    command whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The object command will be created under the
    current namespace if the *objectName* is not fully qualified, and in the
    specified namespace otherwise\.

## <a name='subsection2'></a>Object command

All objects created by the __::doctools::toc::import__ command have the
following general form:

  - <a name='2'></a>__objectName__ __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object it is invoked for\.

  - <a name='4'></a>*objectName* __import text__ *text* ?*format*?

    This method takes the *text* and converts it from the specified *format*
    to the canonical serialization of a table of contents using the import
    plugin for the format\. An error is thrown if no plugin could be found for
    the format\. The serialization generated by the conversion process is
    returned as the result of this method\.

    If no format is specified the method defaults to __doctoc__\.

    The specification of what a *canonical* serialization is can be found in
    the section [ToC serialization format](#section5)\.

    The plugin has to conform to the interface specified in section [Import
    plugin API v2 reference](#section4)\.

  - <a name='5'></a>*objectName* __import file__ *path* ?*format*?

    This method is a convenient wrapper around the __import text__ method
    described by the previous item\. It reads the contents of the specified file
    into memory, feeds the result into __import text__ and returns the
    resulting serialization as its own result\.

  - <a name='6'></a>*objectName* __import object text__ *object* *text* ?*format*?

    This method is a convenient wrapper around the __import text__ method
    described by the previous item\. It expects that *object* is an object
    command supporting a __deserialize__ method expecting the canonical
    serialization of a table of contents\. It imports the text using __import
    text__ and then feeds the resulting serialization into the *object* via
    __deserialize__\. This method returns the empty string as it result\.

  - <a name='7'></a>*objectName* __import object file__ *object* *path* ?*format*?

    This method behaves like __import object text__, except that it reads
    the text to convert from the specified file instead of being given it as
    argument\.

  - <a name='8'></a>*objectName* __config names__

    This method returns a list containing the names of all configuration
    variables currently known to the object\.

  - <a name='9'></a>*objectName* __config get__

    This method returns a dictionary containing the names and values of all
    configuration variables currently known to the object\.

  - <a name='10'></a>*objectName* __config set__ *name* ?*value*?

    This method sets the configuration variable *name* to the specified
    *value* and returns the new value of the variable\.

    If no value is specified it simply returns the current value, without
    changing it\.

    Note that while the user can set the predefined configuration variables
    __user__ and __format__ doing so will have no effect, these values
    will be internally overridden when invoking an import plugin\.

  - <a name='11'></a>*objectName* __config unset__ *pattern*\.\.\.

    This method unsets all configuration variables matching the specified glob
    *pattern*s\. If no pattern is specified it will unset all currently defined
    configuration variables\.

  - <a name='12'></a>*objectName* __includes__

    This method returns a list containing the currently specified paths to use
    to search for include files when processing input\. The order of paths in the
    list corresponds to the order in which they are used, from first to last,
    and also corresponds to the order in which they were added to the object\.

  - <a name='13'></a>*objectName* __include add__ *path*

    This methods adds the specified *path* to the list of paths to use to
    search for include files when processing input\. The path is added to the end
    of the list, causing it to be searched after all previously added paths\. The
    result of the command is the empty string\.

    The method does nothing if the path is already known\.

  - <a name='14'></a>*objectName* __include remove__ *path*

    This methods removes the specified *path* from the list of paths to use to
    search for include files when processing input\. The result of the command is
    the empty string\.

    The method does nothing if the path is not known\.

  - <a name='15'></a>*objectName* __include clear__

    This method clears the list of paths to use to search for include files when
    processing input\. The result of the command is the empty string\.

# <a name='section4'></a>Import plugin API v2 reference

Plugins are what this package uses to manage the support for any input format
beyond the [ToC serialization format](#section5)\. Here we specify the API
the objects created by this package use to interact with their plugins\.

A plugin for this package has to follow the rules listed below:

  1. A plugin is a package\.

  1. The name of a plugin package has the form
     doctools::toc::import::__FOO__, where __FOO__ is the name of the
     format the plugin will generate output for\. This name is also the argument
     to provide to the various __import__ methods of import manager objects
     to get a string encoding a table of contents in that format\.

  1. The plugin can expect that the package
     __doctools::toc::export::plugin__ is present, as indicator that it was
     invoked from a genuine plugin manager\.

  1. The plugin can expect that a command named __IncludeFile__ is present,
     with the signature

       - <a name='16'></a>__IncludeFile__ *currentfile* *path*

         This command has to be invoked by the plugin when it has to process an
         included file, if the format has the concept of such\. An example of
         such a format would be *[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)*\.

         The plugin has to supply the following arguments

           * string *currentfile*

             The path of the file it is currently processing\. This may be the
             empty string if no such is known\.

           * string *path*

             The path of the include file as specified in the include directive
             being processed\.

         The result of the command will be a 5\-element list containing

           1) A boolean flag indicating the success \(__True__\) or failure
              \(__False__\) of the operation\.

           1) In case of success the contents of the included file, and the
              empty string otherwise\.

           1) The resolved, i\.e\. absolute path of the included file, if
              possible, or the unchanged *path* argument\. This is for display
              in an error message, or as the *currentfile* argument of another
              call to __IncludeFile__ should this file contain more files\.

           1) In case of success an empty string, and for failure a code
              indicating the reason for it, one of

                * notfound

                  The specified file could not be found\.

                * notread

                  The specified file was found, but not be read into memory\.

           1) An empty string in case of success of a __notfound__ failure,
              and an additional error message describing the reason for a
              __notread__ error in more detail\.

  1. A plugin has to provide one command, with the signature shown below\.

       - <a name='17'></a>__[import](\.\./\.\./\.\./\.\./index\.md\#import)__ *text* *configuration*

         Whenever an import manager of
         __[doctools::toc](\.\./doctools/doctoc\.md)__ has to parse input
         for a table of contents it will invoke this command\.

           * string *text*

             This argument will contain the text encoding the table of contents
             per the format the plugin is for\.

           * dictionary *configuration*

             This argument will contain the current configuration to apply to
             the parsing, as a dictionary mapping from variable names to values\.

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

  1. A single usage cycle of a plugin consists of the invokations of the command
     __[import](\.\./\.\./\.\./\.\./index\.md\#import)__\. This call has to leave
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

[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc),
[documentation](\.\./\.\./\.\./\.\./index\.md\#documentation),
[import](\.\./\.\./\.\./\.\./index\.md\#import),
[json](\.\./\.\./\.\./\.\./index\.md\#json),
[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin),
[reference](\.\./\.\./\.\./\.\./index\.md\#reference),
[table](\.\./\.\./\.\./\.\./index\.md\#table), [table of
contents](\.\./\.\./\.\./\.\./index\.md\#table\_of\_contents),
[url](\.\./\.\./\.\./\.\./index\.md\#url)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
