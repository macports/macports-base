
[//000000001]: # (math::numtheory \- Tcl Math Library)
[//000000002]: # (Generated from file 'numtheory\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2010 Lars Hellström <Lars dot Hellstrom at residenset dot net>)
[//000000004]: # (math::numtheory\(n\) 1\.1\.3 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::numtheory \- Number Theory

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.5?  
package require math::numtheory ?1\.1\.3?  

[__math::numtheory::isprime__ *N* ?*option* *value* \.\.\.?](#1)  
[__math::numtheory::firstNprimes__ *N*](#2)  
[__math::numtheory::primesLowerThan__ *N*](#3)  
[__math::numtheory::primeFactors__ *N*](#4)  
[__math::numtheory::primesLowerThan__ *N*](#5)  
[__math::numtheory::primeFactors__ *N*](#6)  
[__math::numtheory::uniquePrimeFactors__ *N*](#7)  
[__math::numtheory::factors__ *N*](#8)  
[__math::numtheory::totient__ *N*](#9)  
[__math::numtheory::moebius__ *N*](#10)  
[__math::numtheory::legendre__ *a* *p*](#11)  
[__math::numtheory::jacobi__ *a* *b*](#12)  
[__math::numtheory::gcd__ *m* *n*](#13)  
[__math::numtheory::lcm__ *m* *n*](#14)  
[__math::numtheory::numberPrimesGauss__ *N*](#15)  
[__math::numtheory::numberPrimesLegendre__ *N*](#16)  
[__math::numtheory::numberPrimesLegendreModified__ *N*](#17)  
[__math::numtheory::differenceNumberPrimesLegendreModified__ *lower* *upper*](#18)  
[__math::numtheory::listPrimePairs__ *lower* *upper* *step*](#19)  
[__math::numtheory::listPrimeProgressions__ *lower* *upper* *step*](#20)  

# <a name='description'></a>DESCRIPTION

This package is for collecting various number\-theoretic operations, with a
slight bias to prime numbers\.

  - <a name='1'></a>__math::numtheory::isprime__ *N* ?*option* *value* \.\.\.?

    The __isprime__ command tests whether the integer *N* is a prime,
    returning a boolean true value for prime *N* and a boolean false value for
    non\-prime *N*\. The formal definition of 'prime' used is the conventional,
    that the number being tested is greater than 1 and only has trivial
    divisors\.

    To be precise, the return value is one of __0__ \(if *N* is definitely
    not a prime\), __1__ \(if *N* is definitely a prime\), and __on__ \(if
    *N* is probably prime\); the latter two are both boolean true values\. The
    case that an integer may be classified as "probably prime" arises because
    the Miller\-Rabin algorithm used in the test implementation is basically
    probabilistic, and may if we are unlucky fail to detect that a number is in
    fact composite\. Options may be used to select the risk of such "false
    positives" in the test\. __1__ is returned for "small" *N* \(which
    currently means *N* < 118670087467\), where it is known that no false
    positives are possible\.

    The only option currently defined is:

      * __\-randommr__ *repetitions*

        which controls how many times the Miller\-Rabin test should be repeated
        with randomly chosen bases\. Each repetition reduces the probability of a
        false positive by a factor at least 4\. The default for *repetitions*
        is 4\.

    Unknown options are silently ignored\.

  - <a name='2'></a>__math::numtheory::firstNprimes__ *N*

    Return the first N primes

      * integer *N* \(in\)

        Number of primes to return

  - <a name='3'></a>__math::numtheory::primesLowerThan__ *N*

    Return the prime numbers lower/equal to N

      * integer *N* \(in\)

        Maximum number to consider

  - <a name='4'></a>__math::numtheory::primeFactors__ *N*

    Return a list of the prime numbers in the number N

      * integer *N* \(in\)

        Number to be factorised

  - <a name='5'></a>__math::numtheory::primesLowerThan__ *N*

    Return the prime numbers lower/equal to N

      * integer *N* \(in\)

        Maximum number to consider

  - <a name='6'></a>__math::numtheory::primeFactors__ *N*

    Return a list of the prime numbers in the number N

      * integer *N* \(in\)

        Number to be factorised

  - <a name='7'></a>__math::numtheory::uniquePrimeFactors__ *N*

    Return a list of the *unique* prime numbers in the number N

      * integer *N* \(in\)

        Number to be factorised

  - <a name='8'></a>__math::numtheory::factors__ *N*

    Return a list of all *unique* factors in the number N, including 1 and N
    itself

      * integer *N* \(in\)

        Number to be factorised

  - <a name='9'></a>__math::numtheory::totient__ *N*

    Evaluate the Euler totient function for the number N \(number of numbers
    relatively prime to N\)

      * integer *N* \(in\)

        Number in question

  - <a name='10'></a>__math::numtheory::moebius__ *N*

    Evaluate the Moebius function for the number N

      * integer *N* \(in\)

        Number in question

  - <a name='11'></a>__math::numtheory::legendre__ *a* *p*

    Evaluate the Legendre symbol \(a/p\)

      * integer *a* \(in\)

        Upper number in the symbol

      * integer *p* \(in\)

        Lower number in the symbol \(must be non\-zero\)

  - <a name='12'></a>__math::numtheory::jacobi__ *a* *b*

    Evaluate the Jacobi symbol \(a/b\)

      * integer *a* \(in\)

        Upper number in the symbol

      * integer *b* \(in\)

        Lower number in the symbol \(must be odd\)

  - <a name='13'></a>__math::numtheory::gcd__ *m* *n*

    Return the greatest common divisor of *m* and *n*

      * integer *m* \(in\)

        First number

      * integer *n* \(in\)

        Second number

  - <a name='14'></a>__math::numtheory::lcm__ *m* *n*

    Return the lowest common multiple of *m* and *n*

      * integer *m* \(in\)

        First number

      * integer *n* \(in\)

        Second number

  - <a name='15'></a>__math::numtheory::numberPrimesGauss__ *N*

    Estimate the number of primes according the formula by Gauss\.

      * integer *N* \(in\)

        Number in question, should be larger than 0

  - <a name='16'></a>__math::numtheory::numberPrimesLegendre__ *N*

    Estimate the number of primes according the formula by Legendre\.

      * integer *N* \(in\)

        Number in question, should be larger than 0

  - <a name='17'></a>__math::numtheory::numberPrimesLegendreModified__ *N*

    Estimate the number of primes according the modified formula by Legendre\.

      * integer *N* \(in\)

        Number in question, should be larger than 0

  - <a name='18'></a>__math::numtheory::differenceNumberPrimesLegendreModified__ *lower* *upper*

    Estimate the number of primes between tow limits according the modified
    formula by Legendre\.

      * integer *lower* \(in\)

        Lower limit for the primes, should be larger than 0

      * integer *upper* \(in\)

        Upper limit for the primes, should be larger than 0

  - <a name='19'></a>__math::numtheory::listPrimePairs__ *lower* *upper* *step*

    Return a list of pairs of primes each differing by the given step\.

      * integer *lower* \(in\)

        Lower limit for the primes, should be larger than 0

      * integer *upper* \(in\)

        Upper limit for the primes, should be larger than the lower limit

      * integer *step* \(in\)

        Step by which the primes should differ, defaults to 2

  - <a name='20'></a>__math::numtheory::listPrimeProgressions__ *lower* *upper* *step*

    Return a list of lists of primes each differing by the given step from the
    previous one\.

      * integer *lower* \(in\)

        Lower limit for the primes, should be larger than 0

      * integer *upper* \(in\)

        Upper limit for the primes, should be larger than the lower limit

      * integer *step* \(in\)

        Step by which the primes should differ, defaults to 2

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: numtheory* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[number theory](\.\./\.\./\.\./\.\./index\.md\#number\_theory),
[prime](\.\./\.\./\.\./\.\./index\.md\#prime)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2010 Lars Hellström <Lars dot Hellstrom at residenset dot net>
