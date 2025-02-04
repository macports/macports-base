
[//000000001]: # (critcl\_tcl9 \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_tcl9\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_tcl9\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_tcl9 \- How To Adapt Critcl Packages for Tcl 9

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Additional References](#section2)

  - [Authors](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This guide contains notes and actions to take by writers of
*[CriTcl](critcl\.md)*\-based packages to make their code workable for both
Tcl 8\.6 and 9\.

  1. Generally, if there is no interest in moving to Tcl 9, i\.e\. Tcl 8\.\[456\] are
     the only supported runtimes, then just keep using
     *[CriTcl](critcl\.md)* __3\.2__\.

     The remainder of this document can be ignored\.

  1. Use *[CriTcl](critcl\.md)* version 3\.3\.1 *if, and only if* Tcl 9
     support is wanted\.

     With some work this will then also provide backward compatibility with Tcl
     8\.6\.

  1. Header "tcl\.h"

     Replace any inclusion of Tcl's public "tcl\.h" header file in the package's
     C code with the inclusion of *[CriTcl](critcl\.md)*'s new header file
     "tclpre9compat\.h"\.

     This includes "tcl\.h" and further provides a set of compatibility
     definitions which make supporting both Tcl 8\.6 and Tcl 9 in a single code
     base easier\.

     The following notes assume that this compatibility layer is in place\.

  1. __critcl::tcl__

     Before *[CriTcl](critcl\.md)* 3\.3\.1 a single default \(__8\.4__\) was
     used for the minimum Tcl version, to be overriden by an explicit
     __critcl::tcl__ in the package code\.

     Now the default is dynamic, based on the *runtime* version, i\.e\.
     __package provide Tcl__, *[CriTcl](critcl\.md)* is run with/on\.

     When running on Tcl 9 the new default is version __9__, and __8\.6__
     else\. *Note* how this other default was bumped up from __8\.4__\.

     As a consequence it is possible to

       1) Support just Tcl 8\.4\+, 8\.5\+, by having an explicit __critcl::tcl
          8\.x__ in the package code\.

          *Remember however*, it is better to simply stick with
          *[CriTcl](critcl\.md)* __3\.2__ for this\.

       1) Support just Tcl 9 by having an explicit __critcl::tcl 9__ in the
          package code\.

       1) Support both Tcl 8\.6 and Tcl 9 \(but not 8\.4/8\.5\) by leaving
          __critcl::tcl__ out of the code and using the proper __tclsh__
          version to run *[CriTcl](critcl\.md)* with\.

  1. Code checking

     *[CriTcl](critcl\.md)* 3\.3\.1 comes with a very basic set of code
     checks pointing out places where compatibility might or will be an issue\.

     The implementation checks all inlined C code declared by
     __critcl::ccode__, __critcl::ccommand__, __critcl::cproc__ \(and
     related/derived commands\), as well as the C companion files declared with
     __critcl::csources__\.

     It is very basic because it simply greps the code line by line for a number
     of patterns and reports on their presence\. The C code is not fully parsed\.
     The check can and will report pattern found in C code comments, for
     example\.

     The main patterns deal with functions affected by the change to
     __Tcl\_Size__, the removal of old\-style interpreter state handling, and
     command creation\.

     A warning message is printed for all detections\.

     This is disabled for the __Tcl\_Size__\-related pattern if the line also
     matches the pattern __\*OK tcl9\*__\.

     In this way all places in the code already handled can be marked and
     excluded from the warnings\.

       1) Interpreter State handling

          Tcl 9 removed the type __Tcl\_SavedResult__ and its associated
          functions __Tcl\_SaveResult__, __Tcl\_RestoreResult__, and
          __Tcl\_DiscardResult__\.

          When a package uses this type and the related functions a rewrite is
          necessary\.

          With Tcl 9 use of type __Tcl\_InterpState__ and its functions
          __Tcl\_SaveInterpState__, __Tcl\_RestoreInterpState__, and
          __Tcl\_DiscardInterpState__ is now required\.

          As these were introduced with Tcl 8\.5 the rewrite gives us
          compatibility with Tcl 8\.6 for free\.

       1) __Tcl\_Size__

          One of the main changes introduced with Tcl 9 is the breaking of the
          2G barrier for the number of bytes in a string, elements in a list,
          etc\. In a lot of interfaces __int__ was replaced with
          __Tcl\_Size__, which is effectively __ptrdiff\_t__ behind the
          scenes\.

          The "tclpre9compat\.h" header mentioned above provides a suitable
          definition of __Tcl\_Size__ for __8\.6__, i\.e\. maps it to
          __int__\. This enables the package code to use __Tcl\_Size__
          everywhere and still have it work for both Tcl 8\.6 and 9\.

          It is of course necessary to rewrite the package code to use
          __Tcl\_Size__\.

          The checker reports all lines in the C code using a function whose
          signature was changed to use __Tcl\_Size__ over __int__\.

          Note that it is necessary to manually check the package code for
          places where a __%d__ text formatting specification should be
          replaced with __TCL\_SIZE\_FMT__\.

          I\.e\. all places where __Tcl\_Size__ values are formatted with
          __printf__\-style functions a formatting string

              "... %d ..."

          has to be replaced with

              "... " TCL_SIZE_FMT " ..."

          The macro __TCL\_SIZE\_FMT__ is defined by Critcl's compatibility
          layer, as an extension of the __TCL\_SIZE\_MODIFIER__ macro which
          only contains the formatting modifier to insert into a plain
          __%d__ to handle __Tcl\_Size__ values\.

          *Note* how the original formatting string is split into multiple
          strings\. The C compiler will fuse these back together into a single
          string\.

       1) Command creation\.

          This is technically a part of the __Tcl\_Size__ changes\.

          All places using __Tcl\_CreateObjCommand__ have to be rewritten to
          use __Tcl\_CreateObjCommand2__ instead, and the registered command
          functions to use __Tcl\_Size__ for their *objc* argument\.

          The "tclpre9compat\.h" header maps this back to the old function when
          compilation is done against Tcl 8\.6\.

          *[CriTcl](critcl\.md)* does this itself for the commands created
          via __critcl::ccommand__, __critcl::cproc__, and derived
          places \(__[critcl::class](critcl\_class\.md)__\)\.

       1) TIP 494\. This TIP adds three semantic constants wrapping __\-1__ to
          Tcl 9 to make the meaning of code clearer\. As part of this it also
          casts the constant to the proper type\. They are:

            - __TCL\_IO\_FAILURE__

            - __TCL\_AUTO\_LENGTH__

            - __TCL\_INDEX\_NONE__

          Critcl's compatibility layer provides the same constants to Tcl 8\.6\.

          Critcl's new checker highlights places where __TCL\_AUTO\_LENGTH__
          is suitable\.

          Doing this for the other two constants looks to require deeper and
          proper parsing of C code, which the checker does not do\.

