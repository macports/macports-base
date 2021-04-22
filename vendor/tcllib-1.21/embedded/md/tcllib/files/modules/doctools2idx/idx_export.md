
[//000000001]: # (doctools::idx::export \- Documentation tools)
[//000000002]: # (Generated from file 'idx\_export\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::idx::export\(n\) 0\.2\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::idx::export \- Exporting keyword indices

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

  - [Keyword index serialization format](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require doctools::idx::export ?0\.2\.1?  
package require Tcl 8\.4  
package require struct::map  
package require doctools::idx::structure  
package require snit  
package require pluginmgr  

[__::doctools::idx::export__ *objectName*](#1)  
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

This package provides a class to manage the plugins for the export of keyword
indices to other formats, i\.e\. their conversion to, for example
*[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx)*,
*[HTML](\.\./\.\./\.\./\.\./index\.md\#html)*, etc\.

This is one of the three public pillars the management of keyword indices
resides on\. The other two pillars are

  1. *[Importing keyword indices](idx\_import\.md)*, and

  1. *[Holding keyword indices](idx\_container\.md)*

For information about the [Concepts](#section2) of keyword indices, and
their parts, see the same\-named section\. For information about the data
structure which is the major input to the manager objects provided by this
package see the section [Keyword index serialization format](#section5)\.

The plugin system of our class is based on the package
__[pluginmgr](\.\./pluginmgr/pluginmgr\.md)__, and configured to look for
plugins using

  1. the environment variable __DOCTOOLS\_IDX\_EXPORT\_PLUGINS__,

  1. the environment variable __DOCTOOLS\_IDX\_PLUGINS__,

  1. the environment variable __DOCTOOLS\_PLUGINS__,

  1. the path "~/\.doctools/idx/export/plugin"

  1. the path "~/\.doctools/idx/plugin"

  1. the path "~/\.doctools/plugin"

  1. the path "~/\.doctools/idx/export/plugins"

  1. the path "~/\.doctools/idx/plugins"

  1. the path "~/\.doctools/plugins"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\IDX\\EXPORT\\PLUGINS"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\IDX\\PLUGINS"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\DOCTOOLS\\PLUGINS"

The last three are used only when the package is run on a machine using
Windows\(tm\) operating system\.

The whole system is delivered with six predefined export plugins, namely

  - docidx

    See *[docidx export plugin](export\_docidx\.md)* for details\.

  - html

    See *html export plugin* for details\.

  - json

    See *json export plugin* for details\.

  - nroff

    See *[nroff export plugin](\.\./doctools2toc/toc\_export\_nroff\.md)* for
    details\.

  - text

    See *text export plugin* for details\.

  - wiki

    See *[wiki export plugin](\.\./doctools2toc/toc\_export\_wiki\.md)* for
    details\.

Readers wishing to write their own export plugin for some format, i\.e\. *plugin
writer*s reading and understanding the section containing the [Export plugin
API v2 reference](#section4) is an absolute necessity, as it specifies the
interaction between this package and its plugins in detail\.

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

  - <a name='1'></a>__::doctools::idx::export__ *objectName*

    This command creates a new export manager object with an associated Tcl
    command whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The object command will be created under the
    current namespace if the *objectName* is not fully qualified, and in the
    specified namespace otherwise\.

## <a name='subsection2'></a>Object command

All objects created by the __::doctools::idx::export__ command have the
following general form:

  - <a name='2'></a>__objectName__ __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object it is invoked for\.

  - <a name='4'></a>*objectName* __export serial__ *serial* ?*format*?

    This method takes the canonical serialization of a keyword index stored in
    *serial* and converts it to the specified *format*, using the export
    plugin for the format\. An error is thrown if no plugin could be found for
    the format\. The string generated by the conversion process is returned as
    the result of this method\.

    If no format is specified the method defaults to __docidx__\.

    The specification of what a *canonical* serialization is can be found in
    the section [Keyword index serialization format](#section5)\.

    The plugin has to conform to the interface specified in section [Export
    plugin API v2 reference](#section4)\.

  - <a name='5'></a>*objectName* __export object__ *object* ?*format*?

    This method is a convenient wrapper around the __export serial__ method
    described by the previous item\. It expects that *object* is an object
    command supporting a __serialize__ method returning the canonical
    serialization of a keyword index\. It invokes that method, feeds the result
    into __export serial__ and returns the resulting string as its own
    result\.

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
beyond the [Keyword index serialization format](#section5)\. Here we specify
the API the objects created by this package use to interact with their plugins\.

A plugin for this package has to follow the rules listed below:

  1. A plugin is a package\.

  1. The name of a plugin package has the form
     doctools::idx::export::__FOO__, where __FOO__ is the name of the
     format the plugin will generate output for\. This name is also the argument
     to provide to the various __export__ methods of export manager objects
     to get a string encoding a keyword index in that format\.

  1. The plugin can expect that the package
     __doctools::idx::export::plugin__ is present, as indicator that it was
     invoked from a genuine plugin manager\.

  1. A plugin has to provide one command, with the signature shown below\.

       - <a name='10'></a>__[export](\.\./\.\./\.\./\.\./index\.md\#export)__ *serial* *configuration*

         Whenever an export manager of
         __[doctools::idx](idx\_container\.md)__ has to generate output
         for an index it will invoke this command\.

           * string *serial*

             This argument will contain the *canonical* serialization of the
             index for which to generate the output\. The specification of what a
             *canonical* serialization is can be found in the section
             [Keyword index serialization format](#section5)\.

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

                 This variable, if defined by the user of the index object is
                 expected to contain the name of the input file for which the
                 plugin is generating its output for\.

               + map

                 This variable, if defined by the user of the index object is
                 expected to contain a dictionary mapping from symbolic file
                 names used in the references of type __manpage__ to actual
                 paths \(or urls\)\. A plugin has to be able to handle the
                 possibility that a symbolic name is without entry in this
                 mapping\.

  1. A single usage cycle of a plugin consists of the invokations of the command
     __[export](\.\./\.\./\.\./\.\./index\.md\#export)__\. This call has to leave
     the plugin in a state where another usage cycle can be run without
     problems\.

# <a name='section5'></a>Keyword index serialization format

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
[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx),
[documentation](\.\./\.\./\.\./\.\./index\.md\#documentation),
[export](\.\./\.\./\.\./\.\./index\.md\#export),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[generation](\.\./\.\./\.\./\.\./index\.md\#generation),
[index](\.\./\.\./\.\./\.\./index\.md\#index), [json](\.\./\.\./\.\./\.\./index\.md\#json),
[keyword index](\.\./\.\./\.\./\.\./index\.md\#keyword\_index),
[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[nroff](\.\./\.\./\.\./\.\./index\.md\#nroff),
[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin),
[reference](\.\./\.\./\.\./\.\./index\.md\#reference), [tcler's
wiki](\.\./\.\./\.\./\.\./index\.md\#tcler\_s\_wiki),
[text](\.\./\.\./\.\./\.\./index\.md\#text), [url](\.\./\.\./\.\./\.\./index\.md\#url),
[wiki](\.\./\.\./\.\./\.\./index\.md\#wiki)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
