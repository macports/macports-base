
[//000000001]: # (bibtex \- bibtex)
[//000000002]: # (Generated from file 'bibtex\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 for documentation, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (bibtex\(n\) 0\.7 tcllib "bibtex")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

bibtex \- Parse bibtex files

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require bibtex ?0\.7?  

[__::bibtex::parse__ ?*options*? ?*text*?](#1)  
[__::bibtex::parse__ *text*](#2)  
[__::bibtex::parse__ ?__\-command__ *cmd*? __\-channel__ *chan*](#3)  
[__::bibtex::parse__ ?__\-recordcommand__   *recordcmd*? ?__\-preamblecommand__ *preamblecmd*? ?__\-stringcommand__   *stringcmd*? ?__\-commentcommand__  *commentcmd*? ?__\-progresscommand__ *progresscmd*? ?__\-casesensitivestrings__ *bool*? \(*text* &#124; __\-channel__ *chan*\)](#4)  
[__::bibtex::wait__ *token*](#5)  
[__::bibtex::destroy__ *token*](#6)  
[__::bibtex::addStrings__ *token* *stringdict*](#7)  

# <a name='description'></a>DESCRIPTION

This package provides commands for the parsing of bibliographies in BibTeX
format\.

  - <a name='1'></a>__::bibtex::parse__ ?*options*? ?*text*?

    This is the general form of the command for parsing a bibliography\.
    Depending on the options used to invoke it it will either return a token for
    the parser, or the parsed entries of the input bibliography\. Instead of
    performing an immediate parse returning a predefined format the command can
    also enter an event\-based parsing style where all relevant entries in the
    input are reported through callback commands, in the style of SAX\.

  - <a name='2'></a>__::bibtex::parse__ *text*

    In this form the command will assume that the specified *text* is a
    bibliography in BibTeX format, parse it, and then return a list containing
    one element per record found in the bibliography\. Note that comments, string
    definitions, preambles, etc\. will not show up in the result\. Each element
    will be a list containing record type, bibliography key and record data, in
    this order\. The record data will be a dictionary, its keys the keys of the
    record, with the associated values\.

  - <a name='3'></a>__::bibtex::parse__ ?__\-command__ *cmd*? __\-channel__ *chan*

    In this form the command will reads the bibliography from the specified Tcl
    channel *chan* and then returns the same data structure as described
    above\.

    If however the option __\-command__ is specified the result will be a
    handle for the parser instead and all processing will be incremental and
    happen in the background\. When the input has been exhausted the callback
    *cmd* will be invoked with the result of the parse\. The exact definition
    for the callback is

      * __cmd__ *token* *parseresult*

        The parse result will have the structure explained above, for the
        simpler forms of the parser\.

    *Note* that the parser will *not* close the channel after it has
    exhausted it\. This is still the responsibility of the user of the parser\.

  - <a name='4'></a>__::bibtex::parse__ ?__\-recordcommand__   *recordcmd*? ?__\-preamblecommand__ *preamblecmd*? ?__\-stringcommand__   *stringcmd*? ?__\-commentcommand__  *commentcmd*? ?__\-progresscommand__ *progresscmd*? ?__\-casesensitivestrings__ *bool*? \(*text* &#124; __\-channel__ *chan*\)

    This is the most low\-level form for the parser\. The returned result will be
    a handle for the parser\. During processing it will invoke the invoke the
    specified callback commands for each type of data found in the bibliography\.

    The processing will be incremental and happen in the background if, and only
    if a Tcl channel *chan* is specified\. For a *text* the processing will
    happen immediately and all callbacks will be invoked before the command
    itself returns\.

    The callbacks, i\.e\. *\*cmd*, are all command prefixes and will be invoked
    with additional arguments appended to them\. The meaning of the arguments
    depends on the callback and is explained below\. The first argument will
    however always be the handle of the parser invoking the callback\.

      * __\-casesensitivestrings__

        This option takes a boolean value\. When set string macro processing
        becomes case\-sensitive\. The default is case\-insensitive string macro
        processing\.

      * __recordcmd__ *token* *type* *key* *recorddict*

        This callback is invoked whenever the parser detects a bibliography
        record in the input\. Its arguments are the record type, the bibliography
        key for the record, and a dictionary containing the keys and values
        describing the record\. Any string macros known to the parser have
        already been expanded\.

      * __preamblecmd__ *token* *preambletext*

        This callback is invoked whenever the parser detects an @preamble block
        in the input\. The only additional argument is the text found in the
        preamble block\. By default such entries are ignored\.

      * __stringcmd__ *token* *stringdict*

        This callback is invoked whenever the parser detects an @string\-based
        macro definition in the input\. The argument is a dictionary with the
        macro names as keys and their replacement strings as values\. By default
        such definitions are added to the parser state for use in future
        bibliography records\.

      * __commentcmd__ *token* *commenttext*

        This callback is invoked whenever the parser detects a comment in the
        input\. The only additional argument is the comment text\. By default such
        entries are ignored\.

      * __progresscmd__ *token* *percent*

        This callback is invoked during processing to tell the user about the
        progress which has been made\. Its argument is the percentage of data
        processed, as integer number between __0__ and __100__\. In the
        case of incremental processing the perecentage will always be __\-1__
        as the total number of entries is not known beforehand\.

  - <a name='5'></a>__::bibtex::wait__ *token*

    This command waits for the parser represented by the *token* to complete
    and then returns\. The returned result is the empty string\.

  - <a name='6'></a>__::bibtex::destroy__ *token*

    This command cleans up all internal state associated with the parser
    represented by the handle *token*, effectively destroying it\. This command
    can be called from within the parser callbacks to terminate processing\.

  - <a name='7'></a>__::bibtex::addStrings__ *token* *stringdict*

    This command adds the macro definitions stored in the dictionary
    *stringdict* to the parser represented by the handle *token*\.

    The dictionary keys are the macro names and the values their replacement
    strings\. This command has the correct signature for use as a
    __\-stringcommand__ callback in an invokation of the command
    __::bibtex::parse__\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *bibtex* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[bibliography](\.\./\.\./\.\./\.\./index\.md\#bibliography),
[bibtex](\.\./\.\./\.\./\.\./index\.md\#bibtex),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 for documentation, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
