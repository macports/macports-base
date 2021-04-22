
[//000000001]: # (docstrip \- Literate programming tool)
[//000000002]: # (Generated from file 'docstrip\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003–2010 Lars Hellström <Lars dot Hellstrom at residenset dot net>)
[//000000004]: # (docstrip\(n\) 1\.2 tcllib "Literate programming tool")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

docstrip \- Docstrip style source code extraction

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [File format](#section2)

  - [Commands](#section3)

  - [Document structure](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require docstrip ?1\.2?  

[__docstrip::extract__ *text* *terminals* ?*option* *value* \.\.\.?](#1)  
[__docstrip::sourcefrom__ *filename* *terminals* ?*option* *value* \.\.\.?](#2)  

# <a name='description'></a>DESCRIPTION

__Docstrip__ is a tool created to support a brand of Literate Programming\.
It is most common in the \(La\)TeX community, where it is being used for pretty
much everything from the LaTeX core and up, but there is nothing about
__docstrip__ which prevents using it for other types of software\.

In short, the basic principle of literate programming is that program source
should primarily be written and structured to suit the developers \(and advanced
users who want to peek "under the hood"\), not to suit the whims of a compiler or
corresponding source code consumer\. This means literate sources often need some
kind of "translation" to an illiterate form that dumb software can understand\.
The __docstrip__ Tcl package handles this translation\.

Even for those who do not whole\-hartedly subscribe to the philosophy behind
literate programming, __docstrip__ can bring greater clarity to in
particular:

  - programs employing non\-obvious mathematics

  - projects where separate pieces of code, perhaps in different languages, need
    to be closely coordinated\.

The first is by providing access to much more powerful typographical features
for source code comments than are possible in plain text\. The second is because
all the separate pieces of code can be kept next to each other in the same
source file\.

The way it works is that the programmer edits directly only one or several
"master" source code files, from which __docstrip__ generates the more
traditional "source" files compilers or the like would expect\. The master
sources typically contain a large amount of documentation of the code, sometimes
even in places where the code consumers would not allow any comments\. The
etymology of "docstrip" is that this *doc*umentation was *strip*ped away
\(although "code extraction" might be a better description, as it has always been
a matter of copying selected pieces of the master source rather than deleting
text from it\)\. The __docstrip__ Tcl package contains a reimplementation of
the basic extraction functionality from the __docstrip__ program, and thus
makes it possible for a Tcl interpreter to read and interpret the master source
files directly\.

Readers who are not previously familiar with __docstrip__ but want to know
more about it may consult the following sources\.

  1. *The tclldoc package and class*,
     [http://ctan\.org/tex\-archive/macros/latex/contrib/tclldoc/](http://ctan\.org/tex\-archive/macros/latex/contrib/tclldoc/)\.

  1. *The DocStrip utility*,
     [http://ctan\.org/tex\-archive/macros/latex/base/docstrip\.dtx](http://ctan\.org/tex\-archive/macros/latex/base/docstrip\.dtx)\.

  1. *The doc and shortvrb Packages*,
     [http://ctan\.org/tex\-archive/macros/latex/base/doc\.dtx](http://ctan\.org/tex\-archive/macros/latex/base/doc\.dtx)\.

  1. Chapter 14 of *The LaTeX Companion* \(second edition\), Addison\-Wesley,
     2004; ISBN 0\-201\-36299\-6\.

# <a name='section2'></a>File format

The basic unit __docstrip__ operates on are the *lines* of a master source
file\. Extraction consists of selecting some of these lines to be copied from
input text to output text\. The basic distinction is that between *code lines*
\(which are copied and do not begin with a percent character\) and *comment
lines* \(which begin with a percent character and are not copied\)\.

    docstrip::extract [join {
      {% comment}
      {% more comment !"#$%&/(}
      {some command}
      { % blah $blah "Not a comment."}
      {% abc; this is comment}
      {# def; this is code}
      {ghi}
      {% jkl}
    } \n] {}

returns the same sequence of lines as

    join {
      {some command}
      { % blah $blah "Not a comment."}
      {# def; this is code}
      {ghi} ""
    } \n

It does not matter to __docstrip__ what format is used for the documentation
in the comment lines, but in order to do better than plain text comments, one
typically uses some markup language\. Most commonly LaTeX is used, as that is a
very established standard and also provides the best support for mathematical
formulae, but the __docstrip::util__ package also gives some support for
*[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)*\-like markup\.

Besides the basic code and comment lines, there are also *guard lines*, which
begin with the two characters '%<', and *meta\-comment lines*, which begin with
the two characters '%%'\. Within guard lines there is furthermore the distinction
between *verbatim guard lines*, which begin with '%<<', and ordinary guard
lines, where the '%<' is not followed by another '<'\. The last category is by
far the most common\.

Ordinary guard lines conditions extraction of the code line\(s\) they guard by the
value of a boolean expression; the guarded block of code lines will only be
included if the expression evaluates to true\. The syntax of an ordinary guard
line is one of

    '%' '<' STARSLASH EXPRESSION '>'
    '%' '<' PLUSMINUS EXPRESSION '>' CODE

where

    STARSLASH  ::=  '*' | '/'
    PLUSMINUS  ::=  | '+' | '-'
    EXPRESSION ::= SECONDARY | SECONDARY ',' EXPRESSION
                 | SECONDARY '|' EXPRESSION
    SECONDARY  ::= PRIMARY | PRIMARY '&' SECONDARY
    PRIMARY    ::= TERMINAL | '!' PRIMARY | '(' EXPRESSION ')'
    CODE       ::= { any character except end-of-line }

Comma and vertical bar both denote 'or'\. Ampersand denotes 'and'\. Exclamation
mark denotes 'not'\. A TERMINAL can be any nonempty string of characters not
containing '>', '&', '&#124;', comma, '\(', or '\)', although the __docstrip__
manual is a bit restrictive and only guarantees proper operation for strings of
letters \(although even the LaTeX core sources make heavy use also of digits in
TERMINALs\)\. The second argument of __docstrip::extract__ is the list of
those TERMINALs that should count as having the value 'true'; all other
TERMINALs count as being 'false' when guard expressions are evaluated\.

In the case of a '%<\**EXPRESSION*>' guard, the lines guarded are all lines up
to the next '%</*EXPRESSION*>' guard with the same *EXPRESSION* \(compared as
strings\)\. The blocks of code delimited by such '\*' and '/' guard lines must be
properly nested\.

    set text [join {
       {begin}
       {%<*foo>}
       {1}
       {%<*bar>}
       {2}
       {%</bar>}
       {%<*!bar>}
       {3}
       {%</!bar>}
       {4}
       {%</foo>}
       {5}
       {%<*bar>}
       {6}
       {%</bar>}
       {end}
    } \n]
    set res [docstrip::extract $text foo]
    append res [docstrip::extract $text {foo bar}]
    append res [docstrip::extract $text bar]

sets $res to the result of

    join {
       {begin}
       {1}
       {3}
       {4}
       {5}
       {end}
       {begin}
       {1}
       {2}
       {4}
       {5}
       {6}
       {end}
       {begin}
       {5}
       {6}
       {end} ""
    } \n

In guard lines without a '\*', '/', '\+', or '\-' modifier after the '%<', the
guard applies only to the CODE following the '>' on that single line\. A '\+'
modifier is equivalent to no modifier\. A '\-' modifier is like the case with no
modifier, but the expression is implicitly negated, i\.e\., the CODE of a '%<\-'
guard line is only included if the expression evaluates to false\.

Metacomment lines are "comment lines which should not be stripped away", but be
extracted like code lines; these are sometimes used for copyright notices and
similar material\. The '%%' prefix is however not kept, but substituted by the
current __\-metaprefix__, which is customarily set to some "comment until end
of line" character \(or character sequence\) of the language of the code being
extracted\.

    set text [join {
       {begin}
       {%<foo> foo}
       {%<+foo>plusfoo}
       {%<-foo>minusfoo}
       {middle}
       {%% some metacomment}
       {%<*foo>}
       {%%another metacomment}
       {%</foo>}
       {end}
    } \n]
    set res [docstrip::extract $text foo -metaprefix {# }]
    append res [docstrip::extract $text bar -metaprefix {#}]

sets $res to the result of

    join {
       {begin}
       { foo}
       {plusfoo}
       {middle}
       {#  some metacomment}
       {# another metacomment}
       {end}
       {begin}
       {minusfoo}
       {middle}
       {# some metacomment}
       {end} ""
    } \n

Verbatim guards can be used to force code line interpretation of a block of
lines even if some of them happen to look like any other type of lines to
docstrip\. A verbatim guard has the form '%<<*END\-TAG*' and the verbatim block
is terminated by the first line that is exactly '%*END\-TAG*'\.

    set text [join {
       {begin}
       {%<*myblock>}
       {some stupid()}
       {   #computer<program>}
       {%<<QQQ-98765}
       {% These three lines are copied verbatim (including percents}
       {%% even if -metaprefix is something different than %%).}
       {%</myblock>}
       {%QQQ-98765}
       {   using*strange@programming<language>}
       {%</myblock>}
       {end}
    } \n]
    set res [docstrip::extract $text myblock -metaprefix {# }]
    append res [docstrip::extract $text {}]

sets $res to the result of

    join {
       {begin}
       {some stupid()}
       {   #computer<program>}
       {% These three lines are copied verbatim (including percents}
       {%% even if -metaprefix is something different than %%).}
       {%</myblock>}
       {   using*strange@programming<language>}
       {end}
       {begin}
       {end} ""
    } \n

The processing of verbatim guards takes place also inside blocks of lines which
due to some outer block guard will not be copied\.

The final piece of __docstrip__ syntax is that extraction stops at a line
that is exactly "\\endinput"; this is often used to avoid copying random
whitespace at the end of a file\. In the unlikely case that one wants such a code
line, one can protect it with a verbatim guard\.

# <a name='section3'></a>Commands

The package defines two commands\.

  - <a name='1'></a>__docstrip::extract__ *text* *terminals* ?*option* *value* \.\.\.?

    The __extract__ command docstrips the *text* and returns the extracted
    lines of code, as a string with each line terminated with a newline\. The
    *terminals* is the list of those guard expression terminals which should
    evaluate to true\. The available options are:

      * __\-annotate__ *lines*

        Requests the specified number of lines of annotation to follow each
        extracted line in the result\. Defaults to 0\. Annotation lines are mostly
        useful when the extracted lines are to undergo some further
        transformation\. A first annotation line is a list of three elements:
        line type, prefix removed in extraction, and prefix inserted in
        extraction\. The line type is one of: 'V' \(verbatim\), 'M' \(metacomment\),
        '\+' \(\+ or no modifier guard line\), '\-' \(\- modifier guard line\), '\.'
        \(normal line\)\. A second annotation line is the source line number\. A
        third annotation line is the current stack of block guards\. Requesting
        more than three lines of annotation is currently not supported\.

      * __\-metaprefix__ *string*

        The string by which the '%%' prefix of a metacomment line will be
        replaced\. Defaults to '%%'\. For Tcl code this would typically be '\#'\.

      * __\-onerror__ *keyword*

        Controls what will be done when a format error in the *text* being
        processed is detected\. The settings are:

          + __ignore__

            Just ignore the error; continue as if nothing happened\.

          + __puts__

            Write an error message to __stderr__, then continue processing\.

          + __throw__

            Throw an error\. The __\-errorcode__ is set to a list whose first
            element is __DOCSTRIP__, second element is the type of error,
            and third element is the line number where the error is detected\.
            This is the default\.

      * __\-trimlines__ *boolean*

        Controls whether *spaces* at the end of a line should be trimmed away
        before the line is processed\. Defaults to true\.

    It should be remarked that the *terminals* are often called "options" in
    the context of the __docstrip__ program, since these specify which
    optional code fragments should be included\.

  - <a name='2'></a>__docstrip::sourcefrom__ *filename* *terminals* ?*option* *value* \.\.\.?

    The __sourcefrom__ command is a docstripping emulation of
    __[source](\.\./\.\./\.\./\.\./index\.md\#source)__\. It opens the file
    *filename*, reads it, closes it, docstrips the contents as specified by
    the *terminals*, and evaluates the result in the local context of the
    caller, during which time the __[info](\.\./\.\./\.\./\.\./index\.md\#info)__
    __script__ value will be the *filename*\. The options are passed on to
    __fconfigure__ to configure the file before its contents are read\. The
    __\-metaprefix__ is set to '\#', all other __extract__ options have
    their default values\.

# <a name='section4'></a>Document structure

The file format \(as described above\) determines whether a master source code
file can be processed correctly by __docstrip__, but the usefulness of the
format is to no little part also dependent on that the code and comment lines
together constitute a well\-formed document\.

For a document format that does not require any non\-Tcl software, see the
__ddt2man__ command in the __docstrip::util__ package\. It is suggested
that files employing that document format are given the suffix "\.ddt", to
distinguish them from the more traditional LaTeX\-based "\.dtx" files\.

Master source files with "\.dtx" extension are usually set up so that they can be
typeset directly by __[latex](\.\./\.\./\.\./\.\./index\.md\#latex)__ without any
support from other files\. This is achieved by beginning the file with the lines

> &nbsp;&nbsp;&nbsp;% \\iffalse  
> &nbsp;&nbsp;&nbsp;%<\*driver>  
> &nbsp;&nbsp;&nbsp;\\documentclass\{tclldoc\}  
> &nbsp;&nbsp;&nbsp;\\begin\{document\}  
> &nbsp;&nbsp;&nbsp;\\DocInput\{*filename\.dtx*\}  
> &nbsp;&nbsp;&nbsp;\\end\{document\}  
> &nbsp;&nbsp;&nbsp;%</driver>  
> &nbsp;&nbsp;&nbsp;% \\fi

or some variation thereof\. The trick is that the file gets read twice\. With
normal LaTeX reading rules, the first two lines are comments and therefore
ignored\. The third line is the document preamble, the fourth line begins the
document body, and the sixth line ends the document, so LaTeX stops there —
non\-comments below that point in the file are never subjected to the normal
LaTeX reading rules\. Before that, however, the \\DocInput command on the fifth
line is processed, and that does two things: it changes the interpretation of
'%' from "comment" to "ignored", and it inputs the file specified in the
argument \(which is normally the name of the file the command is in\)\. It is this
second time that the file is being read that the comments and code in it are
typeset\.

The function of the \\iffalse \.\.\. \\fi is to skip lines two to seven on this
second time through; this is similar to the "if 0 \{ \.\.\. \}" idiom for block
comments in Tcl code, and it is needed here because \(amongst other things\) the
\\documentclass command may only be executed once\. The function of the <driver>
guards is to prevent this short piece of LaTeX code from being extracted by
__docstrip__\. The total effect is that the file can function both as a LaTeX
document and as a __docstrip__ master source code file\.

It is not necessary to use the tclldoc document class, but that does provide a
number of features that are convenient for "\.dtx" files containing Tcl code\.
More information on this matter can be found in the references above\.

# <a name='seealso'></a>SEE ALSO

[docstrip\_util](docstrip\_util\.md)

# <a name='keywords'></a>KEYWORDS

[\.dtx](\.\./\.\./\.\./\.\./index\.md\#\_dtx), [LaTeX](\.\./\.\./\.\./\.\./index\.md\#latex),
[docstrip](\.\./\.\./\.\./\.\./index\.md\#docstrip),
[documentation](\.\./\.\./\.\./\.\./index\.md\#documentation), [literate
programming](\.\./\.\./\.\./\.\./index\.md\#literate\_programming),
[source](\.\./\.\./\.\./\.\./index\.md\#source)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003–2010 Lars Hellström <Lars dot Hellstrom at residenset dot net>
