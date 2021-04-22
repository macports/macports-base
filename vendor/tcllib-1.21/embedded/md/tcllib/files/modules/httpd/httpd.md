
[//000000001]: # (httpd \- Tcl Web Server)
[//000000002]: # (Generated from file 'httpd\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2018 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (httpd\(n\) 4\.3\.5 tcllib "Tcl Web Server")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

httpd \- A TclOO and coroutine based web server

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Minimal Example](#section2)

  - [Classes](#section3)

      - [Class httpd::mime](#subsection1)

      - [Class httpd::reply](#subsection2)

      - [Class httpd::server](#subsection3)

      - [Class httpd::server::dispatch](#subsection4)

      - [Class httpd::content\.redirect](#subsection5)

      - [Class httpd::content\.cache](#subsection6)

      - [Class httpd::content\.template](#subsection7)

      - [Class httpd::content\.file](#subsection8)

      - [Class httpd::content\.exec](#subsection9)

      - [Class httpd::content\.proxy](#subsection10)

      - [Class httpd::content\.cgi](#subsection11)

      - [Class httpd::protocol\.scgi](#subsection12)

      - [Class httpd::content\.scgi](#subsection13)

      - [Class httpd::server\.scgi](#subsection14)

      - [Class httpd::content\.websocket](#subsection15)

      - [Class httpd::plugin](#subsection16)

      - [Class httpd::plugin\.dict\_dispatch](#subsection17)

      - [Class httpd::reply\.memchan](#subsection18)

      - [Class httpd::plugin\.local\_memchan](#subsection19)

  - [AUTHORS](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require uuid  
package require clay  
package require coroutine  
package require fileutil  
package require fileutil::magic::filetype  
package require websocket  
package require mime  
package require cron  
package require uri  
package require Markdown  

[method __ChannelCopy__ *in* *out* ?*args*?](#1)  
[method __html\_header__ ?*title* ____? ?*args*?](#2)  
[method __html\_footer__ ?*args*?](#3)  
[method __http\_code\_string__ *code*](#4)  
[method __HttpHeaders__ *sock* ?*debug* ____?](#5)  
[method __HttpHeaders\_Default__](#6)  
[method __HttpServerHeaders__](#7)  
[method __MimeParse__ *mimetext*](#8)  
[method __Url\_Decode__ *data*](#9)  
[method __Url\_PathCheck__ *urlsuffix*](#10)  
[method __wait__ *mode* *sock*](#11)  
[variable __ChannelRegister__](#12)  
[variable __reply__](#13)  
[variable __request__](#14)  
[delegate __<server>__](#15)  
[method __constructor__ *ServerObj* ?*args*?](#16)  
[method __destructor__ ?*dictargs*?](#17)  
[method __ChannelRegister__ ?*args*?](#18)  
[method __close__](#19)  
[method __Log\_Dispatched__](#20)  
[method __dispatch__ *newsock* *datastate*](#21)  
[method __Dispatch__](#22)  
[method __html\_header__ *title* ?*args*?](#23)  
[method __html\_footer__ ?*args*?](#24)  
[method __[error](\.\./\.\./\.\./\.\./index\.md\#error)__ *code* ?*msg* ____? ?*errorInfo* ____?](#25)  
[method __content__](#26)  
[method __EncodeStatus__ *status*](#27)  
[method __[log](\.\./log/log\.md)__ *type* ?*info* ____?](#28)  
[method __CoroName__](#29)  
[method __DoOutput__](#30)  
[method __FormData__](#31)  
[method __PostData__ *length*](#32)  
[method __Session\_Load__](#33)  
[method __puts__ *line*](#34)  
[method __RequestFind__ *field*](#35)  
[method __request__ *subcommand* ?*args*?](#36)  
[method __reply__ *subcommand* ?*args*?](#37)  
[method __reset__](#38)  
[method __timeOutCheck__](#39)  
[method __[timestamp](\.\./\.\./\.\./\.\./index\.md\#timestamp)__](#40)  
[variable __template__](#41)  
[variable __url\_patterns__](#42)  
[method __constructor__ *args* ?*port* __auto__? ?*myaddr* __127\.0\.0\.1__? ?*string* __auto__? ?*name* __auto__? ?*doc\_root* ____? ?*reverse\_dns* __0__? ?*configuration\_file* ____? ?*protocol* __HTTP/1\.1__?](#43)  
[method __destructor__ ?*dictargs*?](#44)  
[method __connect__ *sock* *ip* *port*](#45)  
[method __ServerHeaders__ *ip* *http\_request* *mimetxt*](#46)  
[method __Connect__ *uuid* *sock* *ip*](#47)  
[method __[counter](\.\./counter/counter\.md)__ *which*](#48)  
[method __CheckTimeout__](#49)  
[method __[debug](\.\./debug/debug\.md)__ ?*args*?](#50)  
[method __dispatch__ *data*](#51)  
[method __Dispatch\_Default__ *reply*](#52)  
[method __Dispatch\_Local__ *data*](#53)  
[method __Headers\_Local__ *varname*](#54)  
[method __Headers\_Process__ *varname*](#55)  
[method __HostName__ *ipaddr*](#56)  
[method __[log](\.\./log/log\.md)__ ?*args*?](#57)  
[method __[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin)__ *slot* ?*class* ____?](#58)  
[method __port\_listening__](#59)  
[method __PrefixNormalize__ *prefix*](#60)  
[method __[source](\.\./\.\./\.\./\.\./index\.md\#source)__ *filename*](#61)  
[method __start__](#62)  
[method __stop__](#63)  
[method __SubObject \{\} db__](#64)  
[method __SubObject \{\} default__](#65)  
[method __template__ *page*](#66)  
[method __TemplateSearch__ *page*](#67)  
[method __Thread\_start__](#68)  
[method __Uuid\_Generate__](#69)  
[method __Validate\_Connection__ *sock* *ip*](#70)  
[method __reset__](#71)  
[method __content__](#72)  
[method __Dispatch__](#73)  
[method __content__](#74)  
[method __FileName__](#75)  
[method __DirectoryListing__ *local\_file*](#76)  
[method __content__](#77)  
[method __Dispatch__](#78)  
[variable __exename__](#79)  
[method __CgiExec__ *execname* *script* *arglist*](#80)  
[method __Cgi\_Executable__ *script*](#81)  
[method __proxy\_channel__](#82)  
[method __proxy\_path__](#83)  
[method __ProxyRequest__ *chana* *chanb*](#84)  
[method __ProxyReply__ *chana* *chanb* ?*args*?](#85)  
[method __Dispatch__](#86)  
[method __FileName__](#87)  
[method __proxy\_channel__](#88)  
[method __ProxyRequest__ *chana* *chanb*](#89)  
[method __ProxyReply__ *chana* *chanb* ?*args*?](#90)  
[method __DirectoryListing__ *local\_file*](#91)  
[method __EncodeStatus__ *status*](#92)  
[method __scgi\_info__](#93)  
[method __proxy\_channel__](#94)  
[method __ProxyRequest__ *chana* *chanb*](#95)  
[method __ProxyReply__ *chana* *chanb* ?*args*?](#96)  
[method __[debug](\.\./debug/debug\.md)__ ?*args*?](#97)  
[method __Connect__ *uuid* *sock* *ip*](#98)  
[method __Dispatch\_Dict__ *data*](#99)  
[method __uri \{\} add__ *vhosts* *patterns* *info*](#100)  
[method __uri \{\} direct__ *vhosts* *patterns* *info* *body*](#101)  
[method __output__](#102)  
[method __DoOutput__](#103)  
[method __close__](#104)  
[method __local\_memchan__ *command* ?*args*?](#105)  
[method __Connect\_Local__ *uuid* *sock* ?*args*?](#106)  

# <a name='description'></a>DESCRIPTION

This module implements a web server, suitable for embedding in an application\.
The server is object oriented, and contains all of the fundamentals needed for a
full service website\.

# <a name='section2'></a>Minimal Example

Starting a web service requires starting a class of type __httpd::server__,
and providing that server with one or more URIs to service, and
__httpd::reply__ derived classes to generate them\.

    oo::class create ::reply.hello {
      method content {} {
        my puts "<HTML><HEAD><TITLE>IRM Dispatch Server</TITLE></HEAD><BODY>"
        my puts "<h1>Hello World!</h1>"
        my puts </BODY></HTML>
      }
    }
    ::httpd::server create HTTPD port 8015 myaddr 127.0.0.1 doc_root ~/htdocs
    HTTPD plugin dispatch httpd::server::dispatch
    HTTPD uri add * /hello [list mixin reply.hello]

The bare module does have facilities to hose a files from a file system\. Files
that end in a \.tml will be substituted in the style of Tclhttpd:

    <!-- hello.tml -->
    [my html_header {Hello World!}]
    Your Server is running.
    <p>
    The time is now [clock format [clock seconds]]
    [my html_footer]

A complete example of an httpd server is in the /examples directory of Tcllib\.
It also show how to dispatch URIs to other processes via SCGI and HTTP proxies\.

    cd ~/tcl/sandbox/tcllib
    tclsh examples/httpd.tcl

# <a name='section3'></a>Classes

## <a name='subsection1'></a>Class  httpd::mime

A metaclass for MIME handling behavior across a live socket

__Methods__

  - <a name='1'></a>method __ChannelCopy__ *in* *out* ?*args*?

  - <a name='2'></a>method __html\_header__ ?*title* ____? ?*args*?

    Returns a block of HTML

  - <a name='3'></a>method __html\_footer__ ?*args*?

  - <a name='4'></a>method __http\_code\_string__ *code*

  - <a name='5'></a>method __HttpHeaders__ *sock* ?*debug* ____?

  - <a name='6'></a>method __HttpHeaders\_Default__

  - <a name='7'></a>method __HttpServerHeaders__

  - <a name='8'></a>method __MimeParse__ *mimetext*

    Converts a block of mime encoded text to a key/value list\. If an exception
    is encountered, the method will generate its own call to the
    __[error](\.\./\.\./\.\./\.\./index\.md\#error)__ method, and immediately
    invoke the __output__ method to produce an error code and close the
    connection\.

  - <a name='9'></a>method __Url\_Decode__ *data*

    De\-httpizes a string\.

  - <a name='10'></a>method __Url\_PathCheck__ *urlsuffix*

  - <a name='11'></a>method __wait__ *mode* *sock*

## <a name='subsection2'></a>Class  httpd::reply

*ancestors*: __httpd::mime__

A class which shephards a request through the process of generating a reply\. The
socket associated with the reply is available at all times as the *chan*
variable\. The process of generating a reply begins with an __httpd::server__
generating a __http::class__ object, mixing in a set of behaviors and then
invoking the reply object's __dispatch__ method\. In normal operations the
__dispatch__ method:

  1. Invokes the __reset__ method for the object to populate default
     headers\.

  1. Invokes the __HttpHeaders__ method to stream the MIME headers out of
     the socket

  1. Invokes the __request parse__ method to convert the stream of MIME
     headers into a dict that can be read via the __request__ method\.

  1. Stores the raw stream of MIME headers in the *rawrequest* variable of the
     object\.

  1. Invokes the __content__ method for the object, generating an call to
     the __[error](\.\./\.\./\.\./\.\./index\.md\#error)__ method if an exception
     is raised\.

  1. Invokes the __output__ method for the object

Developers have the option of streaming output to a buffer via the __puts__
method of the reply, or simply populating the *reply\_body* variable of the
object\. The information returned by the __content__ method is not
interpreted in any way\. If an exception is thrown \(via the
__[error](\.\./\.\./\.\./\.\./index\.md\#error)__ command in Tcl, for example\) the
caller will auto\-generate a 500 \{Internal Error\} message\. A typical
implementation of __content__ look like:

    clay::define ::test::content.file {
    	superclass ::httpd::content.file
    	# Return a file
    	# Note: this is using the content.file mixin which looks for the reply_file variable
    	# and will auto-compute the Content-Type
    	method content {} {
    	  my reset
        set doc_root [my request get DOCUMENT_ROOT]
        my variable reply_file
        set reply_file [file join $doc_root index.html]
    	}
    }
    clay::define ::test::content.time {
      # return the current system time
    	method content {} {
    		my variable reply_body
        my reply set Content-Type text/plain
    		set reply_body [clock seconds]
    	}
    }
    clay::define ::test::content.echo {
    	method content {} {
    		my variable reply_body
        my reply set Content-Type [my request get CONTENT_TYPE]
    		set reply_body [my PostData [my request get CONTENT_LENGTH]]
    	}
    }
    clay::define ::test::content.form_handler {
    	method content {} {
    	  set form [my FormData]
    	  my reply set Content-Type {text/html; charset=UTF-8}
        my puts [my html_header {My Dynamic Page}]
        my puts "<BODY>"
        my puts "You Sent<p>"
        my puts "<TABLE>"
        foreach {f v} $form {
          my puts "<TR><TH>$f</TH><TD><verbatim>$v</verbatim></TD>"
        }
        my puts "</TABLE><p>"
        my puts "Send some info:<p>"
        my puts "<FORM action=/[my request get REQUEST_PATH] method POST>"
        my puts "<TABLE>"
        foreach field {name rank serial_number} {
          set line "<TR><TH>$field</TH><TD><input name=\"$field\" "
          if {[dict exists $form $field]} {
            append line " value=\"[dict get $form $field]\"""
          }
          append line " /></TD></TR>"
          my puts $line
        }
        my puts "</TABLE>"
        my puts [my html footer]
    	}
    }

__Variable__

  - <a name='12'></a>variable __ChannelRegister__

  - <a name='13'></a>variable __reply__

    A dictionary which will converted into the MIME headers of the reply

  - <a name='14'></a>variable __request__

    A dictionary containing the SCGI transformed HTTP headers for the request

__Delegate__

  - <a name='15'></a>delegate __<server>__

    The server object which spawned this reply

__Methods__

  - <a name='16'></a>method __constructor__ *ServerObj* ?*args*?

  - <a name='17'></a>method __destructor__ ?*dictargs*?

    clean up on exit

  - <a name='18'></a>method __ChannelRegister__ ?*args*?

    Registers a channel to be closed by the close method

  - <a name='19'></a>method __close__

    Close channels opened by this object

  - <a name='20'></a>method __Log\_Dispatched__

    Record a dispatch event

  - <a name='21'></a>method __dispatch__ *newsock* *datastate*

    Accept the handoff from the server object of the socket *newsock* and feed
    it the state *datastate*\. Fields the *datastate* are looking for in
    particular are:

    \* __mixin__ \- A key/value list of slots and classes to be mixed into the
    object prior to invoking __Dispatch__\.

    \* __http__ \- A key/value list of values to populate the object's
    *request* ensemble

    All other fields are passed along to the __clay__ structure of the
    object\.

  - <a name='22'></a>method __Dispatch__

  - <a name='23'></a>method __html\_header__ *title* ?*args*?

  - <a name='24'></a>method __html\_footer__ ?*args*?

  - <a name='25'></a>method __[error](\.\./\.\./\.\./\.\./index\.md\#error)__ *code* ?*msg* ____? ?*errorInfo* ____?

  - <a name='26'></a>method __content__

    REPLACE ME: This method is the "meat" of your application\. It writes to the
    result buffer via the "puts" method and can tweak the headers via "clay put
    header\_reply"

  - <a name='27'></a>method __EncodeStatus__ *status*

    Formulate a standard HTTP status header from he string provided\.

  - <a name='28'></a>method __[log](\.\./log/log\.md)__ *type* ?*info* ____?

  - <a name='29'></a>method __CoroName__

  - <a name='30'></a>method __DoOutput__

    Generates the the HTTP reply, streams that reply back across *chan*, and
    destroys the object\.

  - <a name='31'></a>method __FormData__

    For GET requests, converts the QUERY\_DATA header into a key/value list\. For
    POST requests, reads the Post data and converts that information to a
    key/value list for application/x\-www\-form\-urlencoded posts\. For multipart
    posts, it composites all of the MIME headers of the post to a singular
    key/value list, and provides MIME\_\* information as computed by the
    __[mime](\.\./mime/mime\.md)__ package, including the MIME\_TOKEN, which
    can be fed back into the mime package to read out the contents\.

  - <a name='32'></a>method __PostData__ *length*

    Stream *length* bytes from the *chan* socket, but only of the request is
    a POST or PUSH\. Returns an empty string otherwise\.

  - <a name='33'></a>method __Session\_Load__

    Manage session data

  - <a name='34'></a>method __puts__ *line*

    Appends the value of *string* to the end of *reply\_body*, as well as a
    trailing newline character\.

  - <a name='35'></a>method __RequestFind__ *field*

  - <a name='36'></a>method __request__ *subcommand* ?*args*?

  - <a name='37'></a>method __reply__ *subcommand* ?*args*?

  - <a name='38'></a>method __reset__

    Clear the contents of the *reply\_body* variable, and reset all headers in
    the __reply__ structure back to the defaults for this object\.

  - <a name='39'></a>method __timeOutCheck__

    Called from the __http::server__ object which spawned this reply\. Checks
    to see if too much time has elapsed while waiting for data or generating a
    reply, and issues a timeout error to the request if it has, as well as
    destroy the object and close the *chan* socket\.

  - <a name='40'></a>method __[timestamp](\.\./\.\./\.\./\.\./index\.md\#timestamp)__

    Return the current system time in the format:

    %a, %d %b %Y %T %Z

## <a name='subsection3'></a>Class  httpd::server

*ancestors*: __httpd::mime__

__Variable__

  - <a name='41'></a>variable __template__

  - <a name='42'></a>variable __url\_patterns__

__Methods__

  - <a name='43'></a>method __constructor__ *args* ?*port* __auto__? ?*myaddr* __127\.0\.0\.1__? ?*string* __auto__? ?*name* __auto__? ?*doc\_root* ____? ?*reverse\_dns* __0__? ?*configuration\_file* ____? ?*protocol* __HTTP/1\.1__?

  - <a name='44'></a>method __destructor__ ?*dictargs*?

  - <a name='45'></a>method __connect__ *sock* *ip* *port*

    Reply to an open socket\. This method builds a coroutine to manage the
    remainder of the connection\. The coroutine's operations are driven by the
    __Connect__ method\.

  - <a name='46'></a>method __ServerHeaders__ *ip* *http\_request* *mimetxt*

  - <a name='47'></a>method __Connect__ *uuid* *sock* *ip*

    This method reads HTTP headers, and then consults the __dispatch__
    method to determine if the request is valid, and/or what kind of reply to
    generate\. Under normal cases, an object of class __::http::reply__ is
    created, and that class's __dispatch__ method\. This action passes
    control of the socket to the reply object\. The reply object manages the rest
    of the transaction, including closing the socket\.

  - <a name='48'></a>method __[counter](\.\./counter/counter\.md)__ *which*

    Increment an internal counter\.

  - <a name='49'></a>method __CheckTimeout__

    Check open connections for a time out event\.

  - <a name='50'></a>method __[debug](\.\./debug/debug\.md)__ ?*args*?

  - <a name='51'></a>method __dispatch__ *data*

    Given a key/value list of information, return a data structure describing
    how the server should reply\.

  - <a name='52'></a>method __Dispatch\_Default__ *reply*

    Method dispatch method of last resort before returning a 404 NOT FOUND
    error\. The default behavior is to look for a file in *DOCUMENT\_ROOT* which
    matches the query\.

  - <a name='53'></a>method __Dispatch\_Local__ *data*

    Method dispatch method invoked prior to invoking methods implemented by
    plugins\. If this method returns a non\-empty dictionary, that structure will
    be passed to the reply\. The default is an empty implementation\.

  - <a name='54'></a>method __Headers\_Local__ *varname*

    Introspect and possibly modify a data structure destined for a reply\. This
    method is invoked before invoking Header methods implemented by plugins\. The
    default implementation is empty\.

  - <a name='55'></a>method __Headers\_Process__ *varname*

    Introspect and possibly modify a data structure destined for a reply\. This
    method is built dynamically by the
    __[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin)__ method\.

  - <a name='56'></a>method __HostName__ *ipaddr*

    Convert an ip address to a host name\. If the server/ reverse\_dns flag is
    false, this method simply returns the IP address back\. Internally, this
    method uses the *dns* module from tcllib\.

  - <a name='57'></a>method __[log](\.\./log/log\.md)__ ?*args*?

    Log an event\. The input for args is free form\. This method is intended to be
    replaced by the user, and is a noop for a stock http::server object\.

  - <a name='58'></a>method __[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin)__ *slot* ?*class* ____?

    Incorporate behaviors from a plugin\. This method dynamically rebuilds the
    __Dispatch__ and __Headers__ method\. For every plugin, the server
    looks for the following entries in *clay plugin/*:

    *load* \- A script to invoke in the server's namespace during the
    __[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin)__ method invokation\.

    *dispatch* \- A script to stitch into the server's __Dispatch__ method\.

    *headers* \- A script to stitch into the server's __Headers__ method\.

    *thread* \- A script to stitch into the server's __Thread\_start__
    method\.

  - <a name='59'></a>method __port\_listening__

    Return the actual port that httpd is listening on\.

  - <a name='60'></a>method __PrefixNormalize__ *prefix*

    For the stock version, trim trailing /'s and \*'s from a prefix\. This method
    can be replaced by the end user to perform any other transformations needed
    for the application\.

  - <a name='61'></a>method __[source](\.\./\.\./\.\./\.\./index\.md\#source)__ *filename*

  - <a name='62'></a>method __start__

    Open the socket listener\.

  - <a name='63'></a>method __stop__

    Shut off the socket listener, and destroy any pending replies\.

  - <a name='64'></a>method __SubObject \{\} db__

  - <a name='65'></a>method __SubObject \{\} default__

  - <a name='66'></a>method __template__ *page*

    Return a template for the string *page*

  - <a name='67'></a>method __TemplateSearch__ *page*

    Perform a search for the template that best matches *page*\. This can
    include local file searches, in\-memory structures, or even database lookups\.
    The stock implementation simply looks for files with a \.tml or \.html
    extension in the ?doc\_root? directory\.

  - <a name='68'></a>method __Thread\_start__

    Built by the __[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin)__ method\.
    Called by the __start__ method\. Intended to allow plugins to spawn
    worker threads\.

  - <a name='69'></a>method __Uuid\_Generate__

    Generate a GUUID\. Used to ensure every request has a unique ID\. The default
    implementation is:

    return [::clay::uuid generate]

  - <a name='70'></a>method __Validate\_Connection__ *sock* *ip*

    Given a socket and an ip address, return true if this connection should be
    terminated, or false if it should be allowed to continue\. The stock
    implementation always returns 0\. This is intended for applications to be
    able to implement black lists and/or provide security based on IP address\.

## <a name='subsection4'></a>Class  httpd::server::dispatch

*ancestors*: __httpd::server__

Provide a backward compadible alias

## <a name='subsection5'></a>Class  httpd::content\.redirect

__Methods__

  - <a name='71'></a>method __reset__

  - <a name='72'></a>method __content__

## <a name='subsection6'></a>Class  httpd::content\.cache

__Methods__

  - <a name='73'></a>method __Dispatch__

## <a name='subsection7'></a>Class  httpd::content\.template

__Methods__

  - <a name='74'></a>method __content__

## <a name='subsection8'></a>Class  httpd::content\.file

Class to deliver Static content When utilized, this class is fed a local
filename by the dispatcher

__Methods__

  - <a name='75'></a>method __FileName__

  - <a name='76'></a>method __DirectoryListing__ *local\_file*

  - <a name='77'></a>method __content__

  - <a name='78'></a>method __Dispatch__

## <a name='subsection9'></a>Class  httpd::content\.exec

__Variable__

  - <a name='79'></a>variable __exename__

__Methods__

  - <a name='80'></a>method __CgiExec__ *execname* *script* *arglist*

  - <a name='81'></a>method __Cgi\_Executable__ *script*

## <a name='subsection10'></a>Class  httpd::content\.proxy

*ancestors*: __httpd::content\.exec__

Return data from an proxy process

__Methods__

  - <a name='82'></a>method __proxy\_channel__

  - <a name='83'></a>method __proxy\_path__

  - <a name='84'></a>method __ProxyRequest__ *chana* *chanb*

  - <a name='85'></a>method __ProxyReply__ *chana* *chanb* ?*args*?

  - <a name='86'></a>method __Dispatch__

## <a name='subsection11'></a>Class  httpd::content\.cgi

*ancestors*: __httpd::content\.proxy__

__Methods__

  - <a name='87'></a>method __FileName__

  - <a name='88'></a>method __proxy\_channel__

  - <a name='89'></a>method __ProxyRequest__ *chana* *chanb*

  - <a name='90'></a>method __ProxyReply__ *chana* *chanb* ?*args*?

  - <a name='91'></a>method __DirectoryListing__ *local\_file*

    For most CGI applications a directory list is vorboten

## <a name='subsection12'></a>Class  httpd::protocol\.scgi

Return data from an SCGI process

__Methods__

  - <a name='92'></a>method __EncodeStatus__ *status*

## <a name='subsection13'></a>Class  httpd::content\.scgi

*ancestors*: __httpd::content\.proxy__

__Methods__

  - <a name='93'></a>method __scgi\_info__

  - <a name='94'></a>method __proxy\_channel__

  - <a name='95'></a>method __ProxyRequest__ *chana* *chanb*

  - <a name='96'></a>method __ProxyReply__ *chana* *chanb* ?*args*?

## <a name='subsection14'></a>Class  httpd::server\.scgi

*ancestors*: __httpd::server__

Act as an SCGI Server

__Methods__

  - <a name='97'></a>method __[debug](\.\./debug/debug\.md)__ ?*args*?

  - <a name='98'></a>method __Connect__ *uuid* *sock* *ip*

## <a name='subsection15'></a>Class  httpd::content\.websocket

Upgrade a connection to a websocket

## <a name='subsection16'></a>Class  httpd::plugin

httpd plugin template

## <a name='subsection17'></a>Class  httpd::plugin\.dict\_dispatch

A rudimentary plugin that dispatches URLs from a dict data structure

__Methods__

  - <a name='99'></a>method __Dispatch\_Dict__ *data*

    Implementation of the dispatcher

  - <a name='100'></a>method __uri \{\} add__ *vhosts* *patterns* *info*

  - <a name='101'></a>method __uri \{\} direct__ *vhosts* *patterns* *info* *body*

## <a name='subsection18'></a>Class  httpd::reply\.memchan

*ancestors*: __httpd::reply__

__Methods__

  - <a name='102'></a>method __output__

  - <a name='103'></a>method __DoOutput__

  - <a name='104'></a>method __close__

## <a name='subsection19'></a>Class  httpd::plugin\.local\_memchan

__Methods__

  - <a name='105'></a>method __local\_memchan__ *command* ?*args*?

  - <a name='106'></a>method __Connect\_Local__ *uuid* *sock* ?*args*?

    A modified connection method that passes simple GET request to an object and
    pulls data directly from the reply\_body data variable in the object Needed
    because memchan is bidirectional, and we can't seem to communicate that the
    server is one side of the link and the reply is another

# <a name='section4'></a>AUTHORS

Sean Woods

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *network* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo), [WWW](\.\./\.\./\.\./\.\./index\.md\#www),
[http](\.\./\.\./\.\./\.\./index\.md\#http), [httpd](\.\./\.\./\.\./\.\./index\.md\#httpd),
[httpserver](\.\./\.\./\.\./\.\./index\.md\#httpserver),
[services](\.\./\.\./\.\./\.\./index\.md\#services)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2018 Sean Woods <yoda@etoyoc\.com>
