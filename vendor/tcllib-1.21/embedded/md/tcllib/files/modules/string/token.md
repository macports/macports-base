
[//000000001]: # (string::token \- Text and string utilities)
[//000000002]: # (Generated from file 'token\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (string::token\(n\) 1 tcllib "Text and string utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

string::token \- Regex based iterative lexing

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require string::token ?1?  
package require fileutil  

[__::string token text__ *lex* *string*](#1)  
[__::string token file__ *lex* *path*](#2)  
[__::string token chomp__ *lex* *startvar* *string* *resultvar*](#3)  

# <a name='description'></a>DESCRIPTION

This package provides commands for regular expression based lexing
\(tokenization\) of strings\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::string token text__ *lex* *string*

    This command takes an ordered dictionary *lex* mapping regular expressions
    to labels, and tokenizes the *string* according to this dictionary\.

    The result of the command is a list of tokens, where each token is a
    3\-element list of label, start\- and end\-index in the *string*\.

    The command will throw an error if it is not able to tokenize the whole
    string\.

  - <a name='2'></a>__::string token file__ *lex* *path*

    This command is a convenience wrapper around __::string token text__
    above, and __fileutil::cat__, enabling the easy tokenization of whole
    files\. *Note* that this command loads the file wholly into memory before
    starting to process it\.

    If the file is too large for this mode of operation a command directly based
    on __::string token chomp__ below will be necessary\.

  - <a name='3'></a>__::string token chomp__ *lex* *startvar* *string* *resultvar*

    This command is the work horse underlying __::string token text__ above\.
    It is exposed to enable users to write their own lexers, which, for example
    may apply different lexing dictionaries according to some internal state,
    etc\.

    The command takes an ordered dictionary *lex* mapping regular expressions
    to labels, a variable *startvar* which indicates where to start lexing in
    the input *string*, and a result variable *resultvar* to extend\.

    The result of the command is a tri\-state numeric code indicating one of

      * __0__

        No token found\.

      * __1__

        Token found\.

      * __2__

        End of string reached\.

    Note that recognition of a token from *lex* is started at the character
    index in *startvar*\.

    If a token was recognized \(status __1__\) the command will update the
    index in *startvar* to point to the first character of the *string* past
    the recognized token, and it will further extend the *resultvar* with a
    3\-element list containing the label associated with the regular expression
    of the token, and the start\- and end\-character\-indices of the token in
    *string*\.

    Neither *startvar* nor *resultvar* will be updated if no token is
    recognized at all\.

    Note that the regular expressions are applied \(tested\) in the order they are
    specified in *lex*, and the first matching pattern stops the process\.
    Because of this it is recommended to specify the patterns to lex with from
    the most specific to the most general\.

    Further note that all regex patterns are implicitly prefixed with the
    constraint escape __A__ to ensure that a match starts exactly at the
    character index found in *startvar*\.

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

[lexing](\.\./\.\./\.\./\.\./index\.md\#lexing),
[regex](\.\./\.\./\.\./\.\./index\.md\#regex),
[string](\.\./\.\./\.\./\.\./index\.md\#string),
[tokenization](\.\./\.\./\.\./\.\./index\.md\#tokenization)

# <a name='category'></a>CATEGORY

Text processing
