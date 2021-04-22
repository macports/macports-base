
[//000000001]: # (rest \- A framework for RESTful web services)
[//000000002]: # (Generated from file 'rest\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (rest\(n\) 1\.5 tcllib "A framework for RESTful web services")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

rest \- define REST web APIs and call them inline or asychronously

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Simple usage](#section2)

  - [Interface usage](#section3)

  - [Examples](#section4)

  - [INCLUDED](#section5)

  - [TLS](#section6)

  - [TLS Security Considerations](#section7)

  - [Bugs, Ideas, Feedback](#section8)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require rest ?1\.5?  

[__::rest::simple__ *url* *query* ?*config*? ?*body*?](#1)  
[__::rest::get__ *url* *query* ?*config*? ?*body*?](#2)  
[__::rest::post__ *url* *query* ?*config*? ?*body*?](#3)  
[__::rest::patch__ *url* *query* ?*config*? ?*body*?](#4)  
[__::rest::head__ *url* *query* ?*config*? ?*body*?](#5)  
[__::rest::put__ *url* *query* ?*config*? ?*body*?](#6)  
[__::rest::delete__ *url* *query* ?*config*? ?*body*?](#7)  
[__::rest::save__ *name* *file*](#8)  
[__::rest::describe__ *name*](#9)  
[__::rest::parameters__ *url* ?*key*?](#10)  
[__::rest::parse\_opts__ *static* *required* *optional* *words*](#11)  
[__::rest::substitute__ *string* *var*](#12)  
[__::rest::create\_interface__ *name*](#13)  

# <a name='description'></a>DESCRIPTION

There are two types of usage this package supports: *simple calls*, and
complete *interfaces*\. In an *interface* you specify a set of rules and then
the package builds the commands which correspond to the REST methods\. These
commands can have many options such as input and output transformations and data
type specific formatting\. This results in a cleaner and simpler script\. On the
other hand, while a *simple call* is easier and quicker to implement it is
also less featureful\. It takes the url and a few options about the command and
returns the result directly\. Any formatting or checking is up to rest of the
script\.

# <a name='section2'></a>Simple usage

In simple usage you make calls using the http method procedures and then check
or process the returned data yourself

  - <a name='1'></a>__::rest::simple__ *url* *query* ?*config*? ?*body*?

  - <a name='2'></a>__::rest::get__ *url* *query* ?*config*? ?*body*?

  - <a name='3'></a>__::rest::post__ *url* *query* ?*config*? ?*body*?

  - <a name='4'></a>__::rest::patch__ *url* *query* ?*config*? ?*body*?

  - <a name='5'></a>__::rest::head__ *url* *query* ?*config*? ?*body*?

  - <a name='6'></a>__::rest::put__ *url* *query* ?*config*? ?*body*?

  - <a name='7'></a>__::rest::delete__ *url* *query* ?*config*? ?*body*?

    These commands are all equivalent except for the http method used\. If you
    use __simple__ then the method should be specified as an option in the
    *config* dictionary\. If that is not done it defaults to __get__\. If a
    *body* is needed then the *config* dictionary must be present, however
    it is allowed to be empty\.

    The *config* dictionary supports the following keys

      * __auth__

      * __content\-type__

      * __cookie__

      * __error\-body__

      * __format__

      * __headers__

      * __method__

    Two quick examples:

    Example 1, Yahoo Boss:

        set appid APPID
        set search tcl
        set res [rest::get http://boss.yahooapis.com/ysearch/web/v1/$search [list appid $appid]]
        set res [rest::format_json $res]

    Example 2, Twitter:

        set url   http://twitter.com/statuses/update.json
        set query [list status $text]
        set res [rest::simple $url $query {
            method post
            auth   {basic user password}
            format json
        }]

# <a name='section3'></a>Interface usage

An interface to a REST API consists of a series of definitions of REST calls
contained in an array\. The name of that array becomes a namespace containing the
defined commands\. Each key of the array specifies the name of the call, with the
associated configuration a dictionary, i\.e\. key/value pairs\. The acceptable
keys, i\.e\. legal configuration options are described below\. After creating the
definitions in the array simply calling __rest::create\_interface__ with the
array as argument will then create the desired commands\.

Example, Yahoo Weather:

    package require rest

    set yweather(forecast) {
       url      http://weather.yahooapis.com/forecastrss
       req_args { p: }
       opt_args { u: }
    }
    rest::create_interface yweather
    puts [yweather::forecast -p 94089]

  - <a name='8'></a>__::rest::save__ *name* *file*

    This command saves a copy of the dynamically created procedures for all the
    API calls specified in the array variable *name* to the *file*, for
    later loading\.

    The result of the command is the empty string

  - <a name='9'></a>__::rest::describe__ *name*

    This command prints a description of all API calls specified in the array
    variable *name* to the channel __stdout__\.

    The result of the command is the empty string\.

  - <a name='10'></a>__::rest::parameters__ *url* ?*key*?

    This command parses an *url* query string into a dictionary and returns
    said dictionary as its result\.

    If *key* is specified the command will not return the entire dictionary,
    but only the value of that *key*\.

  - <a name='11'></a>__::rest::parse\_opts__ *static* *required* *optional* *words*

    This command implements a custom parserfor command options\.

      * dict *static*

        A dictionary of options and their values that are always present in the
        output\.

      * list *required*

        A list of options that must be supplied by *words*

      * list *optional*

        A list of options that may appear in the *words*, but are not
        required\. The elements must be in one of three forms:

          + name

            The option may be present or not, no default\.

          + name:

            When present the option requires an argument\.

          + name:value

            When not present use __value__ as default\.

      * list *words*

        The words to parse into options and values\.

    The result of the command is a list containing two elements\. The first
    element is a dictionary containing the parsed options and their values\. The
    second element is a list of the remaining words\.

  - <a name='12'></a>__::rest::substitute__ *string* *var*

    This command takes a *string*, substitutes values for any option
    identifiers found inside and returns the modified string as its results\.

    The values to substitute are found in the variable *var*, which is
    expected to contain a dictionary mapping from the option identifiers to
    replace to their values\. *Note* that option identifiers which have no key
    in *var* are replaced with the empty string\.

    The option identifiers in *string* have to follow the syntax __%\.\.\.%__
    where __\.\.\.__ may contain any combination of lower\-case alphanumeric
    characters, plus underscore, colon and dash\.

  - <a name='13'></a>__::rest::create\_interface__ *name*

    This command creates procedures for all the API calls specified in the array
    variable *name*\.

    The name of that array becomes a namespace containing the defined commands\.
    Each key of the array specifies the name of the call, with the associated
    configuration a dictionary, i\.e\. key/value pairs\. The legal keys and their
    meanings are:

      * __url__

        The value of this *required* option must be the target of the http
        request\.

      * __description__

        The value of this option must be a short string describing the call\.
        Default to the empty string, if not specified\. Used only by
        __::rest::describe__\.

      * __body__

        The value of this option indicates if arguments are required for the
        call's request body or not\. The acceptable values are listed below\.
        Defaults to __optional__ if not specified\.

          + __none__

            The call has no request body, none must be supplied\.

          + __optional__

            A request body can be supplied, but is not required\.

          + __required__

            A request body must be supplied\.

          + __argument__

            This value must be followed by the name of an option, treating the
            entire string as a list\. The request body will be used as the value
            of that option\.

          + __mime\_multipart__

            A request body must be supplied and will be interpreted as each
            argument representing one part of a mime/multipart document\.
            Arguments must be lists containing 2 elements, a list of header keys
            and values, and the mime part body, in this order\.

          + __mime\_multipart/<value>__

            Same as mime\_multipart, but the __Content\-Type__ header is set
            to __multipart/<value>__\.

      * __method__

        The value of this option must be the name of the HTTP method to call on
        the url\. Defaults to GET, if not specified\. The acceptable values are
        __GET__, __POST__, and __PUT__, regardless of letter\-case\.

      * __copy__

        When present the value of this option specifies the name of a previously
        defined call\. The definition of that call is copied to the current call,
        except for the options specified by the current call itself\.

      * __unset__

        When present the value of this option contains a list of options in the
        current call\. These options are removed from the definition\. Use this
        after __copy__ing an existing definition to remove options, instead
        of overriding their value\.

      * __headers__

        Specification of additional header fields\. The value of this option must
        be a dictionary, interpreted to contain the new header fields and their
        values\. The default is to not add any additional headers\.

      * __content\-type__

        The value of this option specifies the content type for the request
        data\.

      * __req\_args__

        The value of this option is a list naming the required arguments of the
        call\. Names ending in a colon will require a value\.

      * __opt\_args__

        The value of this option a list naming the arguments that may be present
        for a call but are not required\.

      * __static\_args__

        The value of this option a list naming the arguments that are always the
        same\. No sense in troubling the user with these\. A leading dash
        \(__\-__\) is allowed but not required to maintain consistency with the
        command line\.

      * __auth__

        The value of this option specifies how to authenticate the calls\. No
        authentication is done if the option is not specified\.

          + __basic__

            The user may configure the *basic authentication* by overriding
            the procedure __basic\_auth__ in the namespace of interface\. This
            procedure takes two arguments, the username and password, in this
            order\.

          + __bearer__

            The user may configure a bearer token as authentication\. The value
            is the token passed to the HTTP authorization header\.

          + __sign__

            The value must actually be a list with the second element the name
            of a procedure which will be called to perform request signing\.

      * __callback__

        If this option is present then the method will be created as an
        *async* call\. Such calls will return immediately with the value of the
        associated http token instead of the call's result\. The event loop must
        be active to use this option\.

        The value of this option is treated as a command prefix which is invoked
        when the HTTP call is complete\. The prefix will receive at least two
        additional arguments, the name of the calling procedure and the status
        of the result \(one of __OK__ or __ERROR__\), in this order\.

        In case of __OK__ a third argument is added, the data associated
        with the result\.

        If and only if the __ERROR__ is a redirection, the location
        redirected to will be added as argument\. Further, if the configuration
        key __error\-body__ is set to __true__ the data associated with
        the result will be added as argument as well\.

        The http request header will be available in that procedure via
        __upvar token token__\.

      * __cookie__

        The value of this option is a list of cookies to be passed in the http
        header\. This is a shortcut to the __headers__ option\.

      * __input\_transform__

        The value of this option is a command prefix or script to perform a
        transformation on the query before invoking the call\. A script transform
        is wrapped into an automatically generated internal procedure\.

        If not specified no transformation is done\.

        The command \(prefix\) must accept a single argument, the query \(a
        dictionary\) to transform, and must return the modified query \(again as
        dictionary\) as its result\. The request body is accessible in the
        transform command via __upvar body body__\.

      * __format__

      * __result__

        The value of this option specifies the format of the returned data\.
        Defaults to __auto__ if not specified\. The acceptable values are:

          + __auto__

            Auto detect between __xml__ and __json__\.

          + __discard__

          + __json__

          + __raw__

          + __rss__

            This is formatted as a special case of __xml__\.

          + __tdom__

          + __xml__

      * __pre\_transform__

        The value of this option is a command prefix or script to perform a
        transformation on the result of a call \(*before* the application of
        the output transform as per __format__\)\. A script transform is
        wrapped into an automatically generated internal procedure\.

        If not specified no transformation is done\.

        The command \(prefix\) must accept a single argument, the result to
        transform, and must return the modified result as its result\.

        The http request header is accessible in the transform command via
        __upvar token token__

      * __post\_transform__

        The value of this option is a command prefix or script to perform a
        transformation on the result of a call \(*after* the application of the
        output transform as per __format__\)\. A script transform is wrapped
        into an automatically generated internal procedure\.

        If not specified no transformation is done\.

        The command \(prefix\) must accept a single argument, the result to
        transform, and must return the modified result as its result\.

        The http request header is accessible in the transform command via
        __upvar token token__

      * __check\_result__

        The value of this option must be list of two expressions, either of
        which may be empty\.

        The first expression is checks the OK condition, it must return
        __true__ when the result is satisfactory, and __false__
        otherwise\.

        The second expression is the ERROR condition, it must return
        __false__ unless there is an error, then it has to return
        __true__\.

      * __error\_body__

        The value of this option determines whether to return the response when
        encountering an HTTP error, or not\. The default is to not return the
        response body on error\.

        See __callback__ above for more information\.

# <a name='section4'></a>Examples

Yahoo Geo:

    set ygeo(parse) {
        url http://wherein.yahooapis.com/v1/document
        method post
        body { arg documentContent }
    }
    ygeo::parse "san jose ca"
    # "san jose ca" will be interpreted as if it were specified as the -documentContent option

Google Docs:

    set gdocs(upload) {
        url http://docs.google.com/feeds/default/private/full
        body mime_multipart
    }
    gdocs::upload [list {Content-Type application/atom+xml} $xml] [list {Content-Type image/jpeg} $filedata]

Delicious:

    set delicious(updated) {
        url https://api.del.icio.us/v1/posts/update
        auth basic
    }

    rest::create_interface flickr

    flickr::basic_auth username password

Flickr:

    set flickr(auth.getToken) {
       url http://api.flickr.com/services/rest/
       req_args { api_key: secret: }
       auth { sign do_signature }
    }

    rest::create_interface flickr

    proc ::flickr::do_signature {query} {
        # perform some operations on the query here
        return $query
    }

# <a name='section5'></a>INCLUDED

The package provides functional but incomplete implementations for the following
services:

  - __del\.icio\.us__

  - __facebook__

  - __flickr__

  - __twitter__

  - __google calendar__

  - __yahoo boss__

  - __yahoo weather__

Please either read the package's implementation, or use __rest::describe__
after loading it for their details\.

Do not forget developers' documentation on the respective sites either\.

# <a name='section6'></a>TLS

The __rest__ package can be used with
*[https](\.\./\.\./\.\./\.\./index\.md\#https)*\-secured services, by requiring the
__[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ package and then registering it with
the __[http](\.\./\.\./\.\./\.\./index\.md\#http)__ package it is sitting on top
of\. Example

    package require tls
    http::register https 443 ::tls::socket

# <a name='section7'></a>TLS Security Considerations

This package uses the __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ package to
handle the security for __https__ urls and other socket connections\.

Policy decisions like the set of protocols to support and what ciphers to use
are not the responsibility of __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__, nor
of this package itself however\. Such decisions are the responsibility of
whichever application is using the package, and are likely influenced by the set
of servers the application will talk to as well\.

For example, in light of the recent [POODLE
attack](http://googleonlinesecurity\.blogspot\.co\.uk/2014/10/this\-poodle\-bites\-exploiting\-ssl\-30\.html)
discovered by Google many servers will disable support for the SSLv3 protocol\.
To handle this change the applications using
__[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ must be patched, and not this
package, nor __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ itself\. Such a patch
may be as simple as generally activating __tls1__ support, as shown in the
example below\.

    package require tls
    tls::init -tls1 1 ;# forcibly activate support for the TLS1 protocol

    ... your own application code ...

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *rest* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.
