
[//000000001]: # (tepam::procedure \- Tcl's Enhanced Procedure and Argument Manager)
[//000000002]: # (Generated from file 'tepam\_procedure\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2013, Andreas Drollinger)
[//000000004]: # (tepam::procedure\(n\) 0\.5\.0 tcllib "Tcl's Enhanced Procedure and Argument Manager")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tepam::procedure \- TEPAM procedure, reference manual

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [TERMINOLOGY](#section2)

  - [PROCEDURE DECLARATION](#section3)

      - [Procedure Attributes](#subsection1)

      - [Argument Declaration](#subsection2)

  - [VARIABLES](#section4)

  - [ARGUMENT TYPES](#section5)

      - [Predefined Argument Types](#subsection3)

      - [Defining Application Specific Argument Types](#subsection4)

  - [PROCEDURE CALLS](#section6)

      - [Help](#subsection5)

      - [Interactive Procedure Call](#subsection6)

      - [Unnamed Arguments](#subsection7)

      - [Named Arguments](#subsection8)

      - [Unnamed Arguments First, Named Arguments Later \(Tk
        Style\)](#subsection9)

      - [Named Arguments First, Unnamed Arguments Later \(Tcl
        Style\)](#subsection10)

      - [Raw Argument List](#subsection11)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require tepam ?0\.5?  

[__tepam::procedure__ *name* *attributes* *body*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides an alternative way to declare Tcl procedures and to manage
its arguments\. There is a lot of benefit to declare a procedure with TEPAM
rather than with the Tcl standard command __proc__: TEPAM allows specifying
inside the procedure declaration all information that is required to generate
comprehensive documentations and help support\. The information is also used by
an automatically invoked argument checker that validates the provided procedure
arguments before the procedure body is executed\. Finally, a procedure can be
called interactively which will open a graphical form that allows specifying the
procedure arguments\.

TEPAM simplifies also the handling of the different types of argument, like the
*named arguments* \(often also called *options*\) and the *unnamed
arguments*\. TEPAM supports the *named first, unnamed later* style \(typical
Tcl command style\) as well as also the *unnamed first, named later* style
\(typical Tk command style\)\. TEPAM takes care about default values for arguments,
optional arguments, multiple applicable arguments, etc\. and eliminates the need
to check the validity of the argument inside the procedure bodies\.

An informal overview of all the TEPAM procedure declaration and calling features
as well as a short introduction into TEPAM is provided by *tepam\(n\)*\.

# <a name='section2'></a>TERMINOLOGY

The exact meaning of several terms that are used in this document will be
shortly explained to avoid any ambiguities and misunderstandings\.

  - *Subcommand*

    The usage of subcommands is heavily used in the Tcl language\. Several
    commands are incorporated into a single main command and are selectable via
    the first argument\.

    The __string__ command is an example of such a command that implements
    for example subcommands to check a character string length, to compare
    strings, to extract substrings, etc:

    > __string length__ *string*  
    > __string compare__ *string* *string*  
    > __string range__ *string* *first* *last*  
    > \.\.\.

    TEPAM provides a framework that allows implementing easily such subcommands
    in form of Tcl procedures\. It allows not only defining a first level of
    subcommands, but also a higher level of subcommands\. The __string__
    command class check could be implemented as independent sub\-sub\-commands of
    the __string__ command:

    > __string is alnum__ *string*  
    > __string is integer__ *string*  
    > __string is double__ *string*  
    > \.\.\.

  - *Procedure attribute*

    TEPAM allows attaching to a declared procedure different kind of attributes\.
    Some of these attributes are *just* used for documentation purposes, but
    other attributes specify the way how the procedure has to be called\. Also
    the procedure arguments are defined in form of a procedure attribute\.

  - *Argument*

    TEPAM uses the term *argument* for the parameters of a procedure\.

    The following example calls the subcommand __string compare__ with
    several arguments:

    > __string compare__ *\-nocase \-length 3 "emphasized" "emphasised"*

    The following paragraphs discuss these different argument types\.

  - *Named argument*

    Some parameters, as *\-length 3* of the subcommand __string compare__
    have to be provided as pairs of argument names and argument values\. This
    parameter type is often also called *option*\.

    TEPAM uses the term *named argument* for such options as well as for the
    flags \(see next item\)\.

  - *Flag, switch*

    Another parameter type is the *flag* or the *switch*\. Flags are provided
    simply by naming the flag leading with the '\-' character\. The *\-nocase* of
    the previous __string compare__ example is such a flag\.

    *Flags* are considered by TEPAM like a special form of *named
    arguments*\.

  - *Unnamed argument*

    For the other parameters, e\.g\. the ones for which the argument name has not
    to be mentioned, TEPAM uses the term *unnamed argument*\. The previous
    __string compare__ example uses for the two provided character strings
    two *unnamed arguments*\.

  - *Argument attribute*

    TEPAM allows describing the purpose of each procedure argument with
    *argument attributes*\. While some of them are just documenting the
    attributes, most attributes are used by an argument manager to control and
    validate the arguments that are provided during a procedure call\. Argument
    attributes are used to specify default values, parameter classes \(integer,
    xdigit, font, \.\.\.\), choice validation lists, value ranges, etc\.

  - *Named arguments first, unnamed arguments later*

    The __string compare__ command of the previous example requires that the
    *named arguments* \(options, flags\) are provided first\. The two mandatory
    \(unnamed\) arguments have to be provided as last argument\.

    > __string compare__ *\-nocase \-length 3 Water $Text*

    This is the usual Tcl style \(exceptions exist\) which is referred in the
    TEPAM documentation as *named arguments first, unnamed arguments later
    style*\.

  - *Unnamed arguments first, named arguments later*

    In contrast to most Tcl commands, Tk uses generally \(exceptions exist also
    here\) a different calling style where the *unnamed arguments* have to be
    provided first, before the *named arguments* have to be provided:

    > __pack__ *\.ent1 \.ent2 \-fill x \-expand yes \-side left*

    This style is referred in the TEPAM documentation as *unnamed arguments
    first, named arguments later style*\.

# <a name='section3'></a>PROCEDURE DECLARATION

TEPAM allows declaring new Tcl procedures with the command
__tepam::procedure__ that has similar to the standard Tcl command
__proc__ also 3 arguments:

  - <a name='1'></a>__tepam::procedure__ *name* *attributes* *body*

The TEPAM procedure declaration syntax is demonstrated by the following example:

> __tepam::procedure__ \{display message\} \{  
> &nbsp;&nbsp;&nbsp;\-short\_description  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Displays a simple message box"  
> &nbsp;&nbsp;&nbsp;\-description  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"This procedure allows displaying a configurable\\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;message box\. The default message type that is\\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;created is a warning, but also errors and info can\\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;be generated\.  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The procedure accepts multiple text lines\."  
> &nbsp;&nbsp;&nbsp;\-example  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{display message \-mtype Warning "Save first your job"\}  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-mtype \-choices \{Info Warning Error\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-default Warning \-description "Message type"\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{text   \-type string \-multiple \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-description "Multiple text lines to display"\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts "Message type: $mtype"  
> &nbsp;&nbsp;&nbsp;puts "Message: $text"  
> \}

The 3 arguments of __procedure__ are:

  - *name*

    The procedure name can be used in very flexible ways\. Procedure names can
    have namespace qualifiers\. By providing a two element name list as procedure
    name, a subcommand of a procedure will be declared\. It is even possible to
    declare sub\-sub\-commands of a procedure by providing name lists with three
    elements\.

    Here are some valid procedure declarations using different procedure names
    \(the attribute and body arguments are empty for simplicity\):

> *\# Simple procedure name:*  
> tepam::procedure __display\_message__ \{\} \{\}  
> **  
> *\# Procedure declared in the main namespace:*  
> tepam::procedure __::display\_message__ \{\} \{\}  
> **  
> *\# Procedure in the namespace* __::ns__*:*  
> tepam::procedure __::ns::display\_message__ \{\} \{\}  
> **  
> *\# Declaration of the subcommand* __message__ *of the procedure* __display__*:*  
> tepam::procedure __\{display message\}__ \{\} \{\}

  - *attributes*

    All procedure attributes are provided in form of an option list that
    contains pairs of option names and option values\. The example above has as
    procedure attribute a short and a normal description, but also the procedure
    arguments are defined in form of a procedure attribute\.

    Most procedure attributes are providing information for documentation
    purposes\. But some of them affect also the way how the procedure can be
    called\. The section [Procedure Attributes](#subsection1) discusses in
    detail the available procedure attributes\.

    The procedure arguments are defined in form of a special procedure
    attribute\. Most of the information provided in the argument definition is
    not just used for documentation purposes\. This information is in fact used
    by the TEPAM argument manager to handle and validate the various forms of
    arguments that are provided during the procedure calls\. The section
    [Argument Declaration](#subsection2) discusses in detail all the
    argument definition attributes\.

  - *body*

    This is the normal procedure body\. The declared arguments will be available
    to the procedure body in form of variables\.

    The procedure body will only be executed if the provided set of arguments
    could be validated by the TEPAM argument manager\.

> tepam::procedure \{display\_message\} \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-__mtype__ \-default Warning \-choices \{Warning Error\}\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{__text__ \-type string\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts "Message type: __$mtype__"  
> &nbsp;&nbsp;&nbsp;puts "Message: __$text__"  
> \}

The commands __[procedure](\.\./\.\./\.\./\.\./index\.md\#procedure)__ as well as
__argument\_dialogbox__ are exported from the namespace __tepam__\. To use
these commands without the __tepam::__ namespace prefix, it is sufficient to
import them into the main namespace:

> __namespace import tepam::\*__  
>   
> __[procedure](\.\./\.\./\.\./\.\./index\.md\#procedure)__ \{display\_message\} \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\.\.\.

## <a name='subsection1'></a>Procedure Attributes

The first group of attributes affect the behavior of the declared procedure:

  - \-named\_arguments\_first __0__&#124;__1__

    This attribute defines the calling style of a procedure\. TEPAM uses by
    default the *named arguments first, unnamed arguments later* style \(Tcl\)\.
    This default behavior can globally be changed by setting the variable
    __tepam::named\_arguments\_first__ to __0__\. This global calling style
    can be changed individually for a procedure with the
    *\-named\_arguments\_first* attribute\.

  - \-auto\_argument\_name\_completion __0__&#124;__1__

    The declared procedures will by default automatically try to match
    eventually abbreviated argument names to the defined arguments names\. This
    default behavior can globally be changed by setting the variable
    __tepam::auto\_argument\_name\_completion__ to __0__\. This global
    setting of the automatic argument name completion can be changed
    individually for a procedure with the *\-auto\_argument\_name\_completion*
    procedure attribute\.

  - \-interactive\_display\_format __extended__&#124;__short__

    A procedure declared with the TEPAM __procedure__ command can always be
    called with the __\-interactive__ option\. By doing so, a graphical form
    will be generated that allows specifying all procedure argument values\.
    There are two display modes for these interactive forms\. While the
    *extended* mode is more adapted for small procedure argument sets, the
    __short__ form is more adequate for huge procedure argument sets\.

    The choice to use short or extended forms can be globally configured via the
    variable __tepam::interactive\_display\_format__\. This global setting can
    then be changed individually for a procedure with the
    *\-interactive\_display\_format* procedure attribute\.

  - \-args *list*

    The procedure arguments are declared via the *\-args* attribute\. An
    argument is defined via a list having as first element the argument name,
    followed by eventual argument attributes\. All these argument definition
    lists are packaged themselves into a global list that is assigned to the
    *\-args* attribute\.

    The argument definition syntax will be described more in detail in the
    following sub section\.

The next attributes allow specifying custom argument checks as well as custom
error messages in case these checks are failing:

  - \-validatecommand *script*

    Custom argument validations can be performed via specific validation
    commands that are defined with the *\-validatecommand* attribute\.

    Validation command declaration example:

> tepam::procedure \{display\_message\} \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{text \-type string \-description "Message text"\} \}  
> &nbsp;&nbsp;&nbsp;__\-validatecommand \{IllegalWordDetector $text\}__  
> \} \{  
> \}

    The validation command is executed in the context of the declared procedure
    body\. The different argument values are accessed via the argument names\.
    Note there is also an argument attribute *\-validatecommand* that allows
    declaring custom checks for specific arguments\.

    The attribute *\-validatecommand* can be repeated to declare multiple
    custom checks\.

  - \-validatecommand\_error\_text *string*

    This attribute allows overriding the default error message for a custom
    argument validation \(defined by *\-validatecommand*\)\. Also this attribute
    can be repeated in case multiple argument checks are declared\.

The following attribute allows controlling the logging settings for an
individual procedure:

  - \-command\_log __0__&#124;__1__&#124;__"interactive"__

    This argument configures the logging of the procedure calls into the list
    variable __tepam::ProcedureCallLogList__\. The default configuration
    defined by the variable __tepam::command\_log__ will be used if this
    argument is not defined in a procedure declaration\.

    Setting this argument to __0__ will disable any procedure call loggings,
    setting it to __1__ will log any procedure calls and setting it to
    __interactive__ will log just the procedures that are called
    interactively \(procedures called with the __\-interactive__ flag\)\.

The next group of procedure attributes is just used for the purpose of
documentation and help text generation:

  - \-category *string*

    A category can be assigned to a procedure for documentation purposes\. Any
    string is accepted as category\.

  - \-short\_description *string*

    The short description of a procedure is used in the documentation summary of
    a generated procedure list as well as in the NAME section of a generated
    procedure manual page\.

  - \-description *string*

    The \(full\) description assigned to a procedure is used to create user manual
    and help pages\.

  - \-return *string*

    The *\-return* attribute allows defining the expected return value of a
    procedure \(used for documentation purposes\)\.

  - \-example *string*

    A help text or manual page of a procedure can be enriched with eventual
    examples, using the *\-example* attribute\.

## <a name='subsection2'></a>Argument Declaration

The following example shows the structure that is used for the argument
definitions in the context of a procedure declaration:

> tepam::procedure \{display\_message\} \{  
> &nbsp;&nbsp;&nbsp;\-args __\{__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\-mtype \-default Warning \-choices \{Info Warning Error\} \-description "Message type"\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\-font \-type font \-default \{Arial 10 italic\} \-description "Message text font"\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\-level \-type integer \-optional \-range \{1 10\} \-description "Message level"\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\-fg \-type color \-optional \-description "Message color"\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\-log\_file \-type file \-optional \-description "Optional message log file"\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{text \-type string \-multiple \-description "Multiple text lines to display"\}__  
> &nbsp;&nbsp;&nbsp;__\}__  
>   
> \} \{  
> \}

Each of the procedure arguments is declared with a list that has as first
element the argument name, followed by eventual attributes\. The argument
definition syntax can be formalized in the following way:

> tepam::procedure <name> \{  
> &nbsp;&nbsp;&nbsp;\-args __\{__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{<argument\_name\_1> <arg\_attr\_name\_1a> <arg\_attr\_value\_1a>  <arg\_attr\_name\_1b> <arg\_attr\_value\_1b> \.\.\.\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{<argument\_name\_2> <arg\_attr\_name\_2a> <arg\_attr\_value\_2a>  <arg\_attr\_name\_2b> <arg\_attr\_value\_2b> \.\.\.\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\.\.\.__  
> &nbsp;&nbsp;&nbsp;__\}__  
>   
> \} <body>

The argument names and attributes have to be used in the following way:

  - Argument name \(*<argument\_name\_<n>>*\)

    The provided argument name specifies whether the argument is an *unnamed
    argument* or a *named argument*\. In addition to this, an argument name
    can also be blank to indicate an argument comment, or it can start with \# to
    indicate a section comment\.

      * *"<Name>"*

        This is the simplest form of an argument name: An argument whose name is
        not starting with '\-' is an *unnamed argument*\. The parameter provided
        during a procedure call will be assigned to a variable with the name
        *<Name>*\.

> tepam::procedure \{print\_string\} \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{__[text](\.\./\.\./\.\./\.\./index\.md\#text)__ \-type string \-description "This is an unnamed argument"\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts __$text__  
> \}  
>   
> print\_string __"Hello"__  
> &nbsp;*\-> Hello*

      * *"\-<Name>"*

        An argument whose name starts with '\-' is a *named argument* \(also
        called *option*\)\. The parameter provided during a procedure call will
        be assigned to a variable with the name *<Name>* \(not *\-<Name>*\)\.

> tepam::procedure \{print\_string\} \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{__\-text__ \-type string \-description "This is a named argument"\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts __$text__  
> \}  
>   
> print\_string __\-text "Hello"__  
> &nbsp;*\-> Hello*

      * *"\-\-"*

        This flag allows clearly specifying the end of the named arguments and
        the beginning of the unnamed arguments, in case the *named arguments
        first, unnamed arguments later style \(Tcl\)* has been selected\.

        If the *unnamed arguments first, named arguments later style \(Tk\)*
        style is selected, this flag is ignored if the unnamed arguments have
        already been parsed\. Otherwise it will be assigned to the corresponding
        unnamed argument\.

      * *"\-"* or *""*

        A blank argument name \(either '\-' or *''*\) starts a comment for the
        following arguments\.

> tepam::procedure \{print\_time\} \{  
> &nbsp;&nbsp;&nbsp;\-interactive\_display\_format short  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{hours \-type integer \-description "Hour"\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{minutes \-type integer \-description "Minute"\}  
>   
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\- The following arguments are optional:\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{seconds \-type integer \-default 0 \-description "Seconds"\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{milliseconds \-type integer \-default 0 \-description "Milliseconds"\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts "$\{hour\}h$\{minutes\}:\[expr $seconds\+0\.001\*$milliseconds\]"  
> \}

        Argument comments are basically used in the graphical argument
        definition forms that are created if a procedure is called
        interactively\.

      * *"\#\*"*

        An argument definition list that starts with '\#' is considered as a
        section comment\. The argument definition list will be trimmed from the
        '\#' characters and the remaining string will be used as section comment\.

        Section comments can be used to structure visually the argument
        definition code\. Section comments are also used to structure the
        generated help texts and the interactive argument definition forms\.

> tepam::procedure \{complex\_multiply\} \{  
> &nbsp;&nbsp;&nbsp;\-description "This function perform a complex multiplication"  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\#\#\#\# First complex number \#\#\#\#\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-r0 \-type double \-description "First number real part"\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-i0 \-type double \-description "First number imaginary part"\}  
>   
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\#\#\#\# Second complex number \#\#\#\#\}__  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-r1 \-type double \-description "Second number real part"\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-i1 \-type double \-description "Second number imaginary part"\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;return \[expr $r0\*$r1 \- $i0\*$i1\]  
> \}

  - Argument attributes \(*<arg\_attr\_name\_<mn>> <arg\_attr\_value\_<mn>>*\)

    The following argument attributes are supported:

      * \-description *string*

        The description argument attribute is used for documentation purpose\.
        Interactive argument definition forms use this attribute to provide
        explanations for an argument\.

      * \-type *type*

        The type argument attribute allows assigning the argument either to a
        predefined data type, or to an application specific data type\. The
        argument values that are provided during a procedure call are
        automatically checked with respect to the defined argument type\.

        The section [ARGUMENT TYPES](#section5) provides a list of
        predefined data types and explains how application specific types can be
        specified\.

        The argument type *none* has a special meaning\. An argument that has
        the type *none* is handled as a *flag*\. A flag is always optional
        and its related variable contains the logical value __1__ if the
        flag has been defined during the procedure call, or otherwise __0__\.

      * \-default *value*

        Eventual default values can be defined with the \-default argument
        attribute\. Arguments with default values are automatically optional
        arguments\.

      * \-optional&#124;\-mandatory

        Arguments are by default mandatory, unless a default value is defined\.
        The flag *\-optional* transforms an argument into an optional argument\.

        In case an optional argument is not defined during a procedure call, the
        corresponding variable will not be defined\. The flag *\-mandatory* is
        the opposite to *\-optional*\. This flag exists only for completion
        reason, since an argument is anyway mandatory by default\.

      * \-multiple

        Arguments that have the *\-multiple* attribute can be defined multiple
        times during a procedure call\. The values that are provided during a
        procedure call for such an argument are stored in a list variable\. This
        is even the case if such an argument is only defined once during a
        procedure call\.

        The *\-multiple* attribute can be attributed to unnamed arguments and
        to named arguments\. The pair of argument name/argument value has to be
        repeated for each provided value in case of a named argument\. In case
        the argument with the *\-multiple* attribute is an unnamed argument,
        this one has to be the absolute last one of all unnamed arguments\.

      * \-choices *list*

        A possible set of valid argument values can be attributed to an argument
        via the *\-choices* attribute\. The argument value provided during a
        procedure call will be checked against the provided choice values\.

      * \-choicelabels *list*

        An eventual short description can be attributed to each choice option
        with the *\-choicelabels* attribute\. These descriptions will be used in
        the generated help texts and as radio and check box labels for the
        interactive calls\.

        The *\-choicelabels* attribute is optional, but if it is defined, its
        list needs to have the identical size as the *\-choices* argument list\.

      * \-range *\{double double\}*

        Another argument constraint can be defined with the *\-range*
        attribute\. The valid range is defined with a list containing the minimum
        valid value and a maximum valid value\. The *\-range* attribute has to
        be used only for numerical arguments, like integers and doubles\.

      * \-validatecommand *script*

        Custom argument value validations can be performed via specific
        validation commands that are defined with the *\-validatecommand*
        attribute\. The provided validation command can be a complete script in
        which the pattern *%P* is replaced by the argument value that has to
        be validated\.

        Validation command declaration example:

> tepam::procedure \{display\_message\} \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{text \-type string \-description "Message text" \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-validatecommand \{IllegalWordDetector %P\}__\}  
> \} \{  
> \}

        While the purpose of this custom argument validation attribute is the
        validation of a specific argument, there is also a global attribute
        *\-validatecommand* that allows performing validation that involves
        multiple arguments\.

      * \-validatecommand\_error\_text *string*

        This attribute allows overriding the default error message for a custom
        argument validation \(defined by *\-validatecommand*\)\.

      * \-widget *string*

        The widgets that allow defining the different arguments in case of an
        interactive procedure call are normally selected automatically in
        function of the argument type\. The *\-widget* attribute allows
        specifying explicitly a certain widget type for an argument\.

      * \-auxargs *list*

        In case a procedure is called interactively, additional argument
        attributes can be provided to the interactive argument definition form
        via the *\-auxargs* attribute that is itself a list of attribute
        name/attribute value pairs:

            -auxargs {-<arg_attr_name_1a> <arg_attr_value_1a> \
                      -<arg_attr_name_1b> <arg_attr_value_1b>
                      ...
            }

        For example, if a procedure takes as argument a file name it may be
        beneficial to specify the required file type for the interactive
        argument definition form\. This information can be provided via the
        *\-auxargs* attribute to the argument definition form:

> tepam::procedure LoadPicture \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{FileName \-type existingfile \-description "Picture file" \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-auxargs \{\-filetypes \{\{"GIF" \{\*\.gif\}\} \{"JPG" \{\*\.jpg\}\} \}\}__\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> \}

      * \-auxargs\_commands *script*

        If the auxiliary argument attributes are not static but have to be
        dynamically adaptable, the *\-auxargs\_commands* allows defining them
        via commands that are executed during a procedure call\. A list of pairs
        of auxiliary attribute names and commands has to be provided to the
        *\-auxargs\_commands* attribute\. The provided commands are executed in
        the context of the calling procedure\.

            -auxargs_commands {-<arg_attr_name_1a> <arg_attr_command_1a> \
                               -<arg_attr_name_1b> <arg_attr_command_1b>
                               ...
            }

# <a name='section4'></a>VARIABLES

Several variables defined inside the __::tepam__ namespace impact the mode
of operation of the procedures that have been declared with the TEPAM
__procedure__ command\.

  - __named\_arguments\_first__

    This variable defines the general calling style of the procedures\. It is by
    default set to __1__ which selects the *named arguments first, unnamed
    arguments later* style \(Tcl style\)\.

    By setting this variable to __0__, the *named arguments first, unnamed
    arguments later* style is globally selected \(Tk style\):

        set tepam::named_arguments_first 0

    While this variable defines the general calling style, the procedure
    attribute *\-named\_arguments\_first* can adapt this style individually for
    each declared procedure\.

  - __auto\_argument\_name\_completion__

    This variable controls the general automatic argument name matching mode\. By
    default it is set to __1__, meaning that the called procedures are
    trying to match eventually abbreviated argument names with the declared
    argument names\.

    By setting this variable to __0__ the automatic argument name matching
    mode is disabled:

        set tepam::auto_argument_name_completion 0

    While this variable defines the general matching mode, the procedure
    attribute *\-auto\_argument\_name\_completion* can adapt this mode
    individually for each declared procedure\.

  - __interactive\_display\_format__

    A procedure declared via the TEPAM __procedure__ command can always be
    called with the __\-interactive__ switch\. By doing so, a graphical form
    will be generated that allows entering interactively all procedure
    arguments\.

    There are two display modes for these interactive forms\. The *extended*
    mode which is the default mode is more adapted for small procedure argument
    sets\. The __short__ form is more adequate for huge procedure argument
    sets:

        set tepam::interactive_display_format "short"

    The choice to use short or extended forms can be globally configured via the
    variable __interactive\_display\_format__\. This global setting can be
    changed individually for a procedure with the procedure attribute
    *\-interactive\_display\_format*\.

  - __help\_line\_length__

    The maximum line length used by the procedure help text generator can be
    specified with this variable\. The default length which is set to 80
    \(characters\) can easily be adapted to the need of an application:

        set tepam::help_line_length 120

    Since this variable is applied directly during the help text generation, its
    value can continuously be adapted to the current need\.

  - __command\_log__

    Procedure calls can be logged inside the list variable
    __tepam::ProcedureCallLogList__\. The variable __tepam::command\_log__
    controls the default logging settings for any procedures\. The following
    configurations are supported:

      * *0*: Disables any procedure call loggings

      * *1*: Enables any procedure call loggings

      * *"interactive"*: Will log any procedures called interactively \(e\.g\.
        procedures called with the \-interactive flag\)\. This is the default
        configuration\.

    This default logging configuration can be changed individually for each
    procedure with the *\-command\_log* attribute\.

# <a name='section5'></a>ARGUMENT TYPES

TEPAM provides a comprehensive set of procedure argument types\. They can easily
be completed with application specific types if necessary\.

## <a name='subsection3'></a>Predefined Argument Types

To remember, a type can be assigned to each specified procedure argument:

> tepam::procedure \{warning\} \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-font __\-type font__ \-default \{Arial 10 italic\}\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-severity\_level __\-type integer__ \-optional \-range \{1 10\}\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-fg __\-type color__ \-optional \-description "Message color"\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{text __\-type string__ \-multiple \-description "Multiple text lines to display"\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;\.\.\.  
> \}

There are some *special purpose types* that are building the first category of
predefined argument types:

  - __none__ A *flag*, also called *switch*, is defined as a named
    argument that has the type __none__\. Flags are always optional and the
    default value of the assigned variable is set to __0__\. In contrast to
    the \(normal\) named arguments, no argument value has to be provided to a
    flag\.

> tepam::procedure flag\_test \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\{\-flag \-type none \-description "This is a flag"\}__  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts __$flag__  
> \}  
>   
> flag\_test  
> *\-> 0*  
>   
> flag\_test \-flag  
> *\-> 1*

    Since no argument value has to be provided to a flag, also no data check is
    performed for this argument type\.

  - __string__ __String__ is a generic argument data type\. Any data
    string can be provided to a string type argument and no data type checks are
    therefore performed\. The string type allows defining single line strings
    during the interactive procedure calls\.

  - __text__ __Text__ is identical to __string__ with the only
    difference that it allows entering multi line strings during interactive
    procedure calls\.

  - __\{\}__ A __blank__ argument type signifies an undefined argument
    type\. This is the default argument type that will be used if no type has
    been explicitly specified\. An argument that has a __blank__ type behaves
    identically than an argument that has a __string__ type, e\.g\. no
    argument data checks are performed\. The only difference is that the data
    type __string__ is mentioned in the generated help documentation, while
    this is not the case for the __blank__ type\.

Several *numerical types* are defined by TEPAM\. The type validation procedures
are using the __string is <type> \-strict__ commands to check the validity of
the provided arguments, which assures that no empty strings are accepted as
argument value\. The type validation expression for the numerical types and the
argument types to which this expression is applied are:

> string is __<type\_to\_check>__ \-strict *<argument\_value>*

  - *boolean*

  - *integer*

  - *double*

Empty strings are accepted as argument value for all the alpha numeric argument
types\. The argument types that are falling into this category and validation
expression used for them are:

> string is *<type\_to\_check>* *<argument\_value>*

  - *alnum*

  - *alpha*

  - *ascii*

  - *control*

  - *digit*

  - *graph*

  - *lower*

  - *print*

  - *punct*

  - *space*

  - *upper*

  - *wordchar*

  - *xdigit*

In addition to the data types checked with the __string is <type>__
commands, TEPAM specifies some other useful data types:

  - *char* Each string that has a length of 1 character meets the
    *character* type\. The type check is made with the following expression:

> expr \[string length *<argument\_value>*\]==1

  - *color* Any character strings that are accepted by Tk as a color are
    considered as valid color argument\. Please note that the Tk package has to
    be loaded to use the type *color*\. TEPAM is using the following command to
    validate the color type:

> expr \!\[catch \{winfo rgb \. *<argument\_value>*\}\]

  - *font* Any character strings that are accepted by Tk as a font are
    considered as valid font argument\. Please note that the Tk package has to be
    loaded to use the *font* type\. TEPAM is using the following command to
    validate the color type:

        expr ![catch {font measure <argument_value> ""}]

  - *file* Any strings that are not containing one of the following characters
    are considered as valid file names: \* ? " < >\. It is not necessary that the
    file and its containing directory exist\. Zero\-length strings are not
    considered as valid file names\.

    The following expression is used to validate the file names:

        expr [string length <argument_value>]>0 && ![regexp {[\"*?<>:]} <argument_value>]

  - *existingfile* The argument is valid if it matches with an existing file\.
    The following check is performed to validate the arguments of this type:

        file exists <argument_value>

  - *directory* The directory argument is validated exactly in the same way as
    the file arguments\.

  - *existingdirectory* The argument is valid if it matches with an existing
    directory\. The following check is performed to validate the arguments of
    this type:

        file isdirectory <argument_value>

## <a name='subsection4'></a>Defining Application Specific Argument Types

To add support for a new application specific argument type it is just necessary
to add into the namespace __tepam__ a validation function
__Validation\(<type>\)__\. This function requires one argument\. It has to
returns __1__ if the provided argument matches with the relevant data type\.
The function has to return otherwise __0__\.

The validation command section of the "tepam\.tcl" package provides sufficient
examples of validation functions, since it implements the ones for the standard
TEPAM types\.

The following additional code snippet shows the validation function for a custom
argument type that requires values that have a character string length of
exactly 2:

    proc tepam::Validate(two_char) {v} {expr {[string length $v]==2}}

# <a name='section6'></a>PROCEDURE CALLS

## <a name='subsection5'></a>Help

Each procedure can be called with the *\-help* flag\. The procedure will then
print a generated help text to *stdout* and will then return without
performing any additional actions\.

Taking the first procedure declared in [PROCEDURE CALLS](#section6), the
help request and the printed help text would be:

> __display message \-help__  
> *\->*  
> *NAME*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*display message \- Displays a simple message box*  
> *SYNOPSIS*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*display message*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*\[\-mtype <mtype>\]*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*Message type, default: "Warning", choices: \{Info, Warning, Error\}*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*<text>*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*Multiple text lines to display, type: string*  
> *DESCRIPTION*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*This procedure allows displaying a configurable message box\. The default*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*message type that is created is a warning, but also errors and info can*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*be generated\.*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*The procedure accepts multiple text lines\.*  
> *EXAMPLE*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*display message \-mtype Warning "Save first your job"*

The argument manager is checking if the last provided argument is *\-help* and
generates the requested help message if this is the case\. So, also the following
example will print the help message:

> __display message \-mtype Info "It is 7:00" \-help__

On the other hand, the following call will result in an error:

> __display message \-help \-mtype Info "It is 7:00"__  
> *\->*  
> *display message: Argument '\-help' not known*

## <a name='subsection6'></a>Interactive Procedure Call

If Tk has been loaded a procedure can be called with the *\-interactive* flag
to open a graphical form that allows specifying interactively all procedure
arguments\. The following example assures that the Tk library is loaded and shows
the command line to call interactively the procedure declared in [PROCEDURE
CALLS](#section6):

> package require Tk  
> __display message \-interactive__

Also the *\-interactive* flag has to be placed at the last argument position as
this is also required for the *\-help* flag\. Arguments defined before the
*\-interactive* flag will be ignored\. The following example is therefore also a
valid interactive procedure call:

> __display message__ \-mtype Info "It is 7:00" __\-interactive__

## <a name='subsection7'></a>Unnamed Arguments

Unnamed arguments are typically provided to the called procedure as simple
parameters\. This procedure calling form requires that the provided arguments are
strictly following the order of the specified arguments\. Several parameters can
be assigned to the last argument if this one has the *\-multiple* attribute\.
So, the following declared procedure \.\.\.

    tepam::procedure {display_message} {
       -args {
          {mtype -choices {Info Warning Error}}
          {text -type string -multiple}
       }
    } {
       puts "$mtype: [join $text]"
    }

\.\.\. can for example be called in the following ways:

> __display\_message Info "It is PM 7:00\."__  
> *\-> Info: It is PM 7:00\.*  
>   
> __display\_message Info "It is PM 7:00\." "You should go home\."__  
> *\-> Info: It is PM 7:00\. You should go home\.*

The nice thing is that unnamed arguments can also be called as named arguments,
which can be handy, for example if the exact specified argument order is not
known to a user:

> __display\_message \-mtype Info \-text "It is PM 7:00\."__  
> *\-> Info: It is PM 7:00\.*  
>   
> __display\_message \-text "It is PM 7:00\." \-mtype Info__  
> *\-> Info: It is PM 7:00\.*  
>   
> __display\_message \-mtype Info \-text "It is PM 7:00\." \-text "You should go home\."__  
> *\-> Info: It is PM 7:00\. You should go home\.*  
>   
> __display\_message \-text "It is PM 7:00\." \-text "You should go home\." \-mtype Info__  
> *\-> Info: It is PM 7:00\. You should go home\.*

## <a name='subsection8'></a>Named Arguments

Named arguments have to be provided to a procedure in form of a parameter pairs
composed by the argument names and the argument values\. The order how they are
provided during a procedure call is irrelevant and has not to match with the
argument specification order\.

The following declared procedure \.\.\.

    tepam::procedure {display_message} {
       -args {
          {-mtype -choices {Info Warning Error}}
          {-text -type string -multiple}
       }
    } {
       puts "$mtype: [join $text]"
    }

\.\.\. can be called in the following ways:

> __display\_message \-mtype Info \-text "It is PM 7:00\."__  
> *\-> Info: It is PM 7:00\.*  
>   
> __display\_message \-text "It is PM 7:00\." \-mtype Info__  
> *\-> Info: It is PM 7:00\.*  
>   
> __display\_message \-mtype Info \-text "It is PM 7:00\." \-text "You should go home\."__  
> *\-> Info: It is PM 7:00\. You should go home\.*  
>   
> __display\_message \-text "It is PM 7:00\." \-text "You should go home\." \-mtype Info__  
> *\-> Info: It is PM 7:00\. You should go home\.*

Also named arguments that have not the *\-multiple* attribute can be provided
multiple times\. Only the last provided argument will be retained in such a case:

> __display\_message \-mtype Info \-text "It is PM 7:00\." \-mtype Warning__  
> *\-> Warning: It is PM 7:00\.*

## <a name='subsection9'></a>Unnamed Arguments First, Named Arguments Later \(Tk Style\)

A procedure that has been defined while the variable
__tepam::named\_arguments\_first__ was set to 1, or with the procedure
attribute *\-named\_arguments\_first* set to 1 has to be called in the Tcl style\.
The following procedure declaration will be used in this section to illustrate
the meaning of this calling style:

> __set tepam::named\_arguments\_first 1__  
> tepam::procedure my\_proc \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-n1 \-default ""\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-n2 \-default ""\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{u1 \-default ""\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{u2 \-default ""\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts "n1:'$n1', n2:'$n2', u1:'$u1', u2:'$u2'"  
> \}

The unnamed arguments are placed at the end of procedure call, after the named
arguments:

> my\_proc __\-n1 N1 \-n2 N2 U1 U2__  
> *\-> n1:'N1', n2:'N2', u1:'U1', u2:'U2'*

The argument parser considers the first argument that doesn't start with the '\-'
character as well as all following arguments as unnamed argument:

> my\_proc __U1 U2__  
> *\-> n1:'', n2:'', u1:'U1', u2:'U2'*

Named arguments can be defined multiple times\. If the named argument has the
*\-multiply* attribute, all argument values will be collected in a list\.
Otherwise, only the last provided attribute value will be retained:

> my\_proc __\-n1 N1 \-n2 N2 \-n1 M1 U1 U2__  
> *\-> n1:'M1', n2:'N2', u1:'U1', u2:'U2'*

The name of the first unnamed argument has therefore not to start with the '\-'
character\. The unnamed argument is otherwise considered as name of another named
argument\. This is especially important if the first unnamed argument is given by
a variable that can contain any character strings:

> my\_proc __\-n1 N1 \-n2 N2 "\->" "<\-"__  
> *\-> my\_proc: Argument '\->' not known*  
>   
> set U1 "\->"  
> my\_proc __\-n1 N1 \-n2 N2 $U1 U2__  
> my\_proc: Argument '\->' not known

The '\-\-' flag allows separating unambiguously the unnamed arguments from the
named arguments\. All data after the '\-\-' flag will be considered as unnamed
argument:

> my\_proc __\-n1 N1 \-n2 N2 \-\- "\->" "<\-"__  
> *\-> n1:'N1', n2:'N2', u1:'\->', u2:'<\-'*  
>   
> set U1 "\->"  
> my\_proc __\-n1 N1 \-n2 N2 \-\- $U1 U2__  
> *\-> n1:'N1', n2:'N2', u1:'\->', u2:'<\-'*

## <a name='subsection10'></a>Named Arguments First, Unnamed Arguments Later \(Tcl Style\)

The Tk calling style will be chosen if a procedure is defined while the variable
__tepam::named\_arguments\_first__ is set to 0, or if the procedure attribute
*\-named\_arguments\_first* has been set to 0\. The following procedure will be
used in this section to illustrate this calling style:

> __set tepam::named\_arguments\_first 0__  
> tepam::procedure my\_proc \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-n1 \-default ""\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-n2 \-default ""\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{u1\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{u2 \-default "" \-multiple\}  
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts "n1:'$n1', n2:'$n2', u1:'$u1', u2:'$u2'"  
> \}

The unnamed arguments have to be provided first in this case\. The named
arguments are provided afterwards:

> my\_proc __U1 U2 \-n1 N1 \-n2 N2__  
> *\-> n1:'N1', n1:'N1', u1:'U1', u2:'U2'*

The argument parser will assign to each defined unnamed argument a value before
it switches to read the named arguments\. This default behavior changes a bit if
there are unnamed arguments that are optional or that can take multiple values\.

An argument value will only be assigned to an unnamed argument that is optional
\(that has either the *\-optional* attribute or that has a default value\), if
the value is not beginning with the '\-' character or if no named arguments are
defined\. The value that starts with '\-' is otherwise considered as the name of a
named argument\.

Argument values are assigned to an argument that has the *\-multiple* attribute
as long as the parameter value doesn't starts with the '\-' character\.

Values that start with the '\-' character can therefore not be assigned to
optional unnamed arguments, which restricts the usage of the Tcl procedure
calling style\. The Tk style may be preferable in some cases, since it allows
separating unambiguously the named arguments from the unnamed ones with the '\-\-'
flag\.

Let's explore in a bit less theoretically the ways how the previously defined
procedure can be called: The first example calls the procedure without any
parameters, which leads to an error since *u1* is a mandatory argument:

> my\_proc  
> *\-> my\_proc: Required argument is missing: u1*

The procedure call is valid if one parameter is provided for *u1*:

> my\_proc __U1__  
> *\-> n1:'', n2:'', u1:'U1', u2:''*

If more parameters are provided that are not starting with the '\-' character,
they will be attributed to the unnamed arguments\. *U2* will receive 3 of these
parameters, since it accepts multiple values:

> my\_proc __U1 U2 U3 U4__  
> *\-> n1:'', n2:'', u1:'U1', u2:'U2 U3 U4'*

As soon as one parameter starts with '\-' and all unnamed arguments have been
assigned, the argument manager tries to interpret the parameter as name of a
named argument\. The procedure call will fail if a value beginning with '\-' is
assigned to an unnamed argument:

> my\_proc __U1 U2 U3 U4 \-U5__  
> *\-> my\_proc: Argument '\-U5' not known*

The attribution of a parameter to a named argument will fail if there are
undefined unnamed \(non optional\) arguments\. The name specification will in this
case simply be considered as a parameter value that is attributed to the
*next* unnamed argument\. This was certainly not the intention in the following
example:

> my\_proc __\-n1 N1__  
> *\-> n1:'', n2:'', u1:'\-n1', u2:'N1'*

The situation is completely different if values have already been assigned to
all mandatory unnamed arguments\. A parameter beginning with the '\-' character
will in this case be considered as a name identifier for a named argument:

> my\_proc __U1 \-n1 N1__  
> *\-> n1:'N1', n2:'', u1:'U1', u2:''*

No unnamed arguments are allowed behind the named arguments:

> my\_proc __U1 \-n1 N1 U2__  
> *\-> my\_proc: Argument 'U2' is not an option*

The '\-\-' flag has no special meaning if not all mandatory arguments have got
assigned a value\. This flag will simply be attributed to one of the unnamed
arguments:

> my\_proc __\-\- \-n1 N1__  
> *\-> n1:'N1', n2:'', u1:'\-\-', u2:''*

But the '\-\-' flag is simply ignored if the argument parser has started to handle
the named arguments:

> my\_proc __U1 \-\- \-n1 N1__  
> *\-> n1:'N1', n2:'', u1:'U1', u2:''*  
>   
> my\_proc __U1 \-n1 N1 \-\- \-n2 N2__  
> *\-> n1:'N1', n2:'N2', u1:'U1', u2:''*

## <a name='subsection11'></a>Raw Argument List

It may be necessary sometimes that the procedure body is able to access the
entire list of arguments provided during a procedure call\. This can happen via
the __args__ variable that contains always the unprocessed argument list:

> tepam::procedure \{display\_message\} \{  
> &nbsp;&nbsp;&nbsp;\-args \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{\-mtype \-choices \{Warning Error\} \-default Warning\}  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\{text \-type string \-multiple\}  
>   
> &nbsp;&nbsp;&nbsp;\}  
> \} \{  
> &nbsp;&nbsp;&nbsp;puts "args: __$args__"  
> \}  
> display\_message \-mtype Warning "It is 7:00"  
> *\-> args: \-mtype Warning \{It is 7:00\}*

# <a name='seealso'></a>SEE ALSO

[tepam\(n\)](tepam\_introduction\.md),
[tepam::argument\_dialogbox\(n\)](tepam\_argument\_dialogbox\.md)

# <a name='keywords'></a>KEYWORDS

[argument integrity](\.\./\.\./\.\./\.\./index\.md\#argument\_integrity), [argument
validation](\.\./\.\./\.\./\.\./index\.md\#argument\_validation),
[arguments](\.\./\.\./\.\./\.\./index\.md\#arguments),
[procedure](\.\./\.\./\.\./\.\./index\.md\#procedure),
[subcommand](\.\./\.\./\.\./\.\./index\.md\#subcommand)

# <a name='category'></a>CATEGORY

Procedures, arguments, parameters, options

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2013, Andreas Drollinger
