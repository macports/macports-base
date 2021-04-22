
[//000000001]: # (debug \- debug narrative)
[//000000002]: # (Generated from file 'debug\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 200?, Colin McCormack, Wub Server Utilities)
[//000000004]: # (Copyright &copy; 2012\-2014, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (debug\(n\) 1\.0\.6 tcllib "debug narrative")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

debug \- debug narrative \- core

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require debug ?1\.0\.6?  

[__debug\.____tag__ *message* ?*level*?](#1)  
[__debug__ __2array__](#2)  
[__debug__ __define__ *tag*](#3)  
[__debug__ __header__ *text*](#4)  
[__debug__ __level__ *tag* ?*level*? ?*fd*?](#5)  
[__debug__ __names__](#6)  
[__debug__ __off__ *tag*](#7)  
[__debug__ __on__ *tag*](#8)  
[__debug__ __parray__ *arrayvarname*](#9)  
[__debug__ __pdict__ *dict*](#10)  
[__debug__ __hexl__ *data* ?*prefix*?](#11)  
[__debug__ __nl__](#12)  
[__debug__ __tab__](#13)  
[__debug__ __prefix__ *tag* ?*text*?](#14)  
[__debug__ __setting__ \(*tag* *level*\) \.\.\. ?*fd*?](#15)  
[__debug__ __suffix__ *tag* ?*text*?](#16)  
[__debug__ __trailer__ *text*](#17)  

# <a name='description'></a>DESCRIPTION

Debugging areas of interest are represented by 'tags' which have independently
settable levels of interest \(an integer, higher is more detailed\)\.

# <a name='section2'></a>API

  - <a name='1'></a>__debug\.____tag__ *message* ?*level*?

    For each known tag the package creates a command with this signature the
    user can then use to provide the debug narrative of the tag\. The narrative
    *message* is provided as a Tcl script whose value is
    __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__ed in the caller's scope if
    and only if the current level of interest for the *tag* matches or exceeds
    the call's *level* of detail\. This is useful, as one can place arbitrarily
    complex narrative in code without unnecessarily evaluating it\.

    See methods __level__ and __setting__ for querying and manipulating
    the current level of detail for tags\.

    The actually printed text consists of not only the *message*, but also
    global and tag\-specific prefix and suffix, should they exist, with each line
    in the message having the specified headers and trailers\.

    All these parts are __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__ableTcl
    scripts, which are substituted once per message before assembly\.

  - <a name='2'></a>__debug__ __2array__

    This method returns a dictionary mapping the names of all debug tags
    currently known to the package to their state and log level\. The latter are
    encoded in a single numeric value, where a negative number indicates an
    inactive tag at the level given by the absolute value, and a positive number
    is an active tag at that level\.

    See also method __settings__ below\.

  - <a name='3'></a>__debug__ __define__ *tag*

    This method registers the named *tag* with the package\. If the tag was not
    known before it is placed in an inactive state\. The state of an already
    known tag is left untouched\.

    The result of the method is the empty string\.

  - <a name='4'></a>__debug__ __header__ *text*

    This method defines a global
    __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__able Tcl script which
    provides a text printed before each line of output\.

    Note how this is tag\-independent\.

    Further note that the header substitution happens only once per actual
    printed message, i\.e\. all lines of the same message will have the same
    actual heading text\.

    The result of the method is the specified text\.

  - <a name='5'></a>__debug__ __level__ *tag* ?*level*? ?*fd*?

    This method sets the detail\-*level* for the *tag*, and the channel
    *fd* to write the tags narration into\. The level is an integer value >= 0
    defaulting to __1__\. The channel defaults to __stderr__\.

    The result of the method is the new detail\-level for the tag\.

  - <a name='6'></a>__debug__ __names__

    This method returns a list containing the names of all debug tags currently
    known to the package\.

  - <a name='7'></a>__debug__ __off__ *tag*

    This method registers the named *tag* with the package and sets it
    inactive\.

    The result of the method is the empty string\.

  - <a name='8'></a>__debug__ __on__ *tag*

    This method registers the named *tag* with the package, as active\.

    The result of the method is the empty string\.

  - <a name='9'></a>__debug__ __parray__ *arrayvarname*

    This is a convenience method formatting the named array like the builtin
    command __parray__, except it returns the resulting string instead of
    writing it directly to __stdout__\.

    This makes it suitable for use in debug messages\.

  - <a name='10'></a>__debug__ __pdict__ *dict*

    This is a convenience method formatting the dictionary similarly to how the
    builtin command __parray__ does for array, and returns the resulting
    string\.

    This makes it suitable for use in debug messages\.

  - <a name='11'></a>__debug__ __hexl__ *data* ?*prefix*?

    This is a convenience method formatting arbitrary data into a hex\-dump and
    returns the resulting string\.

    This makes it suitable for use in debug messages\.

    Each line of the dump is prefixed with *prefix*\. This prefix defaults to
    the empty string\.

  - <a name='12'></a>__debug__ __nl__

    This is a convenience method to insert a linefeed character \(ASCII 0x0a\)
    into a debug message\.

  - <a name='13'></a>__debug__ __tab__

    This is a convenience method to insert a TAB character \(ASCII 0x09\) into a
    debug message\.

  - <a name='14'></a>__debug__ __prefix__ *tag* ?*text*?

    This method is similar to the method __header__ above, in that it
    defines __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__able Tcl script which
    provides more text for debug messages\.

    In contrast to __header__ the generated text is added to the user's
    message before it is split into lines, making it a per\-message extension\.

    Furthermore the script is tag\-dependent\.

    In exception to that, a script for tag __::__ is applied to all
    messages\.

    If both global and tag\-dependent prefix exist, both are applied, with the
    global prefix coming before the tag\-dependent prefix\.

    Note that the prefix substitution happens only once per actual printed
    message\.

    The result of the method is the empty string\.

    If the *tag* was not known at the time of the call it is registered, and
    set inactive\.

  - <a name='15'></a>__debug__ __setting__ \(*tag* *level*\) \.\.\. ?*fd*?

    This method is a multi\-tag variant of method __level__ above, with the
    functionality of methods __on__, and __off__ also folded in\.

    Each named *tag* is set to the detail\-*level* following it, with a
    negative level deactivating the tag, and a positive level activating it\.

    If the last argument is not followed by a level it is not treated as tag
    name, but as the channel all the named tags should print their messages to\.

    The result of the method is the empty string\.

  - <a name='16'></a>__debug__ __suffix__ *tag* ?*text*?

    This method is similar to the method __trailer__ below, in that it
    defines __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__able Tcl script which
    provides more text for debug messages\.

    In contrast to __trailer__ the generated text is added to the user's
    message before it is split into lines, making it a per\-message extension\.

    Furthermore the script is tag\-dependent\.

    In exception to that, a script for tag __::__ is applied to all
    messages\.

    If both global and tag\-dependent suffix exist, both are applied, with the
    global suffix coming after the tag\-dependent suffix\.

    Note that the suffix substitution happens only once per actual printed
    message\.

    The result of the method is the empty string\.

    If the *tag* was not known at the time of the call it is registered, and
    set inactive\.

  - <a name='17'></a>__debug__ __trailer__ *text*

    This method defines a global
    __[subst](\.\./\.\./\.\./\.\./index\.md\#subst)__able Tcl script which
    provides a text printed after each line of output \(before the EOL however\)\.

    Note how this is tag\-independent\.

    Further note that the trailer substitution happens only once per actual
    printed message, i\.e\. all lines of the same message will have the same
    actual trailing text\.

    The result of the method is the specified text\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *debug* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[debug](\.\./\.\./\.\./\.\./index\.md\#debug), [log](\.\./\.\./\.\./\.\./index\.md\#log),
[narrative](\.\./\.\./\.\./\.\./index\.md\#narrative),
[trace](\.\./\.\./\.\./\.\./index\.md\#trace)

# <a name='category'></a>CATEGORY

debugging, tracing, and logging

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 200?, Colin McCormack, Wub Server Utilities  
Copyright &copy; 2012\-2014, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
