
[//000000001]: # (textutil \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'textutil\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil\(n\) 0\.8 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil \- Procedures to manipulate texts and strings\.

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
package require textutil ?0\.8?  

[__::textutil::adjust__ *string args*](#1)  
[__::textutil::adjust::readPatterns__ *filename*](#2)  
[__::textutil::adjust::listPredefined__](#3)  
[__::textutil::adjust::getPredefined__ *filename*](#4)  
[__::textutil::indent__ *string* *prefix* ?*skip*?](#5)  
[__::textutil::undent__ *string*](#6)  
[__::textutil::splitn__ *string* ?*len*?](#7)  
[__::textutil::splitx__ *string* ?*regexp*?](#8)  
[__::textutil::tabify__ *string* ?*num*?](#9)  
[__::textutil::tabify2__ *string* ?*num*?](#10)  
[__::textutil::trim__ *string* ?*regexp*?](#11)  
[__::textutil::trimleft__ *string* ?*regexp*?](#12)  
[__::textutil::trimright__ *string* ?*regexp*?](#13)  
[__::textutil::trimPrefix__ *string* *prefix*](#14)  
[__::textutil::trimEmptyHeading__ *string*](#15)  
[__::textutil::untabify__ *string* ?*num*?](#16)  
[__::textutil::untabify2__ *string* ?*num*?](#17)  
[__::textutil::strRepeat__ *text num*](#18)  
[__::textutil::blank__ *num*](#19)  
[__::textutil::chop__ *string*](#20)  
[__::textutil::tail__ *string*](#21)  
[__::textutil::cap__ *string*](#22)  
[__::textutil::uncap__ *string*](#23)  
[__::textutil::longestCommonPrefixList__ *list*](#24)  
[__::textutil::longestCommonPrefix__ ?*string*\.\.\.?](#25)  

# <a name='description'></a>DESCRIPTION

The package __textutil__ provides commands that manipulate strings or texts
\(a\.k\.a\. long strings or string with embedded newlines or paragraphs\)\. It is
actually a bundle providing the commands of the six packages

  - __[textutil::adjust](adjust\.md)__

  - __[textutil::repeat](repeat\.md)__

  - __[textutil::split](textutil\_split\.md)__

  - __[textutil::string](textutil\_string\.md)__

  - __[textutil::tabify](tabify\.md)__

  - __[textutil::trim](trim\.md)__

in the namespace __textutil__\.

The bundle is *deprecated*, and it will be removed in a future release of
Tcllib, after the next release\. It is recommended to use the relevant sub
packages instead for whatever functionality is needed by the using package or
application\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::textutil::adjust__ *string args*

    Do a justification on the *string* according to *args*\. The string is
    taken as one big paragraph, ignoring any newlines\. Then the line is
    formatted according to the options used, and the command return a new string
    with enough lines to contain all the printable chars in the input string\. A
    line is a set of chars between the beginning of the string and a newline, or
    between 2 newlines, or between a newline and the end of the string\. If the
    input string is small enough, the returned string won't contain any
    newlines\.

    Together with __::textutil::indent__ it is possible to create properly
    wrapped paragraphs with arbitrary indentations\.

    By default, any occurrence of spaces characters or tabulation are replaced
    by a single space so each word in a line is separated from the next one by
    exactly one space char, and this forms a *real* line\. Each *real* line
    is placed in a *logical* line, which have exactly a given length \(see
    __\-length__ option below\)\. The *real* line may have a lesser length\.
    Again by default, any trailing spaces are ignored before returning the
    string \(see __\-full__ option below\)\. The following options may be used
    after the *string* parameter, and change the way the command place a
    *real* line in a *logical* line\.

      * \-full *boolean*

        If set to __false__, any trailing space chars are deleted before
        returning the string\. If set to __true__, any trailing space chars
        are left in the string\. Default to __false__\.

      * __\-hyphenate__ *boolean*

        if set to __false__, no hyphenation will be done\. If set to
        __true__, the last word of a line is tried to be hyphenated\.
        Defaults to __false__\. Note: hyphenation patterns must be loaded
        prior, using the command __::textutil::adjust::readPatterns__\.

      * __\-justify__ __center&#124;left&#124;plain&#124;right__

        Set the justification of the returned string to __center__,
        __left__, __plain__ or __right__\. By default, it is set to
        __left__\. The justification means that any line in the returned
        string but the last one is build according to the value\. If the
        justification is set to __plain__ and the number of printable chars
        in the last line is less than 90% of the length of a line \(see
        __\-length__\), then this line is justified with the __left__
        value, avoiding the expansion of this line when it is too small\. The
        meaning of each value is:

          + __center__

            The real line is centered in the logical line\. If needed, a set of
            space characters are added at the beginning \(half of the needed set\)
            and at the end \(half of the needed set\) of the line if required \(see
            the option __\-full__\)\.

          + __left__

            The real line is set on the left of the logical line\. It means that
            there are no space chars at the beginning of this line\. If required,
            all needed space chars are added at the end of the line \(see the
            option __\-full__\)\.

          + __plain__

            The real line is exactly set in the logical line\. It means that
            there are no leading or trailing space chars\. All the needed space
            chars are added in the *real* line, between 2 \(or more\) words\.

          + __right__

            The real line is set on the right of the logical line\. It means that
            there are no space chars at the end of this line, and there may be
            some space chars at the beginning, despite of the __\-full__
            option\.

      * __\-length__ *integer*

        Set the length of the *logical* line in the string to *integer*\.
        *integer* must be a positive integer value\. Defaults to __72__\.

      * __\-strictlength__ *boolean*

        If set to __false__, a line can exceed the specified __\-length__
        if a single word is longer than __\-length__\. If set to __true__,
        words that are longer than __\-length__ are split so that no line
        exceeds the specified __\-length__\. Defaults to __false__\.

  - <a name='2'></a>__::textutil::adjust::readPatterns__ *filename*

    Loads the internal storage for hyphenation patterns with the contents of the
    file *filename*\. This has to be done prior to calling command
    __::textutil::adjust__ with "__\-hyphenate__ __true__", or the
    hyphenation process will not work correctly\.

    The package comes with a number of predefined pattern files, and the command
    __::textutil::adjust::listPredefined__ can be used to find out their
    names\.

  - <a name='3'></a>__::textutil::adjust::listPredefined__

    This command returns a list containing the names of the hyphenation files
    coming with this package\.

  - <a name='4'></a>__::textutil::adjust::getPredefined__ *filename*

    Use this command to query the package for the full path name of the
    hyphenation file *filename* coming with the package\. Only the filenames
    found in the list returned by __::textutil::adjust::listPredefined__ are
    legal arguments for this command\.

  - <a name='5'></a>__::textutil::indent__ *string* *prefix* ?*skip*?

    Each line in the *string* indented by adding the string *prefix* at its
    beginning\. The modified string is returned as the result of the command\.

    If *skip* is specified the first *skip* lines are left untouched\. The
    default for *skip* is __0__, causing the modification of all lines\.
    Negative values for *skip* are treated like __0__\. In other words,
    *skip* > __0__ creates a hanging indentation\.

    Together with __::textutil::adjust__ it is possible to create properly
    wrapped paragraphs with arbitrary indentations\.

  - <a name='6'></a>__::textutil::undent__ *string*

    The command computes the common prefix for all lines in *string*
    consisting solely out of whitespace, removes this from each line and returns
    the modified string\.

    Lines containing only whitespace are always reduced to completely empty
    lines\. They and empty lines are also ignored when computing the prefix to
    remove\.

    Together with __::textutil::adjust__ it is possible to create properly
    wrapped paragraphs with arbitrary indentations\.

  - <a name='7'></a>__::textutil::splitn__ *string* ?*len*?

    This command splits the given *string* into chunks of *len* characters
    and returns a list containing these chunks\. The argument *len* defaults to
    __1__ if none is specified\. A negative length is not allowed and will
    cause the command to throw an error\. Providing an empty string as input is
    allowed, the command will then return an empty list\. If the length of the
    *string* is not an entire multiple of the chunk length, then the last
    chunk in the generated list will be shorter than *len*\.

  - <a name='8'></a>__::textutil::splitx__ *string* ?*regexp*?

    Split the *string* and return a list\. The string is split according to the
    regular expression *regexp* instead of a simple list of chars\. Note that
    if you add parenthesis into the *regexp*, the parentheses part of
    separator would be added into list as additional element\. If the *string*
    is empty the result is the empty list, like for
    __[split](\.\./\.\./\.\./\.\./index\.md\#split)__\. If *regexp* is empty the
    *string* is split at every character, like
    __[split](\.\./\.\./\.\./\.\./index\.md\#split)__ does\. The regular expression
    *regexp* defaults to "\[\\\\t \\\\r\\\\n\]\+"\.

  - <a name='9'></a>__::textutil::tabify__ *string* ?*num*?

    Tabify the *string* by replacing any substring of *num* space chars by a
    tabulation and return the result as a new string\. *num* defaults to 8\.

  - <a name='10'></a>__::textutil::tabify2__ *string* ?*num*?

    Similar to __::textutil::tabify__ this command tabifies the *string*
    and returns the result as a new string\. A different algorithm is used
    however\. Instead of replacing any substring of *num* spaces this command
    works more like an editor\. *num* defaults to 8\.

    Each line of the text in *string* is treated as if there are tabstops
    every *num* columns\. Only sequences of space characters containing more
    than one space character and found immediately before a tabstop are replaced
    with tabs\.

  - <a name='11'></a>__::textutil::trim__ *string* ?*regexp*?

    Remove in *string* any leading and trailing substring according to the
    regular expression *regexp* and return the result as a new string\. This
    apply on any *line* in the string, that is any substring between 2 newline
    chars, or between the beginning of the string and a newline, or between a
    newline and the end of the string, or, if the string contain no newline,
    between the beginning and the end of the string\. The regular expression
    *regexp* defaults to "\[ \\\\t\]\+"\.

  - <a name='12'></a>__::textutil::trimleft__ *string* ?*regexp*?

    Remove in *string* any leading substring according to the regular
    expression *regexp* and return the result as a new string\. This apply on
    any *line* in the string, that is any substring between 2 newline chars,
    or between the beginning of the string and a newline, or between a newline
    and the end of the string, or, if the string contain no newline, between the
    beginning and the end of the string\. The regular expression *regexp*
    defaults to "\[ \\\\t\]\+"\.

  - <a name='13'></a>__::textutil::trimright__ *string* ?*regexp*?

    Remove in *string* any trailing substring according to the regular
    expression *regexp* and return the result as a new string\. This apply on
    any *line* in the string, that is any substring between 2 newline chars,
    or between the beginning of the string and a newline, or between a newline
    and the end of the string, or, if the string contain no newline, between the
    beginning and the end of the string\. The regular expression *regexp*
    defaults to "\[ \\\\t\]\+"\.

  - <a name='14'></a>__::textutil::trimPrefix__ *string* *prefix*

    Removes the *prefix* from the beginning of *string* and returns the
    result\. The *string* is left unchanged if it doesn't have *prefix* at
    its beginning\.

  - <a name='15'></a>__::textutil::trimEmptyHeading__ *string*

    Looks for empty lines \(including lines consisting of only whitespace\) at the
    beginning of the *string* and removes it\. The modified string is returned
    as the result of the command\.

  - <a name='16'></a>__::textutil::untabify__ *string* ?*num*?

    Untabify the *string* by replacing any tabulation char by a substring of
    *num* space chars and return the result as a new string\. *num* defaults
    to 8\.

  - <a name='17'></a>__::textutil::untabify2__ *string* ?*num*?

    Untabify the *string* by replacing any tabulation char by a substring of
    at most *num* space chars and return the result as a new string\. Unlike
    __textutil::untabify__ each tab is not replaced by a fixed number of
    space characters\. The command overlays each line in the *string* with
    tabstops every *num* columns instead and replaces tabs with just enough
    space characters to reach the next tabstop\. This is the complement of the
    actions taken by __::textutil::tabify2__\. *num* defaults to 8\.

    There is one asymmetry though: A tab can be replaced with a single space,
    but not the other way around\.

  - <a name='18'></a>__::textutil::strRepeat__ *text num*

    The implementation depends on the core executing the package\. Used
    __string repeat__ if it is present, or a fast tcl implementation if it
    is not\. Returns a string containing the *text* repeated *num* times\. The
    repetitions are joined without characters between them\. A value of *num*
    <= 0 causes the command to return an empty string\.

  - <a name='19'></a>__::textutil::blank__ *num*

    A convenience command\. Returns a string of *num* spaces\.

  - <a name='20'></a>__::textutil::chop__ *string*

    A convenience command\. Removes the last character of *string* and returns
    the shortened string\.

  - <a name='21'></a>__::textutil::tail__ *string*

    A convenience command\. Removes the first character of *string* and returns
    the shortened string\.

  - <a name='22'></a>__::textutil::cap__ *string*

    Capitalizes the first character of *string* and returns the modified
    string\.

  - <a name='23'></a>__::textutil::uncap__ *string*

    The complementary operation to __::textutil::cap__\. Forces the first
    character of *string* to lower case and returns the modified string\.

  - <a name='24'></a>__::textutil::longestCommonPrefixList__ *list*

  - <a name='25'></a>__::textutil::longestCommonPrefix__ ?*string*\.\.\.?

    Computes the longest common prefix for either the *string*s given to the
    command, or the strings specified in the single *list*, and returns it as
    the result of the command\.

    If no strings were specified the result is the empty string\. If only one
    string was specified, the string itself is returned, as it is its own
    longest common prefix\.

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

# <a name='seealso'></a>SEE ALSO

regexp\(n\), split\(n\), string\(n\)

# <a name='keywords'></a>KEYWORDS

[TeX](\.\./\.\./\.\./\.\./index\.md\#tex),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[hyphenation](\.\./\.\./\.\./\.\./index\.md\#hyphenation),
[indenting](\.\./\.\./\.\./\.\./index\.md\#indenting),
[paragraph](\.\./\.\./\.\./\.\./index\.md\#paragraph), [regular
expression](\.\./\.\./\.\./\.\./index\.md\#regular\_expression),
[string](\.\./\.\./\.\./\.\./index\.md\#string),
[trimming](\.\./\.\./\.\./\.\./index\.md\#trimming)

# <a name='category'></a>CATEGORY

Text processing
