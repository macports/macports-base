
[//000000001]: # (textutil::adjust \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'adjust\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil::adjust\(n\) 0\.7\.3 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::adjust \- Procedures to adjust, indent, and undent paragraphs

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
package require textutil::adjust ?0\.7\.3?  

[__::textutil::adjust::adjust__ *string* ?*option value\.\.\.*?](#1)  
[__::textutil::adjust::readPatterns__ *filename*](#2)  
[__::textutil::adjust::listPredefined__](#3)  
[__::textutil::adjust::getPredefined__ *filename*](#4)  
[__::textutil::adjust::indent__ *string* *prefix* ?*skip*?](#5)  
[__::textutil::adjust::undent__ *string*](#6)  

# <a name='description'></a>DESCRIPTION

The package __textutil::adjust__ provides commands that manipulate strings
or texts \(a\.k\.a\. long strings or string with embedded newlines or paragraphs\),
adjusting, or indenting them\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::textutil::adjust::adjust__ *string* ?*option value\.\.\.*?

    Do a justification on the *string* according to the options\. The string is
    taken as one big paragraph, ignoring any newlines\. Then the line is
    formatted according to the options used, and the command returns a new
    string with enough lines to contain all the printable chars in the input
    string\. A line is a set of characters between the beginning of the string
    and a newline, or between 2 newlines, or between a newline and the end of
    the string\. If the input string is small enough, the returned string won't
    contain any newlines\.

    Together with __::textutil::adjust::indent__ it is possible to create
    properly wrapped paragraphs with arbitrary indentations\.

    By default, any occurrence of space or tabulation characters are replaced by
    a single space so that each word in a line is separated from the next one by
    exactly one space character, and this forms a *real* line\. Each *real*
    line is placed in a *logical* line, which has exactly a given length \(see
    the option __\-length__ below\)\. The *real* line may be shorter\. Again
    by default, trailing spaces are ignored before returning the string \(see the
    option __\-full__ below\)\.

    The following options may be used after the *string* parameter, and change
    the way the command places a *real* line in a *logical* line\.

      * __\-full__ *boolean*

        If set to __false__ \(default\), trailing space characters are deleted
        before returning the string\. If set to __true__, any trailing space
        characters are left in the string\.

      * __\-hyphenate__ *boolean*

        If set to __false__ \(default\), no hyphenation will be done\. If set
        to __true__, the command will try to hyphenate the last word of a
        line\. *Note*: Hyphenation patterns must be loaded prior, using the
        command __::textutil::adjust::readPatterns__\.

      * __\-justify__ __center&#124;left&#124;plain&#124;right__

        Sets the justification of the returned string to either __left__
        \(default\), __center__, __plain__ or __right__\. The
        justification means that any line in the returned string but the last
        one is build according to the value\. If the justification is set to
        __plain__ and the number of printable chars in the last line is less
        than 90% of the length of a line \(see the option __\-length__\), then
        this line is justified with the __left__ value, avoiding the
        expansion of this line when it is too small\. The meaning of each value
        is:

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

        If set to __false__ \(default\), a line can exceed the specified
        __\-length__ if a single word is longer than __\-length__\. If set
        to __true__, words that are longer than __\-length__ are split so
        that no line exceeds the specified __\-length__\.

  - <a name='2'></a>__::textutil::adjust::readPatterns__ *filename*

    Loads the internal storage for hyphenation patterns with the contents of the
    file *filename*\. This has to be done prior to calling command
    __::textutil::adjust::adjust__ with "__\-hyphenate__ __true__",
    or the hyphenation process will not work correctly\.

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

  - <a name='5'></a>__::textutil::adjust::indent__ *string* *prefix* ?*skip*?

    Each line in the *string* is indented by adding the string *prefix* at
    its beginning\. The modified string is returned as the result of the command\.

    If *skip* is specified the first *skip* lines are left untouched\. The
    default for *skip* is __0__, causing the modification of all lines\.
    Negative values for *skip* are treated like __0__\. In other words,
    *skip* > __0__ creates a hanging indentation\.

    Together with __::textutil::adjust::adjust__ it is possible to create
    properly wrapped paragraphs with arbitrary indentations\.

  - <a name='6'></a>__::textutil::adjust::undent__ *string*

    The command computes the common prefix for all lines in *string*
    consisting solely out of whitespace, removes this from each line and returns
    the modified string\.

    Lines containing only whitespace are always reduced to completely empty
    lines\. They and empty lines are also ignored when computing the prefix to
    remove\.

    Together with __::textutil::adjust::adjust__ it is possible to create
    properly wrapped paragraphs with arbitrary indentations\.

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
[adjusting](\.\./\.\./\.\./\.\./index\.md\#adjusting),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[hyphenation](\.\./\.\./\.\./\.\./index\.md\#hyphenation),
[indenting](\.\./\.\./\.\./\.\./index\.md\#indenting),
[justification](\.\./\.\./\.\./\.\./index\.md\#justification),
[paragraph](\.\./\.\./\.\./\.\./index\.md\#paragraph),
[string](\.\./\.\./\.\./\.\./index\.md\#string),
[undenting](\.\./\.\./\.\./\.\./index\.md\#undenting)

# <a name='category'></a>CATEGORY

Text processing
