
[//000000001]: # (rcs \- RCS low level utilities)
[//000000002]: # (Generated from file 'rcs\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2005, Colin McCormack <coldstore@users\.sourceforge\.net>)
[//000000005]: # (rcs\(n\) 2\.0\.2 tcllib "RCS low level utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

rcs \- RCS low level utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [TEXT DICT DATA STRUCTURE](#section3)

  - [RCS PATCH FORMAT](#section4)

  - [RCS PATCH COMMAND LIST](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require rcs ?0\.1?  

[__::rcs::text2dict__ *text*](#1)  
[__::rcs::dict2text__ *dict*](#2)  
[__::rcs::file2dict__ *filename*](#3)  
[__::rcs::dict2file__ *filename* *dict*](#4)  
[__::rcs::decodeRcsPatch__ *text*](#5)  
[__::rcs::encodeRcsPatch__ *pcmds*](#6)  
[__::rcs::applyRcsPatch__ *text* *pcmds*](#7)  

# <a name='description'></a>DESCRIPTION

The *Revision Control System*, short *[RCS](\.\./\.\./\.\./\.\./index\.md\#rcs)*,
is a set of applications and related data formats which allow a system to
persist the history of changes to a text\. It, and its relative SCCS are the
basis for many other such systems, like *[CVS](\.\./\.\./\.\./\.\./index\.md\#cvs)*,
etc\.

This package *does not* implement RCS\.

It only provides a number of low level commands which should be useful in the
implementation of any revision management system, namely:

  1. The conversion of texts into and out of a data structures which allow the
     easy modification of such text by *patches*, i\.e\. sequences of
     instructions for the transformation of one text into an other\.

  1. And the conversion of one particular format for patches, the so\-called
     *RCS patches*, into and out of data structures which allow their easy
     application to texts\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::rcs::text2dict__ *text*

    Converts the argument *text* into a dictionary containing and representing
    the same text in an indexed form and returns that dictionary as its result\.
    More information about the format of the result can be found in section
    [TEXT DICT DATA STRUCTURE](#section3)\. This command returns the
    *canonical* representation of the input\.

  - <a name='2'></a>__::rcs::dict2text__ *dict*

    This command provides the complementary operation to
    __::rcs::text2dict__\. It converts a dictionary in the form described in
    section [TEXT DICT DATA STRUCTURE](#section3) back into a text and
    returns that text as its result\. The command does accept non\-canonical
    representations of the text as its input\.

  - <a name='3'></a>__::rcs::file2dict__ *filename*

    This command is identical to __::rcs::text2dict__, except that it reads
    the text to convert from the file with path *filename*\. The file has to
    exist and must be readable as well\.

  - <a name='4'></a>__::rcs::dict2file__ *filename* *dict*

    This command is identical to __::rcs::2dict2text__, except that it
    stores the resulting text in the file with path *filename*\. The file is
    created if it did not exist, and must be writable\. The result of the command
    is the empty string\.

  - <a name='5'></a>__::rcs::decodeRcsPatch__ *text*

    Converts the *text* argument into a patch command list \(PCL\) as specified
    in the section [RCS PATCH COMMAND LIST](#section5) and returns this
    list as its result\. It is assumed that the input text is in *[diff \-n
    format](\.\./\.\./\.\./\.\./index\.md\#diff\_n\_format)*, also known as *[RCS
    patch](\.\./\.\./\.\./\.\./index\.md\#rcs\_patch)* format, as specified in the
    section [RCS PATCH FORMAT](#section4)\. Please note that the command
    ignores no\-ops in the input, in other words the resulting PCL contains only
    instructions doing something\.

  - <a name='6'></a>__::rcs::encodeRcsPatch__ *pcmds*

    This command provides the complementary operation to
    __::rcs::decodeRcsPatch__\. It convert a patch comand list \(PCL\) list as
    specified in the section [RCS PATCH COMMAND LIST](#section5) back into
    a text in [RCS PATCH FORMAT](#section4) and returns that text as its
    result\.

    Note that this command and __::rcs::decodeRcsPatch__ are not exactly
    complementary, as the latter strips no\-ops from its input, which the encoder
    cannot put back anymore into the generated RCS patch\. In other words, the
    result of a decode/encode step may not match the original input at the
    character level, but it will match it at the functional level\.

  - <a name='7'></a>__::rcs::applyRcsPatch__ *text* *pcmds*

    This operation applies a patch in the form of a PCL to a text given in the
    form of a dictionary and returns the modified text, again as dictionary, as
    its result\.

    To handle actual text use the commands __::rcs::text2dict__ \(or
    equivalent\) and __::rcs::decodeRcsPatch__ to transform the inputs into
    data structures acceptable to this command\. Analogously use the command
    __::rcs::dict2text__ \(or equivalent\) to transform the result of this
    command into actuall text as required\.

# <a name='section3'></a>TEXT DICT DATA STRUCTURE

A text dictionary is a dictionary whose keys are integer numbers and text
strings as the associated values\. The keys represent the line numbers of a text
and the values the text of that line\. Note that one text can have many
representations as a dictionary, as the index values only have to be properly
ordered for reconstruction, their exact values do not matter\. Similarly the
strings may actually span multiple physical lines\.

The text

    Hello World,
    how are you ?
    Fine, and you ?

for example can be represented by

    {{1 {Hello World,}} {2 {how are you ?}} {3 {Fine, and you ?}}}

or

    {{5 {Hello World,}} {8 {how are you ?}} {9 {Fine, and you ?}}}

or

    {{-1 {Hello World,
    how are you ?}} {4 {Fine, and you ?}}}

The first dictionary is the *canonical* representation of the text, with line
numbers starting at __1__, increasing in steps of __1__ and without
gaps, and each value representing exactly one physical line\.

All the commands creating dictionaries from text will return the canonical
representation of their input text\. The commands taking a dictionary and
returning text will generally accept all representations, canonical or not\.

The result of applying a patch to a text dictionary will in general cause the
dictionary to become non\-canonical\.

# <a name='section4'></a>RCS PATCH FORMAT

A *[patch](\.\./\.\./\.\./\.\./index\.md\#patch)* is in general a series of
instructions how to transform an input text T into a different text T', and also
encoded in text form as well\.

The text format for patches understood by this package is a very simple one,
known under the names *[RCS patch](\.\./\.\./\.\./\.\./index\.md\#rcs\_patch)* or
*[diff \-n format](\.\./\.\./\.\./\.\./index\.md\#diff\_n\_format)*\.

Patches in this format contain only two different commands, for the deletion of
old text, and addition of new text\. The replacement of some text by a different
text is handled as combination of a deletion following by an addition\.

The format is line oriented, with each line containing either a command or text
data associated with the preceding command\. The first line of a *[RCS
patch](\.\./\.\./\.\./\.\./index\.md\#rcs\_patch)* is always a command line\.

The commands are:

  - ""

    The empty line is a command which does nothing\.

  - "a__start__ __n__"

    A line starting with the character __a__ is a command for the addition
    of text to the output\. It is followed by __n__ lines of text data\. When
    applying the patch the data is added just between the lines __start__
    and __start__\+1\. The same effect is had by appending the data to the
    existing text on line __start__\. A non\-existing line __start__ is
    created\.

  - "d__start__ __n__"

    A line starting with the character __d__ is a command for the deletion
    of text from the output\. When applied it deletes __n__ lines of text,
    and the first line deleted is at index __start__\.

Note that the line indices __start__ always refer to the text which is
transformed as it is in its original state, without taking the precending
changes into account\.

Note also that the instruction have to be applied in the order they occur in the
patch, or in a manner which produces the same result as in\-order application\.

This is the format of results returned by the command
__::rcs::decodeRcsPatch__ and accepted by the commands
__::rcs::encodeRcsPatch__ and __::rcs::appplyRcsPatch__ resp\. Note
however that the decoder will strip no\-op commands, and the encoder will not
generate no\-ops, making them not fully complementary at the textual level, only
at the functional level\.

And example of a RCS patch is

    d1 2
    d4 1
    a4 2
    The named is the mother of all things.

    a11 3
    They both may be called deep and profound.
    Deeper and more profound,
    The door of all subtleties!

# <a name='section5'></a>RCS PATCH COMMAND LIST

Patch command lists \(sort: PCL's\) are the data structures generated by patch
decoder command and accepted by the patch encoder and applicator commands\. They
represent RCS patches in the form of Tcl data structures\.

A PCL is a list where each element represents a single patch instruction, either
an addition, or a deletion\. The elements are lists themselves, where the first
item specifies the command and the remainder represent the arguments of the
command\.

  - a

    This is the instruction for the addition of text\. It has two arguments, the
    index of the line where to add the text, and the text to add, in this order\.

  - d

    This is the instruction for the deletion of text\. It has two arguments, the
    index of the line where to start deleting text, and the number of lines to
    delete, in this order\.

This is the format returned by the patch decoder command and accepted as input
by the patch encoder and applicator commands\.

An example for a patch command is shown below, it represents the example RCS
patch found in section [RCS PATCH FORMAT](#section4)\.

    {{d 1 2} {d 4 1} {a 4 {The named is the mother of all things.

    }} {a 11 {They both may be called deep and profound.
    Deeper and more profound,
    The door of all subtleties!}}}

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *rcs* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[struct](\.\./\.\./\.\./\.\./index\.md\#struct),
[textutil](\.\./textutil/textutil\.md)

# <a name='keywords'></a>KEYWORDS

[CVS](\.\./\.\./\.\./\.\./index\.md\#cvs), [RCS](\.\./\.\./\.\./\.\./index\.md\#rcs), [RCS
patch](\.\./\.\./\.\./\.\./index\.md\#rcs\_patch),
[SCCS](\.\./\.\./\.\./\.\./index\.md\#sccs), [diff \-n
format](\.\./\.\./\.\./\.\./index\.md\#diff\_n\_format),
[patching](\.\./\.\./\.\./\.\./index\.md\#patching), [text
conversion](\.\./\.\./\.\./\.\./index\.md\#text\_conversion), [text
differences](\.\./\.\./\.\./\.\./index\.md\#text\_differences)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 2005, Colin McCormack <coldstore@users\.sourceforge\.net>
