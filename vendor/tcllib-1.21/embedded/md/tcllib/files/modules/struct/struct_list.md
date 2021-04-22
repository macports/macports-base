
[//000000001]: # (struct::list \- Tcl Data Structures)
[//000000002]: # (Generated from file 'struct\_list\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003\-2005 by Kevin B\. Kenny\. All rights reserved)
[//000000004]: # (Copyright &copy; 2003\-2012 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (struct::list\(n\) 1\.8\.5 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::list \- Procedures for manipulating lists

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [LONGEST COMMON SUBSEQUENCE AND FILE COMPARISON](#section3)

  - [TABLE JOIN](#section4)

  - [REFERENCES](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require struct::list ?1\.8\.5?  

[__::struct::list__ __longestCommonSubsequence__ *sequence1* *sequence2* ?*maxOccurs*?](#1)  
[__::struct::list__ __longestCommonSubsequence2__ *sequence1 sequence2* ?*maxOccurs*?](#2)  
[__::struct::list__ __lcsInvert__ *lcsData* *len1* *len2*](#3)  
[__::struct::list__ __lcsInvert2__ *lcs1* *lcs2* *len1* *len2*](#4)  
[__::struct::list__ __lcsInvertMerge__ *lcsData* *len1* *len2*](#5)  
[__::struct::list__ __lcsInvertMerge2__ *lcs1* *lcs2* *len1* *len2*](#6)  
[__::struct::list__ __reverse__ *sequence*](#7)  
[__::struct::list__ __shuffle__ *list*](#8)  
[__::struct::list__ __assign__ *sequence* *varname* ?*varname*?\.\.\.](#9)  
[__::struct::list__ __flatten__ ?__\-full__? ?__\-\-__? *sequence*](#10)  
[__::struct::list__ __map__ *sequence* *cmdprefix*](#11)  
[__::struct::list__ __mapfor__ *var* *sequence* *script*](#12)  
[__::struct::list__ __filter__ *sequence* *cmdprefix*](#13)  
[__::struct::list__ __filterfor__ *var* *sequence* *expr*](#14)  
[__::struct::list__ __split__ *sequence* *cmdprefix* ?*passVar* *failVar*?](#15)  
[__::struct::list__ __fold__ *sequence* *initialvalue* *cmdprefix*](#16)  
[__::struct::list__ __shift__ *listvar*](#17)  
[__::struct::list__ __iota__ *n*](#18)  
[__::struct::list__ __equal__ *a* *b*](#19)  
[__::struct::list__ __repeat__ *size* *element1* ?*element2* *element3*\.\.\.?](#20)  
[__::struct::list__ __repeatn__ *value* *size*\.\.\.](#21)  
[__::struct::list__ __dbJoin__ ?__\-inner__&#124;__\-left__&#124;__\-right__&#124;__\-full__? ?__\-keys__ *varname*? \{*keycol* *table*\}\.\.\.](#22)  
[__::struct::list__ __dbJoinKeyed__ ?__\-inner__&#124;__\-left__&#124;__\-right__&#124;__\-full__? ?__\-keys__ *varname*? *table*\.\.\.](#23)  
[__::struct::list__ __swap__ *listvar* *i* *j*](#24)  
[__::struct::list__ __firstperm__ *list*](#25)  
[__::struct::list__ __nextperm__ *perm*](#26)  
[__::struct::list__ __permutations__ *list*](#27)  
[__::struct::list__ __foreachperm__ *var* *list* *body*](#28)  

# <a name='description'></a>DESCRIPTION

The __::struct::list__ namespace contains several useful commands for
processing Tcl lists\. Generally speaking, they implement algorithms more complex
or specialized than the ones provided by Tcl itself\.

It exports only a single command, __struct::list__\. All functionality
provided here can be reached through a subcommand of this command\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::struct::list__ __longestCommonSubsequence__ *sequence1* *sequence2* ?*maxOccurs*?

    Returns a list of indices into *sequence1* and a corresponding list where
    each item is an index into *sequence2* of the matching value according to
    the longest common subsequences algorithm\. If *maxOccurs* is provided, the
    common subsequence is restricted to elements that occur no more than
    *maxOccurs* times in *sequence2*\.

  - <a name='2'></a>__::struct::list__ __longestCommonSubsequence2__ *sequence1 sequence2* ?*maxOccurs*?

    Returns the longest common subsequence of elements in the two lists
    *sequence1* and *sequence2*\. If *maxOccurs* is provided, the result is
    only an approximation, where the longest common subsequence is approximated
    by first determining the longest common sequence of only those elements that
    occur no more than *maxOccurs* times in *sequence2*, and then using that
    result to align the two lists, determining the longest common subsequences
    of the sublists between the two elements\.

    The result is the same as for __longestCommonSubsequence__\.

  - <a name='3'></a>__::struct::list__ __lcsInvert__ *lcsData* *len1* *len2*

    Takes a description of a longest common subsequence \(*lcsData*\), inverts
    it, and returns the result\. Inversion means here that as the input describes
    which parts of the two sequences are identical the output describes the
    differences instead\.

    To be fully defined the lengths of the two sequences have to be known and
    are specified through *len1* and *len2*\.

    The result is a list where each element describes one chunk of the
    differences between the two sequences\. This description is a list containing
    three elements, a type and two pairs of indices into *sequence1* and
    *sequence2* respectively, in this order\. The type can be one of three
    values:

      * __added__

        Describes an addition\. I\.e\. items which are missing in *sequence1* can
        be found in *sequence2*\. The pair of indices into *sequence1*
        describes where the added range had been expected to be in
        *sequence1*\. The first index refers to the item just before the added
        range, and the second index refers to the item just after the added
        range\. The pair of indices into *sequence2* describes the range of
        items which has been added to it\. The first index refers to the first
        item in the range, and the second index refers to the last item in the
        range\.

      * __deleted__

        Describes a deletion\. I\.e\. items which are in *sequence1* are missing
        from *sequence2*\. The pair of indices into *sequence1* describes the
        range of items which has been deleted\. The first index refers to the
        first item in the range, and the second index refers to the last item in
        the range\. The pair of indices into *sequence2* describes where the
        deleted range had been expected to be in *sequence2*\. The first index
        refers to the item just before the deleted range, and the second index
        refers to the item just after the deleted range\.

      * __changed__

        Describes a general change\. I\.e a range of items in *sequence1* has
        been replaced by a different range of items in *sequence2*\. The pair
        of indices into *sequence1* describes the range of items which has
        been replaced\. The first index refers to the first item in the range,
        and the second index refers to the last item in the range\. The pair of
        indices into *sequence2* describes the range of items replacing the
        original range\. Again the first index refers to the first item in the
        range, and the second index refers to the last item in the range\.

        sequence 1 = {a b r a c a d a b r a}
        lcs 1      =   {1 2   4 5     8 9 10}
        lcs 2      =   {0 1   3 4     5 6 7}
        sequence 2 =   {b r i c a     b r a c}

        Inversion  = {{deleted  {0  0} {-1 0}}
                      {changed  {3  3}  {2 2}}
                      {deleted  {6  7}  {4 5}}
                      {added   {10 11}  {8 8}}}

    *Notes:*

      * An index of __\-1__ in a *deleted* chunk refers to just before the
        first element of the second sequence\.

      * Also an index equal to the length of the first sequence in an *added*
        chunk refers to just behind the end of the sequence\.

  - <a name='4'></a>__::struct::list__ __lcsInvert2__ *lcs1* *lcs2* *len1* *len2*

    Similar to __lcsInvert__\. Instead of directly taking the result of a
    call to __longestCommonSubsequence__ this subcommand expects the indices
    for the two sequences in two separate lists\.

  - <a name='5'></a>__::struct::list__ __lcsInvertMerge__ *lcsData* *len1* *len2*

    Similar to __lcsInvert__\. It returns essentially the same structure as
    that command, except that it may contain chunks of type __unchanged__
    too\.

    These new chunks describe the parts which are unchanged between the two
    sequences\. This means that the result of this command describes both the
    changed and unchanged parts of the two sequences in one structure\.

        sequence 1 = {a b r a c a d a b r a}
        lcs 1      =   {1 2   4 5     8 9 10}
        lcs 2      =   {0 1   3 4     5 6 7}
        sequence 2 =   {b r i c a     b r a c}

        Inversion/Merge  = {{deleted   {0  0} {-1 0}}
                            {unchanged {1  2}  {0 1}}
                            {changed   {3  3}  {2 2}}
                            {unchanged {4  5}  {3 4}}
                            {deleted   {6  7}  {4 5}}
                            {unchanged {8 10}  {5 7}}
                            {added    {10 11}  {8 8}}}

  - <a name='6'></a>__::struct::list__ __lcsInvertMerge2__ *lcs1* *lcs2* *len1* *len2*

    Similar to __lcsInvertMerge__\. Instead of directly taking the result of
    a call to __longestCommonSubsequence__ this subcommand expects the
    indices for the two sequences in two separate lists\.

  - <a name='7'></a>__::struct::list__ __reverse__ *sequence*

    The subcommand takes a single *sequence* as argument and returns a new
    sequence containing the elements of the input sequence in reverse order\.

  - <a name='8'></a>__::struct::list__ __shuffle__ *list*

    The subcommand takes a *list* and returns a copy of that list with the
    elements it contains in random order\. Every possible ordering of elements is
    equally likely to be generated\. The Fisher\-Yates shuffling algorithm is used
    internally\.

  - <a name='9'></a>__::struct::list__ __assign__ *sequence* *varname* ?*varname*?\.\.\.

    The subcommand assigns the first __n__ elements of the input
    *sequence* to the one or more variables whose names were listed after the
    sequence, where __n__ is the number of specified variables\.

    If there are more variables specified than there are elements in the
    *sequence* the empty string will be assigned to the superfluous variables\.

    If there are more elements in the *sequence* than variable names specified
    the subcommand returns a list containing the unassigned elements\. Else an
    empty list is returned\.

        tclsh> ::struct::list assign {a b c d e} foo bar
        c d e
        tclsh> set foo
        a
        tclsh> set bar
        b

  - <a name='10'></a>__::struct::list__ __flatten__ ?__\-full__? ?__\-\-__? *sequence*

    The subcommand takes a single *sequence* and returns a new sequence where
    one level of nesting was removed from the input sequence\. In other words,
    the sublists in the input sequence are replaced by their elements\.

    The subcommand will remove any nesting it finds if the option __\-full__
    is specified\.

        tclsh> ::struct::list flatten {1 2 3 {4 5} {6 7} {{8 9}} 10}
        1 2 3 4 5 6 7 {8 9} 10
        tclsh> ::struct::list flatten -full {1 2 3 {4 5} {6 7} {{8 9}} 10}
        1 2 3 4 5 6 7 8 9 10

  - <a name='11'></a>__::struct::list__ __map__ *sequence* *cmdprefix*

    The subcommand takes a *sequence* to operate on and a command prefix
    \(*cmdprefix*\) specifying an operation, applies the command prefix to each
    element of the sequence and returns a sequence consisting of the results of
    that application\.

    The command prefix will be evaluated with a single word appended to it\. The
    evaluation takes place in the context of the caller of the subcommand\.

        tclsh> # squaring all elements in a list

        tclsh> proc sqr {x} {expr {$x*$x}}
        tclsh> ::struct::list map {1 2 3 4 5} sqr
        1 4 9 16 25

        tclsh> # Retrieving the second column from a matrix
        tclsh> # given as list of lists.

        tclsh> proc projection {n list} {::lindex $list $n}
        tclsh> ::struct::list map {{a b c} {1 2 3} {d f g}} {projection 1}
        b 2 f

  - <a name='12'></a>__::struct::list__ __mapfor__ *var* *sequence* *script*

    The subcommand takes a *sequence* to operate on and a tcl *script*,
    applies the script to each element of the sequence and returns a sequence
    consisting of the results of that application\.

    The script will be evaluated as is, and has access to the current list
    element through the specified iteration variable *var*\. The evaluation
    takes place in the context of the caller of the subcommand\.

            tclsh> # squaring all elements in a list

            tclsh> ::struct::list mapfor x {1 2 3 4 5} {
        	expr {$x * $x}
            }
            1 4 9 16 25

            tclsh> # Retrieving the second column from a matrix
            tclsh> # given as list of lists.

            tclsh> ::struct::list mapfor x {{a b c} {1 2 3} {d f g}} {
        	lindex $x 1
            }
            b 2 f

  - <a name='13'></a>__::struct::list__ __filter__ *sequence* *cmdprefix*

    The subcommand takes a *sequence* to operate on and a command prefix
    \(*cmdprefix*\) specifying an operation, applies the command prefix to each
    element of the sequence and returns a sequence consisting of all elements of
    the *sequence* for which the command prefix returned __true__\. In
    other words, this command filters out all elements of the input *sequence*
    which fail the test the *cmdprefix* represents, and returns the remaining
    elements\.

    The command prefix will be evaluated with a single word appended to it\. The
    evaluation takes place in the context of the caller of the subcommand\.

        tclsh> # removing all odd numbers from the input

        tclsh> proc even {x} {expr {($x % 2) == 0}}
        tclsh> ::struct::list filter {1 2 3 4 5} even
        2 4

    *Note:* The __filter__ is a specialized application of __fold__
    where the result is extended with the current item or not, depending o nthe
    result of the test\.

  - <a name='14'></a>__::struct::list__ __filterfor__ *var* *sequence* *expr*

    The subcommand takes a *sequence* to operate on and a tcl expression
    \(*expr*\) specifying a condition, applies the conditionto each element of
    the sequence and returns a sequence consisting of all elements of the
    *sequence* for which the expression returned __true__\. In other words,
    this command filters out all elements of the input *sequence* which fail
    the test the condition *expr* represents, and returns the remaining
    elements\.

    The expression will be evaluated as is, and has access to the current list
    element through the specified iteration variable *var*\. The evaluation
    takes place in the context of the caller of the subcommand\.

        tclsh> # removing all odd numbers from the input

        tclsh> ::struct::list filterfor x {1 2 3 4 5} {($x % 2) == 0}
        2 4

  - <a name='15'></a>__::struct::list__ __split__ *sequence* *cmdprefix* ?*passVar* *failVar*?

    This is a variant of method __filter__, see above\. Instead of returning
    just the elements passing the test we get lists of both passing and failing
    elements\.

    If no variable names are specified then the result of the command will be a
    list containing the list of passing elements, and the list of failing
    elements, in this order\. Otherwise the lists of passing and failing elements
    are stored into the two specified variables, and the result will be a list
    containing two numbers, the number of elements passing the test, and the
    number of elements failing, in this order\.

    The interface to the test is the same as used by __filter__\.

  - <a name='16'></a>__::struct::list__ __fold__ *sequence* *initialvalue* *cmdprefix*

    The subcommand takes a *sequence* to operate on, an arbitrary string
    *initial value* and a command prefix \(*cmdprefix*\) specifying an
    operation\.

    The command prefix will be evaluated with two words appended to it\. The
    second of these words will always be an element of the sequence\. The
    evaluation takes place in the context of the caller of the subcommand\.

    It then reduces the sequence into a single value through repeated
    application of the command prefix and returns that value\. This reduction is
    done by

      * __1__

        Application of the command to the initial value and the first element of
        the list\.

      * __2__

        Application of the command to the result of the last call and the second
        element of the list\.

      * __\.\.\.__

      * __i__

        Application of the command to the result of the last call and the
        __i__'th element of the list\.

      * __\.\.\.__

      * __end__

        Application of the command to the result of the last call and the last
        element of the list\. The result of this call is returned as the result
        of the subcommand\.

        tclsh> # summing the elements in a list.
        tclsh> proc + {a b} {expr {$a + $b}}
        tclsh> ::struct::list fold {1 2 3 4 5} 0 +
        15

  - <a name='17'></a>__::struct::list__ __shift__ *listvar*

    The subcommand takes the list contained in the variable named by *listvar*
    and shifts it down one element\. After the call *listvar* will contain a
    list containing the second to last elements of the input list\. The first
    element of the ist is returned as the result of the command\. Shifting the
    empty list does nothing\.

  - <a name='18'></a>__::struct::list__ __iota__ *n*

    The subcommand returns a list containing the integer numbers in the range
    __\[0,n\)__\. The element at index __i__ of the list contain the number
    __i__\.

    For "*n* == __0__" an empty list will be returned\.

  - <a name='19'></a>__::struct::list__ __equal__ *a* *b*

    The subcommand compares the two lists *a* and *b* for equality\. In other
    words, they have to be of the same length and have to contain the same
    elements in the same order\. If an element is a list the same definition of
    equality applies recursively\.

    A boolean value will be returned as the result of the command\. This value
    will be __true__ if the two lists are equal, and __false__ else\.

  - <a name='20'></a>__::struct::list__ __repeat__ *size* *element1* ?*element2* *element3*\.\.\.?

    The subcommand creates a list of length "*size* \* *number of elements*"
    by repeating *size* times the sequence of elements *element1*
    *element2* *\.\.\.*\. *size* must be a positive integer,
    *element*__n__ can be any Tcl value\. Note that __repeat 1 arg
    \.\.\.__ is identical to __list arg \.\.\.__, though the *arg* is required
    with __repeat__\.

    *Examples:*

        tclsh> ::struct::list repeat 3 a
        a a a
        tclsh> ::struct::list repeat 3 [::struct::list repeat 3 0]
        {0 0 0} {0 0 0} {0 0 0}
        tclsh> ::struct::list repeat 3 a b c
        a b c a b c a b c
        tclsh> ::struct::list repeat 3 [::struct::list repeat 2 a] b c
        {a a} b c {a a} b c {a a} b c

  - <a name='21'></a>__::struct::list__ __repeatn__ *value* *size*\.\.\.

    The subcommand creates a \(nested\) list containing the *value* in all
    positions\. The exact size and degree of nesting is determined by the
    *size* arguments, all of which have to be integer numbers greater than or
    equal to zero\.

    A single argument *size* which is a list of more than one element will be
    treated as if more than argument *size* was specified\.

    If only one argument *size* is present the returned list will not be
    nested, of length *size* and contain *value* in all positions\. If more
    than one *size* argument is present the returned list will be nested, and
    of the length specified by the last *size* argument given to it\. The
    elements of that list are defined as the result of __Repeat__ for the
    same arguments, but with the last *size* value removed\.

    An empty list will be returned if no *size* arguments are present\.

        tclsh> ::struct::list repeatn  0 3 4
        {0 0 0} {0 0 0} {0 0 0} {0 0 0}
        tclsh> ::struct::list repeatn  0 {3 4}
        {0 0 0} {0 0 0} {0 0 0} {0 0 0}
        tclsh> ::struct::list repeatn  0 {3 4 5}
        {{0 0 0} {0 0 0} {0 0 0} {0 0 0}} {{0 0 0} {0 0 0} {0 0 0} {0 0 0}} {{0 0 0} {0 0 0} {0 0 0} {0 0 0}} {{0 0 0} {0 0 0} {0 0 0} {0 0 0}} {{0 0 0} {0 0 0} {0 0 0} {0 0 0}}

  - <a name='22'></a>__::struct::list__ __dbJoin__ ?__\-inner__&#124;__\-left__&#124;__\-right__&#124;__\-full__? ?__\-keys__ *varname*? \{*keycol* *table*\}\.\.\.

    The method performs a table join according to relational algebra\. The
    execution of any of the possible outer join operation is triggered by the
    presence of either option __\-left__, __\-right__, or __\-full__\.
    If none of these options is present a regular inner join will be performed\.
    This can also be triggered by specifying __\-inner__\. The various
    possible join operations are explained in detail in section [TABLE
    JOIN](#section4)\.

    If the __\-keys__ is present its argument is the name of a variable to
    store the full list of found keys into\. Depending on the exact nature of the
    input table and the join mode the output table may not contain all the keys
    by default\. In such a case the caller can declare a variable for this
    information and then insert it into the output table on its own, as she will
    have more information about the placement than this command\.

    What is left to explain is the format of the arguments\.

    The *keycol* arguments are the indices of the columns in the tables which
    contain the key values to use for the joining\. Each argument applies to the
    table following immediately after it\. The columns are counted from
    __0__, which references the first column\. The table associated with the
    column index has to have at least *keycol*\+1 columns\. An error will be
    thrown if there are less\.

    The *table* arguments represent a table or matrix of rows and columns of
    values\. We use the same representation as generated and consumed by the
    methods __get rect__ and __set rect__ of
    __[matrix](\.\./\.\./\.\./\.\./index\.md\#matrix)__ objects\. In other words,
    each argument is a list, representing the whole matrix\. Its elements are
    lists too, each representing a single rows of the matrix\. The elements of
    the row\-lists are the column values\.

    The table resulting from the join operation is returned as the result of the
    command\. We use the same representation as described above for the input
    *table*s\.

  - <a name='23'></a>__::struct::list__ __dbJoinKeyed__ ?__\-inner__&#124;__\-left__&#124;__\-right__&#124;__\-full__? ?__\-keys__ *varname*? *table*\.\.\.

    The operations performed by this method are the same as described above for
    __dbJoin__\. The only difference is in the specification of the keys to
    use\. Instead of using column indices separate from the table here the keys
    are provided within the table itself\. The row elements in each *table* are
    not the lists of column values, but a two\-element list where the second
    element is the regular list of column values and the first element is the
    key to use\.

  - <a name='24'></a>__::struct::list__ __swap__ *listvar* *i* *j*

    The subcommand exchanges the elements at the indices *i* and *j* in the
    list stored in the variable named by *listvar*\. The list is modified in
    place, and also returned as the result of the subcommand\.

  - <a name='25'></a>__::struct::list__ __firstperm__ *list*

    This subcommand returns the lexicographically first permutation of the input
    *list*\.

  - <a name='26'></a>__::struct::list__ __nextperm__ *perm*

    This subcommand accepts a permutation of a set of elements \(provided by
    *perm*\) and returns the next permutatation in lexicographic sequence\.

    The algorithm used here is by Donal E\. Knuth, see section
    [REFERENCES](#section5) for details\.

  - <a name='27'></a>__::struct::list__ __permutations__ *list*

    This subcommand returns a list containing all permutations of the input
    *list* in lexicographic order\.

  - <a name='28'></a>__::struct::list__ __foreachperm__ *var* *list* *body*

    This subcommand executes the script *body* once for each permutation of
    the specified *list*\. The permutations are visited in lexicographic order,
    and the variable *var* is set to the permutation for which *body* is
    currently executed\. The result of the loop command is the empty string\.

# <a name='section3'></a>LONGEST COMMON SUBSEQUENCE AND FILE COMPARISON

The __longestCommonSubsequence__ subcommand forms the core of a flexible
system for doing differential comparisons of files, similar to the capability
offered by the Unix command __[diff](\.\./\.\./\.\./\.\./index\.md\#diff)__\. While
this procedure is quite rapid for many tasks of file comparison, its performance
degrades severely if *sequence2* contains many equal elements \(as, for
instance, when using this procedure to compare two files, a quarter of whose
lines are blank\. This drawback is intrinsic to the algorithm used \(see the
Reference for details\)\.

One approach to dealing with the performance problem that is sometimes effective
in practice is arbitrarily to exclude elements that appear more than a certain
number of times\. This number is provided as the *maxOccurs* parameter\. If
frequent lines are excluded in this manner, they will not appear in the common
subsequence that is computed; the result will be the longest common subsequence
of infrequent elements\. The procedure __longestCommonSubsequence2__
implements this heuristic\. It functions as a wrapper around
__longestCommonSubsequence__; it computes the longest common subsequence of
infrequent elements, and then subdivides the subsequences that lie between the
matches to approximate the true longest common subsequence\.

# <a name='section4'></a>TABLE JOIN

This is an operation from relational algebra for relational databases\.

The easiest way to understand the regular inner join is that it creates the
cartesian product of all the tables involved first and then keeps only all those
rows in the resulting table for which the values in the specified key columns
are equal to each other\.

Implementing this description naively, i\.e\. as described above will generate a
*huge* intermediate result\. To avoid this the cartesian product and the
filtering of row are done at the same time\. What is required is a fast way to
determine if a key is present in a table\. In a true database this is done
through indices\. Here we use arrays internally\.

An *outer* join is an extension of the inner join for two tables\. There are
three variants of outerjoins, called *left*, *right*, and *full* outer
joins\. Their result always contains all rows from an inner join and then some
additional rows\.

  1. For the left outer join the additional rows are all rows from the left
     table for which there is no key in the right table\. They are joined to an
     empty row of the right table to fit them into the result\.

  1. For the right outer join the additional rows are all rows from the right
     table for which there is no key in the left table\. They are joined to an
     empty row of the left table to fit them into the result\.

  1. The full outer join combines both left and right outer join\. In other
     words, the additional rows are as defined for left outer join, and right
     outer join, combined\.

We extend all the joins from two to __n__ tables \(__n__ > 2\) by
executing

    (...((table1 join table2) join table3) ...) join tableN

Examples for all the joins:

    Inner Join

    {0 foo}              {0 bagel}    {0 foo   0 bagel}
    {1 snarf} inner join {1 snatz}  = {1 snarf 1 snatz}
    {2 blue}             {3 driver}

    Left Outer Join

    {0 foo}                   {0 bagel}    {0 foo   0 bagel}
    {1 snarf} left outer join {1 snatz}  = {1 snarf 1 snatz}
    {2 blue}                  {3 driver}   {2 blue  {} {}}

    Right Outer Join

    {0 foo}                    {0 bagel}    {0 foo   0 bagel}
    {1 snarf} right outer join {1 snatz}  = {1 snarf 1 snatz}
    {2 blue}                   {3 driver}   {{} {}   3 driver}

    Full Outer Join

    {0 foo}                   {0 bagel}    {0 foo   0 bagel}
    {1 snarf} full outer join {1 snatz}  = {1 snarf 1 snatz}
    {2 blue}                  {3 driver}   {2 blue  {} {}}
                                           {{} {}   3 driver}

# <a name='section5'></a>REFERENCES

  1. J\. W\. Hunt and M\. D\. McIlroy, "An algorithm for differential file
     comparison," Comp\. Sci\. Tech\. Rep\. \#41, Bell Telephone Laboratories \(1976\)\.
     Available on the Web at the second author's personal site:
     [http://www\.cs\.dartmouth\.edu/~doug/](http://www\.cs\.dartmouth\.edu/~doug/)

  1. Donald E\. Knuth, "Fascicle 2b of 'The Art of Computer Programming' volume
     4"\. Available on the Web at the author's personal site:
     [http://www\-cs\-faculty\.stanford\.edu/~knuth/fasc2b\.ps\.gz](http://www\-cs\-faculty\.stanford\.edu/~knuth/fasc2b\.ps\.gz)\.

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: list* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[Fisher\-Yates](\.\./\.\./\.\./\.\./index\.md\#fisher\_yates),
[assign](\.\./\.\./\.\./\.\./index\.md\#assign),
[common](\.\./\.\./\.\./\.\./index\.md\#common),
[comparison](\.\./\.\./\.\./\.\./index\.md\#comparison),
[diff](\.\./\.\./\.\./\.\./index\.md\#diff),
[differential](\.\./\.\./\.\./\.\./index\.md\#differential),
[equal](\.\./\.\./\.\./\.\./index\.md\#equal),
[equality](\.\./\.\./\.\./\.\./index\.md\#equality),
[filter](\.\./\.\./\.\./\.\./index\.md\#filter), [first
permutation](\.\./\.\./\.\./\.\./index\.md\#first\_permutation),
[flatten](\.\./\.\./\.\./\.\./index\.md\#flatten),
[folding](\.\./\.\./\.\./\.\./index\.md\#folding), [full outer
join](\.\./\.\./\.\./\.\./index\.md\#full\_outer\_join), [generate
permutations](\.\./\.\./\.\./\.\./index\.md\#generate\_permutations), [inner
join](\.\./\.\./\.\./\.\./index\.md\#inner\_join),
[join](\.\./\.\./\.\./\.\./index\.md\#join), [left outer
join](\.\./\.\./\.\./\.\./index\.md\#left\_outer\_join),
[list](\.\./\.\./\.\./\.\./index\.md\#list), [longest common
subsequence](\.\./\.\./\.\./\.\./index\.md\#longest\_common\_subsequence),
[map](\.\./\.\./\.\./\.\./index\.md\#map), [next
permutation](\.\./\.\./\.\./\.\./index\.md\#next\_permutation), [outer
join](\.\./\.\./\.\./\.\./index\.md\#outer\_join),
[permutation](\.\./\.\./\.\./\.\./index\.md\#permutation),
[reduce](\.\./\.\./\.\./\.\./index\.md\#reduce),
[repeating](\.\./\.\./\.\./\.\./index\.md\#repeating),
[repetition](\.\./\.\./\.\./\.\./index\.md\#repetition),
[reshuffle](\.\./\.\./\.\./\.\./index\.md\#reshuffle),
[reverse](\.\./\.\./\.\./\.\./index\.md\#reverse), [right outer
join](\.\./\.\./\.\./\.\./index\.md\#right\_outer\_join),
[shuffle](\.\./\.\./\.\./\.\./index\.md\#shuffle),
[subsequence](\.\./\.\./\.\./\.\./index\.md\#subsequence),
[swapping](\.\./\.\./\.\./\.\./index\.md\#swapping)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003\-2005 by Kevin B\. Kenny\. All rights reserved  
Copyright &copy; 2003\-2012 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
