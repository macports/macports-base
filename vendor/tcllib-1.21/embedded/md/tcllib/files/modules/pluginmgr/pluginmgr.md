
[//000000001]: # (pluginmgr \- Plugin management)
[//000000002]: # (Generated from file 'pluginmgr\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pluginmgr\(n\) 0\.3 tcllib "Plugin management")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pluginmgr \- Manage a plugin

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PUBLIC API](#section2)

      - [PACKAGE COMMANDS](#subsection1)

      - [OBJECT COMMAND](#subsection2)

      - [OBJECT METHODS](#subsection3)

      - [OBJECT CONFIGURATION](#subsection4)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require pluginmgr ?0\.3?  

[__::pluginmgr__ *objectName* ?*option value*\.\.\.?](#1)  
[__::pluginmgr::paths__ *objectName* *name*\.\.\.](#2)  
[__objectName__ __method__ ?*arg arg \.\.\.*?](#3)  
[*objectName* __clone__](#4)  
[*objectName* __configure__](#5)  
[*objectName* __configure__ *option*](#6)  
[*objectName* __configure__ __\-option__ *value*\.\.\.](#7)  
[*objectName* __cget__ __\-option__](#8)  
[*objectName* __destroy__](#9)  
[*objectName* __do__ *arg*\.\.\.](#10)  
[*objectName* __interpreter__](#11)  
[*objectName* __plugin__](#12)  
[*objectName* __load__ *string*](#13)  
[*objectName* __unload__](#14)  
[*objectName* __list__](#15)  
[*objectName* __path__ *path*](#16)  
[*objectName* __paths__](#17)  

# <a name='description'></a>DESCRIPTION

This package provides commands and objects for the generic management of plugins
which can be loaded into an application\.

To avoid the implementation of yet another system to locate Tcl code the system
provides by this package is built on top of the regular package management
system\. Each plugin is considered as a package and a simple invokation of
__package require__ is enough to locate and load it, if it exists\. The only
time we will need additional paths is when a plugin manager is part of a wrapped
application and has to be able to search for plugins existing outside of that
application\. For this situation the package provides a command to create a
general set of such paths based on names for the plugin manager and/or
application in question\.

The main contribution of this package is a generic framework which allows the
easy declaration of

  1. How to translate a plugin name to the name of the package implementing it,
     and vice versa\.

  1. The list of commands a plugin has to provide as API, and also of more
     complex checks as code\.

  1. The list of commands expected by the plugin from the environment\.

This then allows the easy generation of plugin managers customized to particular
types of plugins for an application\.

It should be noted that all plugin code is considered untrusted and will always
be executed within a safe interpreter\. The interpreter is enabled enough to
allow plugins the loading of all additional packages they may need\.

# <a name='section2'></a>PUBLIC API

## <a name='subsection1'></a>PACKAGE COMMANDS

  - <a name='1'></a>__::pluginmgr__ *objectName* ?*option value*\.\.\.?

    This command creates a new plugin manager object with an associated Tcl
    command whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [OBJECT COMMAND](#subsection2) and [OBJECT
    METHODS](#subsection3)\. The object command will be created under the
    current namespace if the *objectName* is not fully qualified, and in the
    specified namespace otherwise\.

    The options and their values coming after the name of the object are used to
    set the initial configuration of the mamager object, specifying the
    applicable plugins and their API\.

  - <a name='2'></a>__::pluginmgr::paths__ *objectName* *name*\.\.\.

    This utility command adds a set of paths to the specified object, based on
    the given *name*s\. It will search for:

      1. The environment variable __*name*\_PLUGINS__\. Its contents will be
         interpreted as a list of package paths\. The entries have to be
         separated by either __:__ \(unix\) or __;__ \(windows\)\.

         The name will be converted to upper\-case letters\.

      1. The registry entry "HKEY\_LOCAL\_MACHINE\\SOFTWARE\\*name*\\PLUGINS"\. Its
         contents will be interpreted as a list of package paths\. The entries
         have to be separated by __;__\. This item is considered only when on
         Windows \(tm\)\.

         The casing of letters is not changed\.

      1. The registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\*name*\\PLUGINS"\. Its
         contents will be interpreted as a list of package paths\. The entries
         have to be separated by __;__\. This item is considered only when on
         Windows \(tm\)\.

         The casing of letters is not changed\.

      1. The directory "~/\.*name*/plugin"\.

      1. The directory "~/\.*name*/plugins"\.

         The casing of letters is not changed\.

    and add all the paths found that way to the list of package paths maintained
    by the object\.

    If *name* is namespaced each item in the list will be repeated per prefix
    of *name*, with conversion of :\-sequences into the proper separator
    \(underscore for environment variables, backslash for registry entries, and /
    for directories\)\.

    Examples:

        ::pluginmgr::paths ::obj docidx

        => env  DOCIDX_PLUGINS
           reg  HKEY_LOCAL_MACHINE\SOFTWARE\docidx\PLUGINS
           reg  HKEY_CURRENT_USER\SOFTWARE\docidx\PLUGINS
           path ~/.docidx/plugins

        ::pluginmgr::paths ::obj doctools::idx

        => env  DOCTOOLS_PLUGINS
           env  DOCTOOLS_IDX_PLUGINS
           reg  HKEY_LOCAL_MACHINE\SOFTWARE\doctools\PLUGINS
           reg  HKEY_LOCAL_MACHINE\SOFTWARE\doctools\idx\PLUGINS
           reg  HKEY_CURRENT_USER\SOFTWARE\doctools\PLUGINS
           reg  HKEY_CURRENT_USER\SOFTWARE\doctools\idx\PLUGINS
           path ~/.doctools/plugin
           path ~/.doctools/idx/plugin

## <a name='subsection2'></a>OBJECT COMMAND

All commands created by the command __::pluginmgr__ \(See section [PACKAGE
COMMANDS](#subsection1)\) have the following general form and may be used to
invoke various operations on their plugin manager object\.

  - <a name='3'></a>__objectName__ __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [OBJECT METHODS](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>OBJECT METHODS

  - <a name='4'></a>*objectName* __clone__

    This method creates a new plugin management object and returns the
    associated object command\. The generated object is a clone of the object the
    method was invoked on\. I\.e\. the new object will have the same configuration
    as the current object\. With regard to state, if the current object has a
    plugin loaded then this plugin and all associated state is moved to the
    generated clone and the current object is reset into the base state \(no
    plugin loaded\)\. In this manner a configured plugin manager is also a factory
    for loaded plugins\.

  - <a name='5'></a>*objectName* __configure__

    The method returns a list of all known options and their current values when
    called without any arguments\.

  - <a name='6'></a>*objectName* __configure__ *option*

    The method behaves like the method __cget__ when called with a single
    argument and returns the value of the option specified by said argument\.

  - <a name='7'></a>*objectName* __configure__ __\-option__ *value*\.\.\.

    The method reconfigures the specified __option__s of the object, setting
    them to the associated *value*s, when called with an even number of
    arguments, at least two\.

    The legal options are described in the section [OBJECT
    CONFIGURATION](#subsection4)\.

  - <a name='8'></a>*objectName* __cget__ __\-option__

    This method expects a legal configuration option as argument and will return
    the current value of that option for the object the method was invoked for\.

    The legal configuration options are described in section [OBJECT
    CONFIGURATION](#subsection4)\.

  - <a name='9'></a>*objectName* __destroy__

    This method destroys the object it is invoked for\.

  - <a name='10'></a>*objectName* __do__ *arg*\.\.\.

    This method interprets its list of arguments as the words of a command and
    invokes this command in the execution context of the plugin\. The result of
    the invoked command is made the result of the method\. The call will fail
    with an error if no valid plugin has been loaded into the manager object\.

  - <a name='11'></a>*objectName* __interpreter__

    This method returns the handle of the safe interpreter the current plugin is
    loaded into\. An empty string as return value signals that the manager
    currently has no valid plugin loaded\.

  - <a name='12'></a>*objectName* __plugin__

    This method returns the name of the plugin currently loaded\. An empty string
    as return value signals that the manager currently has no valid plugin
    loaded\.

  - <a name='13'></a>*objectName* __load__ *string*

    This method loads, validates, and initializes a named plugin into the
    manager object\.

    The algorithm to locate and load the plugin employed is:

      1. If the *string* contains the path to an existing file then this file
         is taken as the implementation of the plugin\.

      1. Otherwise the plugin name is translated into a package name via the
         value of the option __\-pattern__ and then loaded through the
         regular package management\.

      1. The load fails\.

    The algorithm to validate and initialize the loaded code is:

      1. If the option __\-api__ is non\-empty introspection commands are used
         to ascertain that the plugin provides the listed commands\.

      1. If the option __\-check__ is non\-empty the specified command prefix
         is called\.

      1. If either of the above fails the candidate plugin is unloaded again

      1. Otherwise all the commands specified via the option __\-cmds__ are
         installed in the plugin\.

    A previously loaded plugin is discarded, but only if the new plugin was
    found and sucessfully validated and initialized\. Note that there will be no
    intereference between old and new plugin as both will be put into separate
    safe interpreters\.

  - <a name='14'></a>*objectName* __unload__

    This method unloads the currently loaded plugin\. It returns the empty
    string\. The call will be silently ignored if no plugin is loaded at all\.

  - <a name='15'></a>*objectName* __list__

    This method uses the contents of the option __\-pattern__ to find all
    packages which can be plugins under the purview of this manager object\. It
    translates their names into plugin names and returns a list containing them\.

  - <a name='16'></a>*objectName* __path__ *path*

    This methods adds the specified *path* to the list of additional package
    paths to look at when searching for a plugin\. It returns the empty string\.
    Duplicate paths are ignored, i\.e\. each path is added only once\. Paths are
    made absolute, but are not normalized\.

  - <a name='17'></a>*objectName* __paths__

    This method returns a list containing all additional paths which have been
    added to the plugin manager object since its creation\.

## <a name='subsection4'></a>OBJECT CONFIGURATION

All plugin manager objects understand the following configuration options:

  - __\-pattern__ *string*

    The value of this option is a glob pattern which has to contain exactly one
    '\*'\-operator\. All packages whose names match this pattern are the plugins
    recognized by the manager object\. And vice versa, the replacement of the
    '\*'\-operator with a plugin name will yield the name of the package
    implementing that plugin\.

    This option has no default, except if option __\-name__ was set\. It has
    to be set before attempting to load a plugin, either directly, or through
    option __\-name__\.

  - __\-api__ *list*

    The value of this option is a list of command names, and any plugin loaded
    has to provide these commands\. Names which are not fully qualified are
    considered to be rooted in the global namespace\. If empty no expectations
    are made on the plugin\. The default value is the empty list\.

  - __\-check__ *cmdprefix*

    The value of this option is interpreted as a command prefix\. Its purpose is
    to perform complex checks on a loaded plugin package to validate it, which
    go beyond a simple list of provided commands\.

    It is called with the manager object command as the only argument and has to
    return a boolean value\. A value of __true__ will be interpreted to mean
    that the candidate plugin passed the test\. The call will happen if and only
    if the candidate plugin already passed the basic API check specified through
    the option __\-api__\.

    The default value is the empty list, which causes the manager object to
    suppress the call and to assume the candidate plugin passes\.

  - __\-cmds__ *dict*

    The value of this option is a dictionary\. It specifies the commands which
    will be made available to the plugin \(as keys\), and the trusted commands in
    the environment which implement them \(as values\)\. The trusted commands will
    be executed in the interpreter specified by the option __\-cmdip__\. The
    default value is the empty dictionary\.

  - __\-cmdip__ *ipspec*

    The value of this option is the path of the interpreter where the trusted
    commands given to the plugin will be executed in\. The default is the empty
    string, referring to the current interpreter\.

  - __\-setup__ *cmdprefix*

    The value of this option is interpreted as a command prefix\.

    It is called whenever a new safe interpreter for a plugin has been created,
    but before a plugin is loaded\. It is provided with the manager object
    command and the interpreter handle as its only arguments\. Any return value
    will be ignored\.

    Its purpose is give a user of the plugin management the ability to define
    commands, packages, etc\. a chosen plugin may need while being loaded\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *pluginmgr* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[plugin management](\.\./\.\./\.\./\.\./index\.md\#plugin\_management), [plugin
search](\.\./\.\./\.\./\.\./index\.md\#plugin\_search)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
