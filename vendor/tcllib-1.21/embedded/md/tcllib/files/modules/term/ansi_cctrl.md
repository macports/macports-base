
[//000000001]: # (term::ansi::code::ctrl \- Terminal control)
[//000000002]: # (Generated from file 'ansi\_cctrl\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::ansi::code::ctrl\(n\) 0\.3 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::ansi::code::ctrl \- ANSI control sequences

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Introspection](#subsection1)

      - [Sequences](#subsection2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require term::ansi::code ?0\.2?  
package require term::ansi::code::ctrl ?0\.3?  

[__::term::ansi::code::ctrl::names__](#1)  
[__::term::ansi::code::ctrl::import__ ?*ns*? ?*arg*\.\.\.?](#2)  
[__::term::ansi::code::ctrl::eeol__](#3)  
[__::term::ansi::code::ctrl::esol__](#4)  
[__::term::ansi::code::ctrl::el__](#5)  
[__::term::ansi::code::ctrl::ed__](#6)  
[__::term::ansi::code::ctrl::eu__](#7)  
[__::term::ansi::code::ctrl::es__](#8)  
[__::term::ansi::code::ctrl::sd__](#9)  
[__::term::ansi::code::ctrl::su__](#10)  
[__::term::ansi::code::ctrl::ch__](#11)  
[__::term::ansi::code::ctrl::sc__](#12)  
[__::term::ansi::code::ctrl::rc__](#13)  
[__::term::ansi::code::ctrl::sca__](#14)  
[__::term::ansi::code::ctrl::rca__](#15)  
[__::term::ansi::code::ctrl::st__](#16)  
[__::term::ansi::code::ctrl::ct__](#17)  
[__::term::ansi::code::ctrl::cat__](#18)  
[__::term::ansi::code::ctrl::qdc__](#19)  
[__::term::ansi::code::ctrl::qds__](#20)  
[__::term::ansi::code::ctrl::qcp__](#21)  
[__::term::ansi::code::ctrl::rd__](#22)  
[__::term::ansi::code::ctrl::elw__](#23)  
[__::term::ansi::code::ctrl::dlw__](#24)  
[__::term::ansi::code::ctrl::eg__](#25)  
[__::term::ansi::code::ctrl::lg__](#26)  
[__::term::ansi::code::ctrl::scs0__ *tag*](#27)  
[__::term::ansi::code::ctrl::scs1__ *tag*](#28)  
[__::term::ansi::code::ctrl::sda__ *arg*\.\.\.](#29)  
[__::term::ansi::code::ctrl::sda\_fgblack__](#30)  
[__::term::ansi::code::ctrl::sda\_fgred__](#31)  
[__::term::ansi::code::ctrl::sda\_fggreen__](#32)  
[__::term::ansi::code::ctrl::sda\_fgyellow__](#33)  
[__::term::ansi::code::ctrl::sda\_fgblue__](#34)  
[__::term::ansi::code::ctrl::sda\_fgmagenta__](#35)  
[__::term::ansi::code::ctrl::sda\_fgcyan__](#36)  
[__::term::ansi::code::ctrl::sda\_fgwhite__](#37)  
[__::term::ansi::code::ctrl::sda\_fgdefault__](#38)  
[__::term::ansi::code::ctrl::sda\_bgblack__](#39)  
[__::term::ansi::code::ctrl::sda\_bgred__](#40)  
[__::term::ansi::code::ctrl::sda\_bggreen__](#41)  
[__::term::ansi::code::ctrl::sda\_bgyellow__](#42)  
[__::term::ansi::code::ctrl::sda\_bgblue__](#43)  
[__::term::ansi::code::ctrl::sda\_bgmagenta__](#44)  
[__::term::ansi::code::ctrl::sda\_bgcyan__](#45)  
[__::term::ansi::code::ctrl::sda\_bgwhite__](#46)  
[__::term::ansi::code::ctrl::sda\_bgdefault__](#47)  
[__::term::ansi::code::ctrl::sda\_bold__](#48)  
[__::term::ansi::code::ctrl::sda\_dim__](#49)  
[__::term::ansi::code::ctrl::sda\_italic__](#50)  
[__::term::ansi::code::ctrl::sda\_underline__](#51)  
[__::term::ansi::code::ctrl::sda\_blink__](#52)  
[__::term::ansi::code::ctrl::sda\_revers__](#53)  
[__::term::ansi::code::ctrl::sda\_hidden__](#54)  
[__::term::ansi::code::ctrl::sda\_strike__](#55)  
[__::term::ansi::code::ctrl::sda\_nobold__](#56)  
[__::term::ansi::code::ctrl::sda\_noitalic__](#57)  
[__::term::ansi::code::ctrl::sda\_nounderline__](#58)  
[__::term::ansi::code::ctrl::sda\_noblink__](#59)  
[__::term::ansi::code::ctrl::sda\_norevers__](#60)  
[__::term::ansi::code::ctrl::sda\_nohidden__](#61)  
[__::term::ansi::code::ctrl::sda\_nostrike__](#62)  
[__::term::ansi::code::ctrl::sda\_reset__](#63)  
[__::term::ansi::send::fcp__ *row* *col*](#64)  
[__::term::ansi::code::ctrl::cu__ ?*n*?](#65)  
[__::term::ansi::code::ctrl::cd__ ?*n*?](#66)  
[__::term::ansi::code::ctrl::cf__ ?*n*?](#67)  
[__::term::ansi::code::ctrl::cb__ ?*n*?](#68)  
[__::term::ansi::code::ctrl::ss__ ?*s* *e*?](#69)  
[__::term::ansi::code::ctrl::skd__ *code* *str*](#70)  
[__::term::ansi::code::ctrl::title__ *str*](#71)  
[__::term::ansi::code::ctrl::gron__](#72)  
[__::term::ansi::code::ctrl::groff__](#73)  
[__::term::ansi::code::ctrl::tlc__](#74)  
[__::term::ansi::code::ctrl::trc__](#75)  
[__::term::ansi::code::ctrl::brc__](#76)  
[__::term::ansi::code::ctrl::blc__](#77)  
[__::term::ansi::code::ctrl::ltj__](#78)  
[__::term::ansi::code::ctrl::ttj__](#79)  
[__::term::ansi::code::ctrl::rtj__](#80)  
[__::term::ansi::code::ctrl::btj__](#81)  
[__::term::ansi::code::ctrl::fwj__](#82)  
[__::term::ansi::code::ctrl::hl__](#83)  
[__::term::ansi::code::ctrl::vl__](#84)  
[__::term::ansi::code::ctrl::groptim__ *str*](#85)  
[__::term::ansi::code::ctrl::clear__](#86)  
[__::term::ansi::code::ctrl::init__](#87)  
[__::term::ansi::code::ctrl::showat__ *row* *col* *text*](#88)  

# <a name='description'></a>DESCRIPTION

This package provides symbolic names for the ANSI control sequences\. For each
sequence a single command is provided which returns the sequence as its result\.
None of the commands of this package write to a channel; that is handled by
higher level packages, like __[term::ansi::send](ansi\_send\.md)__\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Introspection

  - <a name='1'></a>__::term::ansi::code::ctrl::names__

    This command is for introspection\. It returns as its result a list
    containing the names of all attribute commands\.

  - <a name='2'></a>__::term::ansi::code::ctrl::import__ ?*ns*? ?*arg*\.\.\.?

    This command imports some or all attribute commands into the namespace
    *ns*\. This is by default the namespace *ctrl*\. Note that this is
    relative namespace name, placing the imported command into a child of the
    current namespace\. By default all commands are imported, this can howver be
    restricted by listing the names of the wanted commands after the namespace
    argument\.

## <a name='subsection2'></a>Sequences

  - <a name='3'></a>__::term::ansi::code::ctrl::eeol__

    Erase \(to\) End Of Line

  - <a name='4'></a>__::term::ansi::code::ctrl::esol__

    Erase \(to\) Start Of Line

  - <a name='5'></a>__::term::ansi::code::ctrl::el__

    Erase \(current\) Line

  - <a name='6'></a>__::term::ansi::code::ctrl::ed__

    Erase Down \(to bottom\)

  - <a name='7'></a>__::term::ansi::code::ctrl::eu__

    Erase Up \(to top\)

  - <a name='8'></a>__::term::ansi::code::ctrl::es__

    Erase Screen

  - <a name='9'></a>__::term::ansi::code::ctrl::sd__

    Scroll Down

  - <a name='10'></a>__::term::ansi::code::ctrl::su__

    Scroll Up

  - <a name='11'></a>__::term::ansi::code::ctrl::ch__

    Cursor Home

  - <a name='12'></a>__::term::ansi::code::ctrl::sc__

    Save Cursor

  - <a name='13'></a>__::term::ansi::code::ctrl::rc__

    Restore Cursor \(Unsave\)

  - <a name='14'></a>__::term::ansi::code::ctrl::sca__

    Save Cursor \+ Attributes

  - <a name='15'></a>__::term::ansi::code::ctrl::rca__

    Restore Cursor \+ Attributes

  - <a name='16'></a>__::term::ansi::code::ctrl::st__

    Set Tab \(@ current position\)

  - <a name='17'></a>__::term::ansi::code::ctrl::ct__

    Clear Tab \(@ current position\)

  - <a name='18'></a>__::term::ansi::code::ctrl::cat__

    Clear All Tabs

  - <a name='19'></a>__::term::ansi::code::ctrl::qdc__

    Query Device Code

  - <a name='20'></a>__::term::ansi::code::ctrl::qds__

    Query Device Status

  - <a name='21'></a>__::term::ansi::code::ctrl::qcp__

    Query Cursor Position

  - <a name='22'></a>__::term::ansi::code::ctrl::rd__

    Reset Device

  - <a name='23'></a>__::term::ansi::code::ctrl::elw__

    Enable Line Wrap

  - <a name='24'></a>__::term::ansi::code::ctrl::dlw__

    Disable Line Wrap

  - <a name='25'></a>__::term::ansi::code::ctrl::eg__

    Enter Graphics Mode

  - <a name='26'></a>__::term::ansi::code::ctrl::lg__

    Exit Graphics Mode

  - <a name='27'></a>__::term::ansi::code::ctrl::scs0__ *tag*

    Set default character set

  - <a name='28'></a>__::term::ansi::code::ctrl::scs1__ *tag*

    Set alternate character set Select Character Set\.

    Choose which character set is used for either default \(scs0\) or alternate
    font \(scs1\)\. This does not change whether default or alternate font are
    used, only their definition\.

    The legal tags, and their meanings, are:

      * A

        United Kingdom Set

      * B

        ASCII Set

      * 0

        Special Graphics

      * 1

        Alternate Character ROM Standard Character Set

      * 2

        Alternate Character ROM Special Graphics

  - <a name='29'></a>__::term::ansi::code::ctrl::sda__ *arg*\.\.\.

    Set Display Attributes\. The arguments are the code sequences for the
    possible attributes, as provided by the package
    __[term::ansi::code::attr](ansi\_cattr\.md)__\. For convenience this
    package also provides additional commands each setting a single specific
    attribute\.

  - <a name='30'></a>__::term::ansi::code::ctrl::sda\_fgblack__

    Set text color to *Black*\.

  - <a name='31'></a>__::term::ansi::code::ctrl::sda\_fgred__

    Set text color to *Red*\.

  - <a name='32'></a>__::term::ansi::code::ctrl::sda\_fggreen__

    Set text color to *Green*\.

  - <a name='33'></a>__::term::ansi::code::ctrl::sda\_fgyellow__

    Set text color to *Yellow*\.

  - <a name='34'></a>__::term::ansi::code::ctrl::sda\_fgblue__

    Set text color to *Blue*\.

  - <a name='35'></a>__::term::ansi::code::ctrl::sda\_fgmagenta__

    Set text color to *Magenta*\.

  - <a name='36'></a>__::term::ansi::code::ctrl::sda\_fgcyan__

    Set text color to *Cyan*\.

  - <a name='37'></a>__::term::ansi::code::ctrl::sda\_fgwhite__

    Set text color to *White*\.

  - <a name='38'></a>__::term::ansi::code::ctrl::sda\_fgdefault__

    Set default text color \(*Black*\)\.

  - <a name='39'></a>__::term::ansi::code::ctrl::sda\_bgblack__

    Set background to *Black*\.

  - <a name='40'></a>__::term::ansi::code::ctrl::sda\_bgred__

    Set background to *Red*\.

  - <a name='41'></a>__::term::ansi::code::ctrl::sda\_bggreen__

    Set background to *Green*\.

  - <a name='42'></a>__::term::ansi::code::ctrl::sda\_bgyellow__

    Set background to *Yellow*\.

  - <a name='43'></a>__::term::ansi::code::ctrl::sda\_bgblue__

    Set background to *Blue*\.

  - <a name='44'></a>__::term::ansi::code::ctrl::sda\_bgmagenta__

    Set background to *Magenta*\.

  - <a name='45'></a>__::term::ansi::code::ctrl::sda\_bgcyan__

    Set background to *Cyan*\.

  - <a name='46'></a>__::term::ansi::code::ctrl::sda\_bgwhite__

    Set background to *White*\.

  - <a name='47'></a>__::term::ansi::code::ctrl::sda\_bgdefault__

    Set default background \(Transparent\)\.

  - <a name='48'></a>__::term::ansi::code::ctrl::sda\_bold__

    Bold on\.

  - <a name='49'></a>__::term::ansi::code::ctrl::sda\_dim__

    Dim on\.

  - <a name='50'></a>__::term::ansi::code::ctrl::sda\_italic__

    Italics on\.

  - <a name='51'></a>__::term::ansi::code::ctrl::sda\_underline__

    Underscore on\.

  - <a name='52'></a>__::term::ansi::code::ctrl::sda\_blink__

    Blink on\.

  - <a name='53'></a>__::term::ansi::code::ctrl::sda\_revers__

    Reverse on\.

  - <a name='54'></a>__::term::ansi::code::ctrl::sda\_hidden__

    Hidden on\.

  - <a name='55'></a>__::term::ansi::code::ctrl::sda\_strike__

    Strike\-through on\.

  - <a name='56'></a>__::term::ansi::code::ctrl::sda\_nobold__

    Bold off\.

  - <a name='57'></a>__::term::ansi::code::ctrl::sda\_noitalic__

    Italics off\.

  - <a name='58'></a>__::term::ansi::code::ctrl::sda\_nounderline__

    Underscore off\.

  - <a name='59'></a>__::term::ansi::code::ctrl::sda\_noblink__

    Blink off\.

  - <a name='60'></a>__::term::ansi::code::ctrl::sda\_norevers__

    Reverse off\.

  - <a name='61'></a>__::term::ansi::code::ctrl::sda\_nohidden__

    Hidden off\.

  - <a name='62'></a>__::term::ansi::code::ctrl::sda\_nostrike__

    Strike\-through off\.

  - <a name='63'></a>__::term::ansi::code::ctrl::sda\_reset__

    Reset all attributes to their default values\.

  - <a name='64'></a>__::term::ansi::send::fcp__ *row* *col*

    Force Cursor Position \(aka Go To\)\.

  - <a name='65'></a>__::term::ansi::code::ctrl::cu__ ?*n*?

    Cursor Up\. *n* defaults to 1\.

  - <a name='66'></a>__::term::ansi::code::ctrl::cd__ ?*n*?

    Cursor Down\. *n* defaults to 1\.

  - <a name='67'></a>__::term::ansi::code::ctrl::cf__ ?*n*?

    Cursor Forward\. *n* defaults to 1\.

  - <a name='68'></a>__::term::ansi::code::ctrl::cb__ ?*n*?

    Cursor Backward\. *n* defaults to 1\.

  - <a name='69'></a>__::term::ansi::code::ctrl::ss__ ?*s* *e*?

    Scroll Screen \(entire display, or between rows start end, inclusive\)\.

  - <a name='70'></a>__::term::ansi::code::ctrl::skd__ *code* *str*

    Set Key Definition\.

  - <a name='71'></a>__::term::ansi::code::ctrl::title__ *str*

    Set the terminal title\.

  - <a name='72'></a>__::term::ansi::code::ctrl::gron__

    Switch to character/box graphics\. I\.e\. switch to the alternate font\.

  - <a name='73'></a>__::term::ansi::code::ctrl::groff__

    Switch to regular characters\. I\.e\. switch to the default font\.

  - <a name='74'></a>__::term::ansi::code::ctrl::tlc__

    Character graphics, Top Left Corner\.

  - <a name='75'></a>__::term::ansi::code::ctrl::trc__

    Character graphics, Top Right Corner\.

  - <a name='76'></a>__::term::ansi::code::ctrl::brc__

    Character graphics, Bottom Right Corner\.

  - <a name='77'></a>__::term::ansi::code::ctrl::blc__

    Character graphics, Bottom Left Corner\.

  - <a name='78'></a>__::term::ansi::code::ctrl::ltj__

    Character graphics, Left T Junction\.

  - <a name='79'></a>__::term::ansi::code::ctrl::ttj__

    Character graphics, Top T Junction\.

  - <a name='80'></a>__::term::ansi::code::ctrl::rtj__

    Character graphics, Right T Junction\.

  - <a name='81'></a>__::term::ansi::code::ctrl::btj__

    Character graphics, Bottom T Junction\.

  - <a name='82'></a>__::term::ansi::code::ctrl::fwj__

    Character graphics, Four\-Way Junction\.

  - <a name='83'></a>__::term::ansi::code::ctrl::hl__

    Character graphics, Horizontal Line\.

  - <a name='84'></a>__::term::ansi::code::ctrl::vl__

    Character graphics, Vertical Line\.

  - <a name='85'></a>__::term::ansi::code::ctrl::groptim__ *str*

    Optimize character graphics\. The generator commands above create way to many
    superfluous commands shifting into and out of the graphics mode\. This
    command removes all shifts which are not needed\. To this end it also knows
    which characters will look the same in both modes, to handle strings created
    outside of this package\.

  - <a name='86'></a>__::term::ansi::code::ctrl::clear__

    Clear screen\. In essence a sequence of CursorHome \+ EraseDown\.

  - <a name='87'></a>__::term::ansi::code::ctrl::init__

    Initialize default and alternate fonts to ASCII and box graphics\.

  - <a name='88'></a>__::term::ansi::code::ctrl::showat__ *row* *col* *text*

    Format the block of text for display at the specified location\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *term* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[ansi](\.\./\.\./\.\./\.\./index\.md\#ansi), [attribute
control](\.\./\.\./\.\./\.\./index\.md\#attribute\_control), [color
control](\.\./\.\./\.\./\.\./index\.md\#color\_control),
[control](\.\./\.\./\.\./\.\./index\.md\#control),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
