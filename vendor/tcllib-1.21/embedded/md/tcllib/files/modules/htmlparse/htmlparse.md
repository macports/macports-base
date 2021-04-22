
[//000000001]: # (htmlparse \- HTML Parser)
[//000000002]: # (Generated from file 'htmlparse\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (htmlparse\(n\) 1\.2\.2 tcllib "HTML Parser")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

htmlparse \- Procedures to parse HTML strings

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require struct::stack 1\.3  
package require cmdline 1\.1  
package require htmlparse ?1\.2\.2?  

[__::htmlparse::parse__ ?\-cmd *cmd*? ?\-vroot *tag*? ?\-split *n*? ?\-incvar *var*? ?\-queue *q*? *html*](#1)  
[__::htmlparse::debugCallback__ ?*clientdata*? *tag slash param textBehindTheTag*](#2)  
[__::htmlparse::mapEscapes__ *html*](#3)  
[__::htmlparse::2tree__ *html tree*](#4)  
[__::htmlparse::removeVisualFluff__ *tree*](#5)  
[__::htmlparse::removeFormDefs__ *tree*](#6)  

# <a name='description'></a>DESCRIPTION

The __htmlparse__ package provides commands that allow libraries and
applications to parse HTML in a string into a representation of their choice\.

The following commands are available:

  - <a name='1'></a>__::htmlparse::parse__ ?\-cmd *cmd*? ?\-vroot *tag*? ?\-split *n*? ?\-incvar *var*? ?\-queue *q*? *html*

    This command is the basic parser for HTML\. It takes an HTML string, parses
    it and invokes a command prefix for every tag encountered\. It is not
    necessary for the HTML to be valid for this parser to function\. It is the
    responsibility of the command invoked for every tag to check this\. Another
    responsibility of the invoked command is the handling of tag attributes and
    character entities \(escaped characters\)\. The parser provides the
    un\-interpreted tag attributes to the invoked command to aid in the former,
    and the package at large provides a helper command,
    __::htmlparse::mapEscapes__, to aid in the handling of the latter\. The
    parser *does* ignore leading DOCTYPE declarations and all valid HTML
    comments it encounters\.

    All information beyond the HTML string itself is specified via options,
    these are explained below\.

    To help understand the options, some more background information about the
    parser\.

    It is capable of detecting incomplete tags in the HTML string given to it\.
    Under normal circumstances this will cause the parser to throw an error, but
    if the option *\-incvar* is used to specify a global \(or namespace\)
    variable, the parser will store the incomplete part of the input into this
    variable instead\. This will aid greatly in the handling of incrementally
    arriving HTML, as the parser will handle whatever it can and defer the
    handling of the incomplete part until more data has arrived\.

    Another feature of the parser are its two possible modes of operation\. The
    normal mode is activated if the option *\-queue* is not present on the
    command line invoking the parser\. If it is present, the parser will go into
    the incremental mode instead\.

    The main difference is that a parser in normal mode will immediately invoke
    the command prefix for each tag it encounters\. In incremental mode however
    the parser will generate a number of scripts which invoke the command prefix
    for groups of tags in the HTML string and then store these scripts in the
    specified queue\. It is then the responsibility of the caller of the parser
    to ensure the execution of the scripts in the queue\.

    *Note*: The queue object given to the parser has to provide the same
    interface as the queue defined in tcllib \-> struct\. This means, for example,
    that all queues created via that tcllib module can be immediately used here\.
    Still, the queue doesn't have to come from tcllib \-> struct as long as the
    same interface is provided\.

    In both modes the parser will return an empty string to the caller\.

    The *\-split* option may be given to a parser in incremental mode to
    specify the size of the groups it creates\. In other words, \-split 5 means
    that each of the generated scripts will invoke the command prefix for 5
    consecutive tags in the HTML string\. A parser in normal mode will ignore
    this option and its value\.

    The option *\-vroot* specifies a virtual root tag\. A parser in normal mode
    will invoke the command prefix for it immediately before and after it
    processes the tags in the HTML, thus simulating that the HTML string is
    enclosed in a <vroot> </vroot> combination\. In incremental mode however the
    parser is unable to provide the closing virtual root as it never knows when
    the input is complete\. In this case the first script generated by each
    invocation of the parser will contain an invocation of the command prefix
    for the virtual root as its first command\. The following options are
    available:

      * __\-cmd__ *cmd*

        The command prefix to invoke for every tag in the HTML string\. Defaults
        to *::htmlparse::debugCallback*\.

      * __\-vroot__ *tag*

        The virtual root tag to add around the HTML in normal mode\. In
        incremental mode it is the first tag in each chunk processed by the
        parser, but there will be no closing tags\. Defaults to *hmstart*\.

      * __\-split__ *n*

        The size of the groups produced by an incremental mode parser\. Ignored
        when in normal mode\. Defaults to 10\. Values <= 0 are not allowed\.

      * __\-incvar__ *var*

        The name of the variable where to store any incomplete HTML into\. This
        makes most sense for the incremental mode\. The parser will throw an
        error if it sees incomplete HTML and has no place to store it to\. This
        makes sense for the normal mode\. Only incomplete tags are detected, not
        missing tags\. Optional, defaults to 'no variable'\.

      * *Interface to the command prefix*

        In normal mode the parser will invoke the command prefix with four
        arguments appended\. See __::htmlparse::debugCallback__ for a
        description\.

        In incremental mode, however, the generated scripts will invoke the
        command prefix with five arguments appended\. The last four of these are
        the same which were mentioned above\. The first is a placeholder string
        \(__@win@__\) for a clientdata value to be supplied later during the
        actual execution of the generated scripts\. This could be a tk window
        path, for example\. This allows the user of this package to preprocess
        HTML strings without committing them to a specific window, object,
        whatever during parsing\. This connection can be made later\. This also
        means that it is possible to cache preprocessed HTML\. Of course, nothing
        prevents the user of the parser from replacing the placeholder with an
        empty string\.

  - <a name='2'></a>__::htmlparse::debugCallback__ ?*clientdata*? *tag slash param textBehindTheTag*

    This command is the standard callback used by the parser in
    __::htmlparse::parse__ if none was specified by the user\. It simply
    dumps its arguments to stdout\. This callback can be used for both normal and
    incremental mode of the calling parser\. In other words, it accepts four or
    five arguments\. The last four arguments are described below\. The optional
    fifth argument contains the clientdata value passed to the callback by a
    parser in incremental mode\. All callbacks have to follow the signature of
    this command in the last four arguments, and callbacks used in incremental
    parsing have to follow this signature in the last five arguments\.

    The first argument, *clientdata*, is optional and present only if this
    command is invoked by a parser in incremental mode\. It contains whatever the
    user of this package wishes\.

    The second argument, *tag*, contains the name of the tag which is
    currently processed by the parser\.

    The third argument, *slash*, is either empty or contains a slash
    character\. It allows the callback to distinguish between opening \(slash is
    empty\) and closing tags \(slash contains a slash character\)\.

    The fourth argument, *param*, contains the un\-interpreted list of
    parameters to the tag\.

    The fifth and last argument, *textBehindTheTag*, contains the text found
    by the parser behind the tag named in *tag*\.

  - <a name='3'></a>__::htmlparse::mapEscapes__ *html*

    This command takes a HTML string, substitutes all escape sequences with
    their actual characters and then returns the resulting string\. HTML strings
    which do not contain escape sequences are returned unchanged\.

  - <a name='4'></a>__::htmlparse::2tree__ *html tree*

    This command is a wrapper around __::htmlparse::parse__ which takes an
    HTML string \(in *html*\) and converts it into a tree containing the logical
    structure of the parsed document\. The name of the tree is given to the
    command as its second argument \(*tree*\)\. The command does __not__
    generate the tree by itself but expects that the caller provided it with an
    existing and empty tree\. It also expects that the specified tree object
    follows the same interface as the tree object in tcllib \-> struct\. It
    doesn't have to be from tcllib \-> struct, but it must provide the same
    interface\.

    The internal callback does some basic checking of HTML validity and tries to
    recover from the most basic errors\. The command returns the contents of its
    second argument\. Side effects are the creation and manipulation of a tree
    object\.

    Each node in the generated tree represent one tag in the input\. The name of
    the tag is stored in the attribute *type* of the node\. Any html attributes
    coming with the tag are stored unmodified in the attribute *data* of the
    tag\. In other words, the command does *not* parse html attributes into
    their names and values\.

    If a tag contains text its node will have children of type *PCDATA*
    containing this text\. The text will be stored in the attribute *data* of
    these children\.

  - <a name='5'></a>__::htmlparse::removeVisualFluff__ *tree*

    This command walks a tree as generated by __::htmlparse::2tree__ and
    removes all the nodes which represent visual tags and not structural ones\.
    The purpose of the command is to make the tree easier to navigate without
    getting bogged down in visual information not relevant to the search\. Its
    only argument is the name of the tree to cut down\.

  - <a name='6'></a>__::htmlparse::removeFormDefs__ *tree*

    Like __::htmlparse::removeVisualFluff__ this command is here to cut down
    on the size of the tree as generated by __::htmlparse::2tree__\. It
    removes all nodes representing forms and form elements\. Its only argument is
    the name of the tree to cut down\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *htmlparse* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[struct::tree](\.\./struct/struct\_tree\.md)

# <a name='keywords'></a>KEYWORDS

[html](\.\./\.\./\.\./\.\./index\.md\#html),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[queue](\.\./\.\./\.\./\.\./index\.md\#queue), [tree](\.\./\.\./\.\./\.\./index\.md\#tree)

# <a name='category'></a>CATEGORY

Text processing
