
[//000000001]: # (math::bignum \- Tcl Math Library)
[//000000002]: # (Generated from file 'bignum\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Salvatore Sanfilippo <antirez at invece dot org>)
[//000000004]: # (Copyright &copy; 2004 Arjen Markus <arjenmarkus at users dot sourceforge dot net>)
[//000000005]: # (math::bignum\(n\) 3\.1 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::bignum \- Arbitrary precision integer numbers

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXAMPLES](#section2)

  - [API](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.4?  
package require math::bignum ?3\.1?  

[__::math::bignum::fromstr__ *string* ?*radix*?](#1)  
[__::math::bignum::tostr__ *bignum* ?*radix*?](#2)  
[__::math::bignum::sign__ *bignum*](#3)  
[__::math::bignum::abs__ *bignum*](#4)  
[__::math::bignum::cmp__ *a* *b*](#5)  
[__::math::bignum::iszero__ *bignum*](#6)  
[__::math::bignum::lt__ *a* *b*](#7)  
[__::math::bignum::le__ *a* *b*](#8)  
[__::math::bignum::gt__ *a* *b*](#9)  
[__::math::bignum::ge__ *a* *b*](#10)  
[__::math::bignum::eq__ *a* *b*](#11)  
[__::math::bignum::ne__ *a* *b*](#12)  
[__::math::bignum::isodd__ *bignum*](#13)  
[__::math::bignum::iseven__ *bignum*](#14)  
[__::math::bignum::add__ *a* *b*](#15)  
[__::math::bignum::sub__ *a* *b*](#16)  
[__::math::bignum::mul__ *a* *b*](#17)  
[__::math::bignum::divqr__ *a* *b*](#18)  
[__::math::bignum::div__ *a* *b*](#19)  
[__::math::bignum::rem__ *a* *b*](#20)  
[__::math::bignum::mod__ *n* *m*](#21)  
[__::math::bignum::pow__ *base* *exp*](#22)  
[__::math::bignum::powm__ *base* *exp* *m*](#23)  
[__::math::bignum::sqrt__ *bignum*](#24)  
[__::math::bignum::rand__ *bits*](#25)  
[__::math::bignum::lshift__ *bignum* *bits*](#26)  
[__::math::bignum::rshift__ *bignum* *bits*](#27)  
[__::math::bignum::bitand__ *a* *b*](#28)  
[__::math::bignum::bitor__ *a* *b*](#29)  
[__::math::bignum::bitxor__ *a* *b*](#30)  
[__::math::bignum::setbit__ *bignumVar* *bit*](#31)  
[__::math::bignum::clearbit__ *bignumVar* *bit*](#32)  
[__::math::bignum::testbit__ *bignum* *bit*](#33)  
[__::math::bignum::bits__ *bignum*](#34)  

# <a name='description'></a>DESCRIPTION

The bignum package provides arbitrary precision integer math \(also known as "big
numbers"\) capabilities to the Tcl language\. Big numbers are internally
represented at Tcl lists: this package provides a set of procedures operating
against the internal representation in order to:

  - perform math operations

  - convert bignums from the internal representation to a string in the desired
    radix and vice versa\.

But the two constants "0" and "1" are automatically converted to the internal
representation, in order to easily compare a number to zero, or increment a big
number\.

The bignum interface is opaque, so operations on bignums that are not returned
by procedures in this package \(but created by hand\) may lead to unspecified
behaviours\. It's safe to treat bignums as pure values, so there is no need to
free a bignum, or to duplicate it via a special operation\.

# <a name='section2'></a>EXAMPLES

This section shows some simple example\. This library being just a way to perform
math operations, examples may be the simplest way to learn how to work with it\.
Consult the API section of this man page for information about individual
procedures\.

    package require math::bignum

    # Multiplication of two bignums
    set a [::math::bignum::fromstr 88888881111111]
    set b [::math::bignum::fromstr 22222220000000]
    set c [::math::bignum::mul $a $b]
    puts [::math::bignum::tostr $c] ; # => will output 1975308271604953086420000000
    set c [::math::bignum::sqrt $c]
    puts [::math::bignum::tostr $c] ; # => will output 44444440277777

    # From/To string conversion in different radix
    set a [::math::bignum::fromstr 1100010101010111001001111010111 2]
    puts [::math::bignum::tostr $a 16] ; # => will output 62ab93d7

    # Factorial example
    proc fact n {
        # fromstr is not needed for 0 and 1
        set z 1
        for {set i 2} {$i <= $n} {incr i} {
            set z [::math::bignum::mul $z [::math::bignum::fromstr $i]]
        }
        return $z
    }

    puts [::math::bignum::tostr [fact 100]]

# <a name='section3'></a>API

  - <a name='1'></a>__::math::bignum::fromstr__ *string* ?*radix*?

    Convert *string* into a bignum\. If *radix* is omitted or zero, the
    string is interpreted in hex if prefixed with *0x*, in octal if prefixed
    with *ox*, in binary if it's pefixed with *bx*, as a number in radix 10
    otherwise\. If instead the *radix* argument is specified in the range 2\-36,
    the *string* is interpreted in the given radix\. Please note that this
    conversion is not needed for two constants : *0* and *1*\. \(see the
    example\)

  - <a name='2'></a>__::math::bignum::tostr__ *bignum* ?*radix*?

    Convert *bignum* into a string representing the number in the specified
    radix\. If *radix* is omitted, the default is 10\.

  - <a name='3'></a>__::math::bignum::sign__ *bignum*

    Return the sign of the bignum\. The procedure returns 0 if the number is
    positive, 1 if it's negative\.

  - <a name='4'></a>__::math::bignum::abs__ *bignum*

    Return the absolute value of the bignum\.

  - <a name='5'></a>__::math::bignum::cmp__ *a* *b*

    Compare the two bignums a and b, returning *0* if *a == b*, *1* if *a
    > b*, and *\-1* if *a < b*\.

  - <a name='6'></a>__::math::bignum::iszero__ *bignum*

    Return true if *bignum* value is zero, otherwise false is returned\.

  - <a name='7'></a>__::math::bignum::lt__ *a* *b*

    Return true if *a < b*, otherwise false is returned\.

  - <a name='8'></a>__::math::bignum::le__ *a* *b*

    Return true if *a <= b*, otherwise false is returned\.

  - <a name='9'></a>__::math::bignum::gt__ *a* *b*

    Return true if *a > b*, otherwise false is returned\.

  - <a name='10'></a>__::math::bignum::ge__ *a* *b*

    Return true if *a >= b*, otherwise false is returned\.

  - <a name='11'></a>__::math::bignum::eq__ *a* *b*

    Return true if *a == b*, otherwise false is returned\.

  - <a name='12'></a>__::math::bignum::ne__ *a* *b*

    Return true if *a \!= b*, otherwise false is returned\.

  - <a name='13'></a>__::math::bignum::isodd__ *bignum*

    Return true if *bignum* is odd\.

  - <a name='14'></a>__::math::bignum::iseven__ *bignum*

    Return true if *bignum* is even\.

  - <a name='15'></a>__::math::bignum::add__ *a* *b*

    Return the sum of the two bignums *a* and *b*\.

  - <a name='16'></a>__::math::bignum::sub__ *a* *b*

    Return the difference of the two bignums *a* and *b*\.

  - <a name='17'></a>__::math::bignum::mul__ *a* *b*

    Return the product of the two bignums *a* and *b*\. The implementation
    uses Karatsuba multiplication if both the numbers are bigger than a given
    threshold, otherwise the direct algorith is used\.

  - <a name='18'></a>__::math::bignum::divqr__ *a* *b*

    Return a two\-elements list containing as first element the quotient of the
    division between the two bignums *a* and *b*, and the remainder of the
    division as second element\.

  - <a name='19'></a>__::math::bignum::div__ *a* *b*

    Return the quotient of the division between the two bignums *a* and *b*\.

  - <a name='20'></a>__::math::bignum::rem__ *a* *b*

    Return the remainder of the division between the two bignums *a* and
    *b*\.

  - <a name='21'></a>__::math::bignum::mod__ *n* *m*

    Return *n* modulo *m*\. This operation is called modular reduction\.

  - <a name='22'></a>__::math::bignum::pow__ *base* *exp*

    Return *base* raised to the exponent *exp*\.

  - <a name='23'></a>__::math::bignum::powm__ *base* *exp* *m*

    Return *base* raised to the exponent *exp*, modulo *m*\. This function
    is often used in the field of cryptography\.

  - <a name='24'></a>__::math::bignum::sqrt__ *bignum*

    Return the integer part of the square root of *bignum*

  - <a name='25'></a>__::math::bignum::rand__ *bits*

    Return a random number of at most *bits* bits\. The returned number is
    internally generated using Tcl's *expr rand\(\)* function and is not
    suitable where an unguessable and cryptographically secure random number is
    needed\.

  - <a name='26'></a>__::math::bignum::lshift__ *bignum* *bits*

    Return the result of left shifting *bignum*'s binary representation of
    *bits* positions on the left\. This is equivalent to multiplying by
    2^*bits* but much faster\.

  - <a name='27'></a>__::math::bignum::rshift__ *bignum* *bits*

    Return the result of right shifting *bignum*'s binary representation of
    *bits* positions on the right\. This is equivalent to dividing by
    *2^bits* but much faster\.

  - <a name='28'></a>__::math::bignum::bitand__ *a* *b*

    Return the result of doing a bitwise AND operation on a and b\. The operation
    is restricted to positive numbers, including zero\. When negative numbers are
    provided as arguments the result is undefined\.

  - <a name='29'></a>__::math::bignum::bitor__ *a* *b*

    Return the result of doing a bitwise OR operation on a and b\. The operation
    is restricted to positive numbers, including zero\. When negative numbers are
    provided as arguments the result is undefined\.

  - <a name='30'></a>__::math::bignum::bitxor__ *a* *b*

    Return the result of doing a bitwise XOR operation on a and b\. The operation
    is restricted to positive numbers, including zero\. When negative numbers are
    provided as arguments the result is undefined\.

  - <a name='31'></a>__::math::bignum::setbit__ *bignumVar* *bit*

    Set the bit at *bit* position to 1 in the bignum stored in the variable
    *bignumVar*\. Bit 0 is the least significant\.

  - <a name='32'></a>__::math::bignum::clearbit__ *bignumVar* *bit*

    Set the bit at *bit* position to 0 in the bignum stored in the variable
    *bignumVar*\. Bit 0 is the least significant\.

  - <a name='33'></a>__::math::bignum::testbit__ *bignum* *bit*

    Return true if the bit at the *bit* position of *bignum* is on,
    otherwise false is returned\. If *bit* is out of range, it is considered as
    set to zero\.

  - <a name='34'></a>__::math::bignum::bits__ *bignum*

    Return the number of bits needed to represent bignum in radix 2\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: bignum* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[bignums](\.\./\.\./\.\./\.\./index\.md\#bignums),
[math](\.\./\.\./\.\./\.\./index\.md\#math),
[multiprecision](\.\./\.\./\.\./\.\./index\.md\#multiprecision),
[tcl](\.\./\.\./\.\./\.\./index\.md\#tcl)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Salvatore Sanfilippo <antirez at invece dot org>  
Copyright &copy; 2004 Arjen Markus <arjenmarkus at users dot sourceforge dot net>