# <a name='section2'></a>Additional References

  1. [https://wiki\.tcl\-lang\.org/page/Porting\+extensions\+to\+Tcl\+9](https://wiki\.tcl\-lang\.org/page/Porting\+extensions\+to\+Tcl\+9)

  1. [https://wiki\.tcl\-lang\.org/page/Tcl\+9\+functions\+using\+Tcl%5FSize](https://wiki\.tcl\-lang\.org/page/Tcl\+9\+functions\+using\+Tcl%5FSize)

  1. [https://core\.tcl\-lang\.org/tcl/wiki?name=Migrating%20scripts%20to%20Tcl%209](https://core\.tcl\-lang\.org/tcl/wiki?name=Migrating%20scripts%20to%20Tcl%209)

  1. [https://core\.tcl\-lang\.org/tcl/wiki?name=Migrating%20C%20extensions%20to%20Tcl%209](https://core\.tcl\-lang\.org/tcl/wiki?name=Migrating%20C%20extensions%20to%20Tcl%209)

# <a name='section3'></a>Authors

Jean Claude Wippler, Steve Landers, Andreas Kupries

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report them at
[https://github\.com/andreas\-kupries/critcl/issues](https://github\.com/andreas\-kupries/critcl/issues)\.
Ideas for enhancements you may have for either package, application, and/or the
documentation are also very welcome and should be reported at
[https://github\.com/andreas\-kupries/critcl/issues](https://github\.com/andreas\-kupries/critcl/issues)
as well\.

# <a name='keywords'></a>KEYWORDS

[C code](\.\./index\.md\#c\_code), [Embedded C
Code](\.\./index\.md\#embedded\_c\_code), [calling C code from
Tcl](\.\./index\.md\#calling\_c\_code\_from\_tcl), [code
generator](\.\./index\.md\#code\_generator), [compile &
run](\.\./index\.md\#compile\_run), [compiler](\.\./index\.md\#compiler),
[dynamic code generation](\.\./index\.md\#dynamic\_code\_generation), [dynamic
compilation](\.\./index\.md\#dynamic\_compilation), [generate
package](\.\./index\.md\#generate\_package), [linker](\.\./index\.md\#linker),
[on demand compilation](\.\./index\.md\#on\_demand\_compilation), [on\-the\-fly
compilation](\.\./index\.md\#on\_the\_fly\_compilation)

# <a name='category'></a>CATEGORY

Glueing/Embedded C code

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; Jean\-Claude Wippler  
Copyright &copy; Steve Landers  
Copyright &copy; 2011\-2024 Andreas Kupries
