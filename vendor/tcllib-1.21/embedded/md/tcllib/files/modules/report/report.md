
[//000000001]: # (report \- Matrix reports)
[//000000002]: # (Generated from file 'report\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002\-2014 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (report\(n\) 0\.3\.2 tcllib "Matrix reports")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

report \- Create and manipulate report objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [REGIONS](#section2)

  - [LINES](#section3)

  - [TEMPLATES](#section4)

  - [STYLES](#section5)

  - [REPORT METHODS](#section6)

  - [EXAMPLES](#section7)

  - [Bugs, Ideas, Feedback](#section8)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require report ?0\.3\.2?  

[__::report::report__ *reportName* *columns* ?__style__ *style arg\.\.\.*?](#1)  
[__reportName__ *option* ?*arg arg \.\.\.*?](#2)  
[__::report::defstyle__ *styleName arguments script*](#3)  
[__::report::rmstyle__ *styleName*](#4)  
[__::report::stylearguments__ *styleName*](#5)  
[__::report::stylebody__ *styleName*](#6)  
[__::report::styles__](#7)  
[*reportName* __destroy__](#8)  
[*reportName* *templatecode* __disable__&#124;__enable__](#9)  
[*reportName* *templatecode* __enabled__](#10)  
[*reportName* *templatecode* __get__](#11)  
[*reportName* *templatecode* __set__ *templatedata*](#12)  
[*reportName* __tcaption__ ?*size*?](#13)  
[*reportName* __bcaption__ *size*](#14)  
[*reportName* __size__ *column* ?*number*&#124;__dyn__?](#15)  
[*reportName* __sizes__ ?*size\-list*?](#16)  
[*reportName* __pad__ *column* ?__left__&#124;__right__&#124;__both__ ?*padstring*??](#17)  
[*reportName* __justify__ *column* ?__left__&#124;__right__&#124;__center__?](#18)  
[*reportName* __printmatrix__ *matrix*](#19)  
[*reportName* __printmatrix2channel__ *matrix chan*](#20)  
[*reportName* __[columns](\.\./\.\./\.\./\.\./index\.md\#columns)__](#21)  

# <a name='description'></a>DESCRIPTION

This package provides report objects which can be used by the formatting methods
of matrix objects to generate tabular reports of the matrix in various forms\.
The report objects defined here break each report down into three
[REGIONS](#section2) and ten classes of
*[lines](\.\./\.\./\.\./\.\./index\.md\#lines)* \(various separator\- and data\-lines\)\.
See the following section for more detailed explanations\.

  - <a name='1'></a>__::report::report__ *reportName* *columns* ?__style__ *style arg\.\.\.*?

    Creates a new report object for a report having *columns* columns with an
    associated global Tcl command whose name is *reportName*\. This command may
    be used to invoke various configuration operations on the report\. It has the
    following general form:

      * <a name='2'></a>__reportName__ *option* ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.
        See section [REPORT METHODS](#section6) for more explanations\. If
        no __style__ is specified the report will use the builtin style
        __plain__ as its default configuration\.

  - <a name='3'></a>__::report::defstyle__ *styleName arguments script*

    Defines the new style *styleName*\. See section [STYLES](#section5)
    for more information\.

  - <a name='4'></a>__::report::rmstyle__ *styleName*

    Deletes the style *styleName*\. Trying to delete an unknown or builtin
    style will result in an error\. Beware, this command will not check that
    there are no other styles depending on the deleted one\. Deleting a style
    which is still used by another style FOO will result in a runtime error when
    FOO is applied to a newly instantiated report\.

  - <a name='5'></a>__::report::stylearguments__ *styleName*

    This introspection command returns the list of arguments associated with the
    style *styleName*\.

  - <a name='6'></a>__::report::stylebody__ *styleName*

    This introspection command returns the script associated with the style
    *styleName*\.

  - <a name='7'></a>__::report::styles__

    This introspection command returns a list containing the names of all styles
    known to the package at the time of the call\. The order of the names in the
    list reflects the order in which the styles were created\. In other words,
    the first item is the predefined style __plain__, followed by the first
    style defined by the user, and so on\.

# <a name='section2'></a>REGIONS

The three regions are the *top caption*, *data area* and *bottom caption*\.
These are, roughly speaking, the title, the values to report and a title at the
bottom\. The size of the caption regions can be specified by the user as the
number of rows they occupy in the matrix to format\. The size of the data area is
specified implicitly\.

# <a name='section3'></a>LINES

[TEMPLATES](#section4) are associated with each of the ten line classes,
defining the formatting for this kind of line\. The user is able to enable and
disable the separator lines at will, but not the data lines\. Their usage is
solely determined by the number of rows contained in the three regions\. Data
lines and all enabled separators must have a template associated with them\.

Note that the data\-lines in a report and the rows in the matrix the report was
generated from are *not* in a 1:1 relationship if any row in the matrix has a
height greater than one\.

The different kinds of lines and the codes used by the report methods to address
them are:

  - __top__

    The topmost line of a report\. Separates the report from anything which came
    before it\. The user can enable the usage of this line at will\.

  - __topdatasep__

    This line is used to separate the data rows in the top caption region, if it
    contains more than one row and the user enabled its usage\.

  - __topcapsep__

    This line is used to separate the top caption and data regions, if the top
    caption is not empty and the user enabled its usage\.

  - __datasep__

    This line is used to separate the data rows in the data region, if it
    contains more than one row and the user enabled its usage\.

  - __botcapsep__

    This line is used to separate the data and bottom caption regions, if the
    bottom caption is not empty and the user enabled its usage\.

  - __botdatasep__

    This line is used to separate the data rows in the bottom caption region, if
    it contains more than one row and the user enabled its usage\.

  - __bottom__

    The bottommost line of a report\. Separates the report from anything which
    comes after it\. The user can enable the usage of this line at will\.

  - __topdata__

    This line defines the format of data lines in the top caption region of the
    report\.

  - __data__

    This line defines the format of data lines in the data region of the report\.

  - __botdata__

    This line defines the format of data lines in the bottom caption region of
    the report\.

# <a name='section4'></a>TEMPLATES

Each template is a list of strings used to format the line it is associated
with\. For a report containing __n__ columns a template for a data line has
to contain "__n__\+1" items and a template for a separator line
"2\*__n__\+1" items\.

The items in a data template specify the strings used to separate the column
information\. Together with the corresponding items in the separator templates
they form the vertical lines in the report\.

*Note* that the corresponding items in all defined templates have to be of
equal length\. This will be checked by the report object\. The first item defines
the leftmost vertical line and the last item defines the rightmost vertical
line\. The item at index __k__ \("1",\.\.\.,"__n__\-2"\) separates the
information in the columns "__k__\-1" and "__k__"\.

The items in a separator template having an even\-numbered index \("0","2",\.\.\.\)
specify the column separators\. The item at index "2\*__k__"
\("0","2",\.\.\.,"2\*__n__"\) corresponds to the items at index "__k__" in the
data templates\.

The items in a separator template having an odd\-numbered index \("1","3",\.\.\.\)
specify the strings used to form the horizontal lines in the separator lines\.
The item at index "2\*__k__\+1" \("1","3",\.\.\.,"2\*__n__\+1"\) corresponds to
column "__k__"\. When generating the horizontal lines the items are
replicated to be at least as long as the size of their column and then cut to
the exact size\.

# <a name='section5'></a>STYLES

Styles are a way for the user of this package to define common configurations
for report objects and then use them later during the actual instantiation of
report objects\. They are defined as tcl scripts which when executed configure
the report object into the requested configuration\.

The command to define styles is __::report::defstyle__\. Its last argument is
the tcl __script__ performing the actual reconfiguration of the report
object to obtain the requested style\.

In this script the names of all previously defined styles are available as
commands, as are all commands found in a safe interpreter and the configuration
methods of report objects\. The latter implicitly operate on the object currently
executing the style script\. The __arguments__ declared here are available in
the __script__ as variables\. When calling the command of a previously
declared style all the arguments expected by it have to be defined in the call\.

# <a name='section6'></a>REPORT METHODS

The following commands are possible for report objects:

  - <a name='8'></a>*reportName* __destroy__

    Destroys the report, including its storage space and associated command\.

  - <a name='9'></a>*reportName* *templatecode* __disable__&#124;__enable__

    Enables or disables the usage of the template addressed by the
    *templatecode*\. Only the codes for separator lines are allowed here\. It is
    not possible to enable or disable data lines\.

    Enabling a template causes the report to check all used templates for
    inconsistencies in the definition of the vertical lines \(See section
    [TEMPLATES](#section4)\)\.

  - <a name='10'></a>*reportName* *templatecode* __enabled__

    Returns the whether the template addressed by the *templatecode* is
    currently enabled or not\.

  - <a name='11'></a>*reportName* *templatecode* __get__

    Returns the template currently associated with the kind of line addressed by
    the *templatecode*\. All known templatecodes are allowed here\.

  - <a name='12'></a>*reportName* *templatecode* __set__ *templatedata*

    Sets the template associated with the kind of line addressed by the
    *templatecode* to the new value in *templatedata*\. See section
    [TEMPLATES](#section4) for constraints on the length of templates\.

  - <a name='13'></a>*reportName* __tcaption__ ?*size*?

    Specifies the *size* of the top caption region as the number rows it
    occupies in the matrix to be formatted\. Only numbers greater than or equal
    to zero are allowed\. If no *size* is specified the command will return the
    current size instead\.

    Setting the size of the top caption to a value greater than zero enables the
    corresponding data template and causes the report to check all used
    templates for inconsistencies in the definition of the vertical lines \(See
    section [TEMPLATES](#section4)\)\.

  - <a name='14'></a>*reportName* __bcaption__ *size*

    Specifies the *size* of the bottom caption region as the number rows it
    occupies in the matrix to be formatted\. Only numbers greater than or equal
    to zero are allowed\. If no *size* is specified the command will return the
    current size instead\.

    Setting the size of the bottom caption to a value greater than zero enables
    the corresponding data template and causes the report to check all used
    templates for inconsistencies in the definition of the vertical lines \(See
    section [TEMPLATES](#section4)\)\.

  - <a name='15'></a>*reportName* __size__ *column* ?*number*&#124;__dyn__?

    Specifies the size of the *column* in the output\. The value __dyn__
    means that the columnwidth returned by the matrix to be formatted for the
    specified column shall be used\. The formatting of the column is dynamic\. If
    a fixed *number* is used instead of __dyn__ it means that the column
    has a width of that many characters \(padding excluded\)\. Only numbers greater
    than zero are allowed here\.

    If no size specification is given the command will return the current size
    of the *column* instead\.

  - <a name='16'></a>*reportName* __sizes__ ?*size\-list*?

    This method allows the user to specify the sizes of all columns in one call\.
    Its argument is a list containing the sizes to associate with the columns\.
    The first item is associated with column 0, the next with column 1, and so
    on\.

    If no *size\-list* is specified the command will return a list containing
    the currently set sizes instead\.

  - <a name='17'></a>*reportName* __pad__ *column* ?__left__&#124;__right__&#124;__both__ ?*padstring*??

    This method allows the user to specify padding on the left, right or both
    sides of a *column*\. If the *padstring* is not specified it defaults to
    a single space character\. *Note*: An alternative way of specifying the
    padding is to use vertical separator strings longer than one character in
    the templates \(See section [TEMPLATES](#section4)\)\.

    If no pad specification is given at all the command will return the current
    state of padding for the column instead\. This will be a list containing two
    elements, the first element the left padding, the second describing the
    right padding\.

  - <a name='18'></a>*reportName* __justify__ *column* ?__left__&#124;__right__&#124;__center__?

    Declares how the cell values for a *column* are filled into the report
    given the specified size of a column in the report\.

    For __left__ and __right__ justification a cell value shorter than
    the width of the column is bound with its named edge to the same edge of the
    column\. The other side is filled with spaces\. In the case of __center__
    the spaces are placed to both sides of the value and the left number of
    spaces is at most one higher than the right number of spaces\.

    For a value longer than the width of the column the value is cut at the
    named edge\. This means for __left__ justification that the *tail*
    \(i\.e\. the __right__ part\) of the value is made visible in the output\.
    For __center__ the value is cut at both sides to fit into the column and
    the number of characters cut at the left side of the value is at most one
    less than the number of characters cut from the right side\.

    If no justification was specified the command will return the current
    justification for the column instead\.

  - <a name='19'></a>*reportName* __printmatrix__ *matrix*

    Formats the *matrix* according to the configuration of the report and
    returns the resulting string\. The matrix has to have the same number of
    columns as the report\. The matrix also has to have enough rows so that the
    top and bottom caption regions do not overlap\. The data region is allowed to
    be empty\.

  - <a name='20'></a>*reportName* __printmatrix2channel__ *matrix chan*

    Formats the *matrix* according to the configuration of the report and
    writes the result into the channel *chan*\. The matrix has to have the same
    number of columns as the report\. The matrix also has to have enough rows so
    that the top and bottom caption regions do not overlap\. The data region is
    allowed to be empty\.

  - <a name='21'></a>*reportName* __[columns](\.\./\.\./\.\./\.\./index\.md\#columns)__

    Returns the number of columns in the report\.

The methods __size__, __pad__ and __justify__ all take a column
index as their first argument\. This index is allowed to use all the forms of an
index as accepted by the __lindex__ command\. The allowed range for indices
is "0,\.\.\.,\[__reportName__ columns\]\-1"\.

# <a name='section7'></a>EXAMPLES

Our examples define some generally useful report styles\.

A simple table with lines surrounding all information and vertical separators,
but without internal horizontal separators\.

        ::report::defstyle simpletable {} {
    	data	set [split "[string repeat "| "   [columns]]|"]
    	top	set [split "[string repeat "+ - " [columns]]+"]
    	bottom	set [top get]
    	top	enable
    	bottom	enable
        }

An extension of a __simpletable__, see above, with a title area\.

        ::report::defstyle captionedtable {{n 1}} {
    	simpletable
    	topdata   set [data get]
    	topcapsep set [top get]
    	topcapsep enable
    	tcaption $n
        }

Given the definitions above now an example which actually formats a matrix into
a tabular report\. It assumes that the matrix actually contains useful data\.

    % ::struct::matrix m
    % # ... fill m with data, assume 5 columns
    % ::report::report r 5 style captionedtable 1
    % r printmatrix m
    +---+-------------------+-------+-------+--------+
    |000|VERSIONS:          |2:8.4a3|1:8.4a3|1:8.4a3%|
    +---+-------------------+-------+-------+--------+
    |001|CATCH return ok    |7      |13     |53.85   |
    |002|CATCH return error |68     |91     |74.73   |
    |003|CATCH no catch used|7      |14     |50.00   |
    |004|IF if true numeric |12     |33     |36.36   |
    |005|IF elseif          |15     |47     |31.91   |
    |   |true numeric       |       |       |        |
    +---+-------------------+-------+-------+--------+
    %
    % # alternate way of doing the above
    % m format 2string r

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *report* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[matrix](\.\./\.\./\.\./\.\./index\.md\#matrix),
[report](\.\./\.\./\.\./\.\./index\.md\#report),
[table](\.\./\.\./\.\./\.\./index\.md\#table)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002\-2014 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
