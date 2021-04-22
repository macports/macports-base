
[//000000001]: # (math::fourier \- Tcl Math Library)
[//000000002]: # (Generated from file 'fourier\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (math::fourier\(n\) 1\.0\.2 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::fourier \- Discrete and fast fourier transforms

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [GENERAL INFORMATION](#section2)

  - [PROCEDURES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require math::fourier 1\.0\.2  

[__::math::fourier::dft__ *in\_data*](#1)  
[__::math::fourier::inverse\_dft__ *in\_data*](#2)  
[__::math::fourier::lowpass__ *cutoff* *in\_data*](#3)  
[__::math::fourier::highpass__ *cutoff* *in\_data*](#4)  

# <a name='description'></a>DESCRIPTION

The __math::fourier__ package uses the fast Fourier transform, if
applicable, or the ordinary transform to implement the discrete Fourier
transform\. It also provides a few simple filter procedures as an illustration of
how such filters can be implemented\.

The purpose of this document is to describe the implemented procedures and
provide some examples of their usage\. As there is ample literature on the
algorithms involved, we refer to relevant text books for more explanations\. We
also refer to the original Wiki page on the subject which describes some of the
considerations behind the current implementation\.

# <a name='section2'></a>GENERAL INFORMATION

The two top\-level procedures defined are

  - dft data\-list

  - inverse\_dft data\-list

Both take a list of *complex numbers* and apply a Discrete Fourier Transform
\(DFT\) or its inverse respectively to these lists of numbers\. A "complex number"
in this case is either \(i\) a pair \(two element list\) of numbers, interpreted as
the real and imaginary parts of the complex number, or \(ii\) a single number,
interpreted as the real part of a complex number whose imaginary part is zero\.
The return value is always in the first format\. \(The DFT generally produces
complex results even if the input is purely real\.\) Applying first one and then
the other of these procedures to a list of complex numbers will \(modulo rounding
errors due to floating point arithmetic\) return the original list of numbers\.

If the input length N is a power of two then these procedures will utilize the
O\(N log N\) Fast Fourier Transform algorithm\. If input length is not a power of
two then the DFT will instead be computed using the naive quadratic algorithm\.

Some examples:

    % dft {1 2 3 4}
    {10 0.0} {-2.0 2.0} {-2 0.0} {-2.0 -2.0}
    % inverse_dft {{10 0.0} {-2.0 2.0} {-2 0.0} {-2.0 -2.0}}
    {1.0 0.0} {2.0 0.0} {3.0 0.0} {4.0 0.0}
    % dft {1 2 3 4 5}
    {15.0 0.0} {-2.5 3.44095480118} {-2.5 0.812299240582} {-2.5 -0.812299240582} {-2.5 -3.44095480118}
    % inverse_dft {{15.0 0.0} {-2.5 3.44095480118} {-2.5 0.812299240582} {-2.5 -0.812299240582} {-2.5 -3.44095480118}}
    {1.0 0.0} {2.0 8.881784197e-17} {3.0 4.4408920985e-17} {4.0 4.4408920985e-17} {5.0 -8.881784197e-17}

In the last case, the imaginary parts <1e\-16 would have been zero in exact
arithmetic, but aren't here due to rounding errors\.

Internally, the procedures use a flat list format where every even index element
of a list is a real part and every odd index element is an imaginary part\. This
is reflected in the variable names by Re\_ and Im\_ prefixes\.

The package includes two simple filters\. They have an analogue equivalent in a
simple electronic circuit, a resistor and a capacitance in series\. Using these
filters requires the __[math::complexnumbers](qcomplex\.md)__ package\.

# <a name='section3'></a>PROCEDURES

The public Fourier transform procedures are:

  - <a name='1'></a>__::math::fourier::dft__ *in\_data*

    Determine the *Fourier transform* of the given list of complex numbers\.
    The result is a list of complex numbers representing the \(complex\)
    amplitudes of the Fourier components\.

      * list *in\_data*

        List of data

  - <a name='2'></a>__::math::fourier::inverse\_dft__ *in\_data*

    Determine the *inverse Fourier transform* of the given list of complex
    numbers \(interpreted as amplitudes\)\. The result is a list of complex numbers
    representing the original \(complex\) data

      * list *in\_data*

        List of data \(amplitudes\)

  - <a name='3'></a>__::math::fourier::lowpass__ *cutoff* *in\_data*

    Filter the \(complex\) amplitudes so that high\-frequency components are
    suppressed\. The implemented filter is a first\-order low\-pass filter, the
    discrete equivalent of a simple electronic circuit with a resistor and a
    capacitance\.

      * float *cutoff*

        Cut\-off frequency

      * list *in\_data*

        List of data \(amplitudes\)

  - <a name='4'></a>__::math::fourier::highpass__ *cutoff* *in\_data*

    Filter the \(complex\) amplitudes so that low\-frequency components are
    suppressed\. The implemented filter is a first\-order low\-pass filter, the
    discrete equivalent of a simple electronic circuit with a resistor and a
    capacitance\.

      * float *cutoff*

        Cut\-off frequency

      * list *in\_data*

        List of data \(amplitudes\)

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: fourier* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[FFT](\.\./\.\./\.\./\.\./index\.md\#fft), [Fourier
transform](\.\./\.\./\.\./\.\./index\.md\#fourier\_transform), [complex
numbers](\.\./\.\./\.\./\.\./index\.md\#complex\_numbers),
[mathematics](\.\./\.\./\.\./\.\./index\.md\#mathematics)

# <a name='category'></a>CATEGORY

Mathematics
