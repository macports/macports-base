
[//000000001]: # (oauth \- oauth)
[//000000002]: # (Generated from file 'oauth\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2014 Javi P\. <hxm@eggdrop\.es>)
[//000000004]: # (oauth\(n\) 1\.0\.3 tcllib "oauth")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

oauth \- oauth API base signature

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [TLS Security Considerations](#section2)

  - [Commands](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require oauth ?1\.0\.3?  

[__::oauth::config__](#1)  
[__::oauth::config__ ?*options*\.\.\.?](#2)  
[__::oauth::header__ *baseURL* ?*postQuery*?](#3)  
[__::oauth::query__ *baseURL* ?*postQuery*?](#4)  

# <a name='description'></a>DESCRIPTION

The __oauth__ package provides a simple Tcl\-only library for communication
with [oauth](http://oauth\.net) APIs\. This current version of the package
supports the Oauth 1\.0 Protocol, as specified in [RFC
5849](http://tools\.ietf\.org/rfc/rfc5849\.txt)\.

# <a name='section2'></a>TLS Security Considerations

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

# <a name='section3'></a>Commands

  - <a name='1'></a>__::oauth::config__

    When this command is invoked without arguments it returns a dictionary
    containing the current values of all options\.

  - <a name='2'></a>__::oauth::config__ ?*options*\.\.\.?

    When invoked with arguments, options followed by their values, it is used to
    set and query various parameters of application and client, like proxy host
    and user agent for the HTTP requests\. The detailed list of options is below:

      * __\-accesstoken__ *string*

        This is the user's token\.

      * __\-accesstokensecret__ *string*

        This is the user's secret token\.

      * __\-consumerkey__ *string*

        This is the public token of your app\.

      * __\-consumersecret__ *string*

        This is the private token of your app\.

      * __\-debug__ *bool*

        The default value is __off__\. If you change this option to
        __on__, the basic signature just created will be printed to stdout,
        among other debug output\.

      * __\-oauthversion__ *version*

        This is the version of the OAuth protocol to use\. At the moment only
        __1\.0__ is supported, the default\.

      * __\-proxyhost__ *hostname*

        You can set up a proxy host for send contact the oauth's api server\.

      * __\-proxyport__ *port\-number*

        Port number of your proxy\.

      * __\-signmethod__ *method*

        The signature method to use\. OAuth 1\.0 only supports __HMAC\-SHA1__,
        the default\.

      * __\-timeout__ *milliseconds*

        Timeout in milliseconds for your query\. The default value is
        __6000__, i\.e\. 6 seconds\.

      * __\-urlencoding__ *encoding*

        The encoding used for creating the x\-url\-encoded URLs with
        __::http::formatQuery__\. The default is __utf\-8__, as specified
        by [RFC 2718](http://tools\.ietf\.org/rfc/rfc2718\.txt)\.

  - <a name='3'></a>__::oauth::header__ *baseURL* ?*postQuery*?

    This command is the base signature creator\. With proper settings for various
    tokens and secrets \(See __::oauth::config__\) the result is the base
    authentication string to send to the server\.

    You do not need to call this procedure to create the query because
    __::oauth::query__ \(see below\) will do for it for you\. Doing so is
    useful for debugging purposes, though\.

      * url *baseURL*

        This argument is the URI path to the OAuth API server\. If you plan send
        a GET query, you should provide a full path\.

    HTTP GET
    ::oauth::header {https://api.twitter.com/1.1/users/lookup.json?screen_name=AbiertaMente}

      * url\-encoded\-string *postQuery*

        When you have to send a header in POST format, you have to put the query
        string into this argument\.

    ::oauth::header {https://api.twitter.com/1.1/friendships/create.json} {user_id=158812437&follow=true}

  - <a name='4'></a>__::oauth::query__ *baseURL* ?*postQuery*?

    This procedure will use the settings made with __::oauth::config__ to
    create the basic authentication and then send the command to the server API\.
    It takes the same arguments as __::oauth::header__\.

    The returned result will be a list containing 2 elements\. The first element
    will be a dictionary containing the HTTP header data response\. This allows
    you, for example, to check the X\-Rate\-Limit from OAuth\. The second element
    will be the raw data returned from API server\. This string is usually a json
    object which can be further decoded with the functions of package
    __[json](\.\./json/json\.md)__, or any other json\-parser for Tcl\.

    Here is an example of how it would work in Twitter\. Do not forget to replace
    the placeholder tokens and keys of the example with your own tokens and keys
    when trying it out\.

    % package require oauth
    % package require json
    % oauth::config -consumerkey {your_consumer_key} -consumersecret {your_consumer_key_secret} -accesstoken {your_access_token} -accesstokensecret {your_access_token_secret}

    % set response [oauth::query https://api.twitter.com/1.1/users/lookup.json?screen_name=AbiertaMente]
    % set jsondata [lindex $response 1]
    % set data [json::json2dict $jsondata]
    $ set data [lindex $data 0]
    % dict for {key val} $data {puts "$key => $val"}
    id => 158812437
    id_str => 158812437
    name => Un Librepensador
    screen_name => AbiertaMente
    location => Explico mis tuits ahí →
    description => 160Caracteres para un SMS y contaba mi vida entera sin recortar vocales. Ahora en Twitter, podemos usar hasta 140 y a mí me sobrarían 20 para contaros todo lo q
    url => http://t.co/SGs3k9odBn
    entities => url {urls {{url http://t.co/SGs3k9odBn expanded_url http://librepensamiento.es display_url librepensamiento.es indices {0 22}}}} description {urls {}}
    protected => false
    followers_count => 72705
    friends_count => 53099
    listed_count => 258
    created_at => Wed Jun 23 18:29:58 +0000 2010
    favourites_count => 297
    utc_offset => 7200
    time_zone => Madrid
    geo_enabled => false
    verified => false
    statuses_count => 8996
    lang => es
    status => created_at {Sun Oct 12 08:02:38 +0000 2014} id 521209314087018496 id_str 521209314087018496 text {@thesamethanhim http://t.co/WFoXOAofCt} source {<a href="http://twitter.com" rel="nofollow">Twitter Web Client</a>} truncated false in_reply_to_status_id 521076457490350081 in_reply_to_status_id_str 521076457490350081 in_reply_to_user_id 2282730867 in_reply_to_user_id_str 2282730867 in_reply_to_screen_name thesamethanhim geo null coordinates null place null contributors null retweet_count 0 favorite_count 0 entities {hashtags {} symbols {} urls {{url http://t.co/WFoXOAofCt expanded_url http://www.elmundo.es/internacional/2014/03/05/53173dc1268e3e3f238b458a.html display_url elmundo.es/internacional/… indices {16 38}}} user_mentions {{screen_name thesamethanhim name Ἑλένη id 2282730867 id_str 2282730867 indices {0 15}}}} favorited false retweeted false possibly_sensitive false lang und
    contributors_enabled => false
    is_translator => true
    is_translation_enabled => false
    profile_background_color => 709397
    profile_background_image_url => http://pbs.twimg.com/profile_background_images/704065051/9309c02aa2728bdf543505ddbd408e2e.jpeg
    profile_background_image_url_https => https://pbs.twimg.com/profile_background_images/704065051/9309c02aa2728bdf543505ddbd408e2e.jpeg
    profile_background_tile => true
    profile_image_url => http://pbs.twimg.com/profile_images/2629816665/8035fb81919b840c5cc149755d3d7b0b_normal.jpeg
    profile_image_url_https => https://pbs.twimg.com/profile_images/2629816665/8035fb81919b840c5cc149755d3d7b0b_normal.jpeg
    profile_banner_url => https://pbs.twimg.com/profile_banners/158812437/1400828874
    profile_link_color => FF3300
    profile_sidebar_border_color => FFFFFF
    profile_sidebar_fill_color => A0C5C7
    profile_text_color => 333333
    profile_use_background_image => true
    default_profile => false
    default_profile_image => false
    following => true
    follow_request_sent => false
    notifications => false

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *oauth* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[RFC 2718](\.\./\.\./\.\./\.\./index\.md\#rfc\_2718), [RFC
5849](\.\./\.\./\.\./\.\./index\.md\#rfc\_5849),
[oauth](\.\./\.\./\.\./\.\./index\.md\#oauth),
[twitter](\.\./\.\./\.\./\.\./index\.md\#twitter)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2014 Javi P\. <hxm@eggdrop\.es>
