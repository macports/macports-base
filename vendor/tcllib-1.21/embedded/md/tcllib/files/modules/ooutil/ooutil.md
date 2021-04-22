
[//000000001]: # (oo::util \- Utility commands for TclOO)
[//000000002]: # (Generated from file 'ooutil\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2015 Andreas Kupries, BSD licensed)
[//000000004]: # (oo::util\(n\) 1\.2\.2 tcllib "Utility commands for TclOO")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

oo::util \- Utility commands for TclOO

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [AUTHORS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require TclOO  
package require oo::util ?1\.2\.2?  

[__mymethod__ *method* ?*arg*\.\.\.?](#1)  
[__classmethod__ *name* *arguments* *body*](#2)  
[__classvariable__ ?*arg*\.\.\.?](#3)  
[__link__ *method*\.\.\.](#4)  
[__link__ \{*alias* *method*\}\.\.\.](#5)  
[__ooutil::singleton__ ?*arg*\.\.\.?](#6)  

# <a name='description'></a>DESCRIPTION

This package provides a convenience command for the easy specification of
instance methods as callback commands, like timers, file events, Tk bindings,
etc\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__mymethod__ *method* ?*arg*\.\.\.?

    This command is available within instance methods\. It takes a method name
    and, possibly, arguments for the method and returns a command prefix which,
    when executed, will invoke the named method of the object we are in, with
    the provided arguments, and any others supplied at the time of actual
    invokation\.

    Note: The command is equivalent to and named after the command provided by
    the OO package __[snit](\.\./snit/snit\.md)__ for the same purpose\.

  - <a name='2'></a>__classmethod__ *name* *arguments* *body*

    This command is available within class definitions\. It takes a method name
    and, possibly, arguments for the method and creates a method on the class,
    available to a user of the class and of derived classes\.

    Note: The command is equivalent to the command __typemethod__ provided
    by the OO package __[snit](\.\./snit/snit\.md)__ for the same purpose\.

    Example

        oo::class create ActiveRecord {
            classmethod find args { puts "[self] called with arguments: $args" }
        }
        oo::class create Table {
            superclass ActiveRecord
        }
        puts [Table find foo bar]
        # ======
        # which will write
        # ======
        # ::Table called with arguments: foo bar

  - <a name='3'></a>__classvariable__ ?*arg*\.\.\.?

    This command is available within instance methods\. It takes a series of
    variable names and makes them available in the method's scope\. The
    originating scope for the variables is the class \(instance\) the object
    instance belongs to\. In other words, the referenced variables are shared
    between all instances of their class\.

    Note: The command is roughly equivalent to the command __typevariable__
    provided by the OO package __[snit](\.\./snit/snit\.md)__ for the same
    purpose\. The difference is that it cannot be used in the class definition
    itself\.

    Example:

        % oo::class create Foo {
            method bar {z} {
                classvariable x y
                return [incr x $z],[incr y]
            }
        }
        ::Foo
        % Foo create a
        ::a
        % Foo create b
        ::b
        % a bar 2
        2,1
        % a bar 3
        5,2
        % b bar 7
        12,3
        % b bar -1
        11,4
        % a bar 0
        11,5

  - <a name='4'></a>__link__ *method*\.\.\.

  - <a name='5'></a>__link__ \{*alias* *method*\}\.\.\.

    This command is available within instance methods\. It takes a list of method
    names and/or pairs of alias\- and method\-name and makes the named methods
    available to all instance methods without requiring the __my__ command\.

    The alias name under which the method becomes available defaults to the
    method name, except where explicitly specified through an alias/method pair\.

    Examples:

        link foo
        # The method foo is now directly accessible as foo instead of my foo.

        link {bar foo}
        # The method foo is now directly accessible as bar.

        link a b c
        # The methods a, b, and c all become directly acessible under their
        # own names.

    The main use of this command is expected to be in instance constructors, for
    convenience, or to set up some methods for use in a mini DSL\.

  - <a name='6'></a>__ooutil::singleton__ ?*arg*\.\.\.?

    This command is a meta\-class, i\.e\. a variant of the builtin
    __oo::class__ which ensures that it creates only a single instance of
    the classes defined with it\.

    Syntax and results are like for __oo::class__\.

    Example:

        % oo::class create example {
           self mixin singleton
           method foo {} {self}
        }
        ::example
        % [example new] foo
        ::oo::Obj22
        % [example new] foo
        ::oo::Obj22

# <a name='section3'></a>AUTHORS

Donal Fellows, Andreas Kupries

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *oo::util* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[snit\(n\)](\.\./snit/snit\.md)

# <a name='keywords'></a>KEYWORDS

[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo),
[callback](\.\./\.\./\.\./\.\./index\.md\#callback), [class
methods](\.\./\.\./\.\./\.\./index\.md\#class\_methods), [class
variables](\.\./\.\./\.\./\.\./index\.md\#class\_variables), [command
prefix](\.\./\.\./\.\./\.\./index\.md\#command\_prefix),
[currying](\.\./\.\./\.\./\.\./index\.md\#currying), [method
reference](\.\./\.\./\.\./\.\./index\.md\#method\_reference), [my
method](\.\./\.\./\.\./\.\./index\.md\#my\_method),
[singleton](\.\./\.\./\.\./\.\./index\.md\#singleton)

# <a name='category'></a>CATEGORY

Utility

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011\-2015 Andreas Kupries, BSD licensed
