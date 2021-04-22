
[//000000001]: # (page\_pluginmgr \- Parser generator tools)
[//000000002]: # (Generated from file 'page\_pluginmgr\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (page\_pluginmgr\(n\) 1\.0 tcllib "Parser generator tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

page\_pluginmgr \- page plugin manager

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [CONFIG PLUGIN API](#section3)

  - [READER PLUGIN API](#section4)

  - [WRITER PLUGIN API](#section5)

  - [TRANSFORM PLUGIN API](#section6)

  - [PREDEFINED PLUGINS](#section7)

  - [FEATURES](#section8)

  - [Bugs, Ideas, Feedback](#section9)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require page::pluginmgr ?0\.2?  
package require fileutil  

[__::page::pluginmgr::reportvia__ *cmd*](#1)  
[__::page::pluginmgr::report__ *level* *text* ?*from* ?*to*??](#2)  
[__::page::pluginmgr::log__ *cmd*](#3)  
[__::page::pluginmgr::configuration__ *name*](#4)  
[__::page::pluginmgr::reader__ *name*](#5)  
[__::page::pluginmgr::rconfigure__ *dict*](#6)  
[__::page::pluginmgr::rtimeable__](#7)  
[__::page::pluginmgr::rtime__](#8)  
[__::page::pluginmgr::rgettime__](#9)  
[__::page::pluginmgr::rhelp__](#10)  
[__::page::pluginmgr::rlabel__](#11)  
[__::page::pluginmgr::read__ *read* *eof* ?*complete*?](#12)  
[*read* *num*](#13)  
[*eof*](#14)  
[*done*](#15)  
[__::page::pluginmgr::writer__ *name*](#16)  
[__::page::pluginmgr::wconfigure__ *dict*](#17)  
[__::page::pluginmgr::wtimeable__](#18)  
[__::page::pluginmgr::wtime__](#19)  
[__::page::pluginmgr::wgettime__](#20)  
[__::page::pluginmgr::whelp__](#21)  
[__::page::pluginmgr::wlabel__](#22)  
[__::page::pluginmgr::write__ *chan* *data*](#23)  
[__::page::pluginmgr::transform__ *name*](#24)  
[__::page::pluginmgr::tconfigure__ *id* *dict*](#25)  
[__::page::pluginmgr::ttimeable__ *id*](#26)  
[__::page::pluginmgr::ttime__ *id*](#27)  
[__::page::pluginmgr::tgettime__ *id*](#28)  
[__::page::pluginmgr::thelp__ *id*](#29)  
[__::page::pluginmgr::tlabel__ *id*](#30)  
[__::page::pluginmgr::transform\_do__ *id* *data*](#31)  
[__page\_cdefinition__](#32)  
[__page\_rfeature__ *name*](#33)  
[__page\_rtime__](#34)  
[__page\_rgettime__](#35)  
[__page\_rlabel__](#36)  
[__page\_rhelp__](#37)  
[__page\_roptions__](#38)  
[__page\_rconfigure__ *option* *value*](#39)  
[__page\_rrun__](#40)  
[__page\_read__ *num*](#41)  
[__page\_read\_done__](#42)  
[__page\_eof__](#43)  
[__page\_info__ *text* ?*from* ?*to*??](#44)  
[__page\_warning__ *text* ?*from* ?*to*??](#45)  
[__page\_error__ *text* ?*from* ?*to*??](#46)  
[__page\_log\_info__ *text*](#47)  
[__page\_log\_warning__ *text*](#48)  
[__page\_log\_error__ *text*](#49)  
[__page\_wfeature__](#50)  
[__page\_wtime__](#51)  
[__page\_wgettime__](#52)  
[__page\_wlabel__](#53)  
[__page\_whelp__](#54)  
[__page\_woptions__](#55)  
[__page\_wconfigure__ *option* *value*](#56)  
[__page\_wrun__ *chan* *data*](#57)  
[__page\_info__ *text* ?*from* ?*to*??](#58)  
[__page\_warning__ *text* ?*from* ?*to*??](#59)  
[__page\_error__ *text* ?*from* ?*to*??](#60)  
[__page\_log\_info__ *text*](#61)  
[__page\_log\_warning__ *text*](#62)  
[__page\_log\_error__ *text*](#63)  
[__page\_tfeature__](#64)  
[__page\_ttime__](#65)  
[__page\_tgettime__](#66)  
[__page\_tlabel__](#67)  
[__page\_thelp__](#68)  
[__page\_toptions__](#69)  
[__page\_tconfigure__ *option* *value*](#70)  
[__page\_trun__ *chan* *data*](#71)  
[__page\_info__ *text* ?*from* ?*to*??](#72)  
[__page\_warning__ *text* ?*from* ?*to*??](#73)  
[__page\_error__ *text* ?*from* ?*to*??](#74)  
[__page\_log\_info__ *text*](#75)  
[__page\_log\_warning__ *text*](#76)  
[__page\_log\_error__ *text*](#77)  

# <a name='description'></a>DESCRIPTION

This package provides the plugin manager central to the
__[page](\.\./\.\./apps/page\.md)__ application\. It manages the various
reader, writer, configuration, and transformation plugins which actually process
the text \(read, transform, and write\)\.

All plugins are loaded into slave interpreters specially prepared for them\.
While implemented using packages they need this special environment and are not
usable in a plain interpreter, like tclsh\. Because of that they are only
described in general terms in section [PREDEFINED PLUGINS](#section7), and
not documented as regular packages\. It is expected that they follow the APIs
specified in the sections

  1. [CONFIG PLUGIN API](#section3)

  1. [READER PLUGIN API](#section4)

  1. [WRITER PLUGIN API](#section5)

  1. [TRANSFORM PLUGIN API](#section6)

as per their type\.

# <a name='section2'></a>API

  - <a name='1'></a>__::page::pluginmgr::reportvia__ *cmd*

    This command defines the callback command used by
    __::page::pluginmgr::report__ \(see below\) to report input errors and
    warnings\. The default is to write such reports to the standard error
    channel\.

  - <a name='2'></a>__::page::pluginmgr::report__ *level* *text* ?*from* ?*to*??

    This command is used to report input errors and warnings\. By default such
    reports are written to the standard error\. This can be changed by setting a
    user\-specific callback command with __::page::pluginmgr::reportvia__
    \(see above\)\.

    The arguments *level* and *text* specify both the importance of the
    message, and the message itself\. For the former see the package
    __[logger](\.\./log/logger\.md)__ for the allowed values\.

    The optional argument *from* and *to* can be used by the caller to
    indicate the location \(or range\) in the input where the reported problem
    occured\. Each is a list containing two elements, the line and the column in
    the input, in this order\.

  - <a name='3'></a>__::page::pluginmgr::log__ *cmd*

    This command defines a log callback command to be used by loaded plugins for
    the reporting of internal errors, warnings, and general information\.
    Specifying the empty string as callback disables logging\.

    Note: The *cmd* has to be created by the
    __[logger](\.\./log/logger\.md)__ package, or follow the same API as
    such\.

    The command returns the empty string as its result\.

  - <a name='4'></a>__::page::pluginmgr::configuration__ *name*

    This command loads the named configuration plugin, retrieves the options
    encoded in it, and then immediately unloads it again\.

    If the *name* is the path to a file, then this files will be tried to be
    loaded as a plugin first, and, if that fails, opened and its contents read
    as a list of options and their arguments, separated by spaces, tabs and
    newlines, possibly quotes with single and double quotes\.

    See section [CONFIG PLUGIN API](#section3) for the API expected of
    configuration plugins\.

    The result of the command is the list of options retrieved\.

  - <a name='5'></a>__::page::pluginmgr::reader__ *name*

    This command loads the named reader plugin and initializes it\. The result of
    the command is a list of options the plugin understands\.

    Only a single reader plugin can be loaded\. Loading another reader plugin
    causes the previously loaded reader plugin to be de\-initialized and
    unloaded\.

    See section [READER PLUGIN API](#section4) for the API expected of
    reader plugins\.

  - <a name='6'></a>__::page::pluginmgr::rconfigure__ *dict*

    This commands configures the loaded reader plugin\. The options and their
    values are provided as a Tcl dictionary\. The result of the command is the
    empty string\.

  - <a name='7'></a>__::page::pluginmgr::rtimeable__

    This commands checks if the loaded reader plugin is able to collect timing
    statistics\. The result of the command is a boolean flag\. The result is
    __true__ if the plugin can be timed, and __false__ otherwise\.

  - <a name='8'></a>__::page::pluginmgr::rtime__

    This command activates the collection of timing statistics in the loaded
    reader plugin\.

  - <a name='9'></a>__::page::pluginmgr::rgettime__

    This command retrieves the collected timing statistics of the loaded reader
    plugin after it was executed\.

  - <a name='10'></a>__::page::pluginmgr::rhelp__

    This command retrieves the help string of the loaded reader plugin\. This is
    expected to be in *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* format\.

  - <a name='11'></a>__::page::pluginmgr::rlabel__

    This command retrieves the human\-readable name of the loaded reader plugin\.

  - <a name='12'></a>__::page::pluginmgr::read__ *read* *eof* ?*complete*?

    This command invokes the loaded reader plugin to process the input, and
    returns the results of the plugin as its own result\. The input is accessible
    through the callback commands *read*, and *eof*\. The optional *done*
    can be used to intrecept when the plugin has completed its processing\. All
    arguments are command prefixes\.

    The plugin will invoke the various callbacks in the following situations:

      * <a name='13'></a>*read* *num*

        is invoked whenever input to process is needed, with the number of
        characters/bytes it asks for\. The result is expected to be the input the
        plugin is in need of\.

      * <a name='14'></a>*eof*

        is invoked by the plugin to check if the input has reached the of the
        stream\. The result is expected to be a boolean flag, __true__ when
        the input has hit EOF, and __false__ otherwise\.

      * <a name='15'></a>*done*

        is invoked when the plugin has completed the processing of the input\.

  - <a name='16'></a>__::page::pluginmgr::writer__ *name*

    This command loads the named writer plugin and initializes it\. The result of
    the command is a list of options the plugin understands\.

    Only a single reader plugin can be loaded\. Loading another reader plugin
    causes the previously loaded reader plugin to be de\-initialized and
    unloaded\.

    See section [WRITER PLUGIN API](#section5) for the API expected of
    writer plugins\.

  - <a name='17'></a>__::page::pluginmgr::wconfigure__ *dict*

    This commands configures the loaded writer plugin\. The options and their
    values are provided as a Tcl dictionary\. The result of the command is the
    empty string\.

  - <a name='18'></a>__::page::pluginmgr::wtimeable__

    This commands checks if the loaded writer plugin is able to measure
    execution times\. The result of the command is a boolean flag\. The result is
    __true__ if the plugin can be timed, and __false__ otherwise\.

  - <a name='19'></a>__::page::pluginmgr::wtime__

    This command activates the collection of timing statistics in the loaded
    writer plugin\.

  - <a name='20'></a>__::page::pluginmgr::wgettime__

    This command retrieves the collected timing statistics of the loaded writer
    plugin after it was executed\.

  - <a name='21'></a>__::page::pluginmgr::whelp__

    This command retrieves the help string of the loaded writer plugin\. This is
    expected to be in *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* format\.

  - <a name='22'></a>__::page::pluginmgr::wlabel__

    This command retrieves the human\-readable name of the loaded writer plugin\.

  - <a name='23'></a>__::page::pluginmgr::write__ *chan* *data*

    The loaded writer plugin is invoked to generate the output\. It is given the
    *data* to generate the outpout from, and the Tcl handle *chan* of the
    channel to write the generated output to\. The command returns th empty
    string as its result\.

  - <a name='24'></a>__::page::pluginmgr::transform__ *name*

    This command loads the named transformation plugin and initializes it\. The
    result of the command is a 2\-element list containing the plugin id and a
    list of options the plugin understands, in this order\.

    Multiple transformations plugins can be loaded and are identified by
    handles\.

    See section [TRANSFORM PLUGIN API](#section6) for the API expected of
    transformation plugins\.

  - <a name='25'></a>__::page::pluginmgr::tconfigure__ *id* *dict*

    This commands configures the identified transformation plugin\. The options
    and their values are provided as a Tcl dictionary\. The result of the command
    is the empty string\.

  - <a name='26'></a>__::page::pluginmgr::ttimeable__ *id*

    This commands checks if the identified transformation plugin is able to
    collect timing statistics\. The result of the command is a boolean flag\. The
    result is __true__ if the plugin can be timed, and __false__
    otherwise\.

  - <a name='27'></a>__::page::pluginmgr::ttime__ *id*

    This command activates the collection of timing statistics in the identified
    transformation plugin\.

  - <a name='28'></a>__::page::pluginmgr::tgettime__ *id*

    This command retrieves the collected timing statistics of the identified
    transformation plugin after it was executed\.

  - <a name='29'></a>__::page::pluginmgr::thelp__ *id*

    This command retrieves the help string of the identified transformation
    plugin\. This is expected to be in
    *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* format\.

  - <a name='30'></a>__::page::pluginmgr::tlabel__ *id*

    This command retrieves the human\-readable name of the identified
    transformation plugin\.

  - <a name='31'></a>__::page::pluginmgr::transform\_do__ *id* *data*

    The identified transformation plugin is invoked to process the specified
    *data*\. The result of the plugin is returned as the result of the command\.

# <a name='section3'></a>CONFIG PLUGIN API

Configuration plugins are expected to provide a single command, described below\.

  - <a name='32'></a>__page\_cdefinition__

    This command of a configuration plugin is called by the plugin manager to
    execute it\. Its result has to be a list of options and values to process\.

Configuration plugins do not expect the environment to provide any special
commands\.

It is expected that a configuration plugin __FOO__ is implemented by the
package __page::config::__FOO____\.

Configuration plugins are loaded, executed, and unloaded in one step, they are
not kept in memory\. The command for doing this is
__::page::pluginmgr::configuration__\.

# <a name='section4'></a>READER PLUGIN API

Reader plugins are expected to provide the following commands, described below\.

  - <a name='33'></a>__page\_rfeature__ *name*

    This command takes a feature *name* and returns a boolean flag indicating
    whether the feature is supported by the plugin, or not\. The result has to be
    __true__ if the feature is supported, and __false__ otherwise\.

    See section [FEATURES](#section8) for the possible features the plugin
    manager will ask for\.

  - <a name='34'></a>__page\_rtime__

    This command is invoked to activate the collection of timing statistics\.

  - <a name='35'></a>__page\_rgettime__

    This command is invoked to retrieve the collected timing statistics\.

  - <a name='36'></a>__page\_rlabel__

    This command is invoked to retrieve a human\-readable label for the plugin\.

  - <a name='37'></a>__page\_rhelp__

    This command is invoked to retrieve a help text for plugin\. The text is
    expected to be in *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* format\.

  - <a name='38'></a>__page\_roptions__

    This command is invoked to retrieve the options understood by the plugin\.

  - <a name='39'></a>__page\_rconfigure__ *option* *value*

    This command is invoked to reconfigure the plugin, specifically the given
    *option* is set to the new *value*\.

  - <a name='40'></a>__page\_rrun__

    This command is invoked to process the input stream per the current plugin
    configuration\. The result of the command is the result of the processing\.

Reader plugins expect the environment to provide the following special commands\.

  - <a name='41'></a>__page\_read__ *num*

    This command is invoked to read *num* characters/bytes from the input\. Its
    result has to be read characters/bytes\.

  - <a name='42'></a>__page\_read\_done__

    This command is invoked to signal that the plugin has completed the
    processing of the input\.

  - <a name='43'></a>__page\_eof__

    This command is invoked to check if the input stream has reached its end\.
    Its result has to be a boolean flag, __true__ when the input has reached
    the end, __false__ otherwise\.

  - <a name='44'></a>__page\_info__ *text* ?*from* ?*to*??

    Invoked to report some information to the user\. May indicate a location or
    range in the input\. Each piece of location data, if provided, is a 2\-element
    list containing line and column numbers\.

  - <a name='45'></a>__page\_warning__ *text* ?*from* ?*to*??

    Invoked to report a warning to the user\. May indicate a location or range in
    the input\. Each piece of location data, if provided, is a 2\-element list
    containing line and column numbers\.

  - <a name='46'></a>__page\_error__ *text* ?*from* ?*to*??

    Invoked to report an error to the user\. May indicate a location or range in
    the input\. Each piece of location data, if provided, is a 2\-element list
    containing line and column numbers\.

  - <a name='47'></a>__page\_log\_info__ *text*

    Invoked to report some internal information\.

  - <a name='48'></a>__page\_log\_warning__ *text*

    Invoked to report an internal warning\.

  - <a name='49'></a>__page\_log\_error__ *text*

    Invoked to report an internal error\.

It is expected that a reader plugin __FOO__ is implemented by the package
__page::reader::__FOO____\.

Reader plugins are loaded by the command __::page::pluginmgr::reader__\. At
most one reader plugin can be kept in memory\.

# <a name='section5'></a>WRITER PLUGIN API

Writer plugins are expected to provide the following commands, described below\.

  - <a name='50'></a>__page\_wfeature__

    This command takes a feature *name* and returns a boolean flag indicating
    whether the feature is supported by the plugin, or not\. The result has to be
    __true__ if the feature is supported, and __false__ otherwise\.

    See section [FEATURES](#section8) for the possible features the plugin
    manager will ask for\.

  - <a name='51'></a>__page\_wtime__

    This command is invoked to activate the collection of timing statistics\.

  - <a name='52'></a>__page\_wgettime__

    This command is invoked to retrieve the collected timing statistics\.

  - <a name='53'></a>__page\_wlabel__

    This command is invoked to retrieve a human\-readable label for the plugin\.

  - <a name='54'></a>__page\_whelp__

    This command is invoked to retrieve a help text for plugin\. The text is
    expected to be in *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* format\.

  - <a name='55'></a>__page\_woptions__

    This command is invoked to retrieve the options understood by the plugin\.

  - <a name='56'></a>__page\_wconfigure__ *option* *value*

    This command is invoked to reconfigure the plugin, specifically the given
    *option* is set to the new *value*\.

  - <a name='57'></a>__page\_wrun__ *chan* *data*

    This command is invoked to process the specified *data* and write it to
    the output stream *chan*\. The latter is a Tcl channel handle opened for
    writing\. The result of the command is the empty string\.

Writer plugins expect the environment to provide the following special commands\.

  - <a name='58'></a>__page\_info__ *text* ?*from* ?*to*??

    Invoked to report some information to the user\. May indicate a location or
    range in the input\. Each piece of location data, if provided, is a 2\-element
    list containing line and column numbers\.

  - <a name='59'></a>__page\_warning__ *text* ?*from* ?*to*??

    Invoked to report a warning to the user\. May indicate a location or range in
    the input\. Each piece of location data, if provided, is a 2\-element list
    containing line and column numbers\.

  - <a name='60'></a>__page\_error__ *text* ?*from* ?*to*??

    Invoked to report an error to the user\. May indicate a location or range in
    the input\. Each piece of location data, if provided, is a 2\-element list
    containing line and column numbers\.

  - <a name='61'></a>__page\_log\_info__ *text*

    Invoked to report some internal information\.

  - <a name='62'></a>__page\_log\_warning__ *text*

    Invoked to report an internal warning\.

  - <a name='63'></a>__page\_log\_error__ *text*

    Invoked to report an internal error\.

It is expected that a writer plugin __FOO__ is implemented by the package
__page::writer::__FOO____\.

Writer plugins are loaded by the command __::page::pluginmgr::writer__\. At
most one writer plugin can be kept in memory\.

# <a name='section6'></a>TRANSFORM PLUGIN API

page::transform::\* Transformation plugins are expected to provide the following
commands, described below\.

  - <a name='64'></a>__page\_tfeature__

    This command takes a feature *name* and returns a boolean flag indicating
    whether the feature is supported by the plugin, or not\. The result has to be
    __true__ if the feature is supported, and __false__ otherwise\.

    See section [FEATURES](#section8) for the possible features the plugin
    manager will ask for\.

  - <a name='65'></a>__page\_ttime__

    This command is invoked to activate the collection of timing statistics\.

  - <a name='66'></a>__page\_tgettime__

    This command is invoked to retrieve the collected timing statistics\.

  - <a name='67'></a>__page\_tlabel__

    This command is invoked to retrieve a human\-readable label for the plugin\.

  - <a name='68'></a>__page\_thelp__

    This command is invoked to retrieve a help text for plugin\. The text is
    expected to be in *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* format\.

  - <a name='69'></a>__page\_toptions__

    This command is invoked to retrieve the options understood by the plugin\.

  - <a name='70'></a>__page\_tconfigure__ *option* *value*

    This command is invoked to reconfigure the plugin, specifically the given
    *option* is set to the new *value*\.

  - <a name='71'></a>__page\_trun__ *chan* *data*

    This command is invoked to process the specified *data* and write it to
    the output stream *chan*\. The latter is a Tcl channel handle opened for
    writing\. The result of the command is the empty string\.

Transformation plugins expect the environment to provide the following special
commands\.

  - <a name='72'></a>__page\_info__ *text* ?*from* ?*to*??

    Invoked to report some information to the user\. May indicate a location or
    range in the input\. Each piece of location data, if provided, is a 2\-element
    list containing line and column numbers\.

  - <a name='73'></a>__page\_warning__ *text* ?*from* ?*to*??

    Invoked to report a warning to the user\. May indicate a location or range in
    the input\. Each piece of location data, if provided, is a 2\-element list
    containing line and column numbers\.

  - <a name='74'></a>__page\_error__ *text* ?*from* ?*to*??

    Invoked to report an error to the user\. May indicate a location or range in
    the input\. Each piece of location data, if provided, is a 2\-element list
    containing line and column numbers\.

  - <a name='75'></a>__page\_log\_info__ *text*

    Invoked to report some internal information\.

  - <a name='76'></a>__page\_log\_warning__ *text*

    Invoked to report an internal warning\.

  - <a name='77'></a>__page\_log\_error__ *text*

    Invoked to report an internal error\.

It is expected that a transformation plugin __FOO__ is implemented by the
package __page::transform::__FOO____\.

Transformation plugins are loaded by the command
__::page::pluginmgr::transform__\. More than one transformation plugin can be
kept in memory\.

# <a name='section7'></a>PREDEFINED PLUGINS

The following predefined plugins are known, i\.e\. provided by the page module\.

  - Configuration

      * peg

        Returns a set of options to configure the
        __[page](\.\./\.\./apps/page\.md)__ application for the processing of
        a PEG grammar and the generation of ME code\. See the packages
        __grammar\_peg__, __grammar\_me__ and relations for more details\.

  - Reader

      * hb

        Expects a so\-called *half\-baked PEG container* as input and returns
        the equivalent abstract syntax tree\. See the writer plugin *hb* for
        the plugin generating this type of input\.

      * lemon

        Expects a grammar specification as understood by Richar Hipp's LEMON
        parser generator and returns an abstract syntax tree for it\.

      * peg

        Expects a grammar specification in the form of a parsing expression
        grammar \(PEG\) and returns an abstract syntax tree for it\.

      * ser

        Expect the serialized form of a parsing expression grammar as generated
        by the package __[grammar::peg](\.\./grammar\_peg/peg\.md)__ as
        input, converts it into an equivalent abstract syntax tree and returns
        that\.

      * treeser

        Expects the serialized form of a tree as generated by the package
        __[struct::tree](\.\./struct/struct\_tree\.md)__ as input and
        returns it, after validation\.

  - Writer

      * hb

        Expects an abstract syntax tree for a parsing expression grammar as
        input and writes it out in the form of a so\-called *half\-baked PEG
        container*\.

      * identity

        Takes any input and writes it as is\.

      * mecpu

        Expects symbolic assembler code for the MatchEngine CPU \(See the package
        __[grammar::me::cpu](\.\./grammar\_me/me\_cpu\.md)__ and relatives\)
        and writes it out as Tcl code for a parser\.

      * me

        Expects an abstract syntax tree for a parsing expression grammar as
        input and writes it out as Tcl code for the MatchEngine \(See the package
        __grammar::me__ and relatives\) which parses input in that grammar\.

      * null

        Takes any input and writes nothing\. The logical equivalent of /dev/null\.

      * peg

        Expects an abstract syntax tree for a parsing expression grammar as
        input and writes it out in the form of a canonical PEG which can be read
        by the reader plugin *peg*\.

      * ser

        Expects an abstract syntax tree for a parsing expression grammar as
        input and writes it out as a serialized PEG container which can be read
        by the reader plugin *ser*\.

      * tpc

        Expects an abstract syntax tree for a parsing expression grammar as
        input and writes it out as Tcl code initializing a PEG container as
        provided by the package
        __[grammar::peg](\.\./grammar\_peg/peg\.md)__\.

      * tree

        Takes any serialized tree \(per package
        __[struct::tree](\.\./struct/struct\_tree\.md)__\) as input and
        writes it out in a generic indented format\.

  - Transformation

      * mecpu

        Takes an abstract syntax tree for a parsing expression grammer as input,
        generates symbolic assembler code for the MatchEngine CPU, and returns
        that as its result \(See the package
        __[grammar::me::cpu](\.\./grammar\_me/me\_cpu\.md)__ and relatives\)\.

      * reachable

        Takes an abstract syntax tree for a parsing expression grammer as input,
        performs a reachability analysis, and returns the modified and annotated
        tree\.

      * realizable

        Takes an abstract syntax tree for a parsing expression grammer as input,
        performs an analysis of realizability, and returns the modified and
        annotated tree\.

# <a name='section8'></a>FEATURES

The plugin manager currently checks the plugins for only one feature,
__timeable__\. A plugin supporting this feature is assumed to be able to
collect timing statistics on request\.

# <a name='section9'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *page* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[page](\.\./\.\./\.\./\.\./index\.md\#page), [parser
generator](\.\./\.\./\.\./\.\./index\.md\#parser\_generator), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing)

# <a name='category'></a>CATEGORY

Page Parser Generator

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
