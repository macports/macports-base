
[//000000001]: # (cache::async \- In\-memory caches)
[//000000002]: # (Generated from file 'async\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (cache::async\(n\) 0\.3\.1 tcllib "In\-memory caches")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

cache::async \- Asynchronous in\-memory cache

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require cache::async ?0\.3\.1?  

[__::cache::async__ *objectName* *commandprefix* ?*options*\.\.\.?](#1)  
[*objectName* __get__ *key* *donecmdprefix*](#2)  
[*objectName* __set__ *key* *value*](#3)  
[*objectName* __unset__ *key*](#4)  
[*objectName* __exists__ *key*](#5)  
[*objectName* __clear__ ?*key*?](#6)  

# <a name='description'></a>DESCRIPTION

This package provides objects which cache data in memory, and operate
asynchronously with regard to request and responses\. The objects are agnostic
with regard to cache keys and values, and unknown methods are delegated to the
provider of cached data\. These two properties make it easy to use caches as a
facade for any data provider\.

# <a name='section2'></a>API

The package exports a class, __cache::async__, as specified below\.

  - <a name='1'></a>__::cache::async__ *objectName* *commandprefix* ?*options*\.\.\.?

    The command creates a new *[cache](\.\./\.\./\.\./\.\./index\.md\#cache)* object
    with an associated global Tcl command whose name is *objectName*\. This
    command may be used to invoke various operations on the object\.

    The *commandprefix* is the action to perform when an user asks for data in
    the cache and the cache doesn't yet know about the key\. When run the
    commandprefix is given three additional arguments, the string __get__,
    the key requested, and the cache object itself, in the form of its object
    command, in this order\. The execution of the action is done in an
    idle\-handler, decoupling it from the original request\.

    The only supported option is

      * __\-full\-async\-results__

        This option defines the behaviour of the cache for when requested keys
        are known to the cache at the time of __get__ request\. By default
        such requeste are responded to asynchronously as well\. Setting this
        option to __false__ forces the cache to respond to them
        synchronuously, although still through the specified callback\.

The object commands created by the class commands above have the form:

  - <a name='2'></a>*objectName* __get__ *key* *donecmdprefix*

    This method requests the data for the *key* from the cache\. If the data is
    not yet known the command prefix specified during construction of the cache
    object is used to ask for this information\.

    Whenever the information is/becomes available the *donecmdprefix* will be
    run to transfer the result to the caller\. This command prefix is invoked
    with either 2 or 3 arguments, i\.e\.

      1. The string __set__, the *key*, and the value\.

      1. The string __unset__, and the *key*\.

    These two possibilities are used to either signal the value for the *key*,
    or that the *key* has no value defined for it\. The latter is distinct from
    the cache not knowing about the *key*\.

    For a cache object configured to be fully asynchronous \(default\) the
    *donecmdprefix* is always run in an idle\-handler, decoupling it from the
    request\. Otherwise the callback will be invoked synchronously when the
    *key* is known to the cache at the time of the invokation\.

    Another important part of the cache's behaviour, as it is asynchronous it is
    possible that multiple __get__ requests are issued for the same *key*
    before it can respond\. In that case the cache will issue only one data
    request to the provider, for the first of these, and suspend the others, and
    then notify all of them when the data becomes available\.

  - <a name='3'></a>*objectName* __set__ *key* *value*

  - <a name='4'></a>*objectName* __unset__ *key*

    These two methods are provided to allow users of the cache to make keys
    known to the cache, as either having a *value*, or as undefined\.

    It is expected that the data provider \(see *commandprefix* of the
    constructor\) uses them in response to data requests for unknown keys\.

    Note how this matches the cache's own API towards its caller, calling the
    *donecmd* of __get__\-requests issued to itself with either "set key
    value" or "unset key", versus issuing __get__\-requests to its own
    provider with itself in the place of the *donecmd*, expecting to be called
    with either "set key value" or "unset key"\.

    This also means that these methods invoke the *donecmd* of all
    __get__\-requests waiting for information about the modified *key*\.

  - <a name='5'></a>*objectName* __exists__ *key*

    This method queries the cache for knowledge about the *key* and returns a
    boolean value\. The result is __true__ if the key is known, and
    __false__ otherwise\.

  - <a name='6'></a>*objectName* __clear__ ?*key*?

    This method resets the state of either the specified *key* or of all keys
    known to the cache, making it unkown\. This forces future
    __get__\-requests to reload the information from the provider\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *cache* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[asynchronous](\.\./\.\./\.\./\.\./index\.md\#asynchronous),
[cache](\.\./\.\./\.\./\.\./index\.md\#cache),
[callback](\.\./\.\./\.\./\.\./index\.md\#callback),
[synchronous](\.\./\.\./\.\./\.\./index\.md\#synchronous)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
