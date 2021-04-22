
[//000000001]: # (uri \- Tcl Uniform Resource Identifier Management)
[//000000002]: # (Generated from file 'uri\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (uri\(n\) 1\.2\.7 tcllib "Tcl Uniform Resource Identifier Management")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

uri \- URI utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [SCHEMES](#section3)

  - [EXTENDING](#section4)

  - [QUIRK OPTIONS](#section5)

      - [BACKWARD COMPATIBILITY](#subsection1)

      - [NEW DESIGNS](#subsection2)

      - [DEFAULT VALUES](#subsection3)

  - [EXAMPLES](#section6)

  - [CREDITS](#section7)

  - [Bugs, Ideas, Feedback](#section8)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require uri ?1\.2\.7?  

[__uri::setQuirkOption__ *option* ?*value*?](#1)  
[__uri::split__ *url* ?*defaultscheme*?](#2)  
[__uri::join__ ?*key* *value*?\.\.\.](#3)  
[__uri::resolve__ *base* *url*](#4)  
[__uri::isrelative__ *url*](#5)  
[__uri::geturl__ *url* ?*options*\.\.\.?](#6)  
[__uri::canonicalize__ *uri*](#7)  
[__uri::register__ *schemeList* *script*](#8)  

# <a name='description'></a>DESCRIPTION

This package does two things\.

First, it provides a number of commands for manipulating URLs/URIs and fetching
data specified by them\. For fetching data this package analyses the requested
URL/URI and then dispatches it to the appropriate package
\(__[http](\.\./\.\./\.\./\.\./index\.md\#http)__,
__[ftp](\.\./ftp/ftp\.md)__, \.\.\.\) for actual retrieval\. Currently these
commands are defined for the schemes *[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
*[https](\.\./\.\./\.\./\.\./index\.md\#https)*,
*[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*,
*[mailto](\.\./\.\./\.\./\.\./index\.md\#mailto)*,
*[news](\.\./\.\./\.\./\.\./index\.md\#news)*,
*[ldap](\.\./\.\./\.\./\.\./index\.md\#ldap)*, *ldaps* and
*[file](\.\./\.\./\.\./\.\./index\.md\#file)*\. The package __uri::urn__ adds
scheme *[urn](\.\./\.\./\.\./\.\./index\.md\#urn)*\.

Second, it provides regular expressions for a number of __registered__
URL/URI schemes\. Registered schemes are currently
*[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*,
*[ldap](\.\./\.\./\.\./\.\./index\.md\#ldap)*, *ldaps*,
*[file](\.\./\.\./\.\./\.\./index\.md\#file)*,
*[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
*[https](\.\./\.\./\.\./\.\./index\.md\#https)*,
*[gopher](\.\./\.\./\.\./\.\./index\.md\#gopher)*,
*[mailto](\.\./\.\./\.\./\.\./index\.md\#mailto)*,
*[news](\.\./\.\./\.\./\.\./index\.md\#news)*,
*[wais](\.\./\.\./\.\./\.\./index\.md\#wais)* and
*[prospero](\.\./\.\./\.\./\.\./index\.md\#prospero)*\. The package __uri::urn__
adds scheme *[urn](\.\./\.\./\.\./\.\./index\.md\#urn)*\.

The commands of the package conform to RFC 3986
\([https://www\.rfc\-editor\.org/rfc/rfc3986\.txt](https://www\.rfc\-editor\.org/rfc/rfc3986\.txt)\),
with the exception of a loophole arising from RFC 1630 and described in RFC 3986
Sections 5\.2\.2 and 5\.4\.2\. The loophole allows a relative URI to include a scheme
if it is the same as the scheme of the base URI against which it is resolved\.
RFC 3986 recommends avoiding this usage\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__uri::setQuirkOption__ *option* ?*value*?

    __uri::setQuirkOption__ is an accessor command for a number of "quirk
    options"\. The command has the same semantics as the command
    __[set](\.\./\.\./\.\./\.\./index\.md\#set)__: when called with one argument
    it reads an existing value; with two arguments it writes a new value\. The
    value of a "quirk option" is boolean: the value __false__ requests
    conformance with RFC 3986, while __true__ requests use of the quirk\. See
    section [QUIRK OPTIONS](#section5) for discussion of the different
    options and their purpose\.

  - <a name='2'></a>__uri::split__ *url* ?*defaultscheme*?

    __uri::split__ takes a *url*, decodes it and then returns a list of
    key/value pairs suitable for __array set__ containing the constituents
    of the *url*\. If the scheme is missing from the *url* it defaults to the
    value of *defaultscheme* if it was specified, or
    *[http](\.\./\.\./\.\./\.\./index\.md\#http)* else\. Currently the schemes
    *[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
    *[https](\.\./\.\./\.\./\.\./index\.md\#https)*,
    *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*,
    *[mailto](\.\./\.\./\.\./\.\./index\.md\#mailto)*,
    *[news](\.\./\.\./\.\./\.\./index\.md\#news)*,
    *[ldap](\.\./\.\./\.\./\.\./index\.md\#ldap)*, *ldaps* and
    *[file](\.\./\.\./\.\./\.\./index\.md\#file)* are supported by the package
    itself\. See section [EXTENDING](#section4) on how to expand that range\.

    The set of constituents of a URL \(= the set of keys in the returned
    dictionary\) is dependent on the scheme of the URL\. The only key which is
    therefore always present is __scheme__\. For the following schemes the
    constituents and their keys are known:

      * ftp

        __user__, __pwd__, __host__, __port__, __path__,
        __type__, __pbare__\. The pbare is optional\.

      * http\(s\)

        __user__, __pwd__, __host__, __port__, __path__,
        __query__, __fragment__, __pbare__\. The pbare is optional\.

      * file

        __path__, __host__\. The host is optional\.

      * mailto

        __user__, __host__\. The host is optional\.

      * ldap\(s\)

        __host__, __port__, __dn__, __attrs__, __scope__,
        __filter__, __extensions__

      * news

        Either __message\-id__ or __newsgroup\-name__\.

    For discussion of the boolean __pbare__ see options *NoInitialSlash*
    and *NoExtraKeys* in [QUIRK OPTIONS](#section5)\.

    The constituents are returned as slices of the argument *url*, without
    removal of percent\-encoding \("url\-encoding"\) or other adaptations\. Notably,
    on Windows® the __path__ in scheme
    *[file](\.\./\.\./\.\./\.\./index\.md\#file)* is not a valid local filename\. See
    [EXAMPLES](#section6) for more information\.

  - <a name='3'></a>__uri::join__ ?*key* *value*?\.\.\.

    __uri::join__ takes a list of key/value pairs \(generated by
    __uri::split__, for example\) and returns the canonical URL they
    represent\. Currently the schemes *[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
    *[https](\.\./\.\./\.\./\.\./index\.md\#https)*,
    *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*,
    *[mailto](\.\./\.\./\.\./\.\./index\.md\#mailto)*,
    *[news](\.\./\.\./\.\./\.\./index\.md\#news)*,
    *[ldap](\.\./\.\./\.\./\.\./index\.md\#ldap)*, *ldaps* and
    *[file](\.\./\.\./\.\./\.\./index\.md\#file)* are supported by the package
    itself\. See section [EXTENDING](#section4) on how to expand that range\.

    The arguments are expected to be slices of a valid URL, with
    percent\-encoding \("url\-encoding"\) and any other necessary adaptations\.
    Notably, on Windows the __path__ in scheme
    *[file](\.\./\.\./\.\./\.\./index\.md\#file)* is not a valid local filename\. See
    [EXAMPLES](#section6) for more information\.

  - <a name='4'></a>__uri::resolve__ *base* *url*

    __uri::resolve__ resolves the specified *url* relative to *base*, in
    conformance with RFC 3986\. In other words: a non\-relative *url* is
    returned unchanged, whereas for a relative *url* the missing parts are
    taken from *base* and prepended to it\. The result of this operation is
    returned\. For an empty *url* the result is *base*, without its URI
    fragment \(if any\)\. The command is available for schemes
    *[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
    *[https](\.\./\.\./\.\./\.\./index\.md\#https)*,
    *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*, and
    *[file](\.\./\.\./\.\./\.\./index\.md\#file)*\.

  - <a name='5'></a>__uri::isrelative__ *url*

    __uri::isrelative__ determines whether the specified *url* is absolute
    or relative\. The command is available for a *url* of any scheme\.

  - <a name='6'></a>__uri::geturl__ *url* ?*options*\.\.\.?

    __uri::geturl__ decodes the specified *url* and then dispatches the
    request to the package appropriate for the scheme found in the URL\. The
    command assumes that the package to handle the given scheme either has the
    same name as the scheme itself \(including possible capitalization\) followed
    by __::geturl__, or, in case of this failing, has the same name as the
    scheme itself \(including possible capitalization\)\. It further assumes that
    whatever package was loaded provides a __geturl__\-command in the
    namespace of the same name as the package itself\. This command is called
    with the given *url* and all given *options*\. Currently __geturl__
    does not handle any options itself\.

    *Note:* *[file](\.\./\.\./\.\./\.\./index\.md\#file)*\-URLs are an exception to
    the rule described above\. They are handled internally\.

    It is not possible to specify results of the command\. They depend on the
    __geturl__\-command for the scheme the request was dispatched to\.

  - <a name='7'></a>__uri::canonicalize__ *uri*

    __uri::canonicalize__ returns the canonical form of a URI\. The canonical
    form of a URI is one where relative path specifications, i\.e\. "\." and "\.\.",
    have been resolved\. The command is available for all URI schemes that have
    __uri::split__ and __uri::join__ commands\. The command returns a
    canonicalized URI if the URI scheme has a __path__ component \(i\.e\.
    *[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
    *[https](\.\./\.\./\.\./\.\./index\.md\#https)*,
    *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*, and
    *[file](\.\./\.\./\.\./\.\./index\.md\#file)*\)\. For schemes that have
    __uri::split__ and __uri::join__ commands but no __path__
    component \(i\.e\. *[mailto](\.\./\.\./\.\./\.\./index\.md\#mailto)*,
    *[news](\.\./\.\./\.\./\.\./index\.md\#news)*,
    *[ldap](\.\./\.\./\.\./\.\./index\.md\#ldap)*, and *ldaps*\), the command
    returns the *uri* unchanged\.

  - <a name='8'></a>__uri::register__ *schemeList* *script*

    __uri::register__ registers the first element of *schemeList* as a new
    scheme and the remaining elements as aliases for this scheme\. It creates the
    namespace for the scheme and executes the *script* in the new namespace\.
    The script has to declare variables containing regular expressions relevant
    to the scheme\. At least the variable __schemepart__ has to be declared
    as that one is used to extend the variables keeping track of the registered
    schemes\.

# <a name='section3'></a>SCHEMES

In addition to the commands mentioned above this package provides regular
expression to recognize URLs for a number of URL schemes\.

For each supported scheme a namespace of the same name as the scheme itself is
provided inside of the namespace *uri* containing the variable __url__
whose contents are a regular expression to recognize URLs of that scheme\.
Additional variables may contain regular expressions for parts of URLs for that
scheme\.

The variable __uri::schemes__ contains a list of all registered schemes\.
Currently these are *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*,
*[ldap](\.\./\.\./\.\./\.\./index\.md\#ldap)*, *ldaps*,
*[file](\.\./\.\./\.\./\.\./index\.md\#file)*,
*[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
*[https](\.\./\.\./\.\./\.\./index\.md\#https)*,
*[gopher](\.\./\.\./\.\./\.\./index\.md\#gopher)*,
*[mailto](\.\./\.\./\.\./\.\./index\.md\#mailto)*,
*[news](\.\./\.\./\.\./\.\./index\.md\#news)*,
*[wais](\.\./\.\./\.\./\.\./index\.md\#wais)* and
*[prospero](\.\./\.\./\.\./\.\./index\.md\#prospero)*\.

# <a name='section4'></a>EXTENDING

Extending the range of schemes supported by __uri::split__ and
__uri::join__ is easy because both commands do not handle the request by
themselves but dispatch it to another command in the *uri* namespace using the
scheme of the URL as criterion\.

__uri::split__ and __uri::join__ call __Split\[string totitle
<scheme>\]__ and __Join\[string totitle <scheme>\]__ respectively\.

The provision of split and join commands is sufficient to extend the commands
__uri::canonicalize__ and __uri::geturl__ \(the latter subject to the
availability of a suitable package with a __geturl__ command\)\. In contrast,
to extend the command __uri::resolve__ to a new scheme, the command itself
must be modified\.

To extend the range of schemes for which pattern information is available, use
the command __uri::register__\.

An example of a package that provides both commands and pattern information for
a new scheme is __uri::urn__, which adds scheme
*[urn](\.\./\.\./\.\./\.\./index\.md\#urn)*\.

# <a name='section5'></a>QUIRK OPTIONS

The value of a "quirk option" is boolean: the value __false__ requests
conformance with RFC 3986, while __true__ requests use of the quirk\. Use
command __uri::setQuirkOption__ to access the values of quirk options\.

Quirk options are useful both for allowing backwards compatibility when a
command specification changes, and for adding useful features that are not
included in RFC specifications\. The following quirk options are currently
defined:

  - *NoInitialSlash*

    This quirk option concerns the leading character of __path__ \(if
    non\-empty\) in the schemes *[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
    *[https](\.\./\.\./\.\./\.\./index\.md\#https)*, and
    *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*\.

    RFC 3986 defines __path__ in an absolute URI to have an initial "/",
    unless the value of __path__ is the empty string\. For the scheme
    *[file](\.\./\.\./\.\./\.\./index\.md\#file)*, all versions of package
    __uri__ follow this rule\. The quirk option *NoInitialSlash* does not
    apply to scheme *[file](\.\./\.\./\.\./\.\./index\.md\#file)*\.

    For the schemes *[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
    *[https](\.\./\.\./\.\./\.\./index\.md\#https)*, and
    *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*, versions of __uri__ before
    1\.2\.7 define the __path__ *NOT* to include an initial "/"\. When the
    quirk option *NoInitialSlash* is __true__ \(the default\), this behavior
    is also used in version 1\.2\.7\. To use instead values of __path__ as
    defined by RFC 3986, set this quirk option to __false__\.

    This setting does not affect RFC 3986 conformance\. If *NoInitialSlash* is
    __true__, then the value of __path__ in the schemes
    *[http](\.\./\.\./\.\./\.\./index\.md\#http)*,
    *[https](\.\./\.\./\.\./\.\./index\.md\#https)*, or
    *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)*, cannot distinguish between URIs in
    which the full "RFC 3986 path" is the empty string "" or a single slash "/"
    respectively\. The missing information is recorded in an additional
    __uri::split__ key __pbare__\.

    The boolean __pbare__ is defined when quirk options *NoInitialSlash*
    and *NoExtraKeys* have values __true__ and __false__ respectively\.
    In this case, if the value of __path__ is the empty string "",
    __pbare__ is __true__ if the full "RFC 3986 path" is "", and
    __pbare__ is __false__ if the full "RFC 3986 path" is "/"\.

    Using this quirk option *NoInitialSlash* is a matter of preference\.

  - *NoExtraKeys*

    This quirk option permits full backward compatibility with versions of
    __uri__ before 1\.2\.7, by omitting the __uri::split__ key
    __pbare__ described above \(see quirk option *NoInitialSlash*\)\. The
    outcome is greater backward compatibility of the __uri::split__ command,
    but an inability to distinguish between URIs in which the full "RFC 3986
    path" is the empty string "" or a single slash "/" respectively \- i\.e\. a
    minor non\-conformance with RFC 3986\.

    If the quirk option *NoExtraKeys* is __false__ \(the default\), command
    __uri::split__ returns an additional key __pbare__, and the commands
    comply with RFC 3986\. If the quirk option *NoExtraKeys* is __true__,
    the key __pbare__ is not defined and there is not full conformance with
    RFC 3986\.

    Using the quirk option *NoExtraKeys* is *NOT* recommended, because if
    set to __true__ it will reduce conformance with RFC 3986\. The option is
    included only for compatibility with code, written for earlier versions of
    __uri__, that needs values of __path__ without a leading "/", *AND
    ALSO* cannot tolerate unexpected keys in the results of __uri::split__\.

  - *HostAsDriveLetter*

    When handling the scheme *[file](\.\./\.\./\.\./\.\./index\.md\#file)* on the
    Windows platform, versions of __uri__ before 1\.2\.7 use the __host__
    field to represent a Windows drive letter and the colon that follows it, and
    the __path__ field to represent the filename path after the colon\. Such
    URIs are invalid, and are not recognized by any RFC\. When the quirk option
    *HostAsDriveLetter* is __true__, this behavior is also used in version
    1\.2\.7\. To use *[file](\.\./\.\./\.\./\.\./index\.md\#file)* URIs on Windows that
    conform to RFC 3986, set this quirk option to __false__ \(the default\)\.

    Using this quirk is *NOT* recommended, because if set to __true__ it
    will cause the __uri__ commands to expect and produce invalid URIs\. The
    option is included only for compatibility with legacy code\.

  - *RemoveDoubleSlashes*

    When a URI is canonicalized by __uri::canonicalize__, its __path__
    is normalized by removal of segments "\." and "\.\."\. RFC 3986 does not mandate
    the removal of empty segments "" \(i\.e\. the merger of double slashes, which
    is a feature of filename normalization but not of URI __path__
    normalization\): it treats URIs with excess slashes as referring to different
    resources\. When the quirk option *RemoveDoubleSlashes* is __true__
    \(the default\), empty segments will be removed from __path__\. To prevent
    removal, and thereby conform to RFC 3986, set this quirk option to
    __false__\.

    Using this quirk is a matter of preference\. A URI with double slashes in its
    path was most likely generated by error, certainly so if it has a
    straightforward mapping to a file on a server\. In some cases it may be
    better to sanitize the URI; in others, to keep the URI and let the server
    handle the possible error\.

## <a name='subsection1'></a>BACKWARD COMPATIBILITY

To behave as similarly as possible to versions of __uri__ earlier than
1\.2\.7, set the following quirk options:

  - __uri::setQuirkOption__ *NoInitialSlash* 1

  - __uri::setQuirkOption__ *NoExtraKeys* 1

  - __uri::setQuirkOption__ *HostAsDriveLetter* 1

  - __uri::setQuirkOption__ *RemoveDoubleSlashes* 0

In code that can tolerate the return by __uri::split__ of an additional key
__pbare__, set

  - __uri::setQuirkOption__ *NoExtraKeys* 0

in order to achieve greater compliance with RFC 3986\.

## <a name='subsection2'></a>NEW DESIGNS

For new projects, the following settings are recommended:

  - __uri::setQuirkOption__ *NoInitialSlash* 0

  - __uri::setQuirkOption__ *NoExtraKeys* 0

  - __uri::setQuirkOption__ *HostAsDriveLetter* 0

  - __uri::setQuirkOption__ *RemoveDoubleSlashes* 0&#124;1

## <a name='subsection3'></a>DEFAULT VALUES

The default values for package __uri__ version 1\.2\.7 are intended to be a
compromise between backwards compatibility and improved features\. Different
default values may be chosen in future versions of package __uri__\.

  - __uri::setQuirkOption__ *NoInitialSlash* 1

  - __uri::setQuirkOption__ *NoExtraKeys* 0

  - __uri::setQuirkOption__ *HostAsDriveLetter* 0

  - __uri::setQuirkOption__ *RemoveDoubleSlashes* 1

# <a name='section6'></a>EXAMPLES

A Windows® local filename such as "__C:\\Other Files\\startup\.txt__" is not
suitable for use as the __path__ element of a URI in the scheme
*[file](\.\./\.\./\.\./\.\./index\.md\#file)*\.

The Tcl command __file normalize__ will convert the backslashes to forward
slashes\. To generate a valid __path__ for the scheme
*[file](\.\./\.\./\.\./\.\./index\.md\#file)*, the normalized filename must be
prepended with "__/__", and then any characters that do not match the
__regexp__ bracket expression

    [a-zA-Z0-9$_.+!*'(,)?:@&=-]

must be percent\-encoded\.

The result in this example is "__/C:/Other%20Files/startup\.txt__" which is a
valid value for __path__\.

    % uri::join path /C:/Other%20Files/startup.txt scheme file

    file:///C:/Other%20Files/startup.txt

    % uri::split file:///C:/Other%20Files/startup.txt

    path /C:/Other%20Files/startup.txt scheme file

On UNIX® systems filenames begin with "__/__" which is also used as the
directory separator\. The only action needed to convert a filename to a valid
__path__ is percent\-encoding\.

# <a name='section7'></a>CREDITS

Original code \(regular expressions\) by Andreas Kupries\. Modularisation by Steve
Ball, also the split/join/resolve functionality\. RFC 3986 conformance by Keith
Nash\.

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *uri* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[fetching information](\.\./\.\./\.\./\.\./index\.md\#fetching\_information),
[file](\.\./\.\./\.\./\.\./index\.md\#file), [ftp](\.\./\.\./\.\./\.\./index\.md\#ftp),
[gopher](\.\./\.\./\.\./\.\./index\.md\#gopher),
[http](\.\./\.\./\.\./\.\./index\.md\#http), [https](\.\./\.\./\.\./\.\./index\.md\#https),
[ldap](\.\./\.\./\.\./\.\./index\.md\#ldap),
[mailto](\.\./\.\./\.\./\.\./index\.md\#mailto),
[news](\.\./\.\./\.\./\.\./index\.md\#news),
[prospero](\.\./\.\./\.\./\.\./index\.md\#prospero), [rfc
1630](\.\./\.\./\.\./\.\./index\.md\#rfc\_1630), [rfc
2255](\.\./\.\./\.\./\.\./index\.md\#rfc\_2255), [rfc
2396](\.\./\.\./\.\./\.\./index\.md\#rfc\_2396), [rfc
3986](\.\./\.\./\.\./\.\./index\.md\#rfc\_3986), [uri](\.\./\.\./\.\./\.\./index\.md\#uri),
[url](\.\./\.\./\.\./\.\./index\.md\#url), [wais](\.\./\.\./\.\./\.\./index\.md\#wais),
[www](\.\./\.\./\.\./\.\./index\.md\#www)

# <a name='category'></a>CATEGORY

Networking
