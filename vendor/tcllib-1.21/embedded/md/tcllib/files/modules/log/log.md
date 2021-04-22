
[//000000001]: # (log \- Logging facility)
[//000000002]: # (Generated from file 'log\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2001\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (log\(n\) 1\.4 tcllib "Logging facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

log \- Procedures to log messages of libraries and applications\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [LEVELS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8  
package require log ?1\.4?  

[__::log::levels__](#1)  
[__::log::lv2longform__ *level*](#2)  
[__::log::lv2color__ *level*](#3)  
[__::log::lv2priority__ *level*](#4)  
[__::log::lv2cmd__ *level*](#5)  
[__::log::lv2channel__ *level*](#6)  
[__::log::lvCompare__ *level1* *level2*](#7)  
[__::log::lvSuppress__ *level* \{*suppress* 1\}](#8)  
[__::log::lvSuppressLE__ *level* \{*suppress* 1\}](#9)  
[__::log::lvIsSuppressed__ *level*](#10)  
[__::log::lvCmd__ *level* *cmd*](#11)  
[__::log::lvCmdForall__ *cmd*](#12)  
[__::log::lvChannel__ *level* *chan*](#13)  
[__::log::lvChannelForall__ *chan*](#14)  
[__::log::lvColor__ *level* *color*](#15)  
[__::log::lvColorForall__ *color*](#16)  
[__::log::log__ *level* *text*](#17)  
[__::log::logarray__ *level* *arrayvar* ?*pattern*?](#18)  
[__::log::loghex__ *level* *text* *data*](#19)  
[__::log::logsubst__ *level* *msg*](#20)  
[__::log::logMsg__ *text*](#21)  
[__::log::logError__ *text*](#22)  
[__::log::Puts__ *level* *text*](#23)  

# <a name='description'></a>DESCRIPTION

The __log__ package provides commands that allow libraries and applications
to selectively log information about their internal operation and state\.

To use the package just execute

    package require log
    log::log notice "Some message"

As can be seen above, each message given to the log facility is associated with
a *level* determining the importance of the message\. The user can then select
which levels to log, what commands to use for the logging of each level and the
channel to write the message to\. In the following example the logging of all
message with level __debug__ is deactivated\.

    package require log
    log::lvSuppress debug
    log::log debug "Unseen message" ; # No output

By default all messages associated with an error\-level \(__emergency__,
__alert__, __critical__, and __error__\) are written to
__stderr__\. Messages with any other level are written to __stdout__\. In
the following example the log module is reconfigured to write __debug__
messages to __stderr__ too\.

    package require log
    log::lvChannel debug stderr
    log::log debug "Written to stderr"

Each message level is also associated with a command to use when logging a
message with that level\. The behaviour above for example relies on the fact that
all message levels use by default the standard command __::log::Puts__ to
log any message\. In the following example all messages of level __notice__
are given to the non\-standard command __toText__ for logging\. This disables
the channel setting for such messages, assuming that __toText__ does not use
it by itself\.

    package require log
    log::lvCmd notice toText
    log::log notice "Handled by \"toText\""

Another database maintained by this facility is a map from message levels to
colors\. The information in this database has *no* influence on the behaviour
of the module\. It is merely provided as a convenience and in anticipation of the
usage of this facility in __tk__\-based application which may want to
colorize message logs\.

# <a name='section2'></a>API

The following commands are available:

  - <a name='1'></a>__::log::levels__

    Returns the names of all known levels, in alphabetical order\.

  - <a name='2'></a>__::log::lv2longform__ *level*

    Converts any unique abbreviation of a level name to the full level name\.

  - <a name='3'></a>__::log::lv2color__ *level*

    Converts any level name including unique abbreviations to the corresponding
    color\.

  - <a name='4'></a>__::log::lv2priority__ *level*

    Converts any level name including unique abbreviations to the corresponding
    priority\.

  - <a name='5'></a>__::log::lv2cmd__ *level*

    Converts any level name including unique abbreviations to the command prefix
    used to write messages with that level\.

  - <a name='6'></a>__::log::lv2channel__ *level*

    Converts any level name including unique abbreviations to the channel used
    by __::log::Puts__ to write messages with that level\.

  - <a name='7'></a>__::log::lvCompare__ *level1* *level2*

    Compares two levels \(including unique abbreviations\) with respect to their
    priority\. This command can be used by the \-command option of lsort\. The
    result is one of \-1, 0 or 1 or an error\. A result of \-1 signals that level1
    is of less priority than level2\. 0 signals that both levels have the same
    priority\. 1 signals that level1 has higher priority than level2\.

  - <a name='8'></a>__::log::lvSuppress__ *level* \{*suppress* 1\}

    \(Un\)suppresses the output of messages having the specified level\. Unique
    abbreviations for the level are allowed here too\.

  - <a name='9'></a>__::log::lvSuppressLE__ *level* \{*suppress* 1\}

    \(Un\)suppresses the output of messages having the specified level or one of
    lesser priority\. Unique abbreviations for the level are allowed here too\.

  - <a name='10'></a>__::log::lvIsSuppressed__ *level*

    Asks the package whether the specified level is currently suppressed\. Unique
    abbreviations of level names are allowed\.

  - <a name='11'></a>__::log::lvCmd__ *level* *cmd*

    Defines for the specified level with which command to write the messages
    having this level\. Unique abbreviations of level names are allowed\. The
    command is actually a command prefix and this facility will append 2
    arguments before calling it, the level of the message and the message
    itself, in this order\.

  - <a name='12'></a>__::log::lvCmdForall__ *cmd*

    Defines for all known levels with which command to write the messages having
    this level\. The command is actually a command prefix and this facility will
    append 2 arguments before calling it, the level of the message and the
    message itself, in this order\.

  - <a name='13'></a>__::log::lvChannel__ *level* *chan*

    Defines for the specified level into which channel __::log::Puts__ \(the
    standard command\) shall write the messages having this level\. Unique
    abbreviations of level names are allowed\. The command is actually a command
    prefix and this facility will append 2 arguments before calling it, the
    level of the message and the message itself, in this order\.

  - <a name='14'></a>__::log::lvChannelForall__ *chan*

    Defines for all known levels with which which channel __::log::Puts__
    \(the standard command\) shall write the messages having this level\. The
    command is actually a command prefix and this facility will append 2
    arguments before calling it, the level of the message and the message
    itself, in this order\.

  - <a name='15'></a>__::log::lvColor__ *level* *color*

    Defines for the specified level the color to return for it in a call to
    __::log::lv2color__\. Unique abbreviations of level names are allowed\.

  - <a name='16'></a>__::log::lvColorForall__ *color*

    Defines for all known levels the color to return for it in a call to
    __::log::lv2color__\. Unique abbreviations of level names are allowed\.

  - <a name='17'></a>__::log::log__ *level* *text*

    Log a message according to the specifications for commands, channels and
    suppression\. In other words: The command will do nothing if the specified
    level is suppressed\. If it is not suppressed the actual logging is delegated
    to the specified command\. If there is no command specified for the level the
    message won't be logged\. The standard command __::log::Puts__ will write
    the message to the channel specified for the given level\. If no channel is
    specified for the level the message won't be logged\. Unique abbreviations of
    level names are allowed\. Errors in the actual logging command are *not*
    caught, but propagated to the caller, as they may indicate misconfigurations
    of the log facility or errors in the callers code itself\.

  - <a name='18'></a>__::log::logarray__ *level* *arrayvar* ?*pattern*?

    Like __::log::log__, but logs the contents of the specified array
    variable *arrayvar*, possibly restricted to entries matching the
    *pattern*\. The pattern defaults to __\*__ \(i\.e\. all entries\) if none
    was specified\.

  - <a name='19'></a>__::log::loghex__ *level* *text* *data*

    Like __::log::log__, but assumes that *data* contains binary data\. It
    converts this into a mixed hex/ascii representation before writing them to
    the log\.

  - <a name='20'></a>__::log::logsubst__ *level* *msg*

    Like __::log::log__, but *msg* may contain substitutions and variable
    references, which are evaluated in the caller scope first\. The purpose of
    this command is to avoid overhead in the non\-logging case, if the log
    message building is expensive\. Any substitution errors raise an error in the
    command execution\. The following example shows an xml text representation,
    which is only generated in debug mode:

    log::logsubst debug {XML of node $node is '[$node toXml]'}

  - <a name='21'></a>__::log::logMsg__ *text*

    Convenience wrapper around __::log::log__\. Equivalent to __::log::log
    info text__\.

  - <a name='22'></a>__::log::logError__ *text*

    Convenience wrapper around __::log::log__\. Equivalent to __::log::log
    error text__\.

  - <a name='23'></a>__::log::Puts__ *level* *text*

    The standard log command, it writes messages and their levels to
    user\-specified channels\. Assumes that the suppression checks were done by
    the caller\. Expects full level names, abbreviations are *not allowed*\.

# <a name='section3'></a>LEVELS

The package currently defines the following log levels, the level of highest
importance listed first\.

  - emergency

  - alert

  - critical

  - error

  - warning

  - notice

  - info

  - debug

*Note* that by default all messages with levels __warning__ down to
__debug__ are suppressed\. This is done intentionally, because \(we believe
that\) in most situations debugging output is not wanted\. Most people wish to
have such output only when actually debugging an application\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *log* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[log](\.\./\.\./\.\./\.\./index\.md\#log), [log
level](\.\./\.\./\.\./\.\./index\.md\#log\_level),
[message](\.\./\.\./\.\./\.\./index\.md\#message), [message
level](\.\./\.\./\.\./\.\./index\.md\#message\_level)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2001\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
