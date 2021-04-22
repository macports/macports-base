
[//000000001]: # (grammar::me::cpu::gasm \- Grammar operations and usage)
[//000000002]: # (Generated from file 'gasm\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::me::cpu::gasm\(n\) 0\.1 tcllib "Grammar operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::me::cpu::gasm \- ME assembler

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [DEFINITIONS](#section2)

  - [API](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require grammar::me::cpu::gasm ?0\.1?  

[__::grammar::me::cpu::gasm::begin__ *g* *n* ?*mode*? ?*note*?](#1)  
[__::grammar::me::cpu::gasm::done__ __\-\->__ *t*](#2)  
[__::grammar::me::cpu::gasm::state__](#3)  
[__::grammar::me::cpu::gasm::state\!__ *s*](#4)  
[__::grammar::me::cpu::gasm::lift__ *t* *dst* __=__ *src*](#5)  
[__::grammar::me::cpu::gasm::Inline__ *t* *node* *label*](#6)  
[__::grammar::me::cpu::gasm::Cmd__ *cmd* ?*arg*\.\.\.?](#7)  
[__::grammar::me::cpu::gasm::Bra__](#8)  
[__::grammar::me::cpu::gasm::Nop__ *text*](#9)  
[__::grammar::me::cpu::gasm::Note__ *text*](#10)  
[__::grammar::me::cpu::gasm::Jmp__ *label*](#11)  
[__::grammar::me::cpu::gasm::Exit__](#12)  
[__::grammar::me::cpu::gasm::Who__ *label*](#13)  
[__::grammar::me::cpu::gasm::/Label__ *name*](#14)  
[__::grammar::me::cpu::gasm::/Clear__](#15)  
[__::grammar::me::cpu::gasm::/Ok__](#16)  
[__::grammar::me::cpu::gasm::/Fail__](#17)  
[__::grammar::me::cpu::gasm::/At__ *name*](#18)  
[__::grammar::me::cpu::gasm::/CloseLoop__](#19)  

# <a name='description'></a>DESCRIPTION

This package provides a simple in\-memory assembler\. Its origin is that of a
support package for use by packages converting PEG and other grammars into a
corresponding matcher based on the ME virtual machine, like
__page::compiler::peg::mecpu__\. Despite that it is actually mostly agnostic
regarding the instructions, users can choose any instruction set they like\.

The program under construction is held in a graph structure \(See package
__[struct::graph](\.\./struct/graph\.md)__\) during assembly and subsequent
manipulation, with instructions represented by nodes, and the flow of execution
between instructions explicitly encoded in the arcs between them\.

In this model jumps are not encoded explicitly, they are implicit in the arcs\.
The generation of explicit jumps is left to any code converting the graph
structure into a more conventional representation\. The same goes for branches\.
They are implicitly encoded by all instructions which have two outgoing arcs,
whereas all other instructions have only one outgoing arc\. Their conditonality
is handled by tagging their outgoing arcs with information about the conditions
under which they are taken\.

While the graph the assembler operates on is supplied from the outside, i\.e\.
external, it does manage some internal state, namely:

  1. The handle of the graph node most assembler operations will work on, the
     *anchor*\.

  1. A mapping from arbitrary strings to instructions\. I\.e\. it is possible to
     *label* an instruction during assembly, and later recall that instruction
     by its label\.

  1. The condition code to use when creating arcs between instructions, which is
     one of __always__, __ok__, and __fail__\.

  1. The current operation mode, one of __halt__, __okfail__, and
     __\!okfail__\.

  1. The name of a node in a tree\. This, and the operation mode above are the
     parts most heavily influenced by the needs of a grammar compiler, as they
     assume some basic program structures \(selected through the operation mode\),
     and intertwine the graph with a tree, like the AST for the grammar to be
     compiled\.

# <a name='section2'></a>DEFINITIONS

As the graph the assembler is operating on, and the tree it is intertwined with,
are supplied to the assembler from the outside it is necessary to specify the
API expected from them, and to describe the structures expected and/or generated
by the assembler in either\.

  1. Any graph object command used by the assembler has to provide the API as
     specified in the documentation for the package
     __[struct::graph](\.\./struct/graph\.md)__\.

  1. Any tree object command used by the assembler has to provide the API as
     specified in the documentation for the package
     __[struct::tree](\.\./struct/struct\_tree\.md)__\.

  1. Any instruction \(node\) generated by the assembler in a graph will have at
     least two, and at most three attributes:

       - __instruction__

         The value of this attribute is the name of the instruction\. The only
         names currently defined by the assembler are the three
         pseudo\-instructions

           * __NOP__

             This instruction does nothing\. Useful for fixed framework nodes,
             unchanging jump destinations, and the like\. No arguments\.

           * __C__

             A \.NOP to allow the insertion of arbitrary comments into the
             instruction stream, i\.e\. a comment node\. One argument, the text of
             the comment\.

           * __BRA__

             A \.NOP serving as explicitly coded conditional branch\. No
             arguments\.

         However we reserve the space of all instructions whose names begin with
         a "\." \(dot\) for future use by the assembler\.

       - __arguments__

         The value of this attribute is a list of strings, the arguments of the
         instruction\. The contents are dependent on the actual instruction and
         the assembler doesn't know or care about them\. This means for example
         that it has no builtin knowledge about what instruction need which
         arguments and thus doesn't perform any type of checking\.

       - __expr__

         This attribute is optional\. When it is present its value is the name of
         a node in the tree intertwined with the graph\.

  1. Any arc between two instructions will have one attribute:

       - __condition__

         The value of this attribute determines under which condition execution
         will take this arc\. It is one of __always__, __ok__, and
         __fail__\. The first condition is used for all arcs which are the
         single outgoing arc of an instruction\. The other two are used for the
         two outgoing arcs of an instruction which implicitly encode a branch\.

  1. A tree node given to the assembler for cross\-referencing will be written to
     and given the following attributes, some fixed, some dependent on the
     operation mode\. All values will be references to nodes in the instruction
     graph\. Some of the instruction will expect some or specific sets of these
     attributes\.

       - __gas::entry__

         Always written\.

       - __gas::exit__

         Written for all modes but __okfail__\.

       - __gas::exit::ok__

         Written for mode __okfail__\.

       - __gas::exit::fail__

         Written for mode __okfail__\.

# <a name='section3'></a>API

  - <a name='1'></a>__::grammar::me::cpu::gasm::begin__ *g* *n* ?*mode*? ?*note*?

    This command starts the assembly of an instruction sequence, and
    \(re\)initializes the state of the assembler\. After completion of the
    instruction sequence use __::grammar::me::cpu::gasm::done__ to finalize
    the assembler\.

    It will operate on the graph *g* in the specified *mode* \(Default is
    __okfail__\)\. As part of the initialization it will always create a
    standard \.NOP instruction and label it "entry"\. The creation of the
    remaining standard instructions is *mode*\-dependent:

      * __halt__

        An "icf\_halt" instruction labeled "exit/return"\.

      * __\!okfail__

        An "icf\_ntreturn" instruction labeled "exit/return"\.

      * __okfail__

        Two \.NOP instructions labeled "exit/ok" and "exit/fail" respectively\.

    The *note*, if specified \(default is not\), is given to the "entry" \.NOP
    instruction\.

    The node reference *n* is simply stored for use by
    __::grammar::me::cpu::gasm::done__\. It has to refer to a node in the
    tree *t* argument of that command\.

    After the initialization is done the "entry" instruction will be the
    *anchor*, and the condition code will be set to __always__\.

    The command returns the empy string as its result\.

  - <a name='2'></a>__::grammar::me::cpu::gasm::done__ __\-\->__ *t*

    This command finalizes the creation of an instruction sequence and then
    clears the state of the assembler\. *NOTE* that this *does not* delete
    any of the created instructions\. They can be made available to future
    begin/done cycles\. Further assembly will be possible only after
    reinitialization of the system via __::grammar::me::cpu::gasm::begin__\.

    Before the state is cleared selected references to selected instructions
    will be written to attributes of the node *n* in the tree *t*\. Which
    instructions are saved is *mode*\-dependent\. Both *mode* and the
    destination node *n* were specified during invokation of
    __::grammar::me::cpu::gasm::begin__\.

    Independent of the mode a reference to the instruction labeled "entry" will
    be saved to the attribute __gas::entry__ of *n*\. The reference to the
    node *n* will further be saved into the attribute "expr" of the "entry"
    instruction\. Beyond that

      * __halt__

        A reference to the instruction labeled "exit/return" will be saved to
        the attribute __gas::exit__ of *n*\.

      * __okfail__

        See __halt__\.

      * __\!okfail__

        Reference to the two instructions labeled "exit/ok" and "exit/fail" will
        be saved to the attributes __gas::exit::ok__ and
        __gas::exit::fail__ of *n* respectively\.

    The command returns the empy string as its result\.

  - <a name='3'></a>__::grammar::me::cpu::gasm::state__

    This command returns the current state of the assembler\. Its format is not
    documented and considered to be internal to the package\.

  - <a name='4'></a>__::grammar::me::cpu::gasm::state\!__ *s*

    This command takes a serialized assembler state *s* as returned by
    __::grammar::me::cpu::gasm::state__ and makes it the current state of
    the assembler\.

    *Note* that this may overwrite label definitions, however all
    non\-conflicting label definitions in the state before are not touched and
    merged with *s*\.

    The command returns the empty string as its result\.

  - <a name='5'></a>__::grammar::me::cpu::gasm::lift__ *t* *dst* __=__ *src*

    This command operates on the tree *t*\. It copies the contents of the
    attributes __gas::entry__, __gas::exit::ok__ and
    __gas::exit::fail__ from the node *src* to the node *dst*\. It
    returns the empty string as its result\.

  - <a name='6'></a>__::grammar::me::cpu::gasm::Inline__ *t* *node* *label*

    This command links an instruction sequence created by an earlier begin/done
    pair into the current instruction sequence\.

    To this end it

      1. reads the instruction references from the attributes
         __gas::entry__, __gas::exit::ok__, and __gas::exit::fail__
         from the node *n* of the tree *t* and makes them available to
         assembler und the labels *label*/entry, *label*/exit::ok, and
         *label*/exit::fail respectively\.

      1. Creates an arc from the *anchor* to the node labeled *label*/entry,
         and tags it with the current condition code\.

      1. Makes the node labeled *label*/exit/ok the new *anchor*\.

    The command returns the empty string as its result\.

  - <a name='7'></a>__::grammar::me::cpu::gasm::Cmd__ *cmd* ?*arg*\.\.\.?

    This is the basic command to add instructions to the graph\. It creates a new
    instruction of type *cmd* with the given arguments *arg*\.\.\. If the
    *anchor* was defined it will also create an arc from the *anchor* to the
    new instruction using the current condition code\. After the call the new
    instruction will be the *anchor* and the current condition code will be
    set to __always__\.

    The command returns the empty string as its result\.

  - <a name='8'></a>__::grammar::me::cpu::gasm::Bra__

    This is a convenience command to create a \.BRA pseudo\-instruction\. It uses
    __::grammar::me::cpu::gasm::Cmd__ to actually create the instruction and
    inherits its behaviour\.

  - <a name='9'></a>__::grammar::me::cpu::gasm::Nop__ *text*

    This is a convenience command to create a \.NOP pseudo\-instruction\. It uses
    __::grammar::me::cpu::gasm::Cmd__ to actually create the instruction and
    inherits its behaviour\. The *text* will be saved as the first and only
    argument of the new instruction\.

  - <a name='10'></a>__::grammar::me::cpu::gasm::Note__ *text*

    This is a convenience command to create a \.C pseudo\-instruction, i\.e\. a
    comment\. It uses __::grammar::me::cpu::gasm::Cmd__ to actually create
    the instruction and inherits its behaviour\. The *text* will be saved as
    the first and only argument of the new instruction\.

  - <a name='11'></a>__::grammar::me::cpu::gasm::Jmp__ *label*

    This command creates an arc from the *anchor* to the instruction labeled
    with *label*, and tags with the the current condition code\.

    The command returns the empty string as its result\.

  - <a name='12'></a>__::grammar::me::cpu::gasm::Exit__

    This command creates an arc from the *anchor* to one of the exit
    instructions, based on the operation mode \(see
    __::grammar::me::cpu::gasm::begin__\), and tags it with current condition
    code\.

    For mode __okfail__ it links to the instruction labeled either "exit/ok"
    or "exit/fail", depending on the current condition code, and tagging it with
    the current condition code For the other two modes it links to the
    instruction labeled "exit/return", tagging it condition code __always__,
    independent the current condition code\.

    The command returns the empty string as its result\.

  - <a name='13'></a>__::grammar::me::cpu::gasm::Who__ *label*

    This command returns a reference to the instruction labeled with *label*\.

  - <a name='14'></a>__::grammar::me::cpu::gasm::/Label__ *name*

    This command labels the *anchor* with *name*\. *Note* that an
    instruction can have more than one label\.

    The command returns the empty string as its result\.

  - <a name='15'></a>__::grammar::me::cpu::gasm::/Clear__

    This command clears the *anchor*, leaving it undefined, and further resets
    the current condition code to __always__\.

    The command returns the empty string as its result\.

  - <a name='16'></a>__::grammar::me::cpu::gasm::/Ok__

    This command sets the current condition code to __ok__\.

    The command returns the empty string as its result\.

  - <a name='17'></a>__::grammar::me::cpu::gasm::/Fail__

    This command sets the current condition code to __fail__\.

    The command returns the empty string as its result\.

  - <a name='18'></a>__::grammar::me::cpu::gasm::/At__ *name*

    This command sets the *anchor* to the instruction labeled with *name*,
    and further resets the current condition code to __always__\.

    The command returns the empty string as its result\.

  - <a name='19'></a>__::grammar::me::cpu::gasm::/CloseLoop__

    This command marks the *anchor* as the last instruction in a loop body, by
    creating the attribute __LOOP__\.

    The command returns the empty string as its result\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *grammar\_me* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[assembler](\.\./\.\./\.\./\.\./index\.md\#assembler),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[graph](\.\./\.\./\.\./\.\./index\.md\#graph),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[tree](\.\./\.\./\.\./\.\./index\.md\#tree), [virtual
machine](\.\./\.\./\.\./\.\./index\.md\#virtual\_machine)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
