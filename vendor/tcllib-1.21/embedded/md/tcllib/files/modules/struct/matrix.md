
[//000000001]: # (struct::matrix \- Tcl Data Structures)
[//000000002]: # (Generated from file 'matrix\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002\-2013,2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (struct::matrix\(n\) 2\.0\.4 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::matrix \- Create and manipulate matrix objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXAMPLES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require struct::matrix ?2\.0\.4?  

[__::struct::matrix__ ?*matrixName*? ?__=__&#124;__:=__&#124;__as__&#124;__deserialize__ *source*?](#1)  
[__matrixName__ *option* ?*arg arg \.\.\.*?](#2)  
[*matrixName* __=__ *sourcematrix*](#3)  
[*matrixName* __\-\->__ *destmatrix*](#4)  
[*matrixName* __add column__ ?*values*?](#5)  
[*matrixName* __add row__ ?*values*?](#6)  
[*matrixName* __add columns__ *n*](#7)  
[*matrixName* __add rows__ *n*](#8)  
[*matrixName* __cells__](#9)  
[*matrixName* __cellsize__ *column row*](#10)  
[*matrixName* __columns__](#11)  
[*matrixName* __columnwidth__ *column*](#12)  
[*matrixName* __delete column__ *column*](#13)  
[*matrixName* __delete columns__ *n*](#14)  
[*matrixName* __delete row__ *row*](#15)  
[*matrixName* __delete rows__ *n*](#16)  
[*matrixName* __deserialize__ *serialization*](#17)  
[*matrixName* __destroy__](#18)  
[*matrixName* __format 2string__ ?*report*?](#19)  
[*matrixName* __format 2chan__ ??*report*? *channel*?](#20)  
[*matrixName* __get cell__ *column row*](#21)  
[*matrixName* __get column__ *column*](#22)  
[*matrixName* __get rect__ *column\_tl row\_tl column\_br row\_br*](#23)  
[*matrixName* __get row__ *row*](#24)  
[*matrixName* __insert column__ *column* ?*values*?](#25)  
[*matrixName* __insert row__ *row* ?*values*?](#26)  
[*matrixName* __link__ ?\-transpose? *arrayvar*](#27)  
[*matrixName* __links__](#28)  
[*matrixName* __rowheight__ *row*](#29)  
[*matrixName* __rows__](#30)  
[*matrixName* __search__ ?\-nocase? ?\-exact&#124;\-glob&#124;\-regexp? __all__ *pattern*](#31)  
[*matrixName* __search__ ?\-nocase? ?\-exact&#124;\-glob&#124;\-regexp? __column__ *column pattern*](#32)  
[*matrixName* __search__ ?\-nocase? ?\-exact&#124;\-glob&#124;\-regexp? __row__ *row pattern*](#33)  
[*matrixName* __search__ ?\-nocase? ?\-exact&#124;\-glob&#124;\-regexp? __rect__ *column\_tl row\_tl column\_br row\_br pattern*](#34)  
[*matrixName* __serialize__ ?*column\_tl row\_tl column\_br row\_br*?](#35)  
[*matrixName* __set cell__ *column row value*](#36)  
[*matrixName* __set column__ *column values*](#37)  
[*matrixName* __set rect__ *column row values*](#38)  
[*matrixName* __set row__ *row values*](#39)  
[*matrixName* __sort columns__ ?__\-increasing__&#124;__\-decreasing__? *row*](#40)  
[*matrixName* __sort rows__ ?__\-increasing__&#124;__\-decreasing__? *column*](#41)  
[*matrixName* __swap columns__ *column\_a column\_b*](#42)  
[*matrixName* __swap rows__ *row\_a row\_b*](#43)  
[*matrixName* __transpose__](#44)  
[*matrixName* __unlink__ *arrayvar*](#45)  

# <a name='description'></a>DESCRIPTION

A matrix is a rectangular collection of cells, i\.e\. organized in rows and
columns\. Each cell contains exactly one value of arbitrary form\. The cells in
the matrix are addressed by pairs of integer numbers, with the first \(left\)
number in the pair specifying the column and the second \(right\) number
specifying the row the cell is in\. These indices are counted from 0 upward\. The
special non\-numeric index __end__ refers to the last row or column in the
matrix, depending on the context\. Indices of the form __end__\-__number__
are counted from the end of the row or column, like they are for standard Tcl
lists\. Trying to access non\-existing cells causes an error\.

The matrices here are created empty, i\.e\. they have neither rows nor columns\.
The user then has to add rows and columns as needed by his application\. A
specialty of this structure is the ability to export an array\-view onto its
contents\. Such can be used by tkTable, for example, to link the matrix into the
display\.

The main command of the package is:

  - <a name='1'></a>__::struct::matrix__ ?*matrixName*? ?__=__&#124;__:=__&#124;__as__&#124;__deserialize__ *source*?

    The command creates a new matrix object with an associated global Tcl
    command whose name is *matrixName*\. This command may be used to invoke
    various operations on the matrix\. It has the following general form:

      * <a name='2'></a>__matrixName__ *option* ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.

    If *matrixName* is not specified a unique name will be generated by the
    package itself\. If a *source* is specified the new matrix will be
    initialized to it\. For the operators __=__, __:=__, and __as__
    the argument *source* is interpreted as the name of another matrix object,
    and the assignment operator __=__ will be executed\. For
    __deserialize__ the *source* is a serialized matrix object and
    __deserialize__ will be executed\.

    In other words

        ::struct::matrix mymatrix = b

    is equivalent to

        ::struct::matrix mymatrix
        mymatrix = b

    and

        ::struct::matrix mymatrix deserialize $b

    is equivalent to

        ::struct::matrix mymatrix
        mymatrix deserialize $b

The following commands are possible for matrix objects:

  - <a name='3'></a>*matrixName* __=__ *sourcematrix*

    This is the assignment operator for matrix objects\. It copies the matrix
    contained in the matrix object *sourcematrix* over the matrix data in
    *matrixName*\. The old contents of *matrixName* are deleted by this
    operation\.

    This operation is in effect equivalent to

    > *matrixName* __deserialize__ \[*sourcematrix* __serialize__\]

  - <a name='4'></a>*matrixName* __\-\->__ *destmatrix*

    This is the reverse assignment operator for matrix objects\. It copies the
    matrix contained in the matrix object *matrixName* over the matrix data in
    the object *destmatrix*\. The old contents of *destmatrix* are deleted by
    this operation\.

    This operation is in effect equivalent to

    > *destmatrix* __deserialize__ \[*matrixName* __serialize__\]

  - <a name='5'></a>*matrixName* __add column__ ?*values*?

    Extends the matrix by one column and then acts like __set column__ \(see
    below\) on this new column if there were *values* supplied\. Without
    *values* the new cells will be set to the empty string\. The new column is
    appended immediately behind the last existing column\.

  - <a name='6'></a>*matrixName* __add row__ ?*values*?

    Extends the matrix by one row and then acts like __set row__ \(see below\)
    on this new row if there were *values* supplied\. Without *values* the
    new cells will be set to the empty string\. The new row is appended
    immediately behind the last existing row\.

  - <a name='7'></a>*matrixName* __add columns__ *n*

    Extends the matrix by *n* columns\. The new cells will be set to the empty
    string\. The new columns are appended immediately behind the last existing
    column\. A value of *n* equal to or smaller than 0 is not allowed\.

  - <a name='8'></a>*matrixName* __add rows__ *n*

    Extends the matrix by *n* rows\. The new cells will be set to the empty
    string\. The new rows are appended immediately behind the last existing row\.
    A value of *n* equal to or smaller than 0 is not allowed\.

  - <a name='9'></a>*matrixName* __cells__

    Returns the number of cells currently managed by the matrix\. This is the
    product of __rows__ and __columns__\.

  - <a name='10'></a>*matrixName* __cellsize__ *column row*

    Returns the length of the string representation of the value currently
    contained in the addressed cell\.

  - <a name='11'></a>*matrixName* __columns__

    Returns the number of columns currently managed by the matrix\.

  - <a name='12'></a>*matrixName* __columnwidth__ *column*

    Returns the length of the longest string representation of all the values
    currently contained in the cells of the addressed column if these are all
    spanning only one line\. For cell values spanning multiple lines the length
    of their longest line goes into the computation\.

    *Note:* The command recognizes ANSI color control sequences and excludes
    them from the width of a line, as they are logically of zero width\.

  - <a name='13'></a>*matrixName* __delete column__ *column*

    Deletes the specified column from the matrix and shifts all columns with
    higher indices one index down\.

  - <a name='14'></a>*matrixName* __delete columns__ *n*

    Deletes *n* columns from the right of the matrix\. The value of *n* has
    to satisfy the constraint "0 < *n* < \[__matrixName__ __columns__\]"

  - <a name='15'></a>*matrixName* __delete row__ *row*

    Deletes the specified row from the matrix and shifts all row with higher
    indices one index down\.

  - <a name='16'></a>*matrixName* __delete rows__ *n*

    Deletes *n* rows from the bottom of the matrix\. The value of *n* has to
    satisfy the constraint "0 < *n* < \[__matrixName__ __rows__\]"

  - <a name='17'></a>*matrixName* __deserialize__ *serialization*

    This is the complement to __serialize__\. It replaces matrix data in
    *matrixName* with the matrix described by the *serialization* value\. The
    old contents of *matrixName* are deleted by this operation\.

  - <a name='18'></a>*matrixName* __destroy__

    Destroys the matrix, including its storage space and associated command\.

  - <a name='19'></a>*matrixName* __format 2string__ ?*report*?

    Formats the matrix using the specified report object and returns the string
    containing the result of this operation\. The report has to support the
    __printmatrix__ method\. If no *report* is specified the system will
    use an internal report definition to format the matrix\.

  - <a name='20'></a>*matrixName* __format 2chan__ ??*report*? *channel*?

    Formats the matrix using the specified report object and writes the string
    containing the result of this operation into the channel\. The report has to
    support the __printmatrix2channel__ method\. If no *report* is
    specified the system will use an internal report definition to format the
    matrix\. If no *channel* is specified the system will use __stdout__\.

  - <a name='21'></a>*matrixName* __get cell__ *column row*

    Returns the value currently contained in the cell identified by row and
    column index\.

  - <a name='22'></a>*matrixName* __get column__ *column*

    Returns a list containing the values from all cells in the column identified
    by the index\. The contents of the cell in row 0 are stored as the first
    element of this list\.

  - <a name='23'></a>*matrixName* __get rect__ *column\_tl row\_tl column\_br row\_br*

    Returns a list of lists of cell values\. The values stored in the result come
    from the sub\-matrix whose top\-left and bottom\-right cells are specified by
    *column\_tl, row\_tl* and *column\_br, row\_br* resp\. Note that the
    following equations have to be true: "*column\_tl* <= *column\_br*" and
    "*row\_tl* <= *row\_br*"\. The result is organized as follows: The outer
    list is the list of rows, its elements are lists representing a single row\.
    The row with the smallest index is the first element of the outer list\. The
    elements of the row lists represent the selected cell values\. The cell with
    the smallest index is the first element in each row list\.

  - <a name='24'></a>*matrixName* __get row__ *row*

    Returns a list containing the values from all cells in the row identified by
    the index\. The contents of the cell in column 0 are stored as the first
    element of this list\.

  - <a name='25'></a>*matrixName* __insert column__ *column* ?*values*?

    Extends the matrix by one column and then acts like __set column__ \(see
    below\) on this new column if there were *values* supplied\. Without
    *values* the new cells will be set to the empty string\. The new column is
    inserted just before the column specified by the given index\. This means, if
    *column* is less than or equal to zero, then the new column is inserted at
    the beginning of the matrix, before the first column\. If *column* has the
    value __end__, or if it is greater than or equal to the number of
    columns in the matrix, then the new column is appended to the matrix, behind
    the last column\. The old column at the chosen index and all columns with
    higher indices are shifted one index upward\.

  - <a name='26'></a>*matrixName* __insert row__ *row* ?*values*?

    Extends the matrix by one row and then acts like __set row__ \(see below\)
    on this new row if there were *values* supplied\. Without *values* the
    new cells will be set to the empty string\. The new row is inserted just
    before the row specified by the given index\. This means, if *row* is less
    than or equal to zero, then the new row is inserted at the beginning of the
    matrix, before the first row\. If *row* has the value __end__, or if it
    is greater than or equal to the number of rows in the matrix, then the new
    row is appended to the matrix, behind the last row\. The old row at that
    index and all rows with higher indices are shifted one index upward\.

  - <a name='27'></a>*matrixName* __link__ ?\-transpose? *arrayvar*

    Links the matrix to the specified array variable\. This means that the
    contents of all cells in the matrix is stored in the array too, with all
    changes to the matrix propagated there too\. The contents of the cell
    *\(column,row\)* is stored in the array using the key *column,row*\. If the
    option __\-transpose__ is specified the key *row,column* will be used
    instead\. It is possible to link the matrix to more than one array\. Note that
    the link is bidirectional, i\.e\. changes to the array are mirrored in the
    matrix too\.

  - <a name='28'></a>*matrixName* __links__

    Returns a list containing the names of all array variables the matrix was
    linked to through a call to method __link__\.

  - <a name='29'></a>*matrixName* __rowheight__ *row*

    Returns the height of the specified row in lines\. This is the highest number
    of lines spanned by a cell over all cells in the row\.

  - <a name='30'></a>*matrixName* __rows__

    Returns the number of rows currently managed by the matrix\.

  - <a name='31'></a>*matrixName* __search__ ?\-nocase? ?\-exact&#124;\-glob&#124;\-regexp? __all__ *pattern*

    Searches the whole matrix for cells matching the *pattern* and returns a
    list with all matches\. Each item in the aforementioned list is a list itself
    and contains the column and row index of the matching cell, in this order\.
    The results are ordered by column first and row second, both times in
    ascending order\. This means that matches to the left and the top of the
    matrix come before matches to the right and down\.

    The type of the pattern \(string, glob, regular expression\) is determined by
    the option after the __search__ keyword\. If no option is given it
    defaults to __\-exact__\.

    If the option __\-nocase__ is specified the search will be
    case\-insensitive\.

  - <a name='32'></a>*matrixName* __search__ ?\-nocase? ?\-exact&#124;\-glob&#124;\-regexp? __column__ *column pattern*

    Like __search all__, but the search is restricted to the specified
    column\.

  - <a name='33'></a>*matrixName* __search__ ?\-nocase? ?\-exact&#124;\-glob&#124;\-regexp? __row__ *row pattern*

    Like __search all__, but the search is restricted to the specified row\.

  - <a name='34'></a>*matrixName* __search__ ?\-nocase? ?\-exact&#124;\-glob&#124;\-regexp? __rect__ *column\_tl row\_tl column\_br row\_br pattern*

    Like __search all__, but the search is restricted to the specified
    rectangular area of the matrix\.

  - <a name='35'></a>*matrixName* __serialize__ ?*column\_tl row\_tl column\_br row\_br*?

    This method serializes the sub\-matrix spanned up by the rectangle
    specification\. In other words it returns a tcl *value* completely
    describing that matrix\. If no rectangle is specified the whole matrix will
    be serialized\. This allows, for example, the transfer of matrix objects \(or
    parts thereof\) over arbitrary channels, persistence, etc\. This method is
    also the basis for both the copy constructor and the assignment operator\.

    The result of this method has to be semantically identical over all
    implementations of the matrix interface\. This is what will enable us to copy
    matrix data between different implementations of the same interface\.

    The result is a list containing exactly three items\.

    The first two elements of the list specify the number of rows and columns of
    the matrix, in that order\. The values integer numbers greater than or equal
    to zero\.

    The last element of the list contains the values of the matrix cells we have
    serialized, in the form of a value like it is returned by the __get
    rect__\. However empty cells to the right and bottom of the matrix can be
    left out of that value as the size information in the serialization allows
    the receiver the creation of a matrix with the proper size despite the
    missing values\.

        # A possible serialization for the matrix structure
        #
        # | a b d g |
        # | c e     |
        # | f       |
        #
        # is
        #
        # 3 4 {{a b d g} {c e} {f}}

  - <a name='36'></a>*matrixName* __set cell__ *column row value*

    Sets the value in the cell identified by row and column index to the data in
    the third argument\.

  - <a name='37'></a>*matrixName* __set column__ *column values*

    Sets the values in the cells identified by the column index to the elements
    of the list provided as the third argument\. Each element of the list is
    assigned to one cell, with the first element going into the cell in row 0
    and then upward\. If there are less values in the list than there are rows
    the remaining rows are set to the empty string\. If there are more values in
    the list than there are rows the superfluous elements are ignored\. The
    matrix is not extended by this operation\.

  - <a name='38'></a>*matrixName* __set rect__ *column row values*

    Takes a list of lists of cell values and writes them into the submatrix
    whose top\-left cell is specified by the two indices\. If the sublists of the
    outerlist are not of equal length the shorter sublists will be filled with
    empty strings to the length of the longest sublist\. If the submatrix
    specified by the top\-left cell and the number of rows and columns in the
    *values* extends beyond the matrix we are modifying the over\-extending
    parts of the values are ignored, i\.e\. essentially cut off\. This subcommand
    expects its input in the format as returned by __get rect__\.

  - <a name='39'></a>*matrixName* __set row__ *row values*

    Sets the values in the cells identified by the row index to the elements of
    the list provided as the third argument\. Each element of the list is
    assigned to one cell, with the first element going into the cell in column 0
    and then upward\. If there are less values in the list than there are columns
    the remaining columns are set to the empty string\. If there are more values
    in the list than there are columns the superfluous elements are ignored\. The
    matrix is not extended by this operation\.

  - <a name='40'></a>*matrixName* __sort columns__ ?__\-increasing__&#124;__\-decreasing__? *row*

    Sorts the columns in the matrix using the data in the specified *row* as
    the key to sort by\. The options __\-increasing__ and __\-decreasing__
    have the same meaning as for __lsort__\. If no option is specified
    __\-increasing__ is assumed\.

  - <a name='41'></a>*matrixName* __sort rows__ ?__\-increasing__&#124;__\-decreasing__? *column*

    Sorts the rows in the matrix using the data in the specified *column* as
    the key to sort by\. The options __\-increasing__ and __\-decreasing__
    have the same meaning as for __lsort__\. If no option is specified
    __\-increasing__ is assumed\.

  - <a name='42'></a>*matrixName* __swap columns__ *column\_a column\_b*

    Swaps the contents of the two specified columns\.

  - <a name='43'></a>*matrixName* __swap rows__ *row\_a row\_b*

    Swaps the contents of the two specified rows\.

  - <a name='44'></a>*matrixName* __transpose__

    Transposes the contents of the matrix, i\.e\. swaps rows for columns and vice
    versa\.

  - <a name='45'></a>*matrixName* __unlink__ *arrayvar*

    Removes the link between the matrix and the specified arrayvariable, if
    there is one\.

# <a name='section2'></a>EXAMPLES

The examples below assume a 5x5 matrix M with the first row containing the
values 1 to 5, with 1 in the top\-left cell\. Each other row contains the contents
of the row above it, rotated by one cell to the right\.

    % M get rect 0 0 4 4
    {{1 2 3 4 5} {5 1 2 3 4} {4 5 1 2 3} {3 4 5 1 2} {2 3 4 5 1}}

    % M set rect 1 1 {{0 0 0} {0 0 0} {0 0 0}}
    % M get rect 0 0 4 4
    {{1 2 3 4 5} {5 0 0 0 4} {4 0 0 0 3} {3 0 0 0 2} {2 3 4 5 1}}

Assuming that the style definitions in the example section of the manpage for
the package __[report](\.\./report/report\.md)__ are loaded into the
interpreter now an example which formats a matrix into a tabular report\. The
code filling the matrix with data is not shown\. contains useful data\.

    % ::struct::matrix m
    % # ... fill m with data, assume 5 columns
    % ::report::report r 5 style captionedtable 1
    % m format 2string r
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
    % r printmatrix m

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: matrix* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[matrix](\.\./\.\./\.\./\.\./index\.md\#matrix)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002\-2013,2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
