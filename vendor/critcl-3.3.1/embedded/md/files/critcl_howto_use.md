
[//000000001]: # (critcl\_howto\_use \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_howto\_use\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_howto\_use\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_howto\_use \- How To Use CriTcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Basics](#section2)

      - [Simple Arguments](#subsection1)

      - [Simple Results](#subsection2)

      - [Range\-limited Simple Arguments](#subsection3)

      - [String Arguments](#subsection4)

      - [String Results](#subsection5)

      - [List Arguments](#subsection6)

      - [Constrained List Arguments](#subsection7)

      - [Raw Tcl\_Obj\* Arguments](#subsection8)

      - [Raw Tcl\_Obj\* Results](#subsection9)

      - [Errors & Messages](#subsection10)

      - [Tcl\_Interp\* Access](#subsection11)

      - [Binary Data Arguments](#subsection12)

      - [Constant Binary Data Results](#subsection13)

      - [Tcl Runtime Version](#subsection14)

      - [Additional Tcl Code](#subsection15)

      - [Debugging Support](#subsection16)

      - [Install The Package](#subsection17)

  - [Using External Libraries](#section3)

      - [Default Values For Arguments](#subsection18)

      - [Custom Argument Validation](#subsection19)

      - [Separating Local C Sources](#subsection20)

      - [Very Simple Results](#subsection21)

      - [Structure Arguments](#subsection22)

      - [Structure Results](#subsection23)

      - [Structure Types](#subsection24)

      - [Large Structures](#subsection25)

      - [External Structures](#subsection26)

      - [External Enumerations](#subsection27)

      - [External Bitsets/Bitmaps/Flags](#subsection28)

      - [Non\-standard header/library locations](#subsection29)

      - [Non\-standard compile/link configuration](#subsection30)

      - [Querying the compilation environment](#subsection31)

      - [Shared C Code](#subsection32)

  - [Various](#section4)

      - [Author, License, Description, Keywords](#subsection33)

      - [Get Critcl Application Help](#subsection34)

      - [Supported Targets & Configurations](#subsection35)

      - [Building A Package](#subsection36)

      - [Building A Package For Debugging](#subsection37)

  - [Authors](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document assumes the presence of a working *[CriTcl](critcl\.md)*
installation\.

If that is missing follow the instructions on *[How To Install
CriTcl](critcl\_howto\_install\.md)*\.

# <a name='section2'></a>Basics

To create a minimal working package

  1. Choose a directory to develop in and make it the working directory\. This
     should not be a checkout of *[CriTcl](critcl\.md)* itself\.

  1. Save the following example to a file\. In the following it is assumed that
     the file was named "example\.tcl"\.

         # -*- tcl -*-
         # Critcl support, absolutely necessary.
         package require critcl

         # Bail out early if the compile environment is not suitable.
         if {![critcl::compiling]} {
             error "Unable to build project, no proper compiler found."
         }

         # Information for the teapot.txt meta data file put into a generated package.
         # Free form strings.
         critcl::license {Andreas Kupries} {Under a BSD license}

         critcl::summary {The first CriTcl-based package}

         critcl::description {
             This package is the first example of a CriTcl-based package. It contains all the
             necessary and conventionally useful pieces.
         }

         critcl::subject example {critcl package}
         critcl::subject {basic critcl}

         # Minimal Tcl version the package should load into.
         critcl::tcl 8.6

         # Use to activate Tcl memory debugging
         #critcl::debug memory
         # Use to activate building and linking with symbols (for gdb, etc.)
         #critcl::debug symbols

         # ## #### ######### ################ #########################
         ## A hello world, directly printed to stdout. Bypasses Tcl's channel system.

         critcl::cproc hello {} void {
             printf("hello world\n");
         }

         # ## #### ######### ################ #########################

         # Forcing compilation, link, and loading now.
         critcl::msg -nonewline { Building ...}
         if {![critcl::load]} {
             error "Building and loading the project failed."
         }

         # Name and version the package. Just like for every kind of Tcl package.
         package provide critcl-example 1

  1. Invoke the command

         critcl -keep -debug all -pkg example.tcl

     This compiles the example and installs it into a "lib/" sub directory of
     the working directory, generating output similar to

         Config:   linux-x86_64-gcc
         Build:    linux-x86_64-gcc
         Target:   linux-x86_64
         Source:   example.tcl  (provide critcl-example 1) Building ...
         Library:  example.so
          (tclStubsPtr     =>  const TclStubs *tclStubsPtr;)
          (tclPlatStubsPtr =>  const TclPlatStubs *tclPlatStubsPtr;)
         Package:  lib/example
         Files left in /home/aku/.critcl/pkg2567272.1644845439

     during operation\.

     The __\-keep__ option suppressed the cleanup of the generated C files,
     object files, compiler log, etc\. normally done at the end of building\.

         % ls -l /home/aku/.critcl/pkg2567272.1644845439
         total 36
         -rw-r--r-- 1 aku aku  1260 Feb 14 18:30 v3118_00000000000000000000000000000004.c
         -rw-r--r-- 1 aku aku  2096 Feb 14 18:30 v3118_00000000000000000000000000000004_pic.o
         -rw-r--r-- 1 aku aku  1728 Feb 14 18:30 v3118_00000000000000000000000000000009.c
         -rw-r--r-- 1 aku aku  2448 Feb 14 18:30 v3118_00000000000000000000000000000009_pic.o
         -rwxr-xr-x 1 aku aku 14424 Feb 14 18:30 v3118_00000000000000000000000000000009.so
         -rw-r--r-- 1 aku aku  1725 Feb 14 18:30 v3118.log

     This enables inspection of the generated C code\. Simply drop the option
     from the command if that is not desired\.

     The option __\-debug__, with argument __all__ activated Tcl's memory
     debugging and caused the generation of the symbol tables needed by
     __gdb__ or any other debugger\. The alternate arguments __memory__
     and __symbols__ activate just one of the these\.

  1. Now invoke an interactive __tclsh__ and enter the commands:

       - *lappend auto\_path lib*

       - *package require critcl\-example*

       - *info loaded*

       - *hello*

       - *exit*

     I\.e\. extend __tclsh__'s package search path to include the location of
     the new package, load the package, verify that the associated shared
     library is present, invoke the package command, and stop the session\.

     When the package command is invoked the terminal will show __hello
     world__, followed by the prompt\.

Commands: *critcl::compiling*, *critcl::cproc*, *critcl::description*,
*critcl::license*, *critcl::load*, *critcl::msg*, *critcl::subject*,
*critcl::summary*, *critcl::tcl*\.

Make a copy of "example\.tcl" before going through the sub\-sections\. Keep it as a
save point to return to from the editing done in the sub\-section\.

## <a name='subsection1'></a>Simple Arguments

A function taking neither arguments nor returning results is not very useful\.

  1. We are now extending the command to take an argument\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc hello \{double x\} void \{  
     > &nbsp;/\* double x; \*/  
     > &nbsp;printf\("hello world, we have %f\\n", x\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. When testing the package again, entering the simple __hello__ will
     fail\.

     The changed command is now expecting an argument, and we gave it none\.

     Retry by entering

         hello 5

     instead\. Now the command behaves as expected and prints the provided value\.

     Further try and enter

         hello world

     This will fail again\. The command expected a real number and we gave it
     something decidedly not so\.

     These checks \(argument count, argument type\) are implemented in the
     translation layer *[CriTcl](critcl\.md)* generates for the C function\.
     The function body is never invoked\.

## <a name='subsection2'></a>Simple Results

A function taking neither arguments nor returning results is not very useful\.

  1. We are now extending the command to return a result\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc twice \{double x\} double \{  
     > &nbsp;return 2\*x;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. Note that the name of the command changed\. Goodbye __hello__, hello
     __twice__\.

  1. Invoke

         twice 4

     and the __tclsh__ will print the result __8__ in the terminal\.

An important limitation of the commands implemented so far is that they cannot
fail\. The types used so far \(__void__, __double__\) and related scalar
types can return only a value of the specified type, and nothing else\. They have
no ability to signal an error to the Tcl script\.

We will come back to this after knowing a bit more about the more complex
argument and result types\.

Of interest to the eager reader: *[CriTcl cproc Type
Reference](critcl\_cproc\.md)*

## <a name='subsection3'></a>Range\-limited Simple Arguments

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc hello \{\{double > 5 < 22\} x\} void \{  
     > &nbsp;/\* double x, range 6\-21; \*/  
     > &nbsp;printf\("hello world, we have %f\\n", x\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. When dealing with simple arguments whose range of legal values is limited
     to a single continuous interval extend the base type with the necessary
     relations \(__>__, __>=__, __<__, and __<=__\) and limiting
     values\.

     *Note* that the limiting values have to be proper constant numbers
     acceptable by the base type\. Symbolic values are not accepted\.

     Here the argument *x* of the changed function will reject all values
     outside of the interval 6 to 21\.

## <a name='subsection4'></a>String Arguments

Tcl prides itself on the fact that *Everything Is A String*\. So how are string
values passed into C functions ?

  1. We are now extending the command with a string argument\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc hello \{pstring x\} void \{  
     > &nbsp;/\* critcl\_pstring x \(\.s, \.len, \.o\); \*/  
     > &nbsp;printf\("hello world, from %s \(%d bytes\)\\n", x\.s, x\.len\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. Testing __hello__ with any kind of argument the information is printed\.

  1. Of note here is that the command argument __x__ is a structure\.

  1. The example uses only two of the three fields, the pointer to the string
     data \(__\.s__\), and the length of the string \(__\.len__\)\. In bytes,
     *not* in characters, because Tcl's internal representation of strings
     uses a modified UTF\-8 encoding\. A character consists of between 1 and
     __TCL\_UTF\_MAX__ bytes\.

  1. *Attention* The pointers \(__\.s__\) refer into data structures
     *internal* to and managed by the Tcl interpreter\. Changing them is highly
     likely to cause subtle and difficult to track down bugs\. Any and all
     complex arguments must be treated as *Read\-Only*\. Never modify them\.

  1. Use the simpler type __char\*__ if and only if the length of the string
     is not relevant to the command, i\.e\. not computed, or not used by any of
     the functions called from the body of the command\. Its value is essentially
     just the __\.s__ field of __pstring__'s structure\. This then looks
     like

             critcl::cproc hello {char* x} void {
         	/* char* x; */
         	printf("hello world, from %s\n", x);
             }

## <a name='subsection5'></a>String Results

Tcl prides itself on the fact that *Everything Is A String*\. So how are string
values returned from C functions ?

  1. We are now giving the command a string result\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc twice \{double x\} char\* \{  
     > &nbsp;char buf \[lb\]40\[rb\];  
     > &nbsp;sprintf\(buf, "%f", 2\*x\);  
     > &nbsp;return buf;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. Note that the name of the command changed\. Goodbye __hello__, hello
     __twice__\.

  1. Invoke

         twice 4

     and the __tclsh__ will print the result __8__ in the terminal\.

  1. *Attention*\. To the translation layer the string pointer is owned by the
     C code\. A copy is made to become the result seen by Tcl\.

     While the C code is certainly allowed to allocate the string on the heap if
     it so wishes, this comes with the responsibility to free the string as
     well\. Abrogation of that responsibility will cause memory leaks\.

     The type __char\*__ is recommended to be used with static string
     buffers, string constants and the like\.

  1. Conversely, to return heap\-allocated strings it is recommended to use the
     type __string__ instead\.

     Replace the definition of __twice__ with

         critcl::cproc twice {double x} string {
             char* buf = Tcl_Alloc (40);
             sprintf(buf, "%f", 2*x);
             return buf;
         }

     Now the translation layer takes ownership of the string from the C code and
     transfers that ownership to the Tcl interpreter\. This means that the string
     will be released when the Tcl interpreter is done with it\. The C code has
     no say in the lifecycle of the string any longer, and having the C code
     releasing the string *will* cause issues\. Dangling pointers and
     associated memory corruption and crashes\.

## <a name='subsection6'></a>List Arguments

Even as a string\-oriented language Tcl is capable of handling more complex
structures\. The first of it, with Tcl since the beginning are *lists*\. Sets of
values indexed by a numeric value\.

In C parlance, *arrays*\.

  1. We are now extending the command with a __list__ argument\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc hello \{list x\} void \{  
     > &nbsp;/\* critcl\_list x \(\.o, \.v, \.c\); \*/  
     > &nbsp;printf\("hello world, %d elements in \(%s\)\\n", x\.c, Tcl\_GetString \(x\.o\)\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. Testing __hello__ with any kind of list argument it will print basic
     information about it\.

  1. Of note here is that the command argument __x__ is a structure\.

  1. The example uses only two of the three fields, the pointer to the original
     __Tcl\_Obj\*__ holding the list \(__\.o__\), and the length of the list
     \(__\.c__\) in elements\.

     The field __\.v__, not used above, is the C array holding the
     __Tcl\_Obj\*__ pointers to the list elements\.

  1. *Attention* The pointers __\.o__ and __\.v__ refer into data
     structures *internal* to and managed by the Tcl interpreter\. Changing
     them is highly likely to cause subtle and difficult to track down bugs\. Any
     and all complex arguments must be treated as *Read\-Only*\. Never modify
     them\.

  1. As a last note, this argument type does not place any constraints on the
     size of the list, or on the type of the elements\.

## <a name='subsection7'></a>Constrained List Arguments

As mentioned at the end of section [List Arguments](#subsection6) the basic
__list__ type places no constraints on the size of the list, nor on the type
of the elements\.

Both kind of constraints can be done however, alone or together\.

  1. We are now extending the command with a length\-limited list\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc hello \{\[5\] x\} void \{  
     > &nbsp;/\* critcl\_list x \(\.o, \.v, \.c\); \*/  
     > &nbsp;printf\("hello world, %d elements in \(%s\)\\n", x\.c, Tcl\_GetString \(x\.o\)\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. Testing the new command will show that only lists holding exactly __5__
     elements will be accepted\.

  1. To accept lists of any length use __\[\]__ or __\[\*\]__\. Both forms are
     actually aliases of the base type, i\.e\. __list__\.

  1. To constrain just the type of elements, for example to type __int__,
     use

         int[]

     or

         []int

  1. To combine both type and length constraints use the forms

         int[5]

     or

         [5]int

  1. The last, most C\-like forms of these contraints place the list indicator
     syntax on the argument instead of the type\. I\.e

         int a[]

     or

         int a[5]

## <a name='subsection8'></a>Raw Tcl\_Obj\* Arguments

When the set of predefined argument types is not enough the oldest way of
handling the situation is falling back to the structures used by Tcl to manage
values, i\.e\. __Tcl\_Obj\*__\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc hello \{object x\} void \{  
     > &nbsp;/\* Tcl\_Obj\* x \*/  
     > &nbsp;int len;  
     > &nbsp;char\* str = Tcl\_GetStringFromObj \(x, &len\);  
     > &nbsp;printf\("hello world, from %s \(%d bytes\)\\n", str, len\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. Having direct access to the raw __Tcl\_Obj\*__ value all functions of the
     public Tcl API for working with Tcl values become usable\. The downside of
     that is that all the considerations for handling them apply as well\.

     In other words, the C code becomes responsible for handling the reference
     counts correctly, for duplicating shared __Tcl\_Obj\*__ structures before
     modifying them, etc\.

     One thing the C code is allowed to do without restriction is to *shimmer*
     the internal representation of the value as needed, through the associated
     Tcl API functions\. For example __Tcl\_GetWideIntFromObj__ and the like\.
     It actually has to be allowed to do so, as the type checking done as part
     of such conversions is now the responsibility of the C code as well\.

     For the predefined types this is all hidden in the translation layer
     generated by *[CriTcl](critcl\.md)*\.

     If more than one command has to perform the same kind of checking and/or
     conversion it is recommended to move the core of the code into proper C
     functions for proper sharing among the commands\.

  1. This is best done by defining a custom argument type using
     *[CriTcl](critcl\.md)* commands\. This extends the translation layer
     *[CriTcl](critcl\.md)* is able to generate\. The necessary conversions,
     type checks, etc\. are then again hidden from the bulk of the application C
     code\.

     We will come back to this\.

## <a name='subsection9'></a>Raw Tcl\_Obj\* Results

When the set of predefined result types is not enough the oldest way of handling
the situation is falling back to the structures used by Tcl to manage values,
i\.e\. __Tcl\_Obj\*__\.

Two builtin types are provided for this, to handle different reference counting
requirements\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc twice \{double x\} object0 \{  
     > &nbsp;return Tcl\_NewDoubleObj\(2\*x\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. With __object0__ the translation layer assumes that the returned
     __Tcl\_Obj\*__ value has a reference count of __0__\. I\.e\. a value
     which is unowned and unshared\.

     This value is passed directly to Tcl for its use, without any changes\. Tcl
     increments the reference count and thus takes ownership\. The value is still
     unshared\.

     It would be extremely detrimental if the translation layer had decremented
     the reference count before passing the value\. This action would release the
     memory and then leave Tcl with a dangling pointer and the associated memory
     corruption bug to come\.

  1. The situation changes when the C code returns a __Tcl\_Obj\*__ value with
     a reference count greater than __0__\. I\.e\. at least owned \(by the C
     code\), and possibly even shared\. There are some object constructors and/or
     mutators in the public Tcl API which do that, although I do not recall
     their names\. The example below simulates this situation by explicitly
     incrementing the reference count before returning the value\.

  1. In this case use the type __object__ \(without the trailing __0__\)\.

  1. Edit the file "example\.tcl" and replace the definition of __twice__
     with

             critcl::cproc twice {double x} object {
         	Tcl_Obj* result = Tcl_NewDoubleObj(2*x);
         	Tcl_IncrRefCount (result);
         	return result;
             }

     and rebuild the package\.

  1. After handing the value to Tcl, with the associated incremented reference
     count, the translation layer decrements the reference count, invalidating
     the C code's ownership and leaving the final reference count the same\.

     Note, the order matters\. If the value has only one reference then
     decrementing it before Tcl increments it would again release the value, and
     again leave Tcl with a dangling pointer\.

     Also, not decrementing the reference count at all causes the inverse
     problem to the memory corruption issues of before, memory leaks\.

  1. *Note* that both types transfer ownership of the value\. Their difference
     is just in the reference count of the value coming out of the function, and
     the \(non\-\)actions having to be \(not\) taken to effect said transfer without
     causing memory issues\.

## <a name='subsection10'></a>Errors & Messages

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc sqrt \{  
     > &nbsp;Tcl\_Interp\* interp  
     > &nbsp;double      x  
     > &nbsp;&nbsp;&nbsp;&nbsp;\} object0 \{  
     > &nbsp;if \(x < 0\) \{  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Tcl\_SetObjResult \(interp, Tcl\_ObjPrintf \("Expected double >=0, but got \\"%d\\"", x\)\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Tcl\_SetErrorCode \(interp, "EXAMPLE", "BAD", "DOMAIN", NULL\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return NULL;  
     > &nbsp;\}  
     > &nbsp;return Tcl\_NewDoubleObj\(sqrt\(x\)\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. In standard C\-based packages commands signal errors by returning
     __TCL\_ERROR__, placing the error message as the interpreter result, and
     maybe providing an error code via __Tcl\_SetErrorCode__\.

  1. When using __critcl::cproc__ this is limited and hidden\.

  1. The simple and string types for results do not allow failure\. The value is
     returned to the translation layer, converted into the interpreter result
     and then reported as success \(__TCL\_OK__\)\.

  1. The object types on the other hand do allow for failure\. Return a
     __NULL__ value to signal failure to the translation layer, which then
     reports this to the interpreter via the standard __TCL\_ERROR__\.

  1. *Attention* Setting the desired error message and code into the
     interpreter is still the responsibility of the function body\.

## <a name='subsection11'></a>Tcl\_Interp\* Access

  1. Reread the example in the __previous__ section\.

  1. Note the type __Tcl\_Interp\*__ used for the first argument\.

  1. This type is special\.

  1. An argument of this type has to be the first argument of a function\.

  1. Using it tells *[CriTcl](critcl\.md)* that the function needs access
     to the Tcl interpreter calling it\. It then arranges for that to happen in
     the generated C code\.

     Using functions from Tcl's public C API taking an interpreter argument in
     the function body is a situation where this is needed\.

  1. *This special argument is not visible at the script level*\.

  1. *This special argument is not an argument of the Tcl command for the
     function*\.

  1. In our example the __sqrt__ command is called with a single argument\.

  1. The name of the argument can be freely chosen\. It is the type which is
     important and triggers the special behaviour\. My prefered names are
     __ip__ and __interp__\.

## <a name='subsection12'></a>Binary Data Arguments

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc hello \{bytes x\} void \{  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;/\* critcl\_bytes x \(\.s, \.len, \.o\); \*/  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;printf\("hello world, with %d bytes \\n data: ", x\.len\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;for \(i = 0; i < x\.len; i\+\+\) \{  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;printf\(" %02x", x\.s\[i\]\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if \(i % 16 == 15\) printf \("\\ndata: "\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\}  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if \(i % 16 \!= 0\) printf \("\\n"\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. To deal with strings holding binary data use the type __bytes__\. It
     ensures that the function sees the proper binary data, and not how Tcl is
     encoding it internally, as the string types would\.

## <a name='subsection13'></a>Constant Binary Data Results

  1. Use the command __critcl::cdata__ to create a command taking no
     arguments and returning a constant ByteArray value\.

             # P5 3 3 255 \n ...
             critcl::cdata cross3x3pgm {
         	80 52 32 51 32 51 32 50 53 53 10
         	0   255 0
         	255 255 255
         	0   255 0
             }

## <a name='subsection14'></a>Tcl Runtime Version

  1. See and reread the [basic package](#section2) for the introduction of
     the commands referenced below\.

  1. Use the command __critcl::tcl__ to tell *[CriTcl](critcl\.md)* the
     minimal version of Tcl the package is to be used with\.

     This determines which Tcl headers all files are compiled against, and what
     version of the public Tcl API is available to the C code\.

     Currently __8\.4__, __8\.5__ and __8\.6__ are supported\.

     If not specified __8\.4__ is assumed\.

## <a name='subsection15'></a>Additional Tcl Code

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc greetings::hello \{\} void \{  
     > &nbsp;printf\("hello world\\n"\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc greetings::hi \{\} void \{  
     > &nbsp;printf\("hi you\\n"\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. The command __hello__ is now available as __greetings::hello__, and
     a second command __greetings::hi__ was added\.

  1. Tcl has automatically created the namespace __greetings__\.

  1. Create a file "example\-policy\.tcl" and enter

             namespace eval greetings {
         	namespace export hello hi
         	namespace ensemble create
             }

     into it\.

  1. Edit "example\.tcl"\. Add the code

         critcl::tsources example-policy.tcl

     and rebuild the package\.

  1. The added Tcl code makes __greetings__ available as an *ensemble*
     command\.

     The commands in the namespace have been registered as methods of the
     ensemble\.

     They can now be invoked as

         greetings hello
         greetings hi

  1. The Tcl builtin command __string__ is an ensemble as well, as is
     __clock__\.

New commands: *critcl::tsources*

## <a name='subsection16'></a>Debugging Support

  1. See and reread the [basic package](#section2) for the introduction of
     the commands referenced below\.

  1. Use the command __critcl::debug__ to activate various features
     supporting debugging\.

         critcl::debug memory  ;# Activate Tcl memory debugging (-DTCL_MEM_DEBUG)
         critcl::debug symbols ;# Activate building and linking with debugger symbols (-g)
         critcl::debug all     ;# Shorthand for both `memory` and `symbols`.

## <a name='subsection17'></a>Install The Package

  1. Starting from the [Basics](#section2)\.

  1. Use an interactive __tclsh__ seesion to determine the value of __info
     library__\.

     For the purpose of this HowTo assume that this path is
     "/home/aku/opt/ActiveTcl/lib/tcl8\.6"

  1. Invoke the critcl application in a terminal, using

         critcl -libdir /home/aku/opt/ActiveTcl/lib/tcl8.6 -pkg example.tcl

  1. The package is now build and installed into the chosen directory\.

         % find /home/aku/opt/ActiveTcl/lib/tcl8.6/example/
          /home/aku/opt/ActiveTcl/lib/tcl8.6/example/
          /home/aku/opt/ActiveTcl/lib/tcl8.6/example/pkgIndex.tcl
          /home/aku/opt/ActiveTcl/lib/tcl8.6/example/critcl-rt.tcl
          /home/aku/opt/ActiveTcl/lib/tcl8.6/example/license.terms
          /home/aku/opt/ActiveTcl/lib/tcl8.6/example/linux-x86_64
          /home/aku/opt/ActiveTcl/lib/tcl8.6/example/linux-x86_64/example.so
          /home/aku/opt/ActiveTcl/lib/tcl8.6/example/teapot.txt

# <a name='section3'></a>Using External Libraries

To create a minimal package wrapping an external library

  1. Choose a directory to develop in and make it the working directory\. This
     should not be a checkout of *[CriTcl](critcl\.md)* itself\.

  1. Save the following example to a file\. In the following it is assumed that
     the file was named "example\.tcl"\.

         # -*- tcl -*-
         # Critcl support, absolutely necessary.
         package require critcl

         # Bail out early if the compile environment is not suitable.
         if {![critcl::compiling]} {
             error "Unable to build project, no proper compiler found."
         }

         # Information for the teapot.txt meta data file put into a generated package.
         # Free form strings.
         critcl::license {Andreas Kupries} {Under a BSD license}

         critcl::summary {The second CriTcl-based package}

         critcl::description {
             This package is the second example of a CriTcl-based package. It contains all the
             necessary and conventionally useful pieces for wrapping an external library.
         }

         critcl::subject {external library usage} example {critcl package}
         critcl::subject {wrapping external library}

         # Minimal Tcl version the package should load into.
         critcl::tcl 8.6

         # Locations for headers and shared library of the library to wrap.
         # Required only for non-standard locations, i.e. where CC is not searching by default.
         critcl::cheaders   -I/usr/include
         critcl::clibraries -L/usr/lib/x86_64-linux-gnu
         critcl::clibraries -lzstd

         # Import library API, i.e. headers.
         critcl::include zstd.h

         # ## #### ######### ################ #########################
         ## (De)compression using Zstd
         ## Data to (de)compress is passed in and returned as Tcl byte arrays.

         critcl::cproc compress {
             Tcl_Interp* ip
             bytes       data
             int         {level ZSTD_CLEVEL_DEFAULT}
         } object0 {
             /* critcl_bytes data; (.s, .len, .o) */
             Tcl_Obj* error_message;

             int max = ZSTD_maxCLevel();
             if ((level < 1) || (level > max)) {
         	error_message = Tcl_ObjPrintf ("level must be integer between 1 and %d", max);
         	goto err;
             }

             size_t dest_sz  = ZSTD_compressBound (data.len);
             void*  dest_buf = Tcl_Alloc(dest_sz);

             if (!dest_buf) {
         	error_message = Tcl_NewStringObj ("can't allocate memory to compress data", -1);
         	goto err;
             }

             size_t compressed_size = ZSTD_compress (dest_buf, dest_sz,
         					    data.s,   data.len,
         					    level);
             if (ZSTD_isError (compressed_size)) {
         	Tcl_Free(dest_buf);
         	error_message = Tcl_ObjPrintf ("zstd encoding error: %s",
         				       ZSTD_getErrorName (compressed_size));
         	goto err;
             }

             Tcl_Obj* compressed = Tcl_NewByteArrayObj (dest_buf, compressed_size);
             Tcl_Free (dest_buf);

             return compressed;
           err:
             Tcl_SetObjResult (ip, error_message);
             return 0;
         }

         critcl::cproc decompress {
             Tcl_Interp*  ip
             bytes        data
         } object0 {
             Tcl_Obj* error_message;

             size_t dest_sz = ZSTD_getDecompressedSize (data.s, data.len);
             if (dest_sz == 0) {
                 error_message = Tcl_NewStringObj("invalid data", -1);
         	goto err;
             }

             void* dest_buf = Tcl_Alloc (dest_sz);
             if (!dest_buf) {
         	error_message = Tcl_NewStringObj("failed to allocate decompression buffer", -1);
         	goto err;
             }

             size_t decompressed_size = ZSTD_decompress (dest_buf, dest_sz,
         						data.s,   data.len);
             if (decompressed_size != dest_sz) {
         	Tcl_Free (dest_buf);
                 error_message = Tcl_ObjPrintf("zstd decoding error: %s",
         				      ZSTD_getErrorName (decompressed_size));
         	goto err;
             }

             Tcl_Obj* decompressed = Tcl_NewByteArrayObj (dest_buf, dest_sz);
             Tcl_Free (dest_buf);

             return decompressed;

           err:
             Tcl_SetObjResult (ip, error_message);
             return 0;
         }

         # ## #### ######### ################ #########################

         # Forcing compilation, link, and loading now.
         critcl::msg -nonewline { Building ...}
         if {![critcl::load]} {
             error "Building and loading the project failed."
         }

         # Name and version the package. Just like for every kind of Tcl package.
         package provide critcl-example 1

  1. Build the package\. See the __Basics__, if necessary\.

  1. Load the package and invoke the commands\.

     *Attention*\. The commands take and return binary data\. This may look very
     bad in the terminal\.

  1. To test the commands enter

         set a [compress {hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhello wwwwwwwworld}]

         decompress $a

     in the interactive __tclsh__

New commands: *critcl::cheaders*, *critcl::clibraries*, *critcl::include*\.

## <a name='subsection18'></a>Default Values For Arguments

  1. Reread the example of the main section\. Note specifically the line

         int {level ZSTD_CLEVEL_DEFAULT}

  1. This line demonstrates that __critcl::cproc__ arguments allowed to have
     default values, in the same vein as __proc__ arguments, and using the
     same syntax\.

  1. *Attention* Default values have to be legal C rvalues and match the C
     type of the argument\.

     They are literally pasted into the generated C code\.

     They bypass any argument validation done in the generated translation
     layer\. This means that it is possible to use a value an invoker of the
     command cannot use from Tcl\.

  1. This kind of in\-band signaling of a default versus a regular argument is
     however not necessary\.

     Look at

             critcl::cproc default_or_not {int {x 0}} void {
         	if !has_x {
         	    printf("called with default\n");
         	    return
         	}
         	printf("called with %d\n", x);
             }

     Any argument *x* with a default causes *[CriTcl](critcl\.md)* to
     create a hidden argument *has\_x*, of type int \(boolean\)\. This argument is
     set to __1__ when *x* was filled from defaults, and __0__ else\.

## <a name='subsection19'></a>Custom Argument Validation

  1. Starting from the [base wrapper](#section3)\. Edit the file
     "example\.tcl"\. Replace the entire __compress__ function with

         critcl::argtype zstd_compression_level {
             /* argtype: `int` */
             if (Tcl_GetIntFromObj (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
             /* additional validation */
             int max = ZSTD_maxCLevel();
             if ((@A < 1) || (@A > max)) {
                 Tcl_SetObjResult (interp,
                     Tcl_ObjPrintf ("zstd compression level must be integer between 1 and %d", max));
                 return TCL_ERROR;
             }
             /* @@: current objv[] element
             ** @A: name of argument variable for transfer to C function
             ** interp: predefined variable, access to current interp - error messages, etc.
             */
         } int int ;# C types of transfer variable and function argument.

         critcl::cproc compress {
             Tcl_Interp*            ip
             bytes                  data
             zstd_compression_level {level ZSTD_CLEVEL_DEFAULT}
         } object0 {
             /* critcl_bytes data; (.s, .len, .o) */
             /* int level; validated to be in range 1...ZSTD_maxCLevel() */

             Tcl_Obj* error_message;

             size_t dest_sz  = ZSTD_compressBound (data.len);
             void*  dest_buf = Tcl_Alloc(dest_sz);

             if (!dest_buf) {
                 error_message = Tcl_NewStringObj ("can't allocate memory to compress data", -1);
                 goto err;
             }

             size_t compressed_size = ZSTD_compress (dest_buf, dest_sz,
                                                     data.s,   data.len,
                                                     level);
             if (ZSTD_isError (compressed_size)) {
                 Tcl_Free(dest_buf);
                 error_message = Tcl_ObjPrintf ("zstd encoding error: %s",
                                                ZSTD_getErrorName (compressed_size));
                 goto err;
             }

             Tcl_Obj* compressed = Tcl_NewByteArrayObj (dest_buf, compressed_size);
             Tcl_Free (dest_buf);

             return compressed;
         err:
             Tcl_SetObjResult (ip, error_message);
             return 0;
         }

     and rebuild the package\.

     In the original example the *level* argument of the function was
     validated in the function itself\. This may detract from the funtionality of
     interest itself, especially if there are lots of arguments requiring
     validation\. If the same kind of argument is used in multiple places this
     causes code duplication in the functions as well\.

     Use a custom argument type as defined by the modification to move this kind
     of validation out of the function, and enhance readability\.

     Code duplication however is only partially adressed\. While there is no
     duplication in the visible definitions the C code of the new argument type
     is replicated for each use of the type\.

  1. Now replace the __argtype__ definition with

         critcl::code {
             int GetCompressionLevel (Tcl_Interp* interp, Tcl_Obj* obj, int* level)
             {
                 if (Tcl_GetIntFromObj (interp, obj, level) != TCL_OK) return TCL_ERROR;

                 int max = ZSTD_maxCLevel();
                 if ((*level < 1) || (*level > max)) {
                     Tcl_SetObjResult (interp,
                         Tcl_ObjPrintf ("zstd compression level must be integer between 1 and %d", max));
                     return TCL_ERROR;
                 }
                 return TCL_OK;
             }
         }

         critcl::argtype zstd_compression_level {
             if (GetCompressionLevel (@@, &@A) != TCL_OK) return TCL_ERROR;
         } int int

     and rebuild the package\.

     Now only the calls to the new validation function are replicated\. The
     function itself exists only once\.

## <a name='subsection20'></a>Separating Local C Sources

  1. Starting from the end of the [previous](#subsection19) section\. Edit
     the file "example\.tcl"\.

  1. Save the contents of the __critcl::ccode__ block into a file
     "example\.c" and then replace the entire block with

             critcl::csources example.c

             critcl::ccode {
         	extern int GetCompressionLevel (Tcl_Interp* interp, Tcl_Obj* obj, int* level);
             }

     When mixing C and Tcl code the different kind of indentation rules for
     these languages may come into strong conflict\. Further, very large blocks
     of C code may reduce overall readability\.

  1. The examples fixes this by moving the code block into a local C file and
     then registering this file with *[CriTcl](critcl\.md)*\. When building
     the package *[CriTcl](critcl\.md)* arranges to build all such
     registered C files as well\.

  1. *Attention*\. The C code is now in a separate compilation unit\. The
     example declares the exported function so that the __cproc__s are again
     able to see and use it\.

  1. Now go a step further\. Save the declaration into a file "example\.h", and
     then use

         critcl::include example.h

     to import it\. Note that this is just a shorthand for

          critcl::ccode {
         	#include "example.h"
             }

  1. As an alternative solution, start from the beginning of the section and
     move the entire original __critcl::ccode__ block into a file
     "example\-check\.tcl"\.

     Then replace it with

         critcl::source example-check.tcl

     to import it into the main code again\.

     *Attention* Tcl's builtin command __source__ is *not suitable* for
     importing the separate file due to how *[CriTcl](critcl\.md)* uses the
     information from __info script__ to key various internal
     datastructures\.

## <a name='subsection21'></a>Very Simple Results

  1. Starting from the end of the [validation](#subsection19) section\. Edit
     the file "example\.tcl"\. Add the code below, just before the
     __compress__ command\.

         critcl::cconst version   char* ZSTD_VERSION_STRING
         critcl::cconst min-level int   1
         critcl::cconst max-level int   ZSTD_maxCLevel()

     and rebuild the package\.

  1. These declarations create three additional commands, each returning the
     specified value\. A fixed string, an integer, and a function call returning
     an integer\.

  1. *Attention* The values have to be legal C rvalues and match the C type of
     the result\. They are literally pasted into the generated C code\.

  1. When using __critcl::cconst__ *[CriTcl](critcl\.md)* is aware that
     the result of the function does not depend on any parameters and is
     computed in a single C expression\.

     This enables it do to away with the internal helper function it would need
     and generate if __critcl::cproc__ had been used instead\. For example

             critcl::cproc version {} char* {
         	return ZSTD_VERSION_STRING;
             }

## <a name='subsection22'></a>Structure Arguments

  1. For all that this is a part of how to [Use External
     Libraries](#section3), for the demonstratation only the basics are
     needed\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::ccode \{  
     > &nbsp;typedef struct vec2 \{  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;double x;  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;double y;  
     > &nbsp;\} vec2;  
     >   
     > &nbsp;typedef vec2\* vec2ptr;  
     >   
     > &nbsp;int  
     > &nbsp;GetVecFromObj \(Tcl\_Interp\* interp, Tcl\_Obj\* obj, vec2ptr\* vec\)  
     > &nbsp;\{  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;int len;  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if \(Tcl\_ListObjLength \(interp, obj, &len\) \!= TCL\_OK\) return TCL\_ERROR;  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if \(len \!= 2\) \{  
     > &nbsp;&nbsp;Tcl\_SetObjResult \(interp, Tcl\_ObjPrintf \("Expected 2 elements, got %d", len\)\);  
     > &nbsp;&nbsp;return TCL\_ERROR;  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\}  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Tcl\_Obj\* lv\[2\];  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if \(Tcl\_ListObjGetElements \(interp, obj, &lv\) \!= TCL\_OK\) return TCL\_ERROR;  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;double x, y;  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if \(Tcl\_GetDoubleFromObj \(interp, lv\[0\], &x\) \!= TCL\_OK\) return TCL\_ERROR;  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if \(Tcl\_GetDoubleFromObj \(interp, lv\[1\], &y\) \!= TCL\_OK\) return TCL\_ERROR;  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\*vec = Tcl\_Alloc \(sizeof \(vec2\)\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\(\*vec\)\->x = x;  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\(\*vec\)\->y = y;  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return TCL\_OK;  
     > &nbsp;\}  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::argtype vec2 \{  
     > &nbsp;if \(GetVecFromObj \(interp, @@, &@A\) \!= TCL\_OK\) return TCL\_ERROR;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\} vec2ptr vec2ptr  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::argtyperelease vec2 \{  
     > &nbsp;/\* @A : C variable holding the data to release \*/  
     > &nbsp;Tcl\_Free \(\(char\*\) @A\);  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc norm \{vec2 vector\} double \{  
     > &nbsp;double norm = hypot \(vector\->x, vector\->y\);  
     > &nbsp;return norm;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. The structure to pass as argument is a 2\-dimensional vector\. It is actually
     passed in as a pointer to a __vec2__ structure\. This pointer is created
     by the __GetVecFromObj__ function\. It allocates and fills the structure
     from the Tcl value, which has to be a list of 2 doubles\. The bulk of the
     code in __GetVecFromObj__ is for verifying this and extracting the
     doubles\.

  1. The __argtyperelease__ code releases the pointer when the C function
     returns\. In other words, the pointer to the structure is owned by the
     translation layer and exists only while the function is active\.

  1. While working this code has two disadvantages\. First there is memory churn\.
     Each call of __norm__ causes the creation and release of a temporary
     __vec2__ structure for the argument\. Second is the need to always
     extract the data from the __Tcl\_Obj\*__ value\.

     Both can be done better\.

     We will come back to this after explaining how to return structures to Tcl\.

## <a name='subsection23'></a>Structure Results

  1. Starting from the end of the [previous](#subsection22) section\.

  1. Edit the file "example\.tcl" and add the following code, just after the
     definition of the __norm__ command\.

             critcl::resulttype vec2 {
         	/* rv: result value of function, interp: current Tcl interpreter */
         	if (rv == NULL) return TCL_ERROR;
         	Tcl_Obj* lv[2];
         	lv[0] = Tcl_NewDoubleObj (rv->x);
         	lv[1] = Tcl_NewDoubleObj (rv->y);
         	Tcl_SetObjResult (interp, Tcl_NewListObj (2, lv));
         	Tcl_Free (rv);
         	return TCL_OK;
             } vec2ptr ;# C result type

             critcl::cproc add {vec2 a vec2 b} vec2 {
         	vec2ptr z = Tcl_Alloc (sizeof (vec2));

         	z->x = a->x + b->x;
         	z->y = a->y + b->y;

         	return z;
             }

     and rebuild the package\.

  1. The new command __add__ takes two vectors and return the element\-wise
     sum of both as a new vector\.

  1. The function allocates and initializes a structure and hands it over to the
     translation layer\. Which in turn constructs a Tcl list of 2 doubles from
     it, sets that as the command's result and at last discards the allocated
     structure again\.

  1. While working this code has two disadvantages\. First there is memory churn\.
     Each call of __add__ causes the creation and release of three temporary
     __vec2__ structures\. One per argument, and one for the result\. Second
     is the need to always construct a complex __Tcl\_Obj\*__ value from the
     structure\.

     Both can be done better\. This is explained in the next section\.

## <a name='subsection24'></a>Structure Types

  1. Starting from the end of the previous section\.

  1. Edit the file "example\.tcl"\.

  1. Remove the entire functionality \(type definitions, related C code, and
     cprocs\)\. Replace it with

             critcl::ccode {
         	typedef struct vec2 {
         	    double x;
         	    double y;
         	} vec2;

         	typedef vec2* vec2ptr;

         	/* -- Core vector structure management -- */

         	static vec2ptr Vec2New (double x, double y) {
         	    vec2ptr vec = Tcl_Alloc (sizeof (vec2));
         	    vec->x = x;
         	    vec->y = y;
         	    return vec;
         	}

         	static vec2ptr Vec2Copy (vec2ptr src) {
         	    vec2ptr vec = Tcl_Alloc (sizeof (vec2));
         	    *vec = *src
         	    return vec;
         	}

         	static void Vec2Release (vec2ptr vec) {
         	    Tcl_Free ((char*) vec);
         	}

         	/* -- Tcl value type for vec2 -- Tcl_ObjType -- */

         	static void Vec2Free     (Tcl_Obj* obj);
         	static void Vec2StringOf (Tcl_Obj* obj);
         	static void Vec2Dup      (Tcl_Obj* obj, Tcl_Obj* dst);
         	static int  Vec2FromAny  (Tcl_Interp* interp, Tcl_Obj* obj);

         	Tcl_ObjType vec2_objtype = {
         	    "vec2",
         	    Vec2Free,
         	    Vec2Dup,
         	    Vec2StringOf,
         	    Vec2FromAny
         	};

         	static void Vec2Free (Tcl_Obj* obj) {
         	    Vec2Release ((vec2ptr) obj->internalRep.otherValuePtr);
         	}

         	static void Vec2Dup (Tcl_Obj* obj, Tcl_Obj* dst) {
         	    vec2ptr vec = (vec2ptr) obj->internalRep.otherValuePtr;

         	    dst->internalRep.otherValuePtr = Vec2Copy (vec);
         	    dst->typePtr                   = &vec2_objtype;
         	}

         	static void Vec2StringOf (Tcl_Obj* obj) {
         	    vec2ptr vec = (vec2ptr) obj->internalRep.otherValuePtr;

         	    /* Serialize vector data to string (list of two doubles) */
         	    Tcl_DString      ds;
         	    Tcl_DStringInit (&ds);

         	    char buf [TCL_DOUBLE_SPACE];

         	    Tcl_PrintDouble (0, vec->x, buf); Tcl_DStringAppendElement (&ds, buf);
         	    Tcl_PrintDouble (0, vec->y, buf); Tcl_DStringAppendElement (&ds, buf);

         	    int length = Tcl_DStringLength (ds);

         	    /* Set string representation */
         	    obj->length = length;
         	    obj->bytes  = Tcl_Alloc(length+1);
         	    memcpy (obj->bytes, Tcl_DStringValue (ds), length);
         	    obj->bytes[length] = '\0';
         	    /*
         	    ** : package require critcl::cutil ;# get C utilities
         	    ** : critcl::cutil::alloc          ;# Activate allocation utilities
         	    ** : (Internally cheaders, include)
         	    ** : Then all of the above can be written as STREP_DS (obj, ds);
         	    ** : STREP_DS = STRing REP from DString
         	    */

         	    Tcl_DStringFree (&ds);
         	}

         	static int Vec2FromAny (Tcl_Interp* interp, Tcl_Obj* obj) {
         	    /* Change intrep of obj to vec2 structure.
         	    ** A Tcl list of 2 doubles is used as an intermediary intrep.
         	    */

         	    int len;
         	    if (Tcl_ListObjLength (interp, obj, &len) != TCL_OK) return TCL_ERROR;
         	    if (len != 2) {
         		Tcl_SetObjResult (interp, Tcl_ObjPrintf ("Expected 2 elements, got %d", len));
         		return TCL_ERROR;
         	    }

         	    Tcl_Obj* lv[2];
         	    if (Tcl_ListObjGetElements (interp, obj, &lv) != TCL_OK) return TCL_ERROR;

         	    double x, y;
         	    if (Tcl_GetDoubleFromObj (interp, lv[0], &x) != TCL_OK) return TCL_ERROR;
         	    if (Tcl_GetDoubleFromObj (interp, lv[1], &y) != TCL_OK) return TCL_ERROR;

         	    obj->internalRep.otherValuePtr = (void*) Vec2New (x, y);
         	    obj->typePtr                   = &vec2_objtype;

         	    return TCL_OK;
         	}

         	/* -- (un)packing structures from/into Tcl values -- */

         	int GetVecFromObj (Tcl_Interp* interp, Tcl_Obj* obj, vec2ptr* vec)
         	{
         	    if (obj->typePtr != &vec2_objtype) {
         		if (Vec2FromAny (interp, obj) != TCL_OK) return TCL_ERROR;
         	    }

         	    *vec = (vec2ptr) obj->internalRep.otherValuePtr;
         	    return TCL_OK;
         	}

         	Tcl_Obj* NewVecObj (vec2ptr vec) {
         	    Tcl_Obj* obj = Tcl_NewObj ();

         	    Tcl_InvalidateStringRep (obj);

         	    obj->internalRep.otherValuePtr = Vec2Copy (vec);
         	    obj->typePtr                   = &vec2_objtype;

         	    return obj;
         	}
             }

             critcl::argtype vec2 {
         	if (GetVecFromObj (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
             } vec2ptr vec2ptr

             critcl::resulttype vec2 {
         	/* rv: result value of function, interp: current Tcl interpreter */
         	Tcl_SetObjResult (interp, NewVecObj (&rv));
         	return TCL_OK;
             } vec2

             critcl::cproc norm {vec2 vector} double {
         	double norm = hypot (vector->x, vector->y);
         	return norm;
             }

             critcl::cproc add {vec2 a vec2 b} vec2 {
         	vec2 z;

         	z.x = a->x + b->x;
         	z.y = a->y + b->y;

         	return z;
             }

     and rebuild the package\.

  1. This implements a new __Tcl\_ObjType__ to handle __vec2__
     structures\. With it __vec2__ structures are become usable as internal
     representation \(*intrep* of __Tcl\_Obj\*__ values\.

     The two functions __NewVecObj__ and __GetVecFromObj__ pack and
     unpack the structures from and into __Tcl\_Obj\*__ values\. The latter
     performs the complex deserialization into a structure if and only if
     needed, i\.e\. when the __TclObj\*__ value has no intrep, or the intrep
     for a different type\. This process of changing the intrep of a Tcl value is
     called *shimmering*\.

     Intreps cache the interpretation of __Tcl\_Obj\*__ values as a specific
     kind of type\. Here __vec2__\. This reduces conversion effort and memory
     churn, as intreps are kept by the Tcl interpreter as long as possible and
     needed\.

  1. The arguments of __norm__ and __add__ are now converted once on
     entry, if not yet in the proper type, or not at all, if so\.

  1. *Attention*\. This example has the issue of passing result structures by
     value through the stack, and then packing a copy into a __Tcl\_Obj\*__
     value\. While this is no trouble for structures as small as __vec2__
     larger structures may pose a problem\.

     We will address this in the next section\.

Packages: *[critcl::cutil](critcl\_cutil\.md)*

## <a name='subsection25'></a>Large Structures

  1. Starting from the end of the previous section\.

  1. Edit the file "example\.tcl"\.

  1. Describing each individual change is too complex\. The following is easier\.

  1. Save the file, then replace the entire functionality with the following\.

  1. After that use a __diff__ of your choice to compare the files and see
     the critical changes\.

             critcl::ccode {
         	typedef struct vec2 {
         	    unsigned int rc;
         	    double x;
         	    double y;
         	} vec2;

         	typedef vec2* vec2ptr;

         	/* -- Core vector structure management -- */

         	static vec2ptr Vec2New (double x, double y) {
         	    vec2ptr vec = Tcl_Alloc (sizeof (vec2));
         	    vec->rc = 0;
         	    vec->x = x;
         	    vec->y = y;
         	    return vec;
         	}

         	static vec2ptr Vec2Copy (vec2ptr src) {
         	    scr->rc ++;
         	    return src;
         	}

         	static void Vec2Release (vec2ptr vec) {
         	    if (vec->rc > 1) {
         		vec->rc --;
         		return;
         	    }

         	    Tcl_Free ((char*) vec);
         	}

         	/* -- Vector obj type -- */

         	static void Vec2Free     (Tcl_Obj* obj);
         	static void Vec2StringOf (Tcl_Obj* obj);
         	static void Vec2Dup      (Tcl_Obj* obj, Tcl_Obj* dst);
         	static int  Vec2FromAny  (Tcl_Interp* interp, Tcl_Obj* obj);

         	Tcl_ObjType vec2_objtype = {
         	    "vec2",
         	    Vec2Free,
         	    Vec2Dup,
         	    Vec2StringOf,
         	    Vec2FromAny
         	};

         	static void Vec2Free (Tcl_Obj* obj) {
         	    Vec2Release ((vec2ptr) obj->internalRep.otherValuePtr);
         	}

         	static void Vec2Dup (Tcl_Obj* obj, Tcl_Obj* dst) {
         	    vec2ptr vec = (vec2ptr) obj->internalRep.otherValuePtr;

         	    dst->internalRep.otherValuePtr = Vec2Copy (vec);
         	    dst->typePtr                   = &vec2_objtype;
         	}

         	static void Vec2StringOf (Tcl_Obj* obj) {
         	    vec2ptr vec = (vec2ptr) obj->internalRep.otherValuePtr;

         	    /* Serialize vector data to string (list of two doubles) */
         	    Tcl_DString      ds;
         	    Tcl_DStringInit (&ds);

         	    char buf [TCL_DOUBLE_SPACE];

         	    Tcl_PrintDouble (0, vec->x, buf); Tcl_DStringAppendElement (&ds, buf);
         	    Tcl_PrintDouble (0, vec->y, buf); Tcl_DStringAppendElement (&ds, buf);

         	    int length = Tcl_DStringLength (ds);

         	    /* Set string representation */
         	    obj->length = length;
         	    obj->bytes  = Tcl_Alloc(length+1);
         	    memcpy (obj->bytes, Tcl_DStringValue (ds), length);
         	    obj->bytes[length] = '\0';
         	    /*
         	    ** : package require critcl::cutil ;# get C utilities
         	    ** : critcl::cutil::alloc          ;# Activate allocation utilities
         	    ** : (Internally cheaders, include)
         	    ** : Then all of the above can be written as STREP_DS (obj, ds);
         	    ** : STREP_DS = STRing REP from DString
         	    */

         	    Tcl_DStringFree (&ds);
         	}

         	static int Vec2FromAny (Tcl_Interp* interp, Tcl_Obj* obj) {
         	    /* Change internal rep of obj to vector structure.
         	    ** A Tcl list of 2 doubles is used as intermediary int rep.
         	    */

         	    int len;
         	    if (Tcl_ListObjLength (interp, obj, &len) != TCL_OK) return TCL_ERROR;
         	    if (len != 2) {
         		Tcl_SetObjResult (interp, Tcl_ObjPrintf ("Expected 2 elements, got %d", len));
         		return TCL_ERROR;
         	    }

         	    Tcl_Obj* lv[2];
         	    if (Tcl_ListObjGetElements (interp, obj, &lv) != TCL_OK) return TCL_ERROR;

         	    double x, y;
         	    if (Tcl_GetDoubleFromObj (interp, lv[0], &x) != TCL_OK) return TCL_ERROR;
         	    if (Tcl_GetDoubleFromObj (interp, lv[1], &y) != TCL_OK) return TCL_ERROR;

         	    obj->internalRep.otherValuePtr = (void*) Vec2New (x, y);
         	    obj->typePtr                   = &vec2_objtype;

         	    return TCL_OK;
         	}

         	/* (un)packing structures from/into Tcl values -- */

         	int GetVecFromObj (Tcl_Interp* interp, Tcl_Obj* obj, vec2ptr* vec)
         	{
         	    if (obj->typePtr != &vec2_objtype) {
         		if (VecFromAny (interp, obj) != TCL_OK) return TCL_ERROR;
         	    }

         	    *vec = (vec2ptr) obj->internalRep.otherValuePtr;
         	    return TCL_OK;
         	}

         	Tcl_Obj* NewVecObj (vec2ptr vec) {
         	    Tcl_Obj* obj = Tcl_NewObj ();

         	    Tcl_InvalidateStringRep (obj);

         	    obj->internalRep.otherValuePtr = Vec2Copy (vec);
         	    obj->typePtr                   = &vec2_objtype;

         	    return obj;
         	}
             }

             critcl::argtype vec2 {
         	if (GetVecFromObj (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
             } vec2ptr vec2ptr

             critcl::resulttype vec2 {
         	/* rv: result value of function, interp: current Tcl interpreter */
         	Tcl_SetObjResult (interp, NewVecObj (rv));
         	return TCL_OK;
             } vec2ptr

             critcl::cproc norm {vec2 vector} double {
         	double norm = hypot (vector->x, vector->y);
         	return norm;
             }

             critcl::cproc add {vec2 a vec2 b} vec2 {
         	return Vec2New (a->x + b->x, a->y + b->y);
             }

  1. The __vec2__ structure is now reference counted\.

  1. The core management functions, i\.e\. __Vec2New__, __Vec2Copy__, and
     __Vec2Release__ are changed to maintain that reference count\. Starting
     at __0__ on creation, copies increment, and releases decrement\. A
     structure is actually only freed when its reference count falls to
     __0__ or below\.

  1. __vec2__ results are changed to pointers, easily passed back through
     the stack\. The modified translation layer just wraps it into a
     __Tcl\_Obj\*__ value\.

  1. *Attention*\. Duplicating such a __Tcl\_Obj\*__ does not duplicate the
     referenced __vec2__ structure anymore, just adds a reference\.

  1. Regarding __diff__ commands, I know of two graphical diffs for Tcl/Tk,
     [TkDiff](https://tkdiff\.sourceforge\.io), and
     [Eskil](http://eskil\.tcl\.tk)\.

Packages: *[critcl::cutil](critcl\_cutil\.md)*

## <a name='subsection26'></a>External Structures

  1. Handle structures provided by external libraries using either [Structure
     Types](#subsection24) or [Large Structures](#subsection25) as
     template\.

  1. *Attention*\. The choice is with the developer\.

     This is true even if the external structure is not reference counted by
     itself\.

     To reference count a structure __S__ without such simply wrap __S__
     into a local structure which provides the reference count and has a field
     for __S__ \(pointer or value\)\.

  1. *Attention* Opaque external types, i\.e\. pointers to structures with
     hidden fields, can also be handled by the given templates\.

## <a name='subsection27'></a>External Enumerations

This section demonstrates how to convert from any kind of enumeration provided
by an external library to Tcl strings, and the converse\.

  1. For all that this is a part of how to [Use External
     Libraries](#section3), for the demonstratation only the basics are
     needed\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;package require critcl::emap  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;\# no header included due to use of literal ints instead of symbolic names  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::emap::def yaml\_sequence\_style\_t \{  
     > &nbsp;any   0  
     > &nbsp;block 1  
     > &nbsp;flow  2  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;\# encode: style to int  
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc encode \{yaml\_sequence\_style\_t style\} int \{  
     > &nbsp;return style;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;\# decode: int to style  
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc decode \{int style\} yaml\_sequence\_style\_t \{  
     > &nbsp;return style;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. The map converts between the Tcl level strings listed on the left side to
     the C values on the right side, and the reverse\.

  1. It automatically generates __critcl::argtype__ and
     __critcl::resulttype__ definitions\.

  1. *Attention* Like the default values for __cproc__ arguments, and the
     results for __cconst__ definitions the values on the right side have to
     be proper C rvalues\. They have to match C type __int__\.

     In other words, it is perfectly ok to use the symbolic names provided by
     the header file of the external library\.

     *Attention* This however comes at a loss in efficiency\. As
     *[CriTcl](critcl\.md)* then has no insight into the covered range of
     ints, gaps, etc\. it has to perform a linear search when mapping from C to
     Tcl\. When it knows the exact integer values it can use a table lookup
     instead\.

     *Attention* It also falls back to a search if a lookup table would
     contain more than 50 entries\.

Packages: *[critcl::emap](critcl\_emap\.md)*

## <a name='subsection28'></a>External Bitsets/Bitmaps/Flags

This section demonstrates how to convert from any kind of bit\-mapped flags
provided by an external library to lists of Tcl strings, and the converse\.

  1. For all that this is a part of how to [Use External
     Libraries](#section3), for the demonstratation only the basics are
     needed\.

  1. > &nbsp;Starting from the [Basics](#section2)\.   
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Edit the file "example\.tcl"\.  
     > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove the definition of __hello__\. Replace it with   
     > &nbsp;&nbsp;&nbsp;&nbsp;\# http://man7\.org/linux/man\-pages/man7/inotify\.7\.html  
     > &nbsp;&nbsp;&nbsp;&nbsp;  
     > &nbsp;&nbsp;&nbsp;&nbsp;package require critcl::bitmap  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;\# critcl::cheaders \- n/a, header is in system directories  
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::include sys/inotify\.h  
     > &nbsp;&nbsp;&nbsp;&nbsp;  
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::bitmap::def tcl\_inotify\_events \{  
     > &nbsp;accessed       IN\_ACCESS  
     > &nbsp;all            IN\_ALL\_EVENTS  
     > &nbsp;attribute      IN\_ATTRIB  
     > &nbsp;closed         IN\_CLOSE  
     > &nbsp;closed\-nowrite IN\_CLOSE\_NOWRITE  
     > &nbsp;closed\-write   IN\_CLOSE\_WRITE  
     > &nbsp;created        IN\_CREATE  
     > &nbsp;deleted        IN\_DELETE  
     > &nbsp;deleted\-self   IN\_DELETE\_SELF  
     > &nbsp;dir\-only       IN\_ONLYDIR  
     > &nbsp;dont\-follow    IN\_DONT\_FOLLOW  
     > &nbsp;modified       IN\_MODIFY  
     > &nbsp;move           IN\_MOVE  
     > &nbsp;moved\-from     IN\_MOVED\_FROM  
     > &nbsp;moved\-self     IN\_MOVE\_SELF  
     > &nbsp;moved\-to       IN\_MOVED\_TO  
     > &nbsp;oneshot        IN\_ONESHOT  
     > &nbsp;open           IN\_OPEN  
     > &nbsp;overflow       IN\_Q\_OVERFLOW  
     > &nbsp;unmount        IN\_UNMOUNT  
     > &nbsp;&nbsp;&nbsp;&nbsp;\} \{  
     > &nbsp;all closed move oneshot  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}  
     > &nbsp;&nbsp;&nbsp;&nbsp;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\# encode: flag set to int  
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc encode \{tcl\_inotify\_events e\} int \{  
     > &nbsp;return e;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}  
     >   
     > &nbsp;&nbsp;&nbsp;&nbsp;\# decode: int to flag set  
     > &nbsp;&nbsp;&nbsp;&nbsp;critcl::cproc decode \{int e\} tcl\_inotify\_events \{  
     > &nbsp;return e;  
     > &nbsp;&nbsp;&nbsp;&nbsp;\}

     and rebuild the package\.

  1. The map converts between lists of the Tcl level strings listed on the left
     side to the bit\-union of the C values on the right side, and the reverse\.

     It is noted that the four strings __all__, __closed__,
     __move__, and __oneshot__ cannot be converted from C flags to list
     of strings, only from list to bits\.

  1. It automatically generates __critcl::argtype__ and
     __critcl::resulttype__ definitions\.

  1. *Attention* Like the default values for __cproc__ arguments, and the
     results for __cconst__ definitions the values on the right side have to
     be proper C rvalues\. They have to match C type __int__\.

     In other words, it is perfectly ok to use the symbolic names provided by
     the header file of the external library\. As shown\.

Packages: *[critcl::bitmap](critcl\_bitmap\.md)*

## <a name='subsection29'></a>Non\-standard header/library locations

  1. See and reread the [basic wrapper package](#section3) for the
     introduction of the commands referenced below\.

  1. *Attention* Relative paths will be resolved relative to the location of
     the "\.tcl" file containing the *[CriTcl](critcl\.md)* commands\.

  1. Use the command __critcl::cheaders__ to tell
     *[CriTcl](critcl\.md)* about non\-standard locations for header files\.

     Multiple arguments are allowed, and multiple calls as well\. The information
     accumulates\.

     Arguments of the form "\-Idirectory" register the directory directly\.

     For arguments of the form "path" the directory holding the path is
     registered\. In other words, it is assumed to be the full path of a header
     *file*, and not a directory\.

         critcl::cheaders -I/usr/local/include
         critcl::cheaders local/types.h
         critcl::cheaders other-support/*.h

  1. Use the command __critcl::include__ to actually use a specific header
     file\.

  1. Use the command __critcl::clibraries__ to tell
     *[CriTcl](critcl\.md)* about non\-standard locations for shared
     libaries, and about shared libaries to link to

     Multiple arguments are allowed, and multiple calls as well\. The information
     accumulates\.

     Arguments of the form "\-Ldirectory" register a directory\.

     Arguments of the form "\-lname" register a shared libary to link to by name\.
     The library will be looked for in both standard and registered directories\.

     Arguments of the form "\-path" register a shared libary to link to by full
     path\.

         critcl::clibraries -L/usr/lib/x86_64-linux-gnu
         critcl::clibraries -lzstd
         critcl::clibraries /usr/lib/x86_64-linux-gnu/libzstd.so

  1. On Mac OS X use the command __critcl::framework__ to name the
     frameworks to use in the package\.

     *Attention* Using the command on other platforms is ok, and will be
     ignored\.

  1. Not answered in the above is how to find the necessary paths if they are
     not fixed across machines or platforms\.

     We will come back to this\.

## <a name='subsection30'></a>Non\-standard compile/link configuration

  1. See and reread the [basic wrapper package](#section3) for the
     introduction of the commands referenced below\.

  1. Use the command __critcl::cflags__ to provide additional, non\-standard
     flags to the compiler\.

         critcl::cflags -DBYTE_ORDER=bigendian

  1. Use the command __critcl::ldflags__ to provide additional, non\-standard
     flags to the linker\.

         critcl::ldflags -

  1. Not answered in the above is how to determine such flags if they are not
     fixed across machines or platforms\.

     This is addressed by the next section\.

## <a name='subsection31'></a>Querying the compilation environment

  1. Use the command __critcl::check__ to immediately check if a piece of C
     code can compiled successfully as a means of querying the compiler
     configuration itself\.

         if {[critcl::check {
             #include <FOO.h>
         }]} {
             Do stuff with FOO.h present.
         } else {
             Do stuff without FOO.h
         }

     All header and library paths which were registered with
     *[CriTcl](critcl\.md)* before using __critcl::check__ take part in
     the attempted compilation\.

     Use the package __[critcl::util](critcl\_util\.md)__ and various
     convenience commands it provides\.

  1. Use the full *Power of Tcl \(tm\)* itself\.

## <a name='subsection32'></a>Shared C Code

  1. See and reread the [basic wrapper package](#section3) for the
     introduction of the commands referenced below\.

  1. Use the command __critcl::ccode__ to write C code residing outside of
     __cproc__ bodies\.

  1. Or, alternatively, place the C code into one or more "\.c" files and use the
     command __critcl::csources__ to register them with
     *[CriTcl](critcl\.md)* for compilation\.

  1. This topic is also treated in section [Separating Local C
     Sources](#subsection20)\.

# <a name='section4'></a>Various

## <a name='subsection33'></a>Author, License, Description, Keywords

  1. See and reread the [basic package](#section2) for the introduction of
     the commands referenced below\.

  1. Use the command __critcl::license__ to set the package license\.

     Use the same command to set the package author\.

     Both arguments are free form text\.

  1. Use the command __critcl::summary__ to set a short package description\.

  1. Use the command __critcl::description__ to set a longer package
     description\.

     The arguments of both commands are free form text\.

  1. Use the command __critcl::subject__ to set one or more keywords\.

     *Attention* Contrary to the other commands the arguments accumulate\.

  1. All the commands are optional\.

  1. Their information is not placed into the generated C code\.

  1. In *package mode* the information is placed into the file "teapot\.txt" of
     the generated package\.

  1. This file serves as integration point for *Teapot*, the package system of
     *ActiveTcl*\.

## <a name='subsection34'></a>Get Critcl Application Help

  1. Invoke the command

         critcl -help

     in a terminal to get help about the __[critcl](critcl\.md)__
     application\.

## <a name='subsection35'></a>Supported Targets & Configurations

  1. Invoke the application as

         critcl -show

     in a terminal to get the detailed configuration of the target for the
     current platform\.

  1. Invoke the application as

         critcl -show -target NAME

     in a terminal to get the detailed configuration of the named target\.

  1. Invoke the application as

         critcl -targets

     in a terminal to get a list of the available targets\.

## <a name='subsection36'></a>Building A Package

  1. Start at section [Basics](#section2)\.

## <a name='subsection37'></a>Building A Package For Debugging

  1. Start at section [Basics](#section2)\.

# <a name='section5'></a>Authors

Jean Claude Wippler, Steve Landers, Andreas Kupries

# <a name='section6'></a>Bugs, Ideas, Feedback

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
