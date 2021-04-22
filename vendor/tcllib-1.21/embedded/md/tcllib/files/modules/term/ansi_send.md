
[//000000001]: # (term::ansi::send \- Terminal control)
[//000000002]: # (Generated from file 'ansi\_send\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::ansi::send\(n\) 0\.2 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::ansi::send \- Output of ANSI control sequences to terminals

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require term::ansi::send ?0\.2?  

[__::term::ansi::send::import__ ?*ns*? *\.\.\.*](#1)  
[__::term::ansi::send::eeol__](#2)  
[__::term::ansi::send::esol__](#3)  
[__::term::ansi::send::el__](#4)  
[__::term::ansi::send::ed__](#5)  
[__::term::ansi::send::eu__](#6)  
[__::term::ansi::send::es__](#7)  
[__::term::ansi::send::sd__](#8)  
[__::term::ansi::send::su__](#9)  
[__::term::ansi::send::ch__](#10)  
[__::term::ansi::send::sc__](#11)  
[__::term::ansi::send::rc__](#12)  
[__::term::ansi::send::sca__](#13)  
[__::term::ansi::send::rca__](#14)  
[__::term::ansi::send::st__](#15)  
[__::term::ansi::send::ct__](#16)  
[__::term::ansi::send::cat__](#17)  
[__::term::ansi::send::qdc__](#18)  
[__::term::ansi::send::qds__](#19)  
[__::term::ansi::send::qcp__](#20)  
[__::term::ansi::send::rd__](#21)  
[__::term::ansi::send::elw__](#22)  
[__::term::ansi::send::dlw__](#23)  
[__::term::ansi::send::eg__](#24)  
[__::term::ansi::send::lg__](#25)  
[__::term::ansi::send::scs0__ *tag*](#26)  
[__::term::ansi::send::scs1__ *tag*](#27)  
[__::term::ansi::send::sda__ *arg*\.\.\.](#28)  
[__::term::ansi::send::sda\_fgblack__](#29)  
[__::term::ansi::send::sda\_fgred__](#30)  
[__::term::ansi::send::sda\_fggreen__](#31)  
[__::term::ansi::send::sda\_fgyellow__](#32)  
[__::term::ansi::send::sda\_fgblue__](#33)  
[__::term::ansi::send::sda\_fgmagenta__](#34)  
[__::term::ansi::send::sda\_fgcyan__](#35)  
[__::term::ansi::send::sda\_fgwhite__](#36)  
[__::term::ansi::send::sda\_fgdefault__](#37)  
[__::term::ansi::send::sda\_bgblack__](#38)  
[__::term::ansi::send::sda\_bgred__](#39)  
[__::term::ansi::send::sda\_bggreen__](#40)  
[__::term::ansi::send::sda\_bgyellow__](#41)  
[__::term::ansi::send::sda\_bgblue__](#42)  
[__::term::ansi::send::sda\_bgmagenta__](#43)  
[__::term::ansi::send::sda\_bgcyan__](#44)  
[__::term::ansi::send::sda\_bgwhite__](#45)  
[__::term::ansi::send::sda\_bgdefault__](#46)  
[__::term::ansi::send::sda\_bold__](#47)  
[__::term::ansi::send::sda\_dim__](#48)  
[__::term::ansi::send::sda\_italic__](#49)  
[__::term::ansi::send::sda\_underline__](#50)  
[__::term::ansi::send::sda\_blink__](#51)  
[__::term::ansi::send::sda\_revers__](#52)  
[__::term::ansi::send::sda\_hidden__](#53)  
[__::term::ansi::send::sda\_strike__](#54)  
[__::term::ansi::send::sda\_nobold__](#55)  
[__::term::ansi::send::sda\_noitalic__](#56)  
[__::term::ansi::send::sda\_nounderline__](#57)  
[__::term::ansi::send::sda\_noblink__](#58)  
[__::term::ansi::send::sda\_norevers__](#59)  
[__::term::ansi::send::sda\_nohidden__](#60)  
[__::term::ansi::send::sda\_nostrike__](#61)  
[__::term::ansi::send::sda\_reset__](#62)  
[__::term::ansi::send::fcp__ *row* *col*](#63)  
[__::term::ansi::send::cu__ ?*n*?](#64)  
[__::term::ansi::send::cd__ ?*n*?](#65)  
[__::term::ansi::send::cf__ ?*n*?](#66)  
[__::term::ansi::send::cb__ ?*n*?](#67)  
[__::term::ansi::send::ss__ ?*s* *e*?](#68)  
[__::term::ansi::send::skd__ *code* *str*](#69)  
[__::term::ansi::send::title__ *str*](#70)  
[__::term::ansi::send::gron__](#71)  
[__::term::ansi::send::groff__](#72)  
[__::term::ansi::send::tlc__](#73)  
[__::term::ansi::send::trc__](#74)  
[__::term::ansi::send::brc__](#75)  
[__::term::ansi::send::blc__](#76)  
[__::term::ansi::send::ltj__](#77)  
[__::term::ansi::send::ttj__](#78)  
[__::term::ansi::send::rtj__](#79)  
[__::term::ansi::send::btj__](#80)  
[__::term::ansi::send::fwj__](#81)  
[__::term::ansi::send::hl__](#82)  
[__::term::ansi::send::vl__](#83)  
[__::term::ansi::send::groptim__ *str*](#84)  
[__::term::ansi::send::clear__](#85)  
[__::term::ansi::send::init__](#86)  
[__::term::ansi::send::showat__ *row* *col* *text*](#87)  

# <a name='description'></a>DESCRIPTION

This package provides commands to send ANSI terminal control sequences to a
terminal\. All commands come in two variants, one for sending to any channel, the
other for sending to *stdout*\.

The commands are defined using the control sequences provided by the package
__[term::ansi::code::ctrl](ansi\_cctrl\.md)__\. They have the same
arguments as the commands they are based on, with the exception of the variant
for sending to any channel\. Their first argument is always a channel handle,
then followed by the original arguments\. Below we will list only the variant
sending to *stdout*\.

  - <a name='1'></a>__::term::ansi::send::import__ ?*ns*? *\.\.\.*

    Imports the commands of this package into the namespace *ns*\. If not
    specified it defaults to *send*\. Note that this default is a relative
    namespace name, i\.e\. the actual namespace will be created under the current
    namespace\.

    By default all commands will be imported, this can however be restricted to
    specific commands, by listing them after the namespace to import them into\.

  - <a name='2'></a>__::term::ansi::send::eeol__

    Erase \(to\) End Of Line\.

  - <a name='3'></a>__::term::ansi::send::esol__

    Erase \(to\) Start Of Line\.

  - <a name='4'></a>__::term::ansi::send::el__

    Erase \(current\) Line\.

  - <a name='5'></a>__::term::ansi::send::ed__

    Erase Down \(to bottom\)\.

  - <a name='6'></a>__::term::ansi::send::eu__

    Erase Up \(to top\)\.

  - <a name='7'></a>__::term::ansi::send::es__

    Erase Screen\.

  - <a name='8'></a>__::term::ansi::send::sd__

    Scroll Down\.

  - <a name='9'></a>__::term::ansi::send::su__

    Scroll Up\.

  - <a name='10'></a>__::term::ansi::send::ch__

    Cursor Home\.

  - <a name='11'></a>__::term::ansi::send::sc__

    Save Cursor\. Note: Only one saved position can be handled\. This is no
    unlimited stack\. Saving before restoring will overwrite the saved data\.

  - <a name='12'></a>__::term::ansi::send::rc__

    Restore Cursor \(Unsave\)\.

  - <a name='13'></a>__::term::ansi::send::sca__

    Save Cursor \+ Attributes\.

  - <a name='14'></a>__::term::ansi::send::rca__

    Restore Cursor \+ Attributes\.

  - <a name='15'></a>__::term::ansi::send::st__

    Set Tab \(@ current position\)\.

  - <a name='16'></a>__::term::ansi::send::ct__

    Clear Tab \(@ current position\)\.

  - <a name='17'></a>__::term::ansi::send::cat__

    Clear All Tabs\.

  - <a name='18'></a>__::term::ansi::send::qdc__

    Query Device Code\.

  - <a name='19'></a>__::term::ansi::send::qds__

    Query Device Status\.

  - <a name='20'></a>__::term::ansi::send::qcp__

    Query Cursor Position\.

  - <a name='21'></a>__::term::ansi::send::rd__

    Reset Device\.

  - <a name='22'></a>__::term::ansi::send::elw__

    Enable Line Wrap\.

  - <a name='23'></a>__::term::ansi::send::dlw__

    Disable Line Wrap\.

  - <a name='24'></a>__::term::ansi::send::eg__

    Enter Graphics Mode\.

  - <a name='25'></a>__::term::ansi::send::lg__

    Exit Graphics Mode\.

  - <a name='26'></a>__::term::ansi::send::scs0__ *tag*

  - <a name='27'></a>__::term::ansi::send::scs1__ *tag*

    Select Character Set\.

    Choose which character set is used for default \(scs0\) and alternate font
    \(scs1\)\. This does not change whether default or alternate font are used,
    just their definitions\.

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

  - <a name='28'></a>__::term::ansi::send::sda__ *arg*\.\.\.

    Set Display Attributes\. The arguments are the code sequences for the
    possible attributes, as provided by the package
    __[term::ansi::code::attr](ansi\_cattr\.md)__\. For convenience this
    package also provides additional commands each setting a single specific
    attribute\.

  - <a name='29'></a>__::term::ansi::send::sda\_fgblack__

    Set text color to *Black*\.

  - <a name='30'></a>__::term::ansi::send::sda\_fgred__

    Set text color to *Red*\.

  - <a name='31'></a>__::term::ansi::send::sda\_fggreen__

    Set text color to *Green*\.

  - <a name='32'></a>__::term::ansi::send::sda\_fgyellow__

    Set text color to *Yellow*\.

  - <a name='33'></a>__::term::ansi::send::sda\_fgblue__

    Set text color to *Blue*\.

  - <a name='34'></a>__::term::ansi::send::sda\_fgmagenta__

    Set text color to *Magenta*\.

  - <a name='35'></a>__::term::ansi::send::sda\_fgcyan__

    Set text color to *Cyan*\.

  - <a name='36'></a>__::term::ansi::send::sda\_fgwhite__

    Set text color to *White*\.

  - <a name='37'></a>__::term::ansi::send::sda\_fgdefault__

    Set default text color \(*Black*\)\.

  - <a name='38'></a>__::term::ansi::send::sda\_bgblack__

    Set background to *Black*\.

  - <a name='39'></a>__::term::ansi::send::sda\_bgred__

    Set background to *Red*\.

  - <a name='40'></a>__::term::ansi::send::sda\_bggreen__

    Set background to *Green*\.

  - <a name='41'></a>__::term::ansi::send::sda\_bgyellow__

    Set background to *Yellow*\.

  - <a name='42'></a>__::term::ansi::send::sda\_bgblue__

    Set background to *Blue*\.

  - <a name='43'></a>__::term::ansi::send::sda\_bgmagenta__

    Set background to *Magenta*\.

  - <a name='44'></a>__::term::ansi::send::sda\_bgcyan__

    Set background to *Cyan*\.

  - <a name='45'></a>__::term::ansi::send::sda\_bgwhite__

    Set background to *White*\.

  - <a name='46'></a>__::term::ansi::send::sda\_bgdefault__

    Set default background \(Transparent\)\.

  - <a name='47'></a>__::term::ansi::send::sda\_bold__

    Bold on\.

  - <a name='48'></a>__::term::ansi::send::sda\_dim__

    Dim on\.

  - <a name='49'></a>__::term::ansi::send::sda\_italic__

    Italics on\.

  - <a name='50'></a>__::term::ansi::send::sda\_underline__

    Underscore on\.

  - <a name='51'></a>__::term::ansi::send::sda\_blink__

    Blink on\.

  - <a name='52'></a>__::term::ansi::send::sda\_revers__

    Reverse on\.

  - <a name='53'></a>__::term::ansi::send::sda\_hidden__

    Hidden on\.

  - <a name='54'></a>__::term::ansi::send::sda\_strike__

    Strike\-through on\.

  - <a name='55'></a>__::term::ansi::send::sda\_nobold__

    Bold off\.

  - <a name='56'></a>__::term::ansi::send::sda\_noitalic__

    Italics off\.

  - <a name='57'></a>__::term::ansi::send::sda\_nounderline__

    Underscore off\.

  - <a name='58'></a>__::term::ansi::send::sda\_noblink__

    Blink off\.

  - <a name='59'></a>__::term::ansi::send::sda\_norevers__

    Reverse off\.

  - <a name='60'></a>__::term::ansi::send::sda\_nohidden__

    Hidden off\.

  - <a name='61'></a>__::term::ansi::send::sda\_nostrike__

    Strike\-through off\.

  - <a name='62'></a>__::term::ansi::send::sda\_reset__

    Reset all attributes to their default values\.

  - <a name='63'></a>__::term::ansi::send::fcp__ *row* *col*

    Force Cursor Position \(aka Go To\)\.

  - <a name='64'></a>__::term::ansi::send::cu__ ?*n*?

    Cursor Up\. *n* defaults to 1\.

  - <a name='65'></a>__::term::ansi::send::cd__ ?*n*?

    Cursor Down\. *n* defaults to 1\.

  - <a name='66'></a>__::term::ansi::send::cf__ ?*n*?

    Cursor Forward\. *n* defaults to 1\.

  - <a name='67'></a>__::term::ansi::send::cb__ ?*n*?

    Cursor Backward\. *n* defaults to 1\.

  - <a name='68'></a>__::term::ansi::send::ss__ ?*s* *e*?

    Scroll Screen \(entire display, or between rows start end, inclusive\)\.

  - <a name='69'></a>__::term::ansi::send::skd__ *code* *str*

    Set Key Definition\.

  - <a name='70'></a>__::term::ansi::send::title__ *str*

    Set the terminal title\.

  - <a name='71'></a>__::term::ansi::send::gron__

    Switch to character/box graphics\. I\.e\. switch to the alternate font\.

  - <a name='72'></a>__::term::ansi::send::groff__

    Switch to regular characters\. I\.e\. switch to the default font\.

  - <a name='73'></a>__::term::ansi::send::tlc__

    Character graphics, Top Left Corner\.

  - <a name='74'></a>__::term::ansi::send::trc__

    Character graphics, Top Right Corner\.

  - <a name='75'></a>__::term::ansi::send::brc__

    Character graphics, Bottom Right Corner\.

  - <a name='76'></a>__::term::ansi::send::blc__

    Character graphics, Bottom Left Corner\.

  - <a name='77'></a>__::term::ansi::send::ltj__

    Character graphics, Left T Junction\.

  - <a name='78'></a>__::term::ansi::send::ttj__

    Character graphics, Top T Junction\.

  - <a name='79'></a>__::term::ansi::send::rtj__

    Character graphics, Right T Junction\.

  - <a name='80'></a>__::term::ansi::send::btj__

    Character graphics, Bottom T Junction\.

  - <a name='81'></a>__::term::ansi::send::fwj__

    Character graphics, Four\-Way Junction\.

  - <a name='82'></a>__::term::ansi::send::hl__

    Character graphics, Horizontal Line\.

  - <a name='83'></a>__::term::ansi::send::vl__

    Character graphics, Vertical Line\.

  - <a name='84'></a>__::term::ansi::send::groptim__ *str*

    Optimize character graphics\. The generator commands above create way to many
    superfluous commands shifting into and out of the graphics mode\. This
    command removes all shifts which are not needed\. To this end it also knows
    which characters will look the same in both modes, to handle strings created
    outside of this package\.

  - <a name='85'></a>__::term::ansi::send::clear__

    Clear screen\. In essence a sequence of CursorHome \+ EraseDown\.

  - <a name='86'></a>__::term::ansi::send::init__

    Initialize default and alternate fonts to ASCII and box graphics\.

  - <a name='87'></a>__::term::ansi::send::showat__ *row* *col* *text*

    Show the block of text at the specified location\.

# <a name='section2'></a>Bugs, Ideas, Feedback

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

[character output](\.\./\.\./\.\./\.\./index\.md\#character\_output),
[control](\.\./\.\./\.\./\.\./index\.md\#control),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
