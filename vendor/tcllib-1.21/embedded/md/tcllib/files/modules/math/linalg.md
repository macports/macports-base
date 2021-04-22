
[//000000001]: # (math::linearalgebra \- Tcl Math Library)
[//000000002]: # (Generated from file 'linalg\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004\-2008 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2004 Ed Hume <http://www\.hume\.com/contact\.us\.htm>)
[//000000005]: # (Copyright &copy; 2008 Michael Buadin <relaxkmike@users\.sourceforge\.net>)
[//000000006]: # (math::linearalgebra\(n\) 1\.1\.5 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::linearalgebra \- Linear Algebra

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [STORAGE](#section3)

  - [REMARKS ON THE IMPLEMENTATION](#section4)

  - [TODO](#section5)

  - [NAMING CONFLICT](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.4?  
package require math::linearalgebra ?1\.1\.5?  

[__::math::linearalgebra::mkVector__ *ndim* *value*](#1)  
[__::math::linearalgebra::mkUnitVector__ *ndim* *ndir*](#2)  
[__::math::linearalgebra::mkMatrix__ *nrows* *ncols* *value*](#3)  
[__::math::linearalgebra::getrow__ *matrix* *row* ?imin? ?imax?](#4)  
[__::math::linearalgebra::setrow__ *matrix* *row* *newvalues* ?imin? ?imax?](#5)  
[__::math::linearalgebra::getcol__ *matrix* *col* ?imin? ?imax?](#6)  
[__::math::linearalgebra::setcol__ *matrix* *col* *newvalues* ?imin? ?imax?](#7)  
[__::math::linearalgebra::getelem__ *matrix* *row* *col*](#8)  
[__::math::linearalgebra::setelem__ *matrix* *row* ?col? *newvalue*](#9)  
[__::math::linearalgebra::swaprows__ *matrix* *irow1* *irow2* ?imin? ?imax?](#10)  
[__::math::linearalgebra::swapcols__ *matrix* *icol1* *icol2* ?imin? ?imax?](#11)  
[__::math::linearalgebra::show__ *obj* ?format? ?rowsep? ?colsep?](#12)  
[__::math::linearalgebra::dim__ *obj*](#13)  
[__::math::linearalgebra::shape__ *obj*](#14)  
[__::math::linearalgebra::conforming__ *type* *obj1* *obj2*](#15)  
[__::math::linearalgebra::symmetric__ *matrix* ?eps?](#16)  
[__::math::linearalgebra::norm__ *vector* *type*](#17)  
[__::math::linearalgebra::norm\_one__ *vector*](#18)  
[__::math::linearalgebra::norm\_two__ *vector*](#19)  
[__::math::linearalgebra::norm\_max__ *vector* ?index?](#20)  
[__::math::linearalgebra::normMatrix__ *matrix* *type*](#21)  
[__::math::linearalgebra::dotproduct__ *vect1* *vect2*](#22)  
[__::math::linearalgebra::unitLengthVector__ *vector*](#23)  
[__::math::linearalgebra::normalizeStat__ *mv*](#24)  
[__::math::linearalgebra::axpy__ *scale* *mv1* *mv2*](#25)  
[__::math::linearalgebra::add__ *mv1* *mv2*](#26)  
[__::math::linearalgebra::sub__ *mv1* *mv2*](#27)  
[__::math::linearalgebra::scale__ *scale* *mv*](#28)  
[__::math::linearalgebra::rotate__ *c* *s* *vect1* *vect2*](#29)  
[__::math::linearalgebra::transpose__ *matrix*](#30)  
[__::math::linearalgebra::matmul__ *mv1* *mv2*](#31)  
[__::math::linearalgebra::angle__ *vect1* *vect2*](#32)  
[__::math::linearalgebra::crossproduct__ *vect1* *vect2*](#33)  
[__::math::linearalgebra::matmul__ *mv1* *mv2*](#34)  
[__::math::linearalgebra::mkIdentity__ *size*](#35)  
[__::math::linearalgebra::mkDiagonal__ *diag*](#36)  
[__::math::linearalgebra::mkRandom__ *size*](#37)  
[__::math::linearalgebra::mkTriangular__ *size* ?uplo? ?value?](#38)  
[__::math::linearalgebra::mkHilbert__ *size*](#39)  
[__::math::linearalgebra::mkDingdong__ *size*](#40)  
[__::math::linearalgebra::mkOnes__ *size*](#41)  
[__::math::linearalgebra::mkMoler__ *size*](#42)  
[__::math::linearalgebra::mkFrank__ *size*](#43)  
[__::math::linearalgebra::mkBorder__ *size*](#44)  
[__::math::linearalgebra::mkWilkinsonW\+__ *size*](#45)  
[__::math::linearalgebra::mkWilkinsonW\-__ *size*](#46)  
[__::math::linearalgebra::solveGauss__ *matrix* *bvect*](#47)  
[__::math::linearalgebra::solvePGauss__ *matrix* *bvect*](#48)  
[__::math::linearalgebra::solveTriangular__ *matrix* *bvect* ?uplo?](#49)  
[__::math::linearalgebra::solveGaussBand__ *matrix* *bvect*](#50)  
[__::math::linearalgebra::solveTriangularBand__ *matrix* *bvect*](#51)  
[__::math::linearalgebra::determineSVD__ *A* *eps*](#52)  
[__::math::linearalgebra::eigenvectorsSVD__ *A* *eps*](#53)  
[__::math::linearalgebra::leastSquaresSVD__ *A* *y* *qmin* *eps*](#54)  
[__::math::linearalgebra::choleski__ *matrix*](#55)  
[__::math::linearalgebra::orthonormalizeColumns__ *matrix*](#56)  
[__::math::linearalgebra::orthonormalizeRows__ *matrix*](#57)  
[__::math::linearalgebra::dger__ *matrix* *alpha* *x* *y* ?scope?](#58)  
[__::math::linearalgebra::dgetrf__ *matrix*](#59)  
[__::math::linearalgebra::det__ *matrix*](#60)  
[__::math::linearalgebra::largesteigen__ *matrix* *tolerance* *maxiter*](#61)  
[__::math::linearalgebra::to\_LA__ *mv*](#62)  
[__::math::linearalgebra::from\_LA__ *mv*](#63)  

# <a name='description'></a>DESCRIPTION

This package offers both low\-level procedures and high\-level algorithms to deal
with linear algebra problems:

  - robust solution of linear equations or least squares problems

  - determining eigenvectors and eigenvalues of symmetric matrices

  - various decompositions of general matrices or matrices of a specific form

  - \(limited\) support for matrices in band storage, a common type of sparse
    matrices

It arose as a re\-implementation of Hume's LA package and the desire to offer
low\-level procedures as found in the well\-known BLAS library\. Matrices are
implemented as lists of lists rather linear lists with reserved elements, as in
the original LA package, as it was found that such an implementation is actually
faster\.

It is advisable, however, to use the procedures that are offered, such as
*setrow* and *getrow*, rather than rely on this representation explicitly:
that way it is to switch to a possibly even faster compiled implementation that
supports the same API\.

*Note:* When using this package in combination with Tk, there may be a naming
conflict, as both this package and Tk define a command *scale*\. See the
[NAMING CONFLICT](#section6) section below\.

# <a name='section2'></a>PROCEDURES

The package defines the following public procedures \(several exist as
specialised procedures, see below\):

*Constructing matrices and vectors*

  - <a name='1'></a>__::math::linearalgebra::mkVector__ *ndim* *value*

    Create a vector with ndim elements, each with the value *value*\.

      * integer *ndim*

        Dimension of the vector \(number of components\)

      * double *value*

        Uniform value to be used \(default: 0\.0\)

  - <a name='2'></a>__::math::linearalgebra::mkUnitVector__ *ndim* *ndir*

    Create a unit vector in *ndim*\-dimensional space, along the *ndir*\-th
    direction\.

      * integer *ndim*

        Dimension of the vector \(number of components\)

      * integer *ndir*

        Direction \(0, \.\.\., ndim\-1\)

  - <a name='3'></a>__::math::linearalgebra::mkMatrix__ *nrows* *ncols* *value*

    Create a matrix with *nrows* rows and *ncols* columns\. All elements have
    the value *value*\.

      * integer *nrows*

        Number of rows

      * integer *ncols*

        Number of columns

      * double *value*

        Uniform value to be used \(default: 0\.0\)

  - <a name='4'></a>__::math::linearalgebra::getrow__ *matrix* *row* ?imin? ?imax?

    Returns a single row of a matrix as a list

      * list *matrix*

        Matrix in question

      * integer *row*

        Index of the row to return

      * integer *imin*

        Minimum index of the column \(default: 0\)

      * integer *imax*

        Maximum index of the column \(default: ncols\-1\)

  - <a name='5'></a>__::math::linearalgebra::setrow__ *matrix* *row* *newvalues* ?imin? ?imax?

    Set a single row of a matrix to new values \(this list must have the same
    number of elements as the number of *columns* in the matrix\)

      * list *matrix*

        *name* of the matrix in question

      * integer *row*

        Index of the row to update

      * list *newvalues*

        List of new values for the row

      * integer *imin*

        Minimum index of the column \(default: 0\)

      * integer *imax*

        Maximum index of the column \(default: ncols\-1\)

  - <a name='6'></a>__::math::linearalgebra::getcol__ *matrix* *col* ?imin? ?imax?

    Returns a single column of a matrix as a list

      * list *matrix*

        Matrix in question

      * integer *col*

        Index of the column to return

      * integer *imin*

        Minimum index of the row \(default: 0\)

      * integer *imax*

        Maximum index of the row \(default: nrows\-1\)

  - <a name='7'></a>__::math::linearalgebra::setcol__ *matrix* *col* *newvalues* ?imin? ?imax?

    Set a single column of a matrix to new values \(this list must have the same
    number of elements as the number of *rows* in the matrix\)

      * list *matrix*

        *name* of the matrix in question

      * integer *col*

        Index of the column to update

      * list *newvalues*

        List of new values for the column

      * integer *imin*

        Minimum index of the row \(default: 0\)

      * integer *imax*

        Maximum index of the row \(default: nrows\-1\)

  - <a name='8'></a>__::math::linearalgebra::getelem__ *matrix* *row* *col*

    Returns a single element of a matrix/vector

      * list *matrix*

        Matrix or vector in question

      * integer *row*

        Row of the element

      * integer *col*

        Column of the element \(not present for vectors\)

  - <a name='9'></a>__::math::linearalgebra::setelem__ *matrix* *row* ?col? *newvalue*

    Set a single element of a matrix \(or vector\) to a new value

      * list *matrix*

        *name* of the matrix in question

      * integer *row*

        Row of the element

      * integer *col*

        Column of the element \(not present for vectors\)

  - <a name='10'></a>__::math::linearalgebra::swaprows__ *matrix* *irow1* *irow2* ?imin? ?imax?

    Swap two rows in a matrix completely or only a selected part

      * list *matrix*

        *name* of the matrix in question

      * integer *irow1*

        Index of first row

      * integer *irow2*

        Index of second row

      * integer *imin*

        Minimum column index \(default: 0\)

      * integer *imin*

        Maximum column index \(default: ncols\-1\)

  - <a name='11'></a>__::math::linearalgebra::swapcols__ *matrix* *icol1* *icol2* ?imin? ?imax?

    Swap two columns in a matrix completely or only a selected part

      * list *matrix*

        *name* of the matrix in question

      * integer *irow1*

        Index of first column

      * integer *irow2*

        Index of second column

      * integer *imin*

        Minimum row index \(default: 0\)

      * integer *imin*

        Maximum row index \(default: nrows\-1\)

*Querying matrices and vectors*

  - <a name='12'></a>__::math::linearalgebra::show__ *obj* ?format? ?rowsep? ?colsep?

    Return a string representing the vector or matrix, for easy printing\. \(There
    is currently no way to print fixed sets of columns\)

      * list *obj*

        Matrix or vector in question

      * string *format*

        Format for printing the numbers \(default: %6\.4f\)

      * string *rowsep*

        String to use for separating rows \(default: newline\)

      * string *colsep*

        String to use for separating columns \(default: space\)

  - <a name='13'></a>__::math::linearalgebra::dim__ *obj*

    Returns the number of dimensions for the object \(either 0 for a scalar, 1
    for a vector and 2 for a matrix\)

      * any *obj*

        Scalar, vector, or matrix

  - <a name='14'></a>__::math::linearalgebra::shape__ *obj*

    Returns the number of elements in each dimension for the object \(either an
    empty list for a scalar, a single number for a vector and a list of the
    number of rows and columns for a matrix\)

      * any *obj*

        Scalar, vector, or matrix

  - <a name='15'></a>__::math::linearalgebra::conforming__ *type* *obj1* *obj2*

    Checks if two objects \(vector or matrix\) have conforming shapes, that is if
    they can be applied in an operation like addition or matrix multiplication\.

      * string *type*

        Type of check:

          + "shape" \- the two objects have the same shape \(for all element\-wise
            operations\)

          + "rows" \- the two objects have the same number of rows \(for use as A
            and b in a system of linear equations *Ax = b*

          + "matmul" \- the first object has the same number of columns as the
            number of rows of the second object\. Useful for matrix\-matrix or
            matrix\-vector multiplication\.

      * list *obj1*

        First vector or matrix \(left operand\)

      * list *obj2*

        Second vector or matrix \(right operand\)

  - <a name='16'></a>__::math::linearalgebra::symmetric__ *matrix* ?eps?

    Checks if the given \(square\) matrix is symmetric\. The argument eps is the
    tolerance\.

      * list *matrix*

        Matrix to be inspected

      * float *eps*

        Tolerance for determining approximate equality \(defaults to 1\.0e\-8\)

*Basic operations*

  - <a name='17'></a>__::math::linearalgebra::norm__ *vector* *type*

    Returns the norm of the given vector\. The type argument can be: 1, 2, inf or
    max, respectively the sum of absolute values, the ordinary Euclidean norm or
    the max norm\.

      * list *vector*

        Vector, list of coefficients

      * string *type*

        Type of norm \(default: 2, the Euclidean norm\)

  - <a name='18'></a>__::math::linearalgebra::norm\_one__ *vector*

    Returns the L1 norm of the given vector, the sum of absolute values

      * list *vector*

        Vector, list of coefficients

  - <a name='19'></a>__::math::linearalgebra::norm\_two__ *vector*

    Returns the L2 norm of the given vector, the ordinary Euclidean norm

      * list *vector*

        Vector, list of coefficients

  - <a name='20'></a>__::math::linearalgebra::norm\_max__ *vector* ?index?

    Returns the Linf norm of the given vector, the maximum absolute coefficient

      * list *vector*

        Vector, list of coefficients

      * integer *index*

        \(optional\) if non zero, returns a list made of the maximum value and the
        index where that maximum was found\. if zero, returns the maximum value\.

  - <a name='21'></a>__::math::linearalgebra::normMatrix__ *matrix* *type*

    Returns the norm of the given matrix\. The type argument can be: 1, 2, inf or
    max, respectively the sum of absolute values, the ordinary Euclidean norm or
    the max norm\.

      * list *matrix*

        Matrix, list of row vectors

      * string *type*

        Type of norm \(default: 2, the Euclidean norm\)

  - <a name='22'></a>__::math::linearalgebra::dotproduct__ *vect1* *vect2*

    Determine the inproduct or dot product of two vectors\. These must have the
    same shape \(number of dimensions\)

      * list *vect1*

        First vector, list of coefficients

      * list *vect2*

        Second vector, list of coefficients

  - <a name='23'></a>__::math::linearalgebra::unitLengthVector__ *vector*

    Return a vector in the same direction with length 1\.

      * list *vector*

        Vector to be normalized

  - <a name='24'></a>__::math::linearalgebra::normalizeStat__ *mv*

    Normalize the matrix or vector in a statistical sense: the mean of the
    elements of the columns of the result is zero and the standard deviation is
    1\.

      * list *mv*

        Vector or matrix to be normalized in the above sense

  - <a name='25'></a>__::math::linearalgebra::axpy__ *scale* *mv1* *mv2*

    Return a vector or matrix that results from a "daxpy" operation, that is:
    compute a\*x\+y \(a a scalar and x and y both vectors or matrices of the same
    shape\) and return the result\.

    Specialised variants are: axpy\_vect and axpy\_mat \(slightly faster, but no
    check on the arguments\)

      * double *scale*

        The scale factor for the first vector/matrix \(a\)

      * list *mv1*

        First vector or matrix \(x\)

      * list *mv2*

        Second vector or matrix \(y\)

  - <a name='26'></a>__::math::linearalgebra::add__ *mv1* *mv2*

    Return a vector or matrix that is the sum of the two arguments \(x\+y\)

    Specialised variants are: add\_vect and add\_mat \(slightly faster, but no
    check on the arguments\)

      * list *mv1*

        First vector or matrix \(x\)

      * list *mv2*

        Second vector or matrix \(y\)

  - <a name='27'></a>__::math::linearalgebra::sub__ *mv1* *mv2*

    Return a vector or matrix that is the difference of the two arguments \(x\-y\)

    Specialised variants are: sub\_vect and sub\_mat \(slightly faster, but no
    check on the arguments\)

      * list *mv1*

        First vector or matrix \(x\)

      * list *mv2*

        Second vector or matrix \(y\)

  - <a name='28'></a>__::math::linearalgebra::scale__ *scale* *mv*

    Scale a vector or matrix and return the result, that is: compute a\*x\.

    Specialised variants are: scale\_vect and scale\_mat \(slightly faster, but no
    check on the arguments\)

      * double *scale*

        The scale factor for the vector/matrix \(a\)

      * list *mv*

        Vector or matrix \(x\)

  - <a name='29'></a>__::math::linearalgebra::rotate__ *c* *s* *vect1* *vect2*

    Apply a planar rotation to two vectors and return the result as a list of
    two vectors: c\*x\-s\*y and s\*x\+c\*y\. In algorithms you can often easily
    determine the cosine and sine of the angle, so it is more efficient to pass
    that information directly\.

      * double *c*

        The cosine of the angle

      * double *s*

        The sine of the angle

      * list *vect1*

        First vector \(x\)

      * list *vect2*

        Seocnd vector \(x\)

  - <a name='30'></a>__::math::linearalgebra::transpose__ *matrix*

    Transpose a matrix

      * list *matrix*

        Matrix to be transposed

  - <a name='31'></a>__::math::linearalgebra::matmul__ *mv1* *mv2*

    Multiply a vector/matrix with another vector/matrix\. The result is a matrix,
    if both x and y are matrices or both are vectors, in which case the "outer
    product" is computed\. If one is a vector and the other is a matrix, then the
    result is a vector\.

      * list *mv1*

        First vector/matrix \(x\)

      * list *mv2*

        Second vector/matrix \(y\)

  - <a name='32'></a>__::math::linearalgebra::angle__ *vect1* *vect2*

    Compute the angle between two vectors \(in radians\)

      * list *vect1*

        First vector

      * list *vect2*

        Second vector

  - <a name='33'></a>__::math::linearalgebra::crossproduct__ *vect1* *vect2*

    Compute the cross product of two \(three\-dimensional\) vectors

      * list *vect1*

        First vector

      * list *vect2*

        Second vector

  - <a name='34'></a>__::math::linearalgebra::matmul__ *mv1* *mv2*

    Multiply a vector/matrix with another vector/matrix\. The result is a matrix,
    if both x and y are matrices or both are vectors, in which case the "outer
    product" is computed\. If one is a vector and the other is a matrix, then the
    result is a vector\.

      * list *mv1*

        First vector/matrix \(x\)

      * list *mv2*

        Second vector/matrix \(y\)

*Common matrices and test matrices*

  - <a name='35'></a>__::math::linearalgebra::mkIdentity__ *size*

    Create an identity matrix of dimension *size*\.

      * integer *size*

        Dimension of the matrix

  - <a name='36'></a>__::math::linearalgebra::mkDiagonal__ *diag*

    Create a diagonal matrix whose diagonal elements are the elements of the
    vector *diag*\.

      * list *diag*

        Vector whose elements are used for the diagonal

  - <a name='37'></a>__::math::linearalgebra::mkRandom__ *size*

    Create a square matrix whose elements are uniformly distributed random
    numbers between 0 and 1 of dimension *size*\.

      * integer *size*

        Dimension of the matrix

  - <a name='38'></a>__::math::linearalgebra::mkTriangular__ *size* ?uplo? ?value?

    Create a triangular matrix with non\-zero elements in the upper or lower
    part, depending on argument *uplo*\.

      * integer *size*

        Dimension of the matrix

      * string *uplo*

        Fill the upper \(U\) or lower part \(L\)

      * double *value*

        Value to fill the matrix with

  - <a name='39'></a>__::math::linearalgebra::mkHilbert__ *size*

    Create a Hilbert matrix of dimension *size*\. Hilbert matrices are very
    ill\-conditioned with respect to eigenvalue/eigenvector problems\. Therefore
    they are good candidates for testing the accuracy of algorithms and
    implementations\.

      * integer *size*

        Dimension of the matrix

  - <a name='40'></a>__::math::linearalgebra::mkDingdong__ *size*

    Create a "dingdong" matrix of dimension *size*\. Dingdong matrices are
    imprecisely represented, but have the property of being very stable in such
    algorithms as Gauss elimination\.

      * integer *size*

        Dimension of the matrix

  - <a name='41'></a>__::math::linearalgebra::mkOnes__ *size*

    Create a square matrix of dimension *size* whose entries are all 1\.

      * integer *size*

        Dimension of the matrix

  - <a name='42'></a>__::math::linearalgebra::mkMoler__ *size*

    Create a Moler matrix of size *size*\. \(Moler matrices have a very simple
    Choleski decomposition\. It has one small eigenvalue and it can easily upset
    elimination methods for systems of linear equations\.\)

      * integer *size*

        Dimension of the matrix

  - <a name='43'></a>__::math::linearalgebra::mkFrank__ *size*

    Create a Frank matrix of size *size*\. \(Frank matrices are fairly
    well\-behaved matrices\)

      * integer *size*

        Dimension of the matrix

  - <a name='44'></a>__::math::linearalgebra::mkBorder__ *size*

    Create a bordered matrix of size *size*\. \(Bordered matrices have a very
    low rank and can upset certain specialised algorithms\.\)

      * integer *size*

        Dimension of the matrix

  - <a name='45'></a>__::math::linearalgebra::mkWilkinsonW\+__ *size*

    Create a Wilkinson W\+ of size *size*\. This kind of matrix has pairs of
    eigenvalues that are very close together\. Usually the order \(size\) is odd\.

      * integer *size*

        Dimension of the matrix

  - <a name='46'></a>__::math::linearalgebra::mkWilkinsonW\-__ *size*

    Create a Wilkinson W\- of size *size*\. This kind of matrix has pairs of
    eigenvalues with opposite signs, when the order \(size\) is odd\.

      * integer *size*

        Dimension of the matrix

*Common algorithms*

  - <a name='47'></a>__::math::linearalgebra::solveGauss__ *matrix* *bvect*

    Solve a system of linear equations \(Ax=b\) using Gauss elimination\. Returns
    the solution \(x\) as a vector or matrix of the same shape as bvect\.

      * list *matrix*

        Square matrix \(matrix A\)

      * list *bvect*

        Vector or matrix whose columns are the individual b\-vectors

  - <a name='48'></a>__::math::linearalgebra::solvePGauss__ *matrix* *bvect*

    Solve a system of linear equations \(Ax=b\) using Gauss elimination with
    partial pivoting\. Returns the solution \(x\) as a vector or matrix of the same
    shape as bvect\.

      * list *matrix*

        Square matrix \(matrix A\)

      * list *bvect*

        Vector or matrix whose columns are the individual b\-vectors

  - <a name='49'></a>__::math::linearalgebra::solveTriangular__ *matrix* *bvect* ?uplo?

    Solve a system of linear equations \(Ax=b\) by backward substitution\. The
    matrix is supposed to be upper\-triangular\.

      * list *matrix*

        Lower or upper\-triangular matrix \(matrix A\)

      * list *bvect*

        Vector or matrix whose columns are the individual b\-vectors

      * string *uplo*

        Indicates whether the matrix is lower\-triangular \(L\) or upper\-triangular
        \(U\)\. Defaults to "U"\.

  - <a name='50'></a>__::math::linearalgebra::solveGaussBand__ *matrix* *bvect*

    Solve a system of linear equations \(Ax=b\) using Gauss elimination, where the
    matrix is stored as a band matrix \(*cf\.* [STORAGE](#section3)\)\.
    Returns the solution \(x\) as a vector or matrix of the same shape as bvect\.

      * list *matrix*

        Square matrix \(matrix A; in band form\)

      * list *bvect*

        Vector or matrix whose columns are the individual b\-vectors

  - <a name='51'></a>__::math::linearalgebra::solveTriangularBand__ *matrix* *bvect*

    Solve a system of linear equations \(Ax=b\) by backward substitution\. The
    matrix is supposed to be upper\-triangular and stored in band form\.

      * list *matrix*

        Upper\-triangular matrix \(matrix A\)

      * list *bvect*

        Vector or matrix whose columns are the individual b\-vectors

  - <a name='52'></a>__::math::linearalgebra::determineSVD__ *A* *eps*

    Determines the Singular Value Decomposition of a matrix: A = U S Vtrans\.
    Returns a list with the matrix U, the vector of singular values S and the
    matrix V\.

      * list *A*

        Matrix to be decomposed

      * float *eps*

        Tolerance \(defaults to 2\.3e\-16\)

  - <a name='53'></a>__::math::linearalgebra::eigenvectorsSVD__ *A* *eps*

    Determines the eigenvectors and eigenvalues of a real *symmetric* matrix,
    using SVD\. Returns a list with the matrix of normalized eigenvectors and
    their eigenvalues\.

      * list *A*

        Matrix whose eigenvalues must be determined

      * float *eps*

        Tolerance \(defaults to 2\.3e\-16\)

  - <a name='54'></a>__::math::linearalgebra::leastSquaresSVD__ *A* *y* *qmin* *eps*

    Determines the solution to a least\-sqaures problem Ax ~ y via singular value
    decomposition\. The result is the vector x\.

    Note that if you add a column of 1s to the matrix, then this column will
    represent a constant like in: y = a\*x1 \+ b\*x2 \+ c\. To force the intercept to
    be zero, simply leave it out\.

      * list *A*

        Matrix of independent variables

      * list *y*

        List of observed values

      * float *qmin*

        Minimum singular value to be considered \(defaults to 0\.0\)

      * float *eps*

        Tolerance \(defaults to 2\.3e\-16\)

  - <a name='55'></a>__::math::linearalgebra::choleski__ *matrix*

    Determine the Choleski decomposition of a symmetric positive semidefinite
    matrix \(this condition is not checked\!\)\. The result is the lower\-triangular
    matrix L such that L Lt = matrix\.

      * list *matrix*

        Matrix to be decomposed

  - <a name='56'></a>__::math::linearalgebra::orthonormalizeColumns__ *matrix*

    Use the modified Gram\-Schmidt method to orthogonalize and normalize the
    *columns* of the given matrix and return the result\.

      * list *matrix*

        Matrix whose columns must be orthonormalized

  - <a name='57'></a>__::math::linearalgebra::orthonormalizeRows__ *matrix*

    Use the modified Gram\-Schmidt method to orthogonalize and normalize the
    *rows* of the given matrix and return the result\.

      * list *matrix*

        Matrix whose rows must be orthonormalized

  - <a name='58'></a>__::math::linearalgebra::dger__ *matrix* *alpha* *x* *y* ?scope?

    Perform the rank 1 operation A \+ alpha\*x\*y' inline \(that is: the matrix A is
    adjusted\)\. For convenience the new matrix is also returned as the result\.

      * list *matrix*

        Matrix whose rows must be adjusted

      * double *alpha*

        Scale factor

      * list *x*

        A column vector

      * list *y*

        A column vector

      * list *scope*

        If not provided, the operation is performed on all rows/columns of A if
        provided, it is expected to be the list \{imin imax jmin jmax\} where:

          + *imin* Minimum row index

          + *imax* Maximum row index

          + *jmin* Minimum column index

          + *jmax* Maximum column index

  - <a name='59'></a>__::math::linearalgebra::dgetrf__ *matrix*

    Computes an LU factorization of a general matrix, using partial, pivoting
    with row interchanges\. Returns the permutation vector\.

    The factorization has the form

        P * A = L * U

    where P is a permutation matrix, L is lower triangular with unit diagonal
    elements, and U is upper triangular\. Returns the permutation vector, as a
    list of length n\-1\. The last entry of the permutation is not stored, since
    it is implicitely known, with value n \(the last row is not swapped with any
    other row\)\. At index \#i of the permutation is stored the index of the row \#j
    which is swapped with row \#i at step \#i\. That means that each index of the
    permutation gives the permutation at each step, not the cumulated
    permutation matrix, which is the product of permutations\.

      * list *matrix*

        On entry, the matrix to be factored\. On exit, the factors L and U from
        the factorization P\*A = L\*U; the unit diagonal elements of L are not
        stored\.

  - <a name='60'></a>__::math::linearalgebra::det__ *matrix*

    Returns the determinant of the given matrix, based on PA=LU decomposition,
    i\.e\. Gauss partial pivotal\.

      * list *matrix*

        Square matrix \(matrix A\)

      * list *ipiv*

        The pivots \(optionnal\)\. If the pivots are not provided, a PA=LU
        decomposition is performed\. If the pivots are provided, we assume that
        it contains the pivots and that the matrix A contains the L and U
        factors, as provided by dgterf\. b\-vectors

  - <a name='61'></a>__::math::linearalgebra::largesteigen__ *matrix* *tolerance* *maxiter*

    Returns a list made of the largest eigenvalue \(in magnitude\) and associated
    eigenvector\. Uses iterative Power Method as provided as algorithm \#7\.3\.3 of
    Golub & Van Loan\. This algorithm is used here for a dense matrix \(but is
    usually used for sparse matrices\)\.

      * list *matrix*

        Square matrix \(matrix A\)

      * double *tolerance*

        The relative tolerance of the eigenvalue \(default:1\.e\-8\)\.

      * integer *maxiter*

        The maximum number of iterations \(default:10\)\.

*Compability with the LA package* Two procedures are provided for
compatibility with Hume's LA package:

  - <a name='62'></a>__::math::linearalgebra::to\_LA__ *mv*

    Transforms a vector or matrix into the format used by the original LA
    package\.

      * list *mv*

        Matrix or vector

  - <a name='63'></a>__::math::linearalgebra::from\_LA__ *mv*

    Transforms a vector or matrix from the format used by the original LA
    package into the format used by the present implementation\.

      * list *mv*

        Matrix or vector as used by the LA package

# <a name='section3'></a>STORAGE

While most procedures assume that the matrices are given in full form, the
procedures *solveGaussBand* and *solveTriangularBand* assume that the
matrices are stored as *band matrices*\. This common type of "sparse" matrices
is related to ordinary matrices as follows:

  - "A" is a full\-size matrix with N rows and M columns\.

  - "B" is a band matrix, with m upper and lower diagonals and n rows\.

  - "B" can be stored in an ordinary matrix of \(2m\+1\) columns \(one for each
    off\-diagonal and the main diagonal\) and n rows\.

  - Element i,j \(i = \-m,\.\.\.,m; j =1,\.\.\.,n\) of "B" corresponds to element k,j of
    "A" where k = M\+i\-1 and M is at least \(\!\) n, the number of rows in "B"\.

  - To set element \(i,j\) of matrix "B" use:

        setelem B $j [expr {$N+$i-1}] $value

\(There is no convenience procedure for this yet\)

# <a name='section4'></a>REMARKS ON THE IMPLEMENTATION

There is a difference between the original LA package by Hume and the current
implementation\. Whereas the LA package uses a linear list, the current package
uses lists of lists to represent matrices\. It turns out that with this
representation, the algorithms are faster and easier to implement\.

The LA package was used as a model and in fact the implementation of, for
instance, the SVD algorithm was taken from that package\. The set of procedures
was expanded using ideas from the well\-known BLAS library and some algorithms
were updated from the second edition of J\.C\. Nash's book, Compact Numerical
Methods for Computers, \(Adam Hilger, 1990\) that inspired the LA package\.

Two procedures are provided to make the transition between the two
implementations easier: *to\_LA* and *from\_LA*\. They are described above\.

# <a name='section5'></a>TODO

Odds and ends: the following algorithms have not been implemented yet:

  - determineQR

  - certainlyPositive, diagonallyDominant

# <a name='section6'></a>NAMING CONFLICT

If you load this package in a Tk\-enabled shell like wish, then the command

    namespace import ::math::linearalgebra

results in an error message about "scale"\. This is due to the fact that Tk
defines all its commands in the global namespace\. The solution is to import the
linear algebra commands in a namespace that is not the global one:

    package require math::linearalgebra
    namespace eval compute {
        namespace import ::math::linearalgebra::*
        ... use the linear algebra version of scale ...
    }

To use Tk's scale command in that same namespace you can rename it:

    namespace eval compute {
        rename ::scale scaleTk
        scaleTk .scale ...
    }

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: linearalgebra* of
the [Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also
report any ideas for enhancements you may have for either package and/or
documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[least squares](\.\./\.\./\.\./\.\./index\.md\#least\_squares), [linear
algebra](\.\./\.\./\.\./\.\./index\.md\#linear\_algebra), [linear
equations](\.\./\.\./\.\./\.\./index\.md\#linear\_equations),
[math](\.\./\.\./\.\./\.\./index\.md\#math),
[matrices](\.\./\.\./\.\./\.\./index\.md\#matrices),
[matrix](\.\./\.\./\.\./\.\./index\.md\#matrix),
[vectors](\.\./\.\./\.\./\.\./index\.md\#vectors)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004\-2008 Arjen Markus <arjenmarkus@users\.sourceforge\.net>  
Copyright &copy; 2004 Ed Hume <http://www\.hume\.com/contact\.us\.htm>  
Copyright &copy; 2008 Michael Buadin <relaxkmike@users\.sourceforge\.net>
