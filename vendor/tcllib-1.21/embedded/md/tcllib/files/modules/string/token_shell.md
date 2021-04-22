
[//000000001]: # (string::token::shell \- Text and string utilities)
[//000000002]: # (Generated from file 'token\_shell\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (string::token::shell\(n\) 1\.2 tcllib "Text and string utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

string::token::shell \- Parsing of shell command line

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require string::token::shell ?1\.2?  
package require string::token ?1?  
package require fileutil  

[__::string token shell__ ?__\-indices__? ?__\-partial__? ?\-\-? *string*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a command which parses a line of text using basic
__sh__\-syntax into a list of words\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::string token shell__ ?__\-indices__? ?__\-partial__? ?\-\-? *string*

    This command parses the input *string* under the assumption of it
    following basic __sh__\-syntax\. The result of the command is a list of
    words in the *string*\. An error is thrown if the input does not follow the
    allowed syntax\. The behaviour can be modified by specifying any of the two
    options __\-indices__ and __\-partial__\.

      * __\-\-__

        When specified option parsing stops at this point\. This option is needed
        if the input *string* may start with dash\. In other words, this is
        pretty much required if *string* is user input\.

      * __\-indices__

        When specified the output is not a list of words, but a list of 4\-tuples
        describing the words\. Each tuple contains the type of the word, its
        start\- and end\-indices in the input, and the actual text of the word\.

        Note that the length of the word as given by the indices can differ from
        the length of the word found in the last element of the tuple\. The
        indices describe the words extent in the input, including delimiters,
        intra\-word quoting, etc\. whereas for the actual text of the word
        delimiters are stripped, intra\-word quoting decoded, etc\.

        The possible token types are

          + __PLAIN__

            Plain word, not quoted\.

          + __D:QUOTED__

            Word is delimited by double\-quotes\.

          + __S:QUOTED__

            Word is delimited by single\-quotes\.

          + __D:QUOTED:PART__

          + __S:QUOTED:PART__

            Like the previous types, but the word has no closing quote, i\.e\. is
            incomplete\. These token types can occur if and only if the option
            __\-partial__ was specified, and only for the last word of the
            result\. If the option __\-partial__ was not specified such
            incomplete words cause the command to thrown an error instead\.

      * __\-partial__

        When specified the parser will accept an incomplete quoted word \(i\.e\.
        without closing quote\) at the end of the line as valid instead of
        throwing an error\.

    The basic shell syntax accepted here are unquoted, single\- and double\-quoted
    words, separated by whitespace\. Leading and trailing whitespace are possible
    too, and stripped\. Shell variables in their various forms are *not*
    recognized, nor are sub\-shells\. As for the recognized forms of words, see
    below for the detailed specification\.

      * __single\-quoted word__

        A single\-quoted word begins with a single\-quote character, i\.e\.
        __'__ \(ASCII 39\) followed by zero or more unicode characters not a
        single\-quote, and then closed by a single\-quote\.

        The word must be followed by either the end of the string, or
        whitespace\. A word cannot directly follow the word\.

      * __double\-quoted word__

        A double\-quoted word begins with a double\-quote character, i\.e\.
        __"__ \(ASCII 34\) followed by zero or more unicode characters not a
        double\-quote, and then closed by a double\-quote\.

        Contrary to single\-quoted words a double\-quote can be embedded into the
        word, by prefacing, i\.e\. escaping, i\.e\. quoting it with a backslash
        character __\\__ \(ASCII 92\)\. Similarly a backslash character must be
        quoted with itself to be inserted literally\.

      * __unquoted word__

        Unquoted words are not delimited by quotes and thus cannot contain
        whitespace or single\-quote characters\. Double\-quote and backslash
        characters can be put into unquoted words, by quting them like for
        double\-quoted words\.

      * __whitespace__

        Whitespace is any unicode space character\. This is equivalent to
        __string is space__, or the regular expression \\\\s\.

        Whitespace may occur before the first word, or after the last word\.
        Whitespace must occur between adjacent words\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *textutil* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[bash](\.\./\.\./\.\./\.\./index\.md\#bash),
[lexing](\.\./\.\./\.\./\.\./index\.md\#lexing),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[shell](\.\./\.\./\.\./\.\./index\.md\#shell),
[string](\.\./\.\./\.\./\.\./index\.md\#string),
[tokenization](\.\./\.\./\.\./\.\./index\.md\#tokenization)

# <a name='category'></a>CATEGORY

Text processing
