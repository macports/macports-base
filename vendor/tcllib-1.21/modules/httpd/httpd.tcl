###
# Amalgamated package for httpd
# Do not edit directly, tweak the source in src/ and rerun
# build.tcl
###
package require Tcl 8.6
package provide httpd 4.3.5
namespace eval ::httpd {}
set ::httpd::version 4.3.5
###
# START: core.tcl
###
package require uri
package require dns
package require cron
package require coroutine
package require mime
package require fileutil
package require websocket
package require Markdown
package require fileutil::magic::filetype
package require clay 0.7
namespace eval httpd::content {
}
namespace eval ::url {
}
namespace eval ::httpd {
}
namespace eval ::scgi {
}
if {
    [package vsatisfies [package require fileutil::magic::filetype] 2] ||
    [package vsatisfies [package require fileutil::magic::filetype] 1.2]
} {
    # v1.2+, v2+: filetype result structure was changed completely.
    proc ::httpd::mime-type {path} {
	join [lindex [::fileutil::magic::filetype $path] 1] /
    }
} else {
    # filetype result is mime type directly.
    proc ::httpd::mime-type {path} {
	::fileutil::magic::filetype $path
    }
}
clay::define ::httpd::mime {
  method ChannelCopy {in out args} {
    try {
      my clay refcount_incr
      set chunk 4096
      set size -1
      foreach {f v} $args {
        set [string trim $f -] $v
      }
      dict set info coroutine [info coroutine]
      if {$size>0 && $chunk>$size} {
          set chunk $size
      }
      set bytes 0
      set sofar 0
      set method [self method]
      while 1 {
        set command {}
        set error {}
        if {$size>=0} {
          incr sofar $bytes
          set remaining [expr {$size-$sofar}]
          if {$remaining <= 0} {
            break
          } elseif {$chunk > $remaining} {
            set chunk $remaining
          }
        }
        lassign [yieldto chan copy $in $out -size $chunk \
          -command [list [info coroutine] $method]] \
          command bytes error
        if {$command ne $method} {
          error "Subroutine $method interrupted"
        }
        if {[string length $error]} {
          error $error
        }
        if {[chan eof $in]} {
          break
        }
      }
    } finally {
      my clay refcount_decr
    }
  }
  method html_header {{title {}} args} {
    set result {}
    append result "<!DOCTYPE html>\n<HTML><HEAD>"
    if {$title ne {}} {
      append result "<TITLE>$title</TITLE>"
    }
    if {[dict exists $args stylesheet]} {
      append result "<link rel=\"stylesheet\" href=\"[dict get $args stylesheet]\">"
    } else {
      append result "<link rel=\"stylesheet\" href=\"/style.css\">"
    }
    append result "</HEAD><BODY>"
    return $result
  }
  method html_footer {args} {
    return "</BODY></HTML>"
  }
  method http_code_string code {
    set codes {
      200 {Data follows}
      204 {No Content}
      301 {Moved Permanently}
      302 {Found}
      303 {Moved Temporarily}
      304 {Not Modified}
      307 {Moved Permanently}
      308 {Moved Temporarily}
      400 {Bad Request}
      401 {Authorization Required}
      403 {Permission denied}
      404 {Not Found}
      408 {Request Timeout}
      411 {Length Required}
      419 {Expectation Failed}
      500 {Server Internal Error}
      501 {Server Busy}
      503 {Service Unavailable}
      504 {Service Temporarily Unavailable}
      505 {HTTP Version Not Supported}
    }
    if {[dict exists $codes $code]} {
      return [dict get $codes $code]
    }
    return {Unknown Http Code}
  }
  method HttpHeaders {sock {debug {}}} {
    set result {}
    set LIMIT 8192
    ###
    # Set up a channel event to stream the data from the socket line by
    # line. When a blank line is read, the HttpHeaderLine method will send
    # a flag which will terminate the vwait.
    #
    # We do this rather than entering blocking mode to prevent the process
    # from locking up if it's starved for input. (Or in the case of the test
    # suite, when we are opening a blocking channel on the other side of the
    # socket back to ourselves.)
    ###
    chan configure $sock -translation {auto crlf} -blocking 0 -buffering line
    while 1 {
      set readCount [::coroutine::util::gets_safety $sock $LIMIT line]
      if {$readCount<=0} break
      append result $line \n
      if {[string length $result] > $LIMIT} {
        error {Headers too large}
      }
    }
    ###
    # Return our buffer
    ###
    return $result
  }
  method HttpHeaders_Default {} {
    return {Status {200 OK}
Content-Size 0
Content-Type {text/html; charset=UTF-8}
Cache-Control {no-cache}
Connection close}
  }
  method HttpServerHeaders {} {
    return {
      CONTENT_LENGTH CONTENT_TYPE QUERY_STRING REMOTE_USER AUTH_TYPE
      REQUEST_METHOD REMOTE_ADDR REMOTE_HOST REQUEST_URI REQUEST_PATH
      REQUEST_VERSION  DOCUMENT_ROOT QUERY_STRING REQUEST_RAW
      GATEWAY_INTERFACE SERVER_PORT SERVER_HTTPS_PORT
      SERVER_NAME  SERVER_SOFTWARE SERVER_PROTOCOL
    }
  }
  method MimeParse mimetext {
    set data(mimeorder) {}
    foreach line [split $mimetext \n] {
      # This regexp picks up
      # key: value
      # MIME headers.  MIME headers may be continue with a line
      # that starts with spaces or a tab
      if {[string length [string trim $line]]==0} break
      if {[regexp {^([^ :]+):[ 	]*(.*)} $line dummy key value]} {
        # The following allows something to
        # recreate the headers exactly
        lappend data(headerlist) $key $value
        # The rest of this makes it easier to pick out
        # headers from the data(mime,headername) array
        #set key [string tolower $key]
        if {[info exists data(mime,$key)]} {
          append data(mime,$key) ,$value
        } else {
          set data(mime,$key) $value
          lappend data(mimeorder) $key
        }
        set data(key) $key
      } elseif {[regexp {^[ 	]+(.*)}  $line dummy value]} {
        # Are there really continuation lines in the spec?
        if {[info exists data(key)]} {
          append data(mime,$data(key)) " " $value
        } else {
          error "INVALID HTTP HEADER FORMAT: $line"
        }
      } else {
        error "INVALID HTTP HEADER FORMAT: $line"
      }
    }
    ###
    # To make life easier for our SCGI implementation rig things
    # such that CONTENT_LENGTH is always first
    # Also map all headers specified in rfc2616 to their canonical case
    ###
    set result {}
    dict set result Content-Length 0
    foreach {key} $data(mimeorder) {
      set ckey $key
      switch [string tolower $key] {
        content-length {
          set ckey Content-Length
        }
        content-encoding {
          set ckey Content-Encoding
        }
        content-language {
          set ckey Content-Language
        }
        content-location {
          set ckey Content-Location
        }
        content-md5 {
          set ckey Content-MD5
        }
        content-range {
          set ckey Content-Range
        }
        content-type {
          set ckey Content-Type
        }
        expires {
          set ckey Expires
        }
        last-modified {
          set ckey Last-Modified
        }
        cookie {
          set ckey COOKIE
        }
        referer -
        referrer {
          # Standard misspelling in the RFC
          set ckey Referer
        }
      }
      dict set result $ckey $data(mime,$key)
    }
    return $result
  }
  method Url_Decode data {
    regsub -all {\+} $data " " data
    regsub -all {([][$\\])} $data {\\\1} data
    regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
    return [subst $data]
  }
  method Url_PathCheck {urlsuffix} {
    set pathlist ""
    foreach part  [split $urlsuffix /] {
      if {[string length $part] == 0} {
        # It is important *not* to "continue" here and skip
        # an empty component because it could be the last thing,
        # /a/b/c/
        # which indicates a directory.  In this case you want
        # Auth_Check to recurse into the directory in the last step.
      }
      set part [Url_Decode $part]
    	# Disallow Mac and UNIX path separators in components
	    # Windows drive-letters are bad, too
 	    if {[regexp [/\\:] $part]} {
  	    error "URL components cannot include \ or :"
	    }
	    switch -- $part {
	      .  { }
    	  .. {
          set len [llength $pathlist]
          if {[incr len -1] < 0} {
            error "URL out of range"
          }
          set pathlist [lrange $pathlist 0 [incr len -1]]
        }
        default {
          lappend pathlist $part
        }
      }
    }
    return $pathlist
  }
  method wait {mode sock} {
    my clay refcount_incr
    if {[info coroutine] eq {}} {
      chan event $sock $mode [list set ::httpd::lock_$sock $mode]
      vwait ::httpd::lock_$sock
    } else {
      chan event $sock $mode [info coroutine]
      yield
    }
    chan event $sock $mode {}
    my clay refcount_decr
  }
}

###
# END: core.tcl
###
###
# START: reply.tcl
###
::clay::define ::httpd::reply {
  superclass ::httpd::mime
  Variable ChannelRegister {}
  Delegate <server> {
    description {The server object which spawned this reply}
  }
  Dict reply {}
  Dict request {
    CONTENT_LENGTH 0
    COOKIE {}
    HTTP_HOST {}
    REFERER {}
    REQUEST_URI {}
    REMOTE_ADDR {}
    REMOTE_HOST {}
    USER_AGENT {}
    SESSION {}
  }
  constructor {ServerObj args} {
    my variable dispatched_time uuid
    set uuid [namespace tail [self]]
    set dispatched_time [clock milliseconds]
    my clay delegate <server> $ServerObj
    foreach {field value} [::clay::args_to_options {*}$args] {
      my clay set config $field: $value
    }
  }
  destructor {
    my close
  }
  method ChannelRegister args {
    my variable ChannelRegister
    if {![info exists ChannelRegister]} {
      set ChannelRegister {}
    }
    foreach c $args {
      if {$c ni $ChannelRegister} {
        lappend ChannelRegister $c
      }
    }
  }
  method close {} {
    my variable ChannelRegister
    if {![info exists ChannelRegister]} {
      return
    }
    foreach c $ChannelRegister {
      catch {chan event $c readable {}}
      catch {chan event $c writable {}}
      catch {chan flush $c}
      catch {chan close $c}
    }
    set ChannelRegister {}
  }
  method Log_Dispatched {} {
    my log Dispatched [dict create \
     REMOTE_ADDR [my request get REMOTE_ADDR] \
     REMOTE_HOST [my request get REMOTE_HOST] \
     COOKIE [my request get HTTP_COOKIE] \
     REFERER [my request get HTTP_REFERER] \
     USER_AGENT [my request get HTTP_USER_AGENT] \
     REQUEST_URI [my request get REQUEST_URI] \
     HTTP_HOST [my request get HTTP_HOST] \
     SESSION [my request get SESSION] \
    ]
  }
  method dispatch {newsock datastate} {
    my variable chan request
    try {
      my clay refcount_incr
      set chan $newsock
      my ChannelRegister $chan
      chan event $chan readable {}
      chan configure $chan -translation {auto crlf} -buffering line
      if {[dict exists $datastate mixin]} {
        set mixinmap [dict get $datastate mixin]
      } else {
        set mixinmap {}
      }
      foreach item [dict keys $datastate MIXIN_*] {
        set slot [string range $item 6 end]
        dict set mixinmap [string tolower $slot] [dict get $datastate $item]
      }
      my clay mixinmap {*}$mixinmap
      if {[dict exists $datastate delegate]} {
        my clay delegate {*}[dict get $datastate delegate]
      }
      my reset
      set request [my clay get dict/ request]
      foreach {f v} $datastate {
        if {[string index $f end] eq "/"} {
          catch {my clay merge $f $v}
        } else {
          my clay set $f $v
        }
        if {$f eq "http"} {
          foreach {ff vf} $v {
            dict set request $ff $vf
          }
        }
      }
      my Session_Load
      my Log_Dispatched
      my Dispatch
    } on error {err errdat} {
      my error 500 $err [dict get $errdat -errorinfo]
      my DoOutput
    } finally {
      my close
      my clay refcount_decr
    }
  }
  method Dispatch {} {
    # Invoke the URL implementation.
    my content
    my DoOutput
  }
  method html_header {title args} {
    set result {}
    append result "<HTML><HEAD>"
    if {$title ne {}} {
      append result "<TITLE>$title</TITLE>"
    }
    append result "</HEAD><BODY>"
    append result \n {<div id="top-menu">}
    if {[dict exists $args banner]} {
      append result "<img src=\"[dict get $args banner]\">"
    } else {
      append result {<img src="/images/etoyoc-banner.jpg">}
    }
    append result {</div>}
    if {[dict exists $args sideimg]} {
      append result "\n<div name=\"sideimg\"><img align=right src=\"[dict get $args sideimg]\"></div>"
    }
    append result {<div id="content">}
    return $result
  }
  method html_footer {args} {
    set result {</div><div id="footer">}
    append result {</div></BODY></HTML>}
  }
  method error {code {msg {}} {errorInfo {}}} {
    my clay set  HTTP_ERROR $code
    my reset
    set qheaders [my clay dump]
    set HTTP_STATUS "$code [my http_code_string $code]"
    dict with qheaders {}
    my reply replace {}
    my reply set Status $HTTP_STATUS
    my reply set Content-Type {text/html; charset=UTF-8}
    switch $code {
      301 - 302 - 303 - 307 - 308 {
        my reply set Location $msg
        set template [my <server> template redirect]
      }
      404 {
        set template [my <server> template notfound]
      }
      default {
        set template [my <server> template internal_error]
      }
    }
    my puts [subst $template]
  }
  method content {} {
    my puts [my html_header {Hello World!}]
    my puts "<H1>HELLO WORLD!</H1>"
    my puts [my html_footer]
  }
  method EncodeStatus {status} {
    return "HTTP/1.0 $status"
  }
  method log {type {info {}}} {
    my variable dispatched_time uuid
    my <server> log $type $uuid $info
  }
  method CoroName {} {
    if {[info coroutine] eq {}} {
      return ::httpd::object::[my clay get UUID]
    }
  }
  method DoOutput {} {
    my variable reply_body chan
    if {$chan eq {}} return
    catch {
      # Causing random issues. Technically a socket is always open for read and write
      # anyway
      #my wait writable $chan
      chan configure $chan  -translation {binary binary}
      ###
      # Return dynamic content
      ###
      set length [string length $reply_body]
      set result {}
      if {${length} > 0} {
        my reply set Content-Length [string length $reply_body]
        append result [my reply output] \n
        append result $reply_body
      } else {
        append result [my reply output]
      }
      chan puts -nonewline $chan $result
      my log HttpAccess {}
    }
  }
  method FormData {} {
    my variable chan formdata
    # Run this only once
    if {[info exists formdata]} {
      return $formdata
    }
    set length [my request get CONTENT_LENGTH]
    set formdata {}
    if {[my request get REQUEST_METHOD] in {"POST" "PUSH"}} {
      set rawtype [my request get CONTENT_TYPE]
      if {[string toupper [string range $rawtype 0 8]] ne "MULTIPART"} {
        set type $rawtype
      } else {
        set type multipart
      }
      switch $type {
        multipart {
          ###
          # Ok, Multipart MIME is troublesome, farm out the parsing to a dedicated tool
          ###
          set body [my clay get mimetxt]
          append body \n [my PostData $length]
          set token [::mime::initialize -string $body]
          foreach item [::mime::getheader $token -names] {
            dict set formdata $item [::mime::getheader $token $item]
          }
          foreach item {content encoding params parts size} {
            dict set formdata MIME_[string toupper $item] [::mime::getproperty $token $item]
          }
          dict set formdata MIME_TOKEN $token
        }
        application/x-www-form-urlencoded {
          # These foreach loops are structured this way to ensure there are matched
          # name/value pairs.  Sometimes query data gets garbled.
          set body [my PostData $length]
          set result {}
          foreach pair [split $body "&"] {
            foreach {name value} [split $pair "="] {
              lappend formdata [my Url_Decode $name] [my Url_Decode $value]
            }
          }
        }
      }
    } else {
      foreach pair [split [my request get QUERY_STRING] "&"] {
        foreach {name value} [split $pair "="] {
          lappend formdata [my Url_Decode $name] [my Url_Decode $value]
        }
      }
    }
    return $formdata
  }
  method PostData {length} {
    my variable postdata
    # Run this only once
    if {[info exists postdata]} {
      return $postdata
    }
    set postdata {}
    if {[my request get REQUEST_METHOD] in {"POST" "PUSH"}} {
      my variable chan
      chan configure $chan -translation binary -blocking 0 -buffering full -buffersize 4096
      set postdata [::coroutine::util::read $chan $length]
    }
    return $postdata
  }
  method Session_Load {} {}
  method puts line {
    my variable reply_body
    append reply_body $line \n
  }
  method RequestFind {field} {
    my variable request
    if {[dict exists $request $field]} {
      return $field
    }
    foreach item [dict keys $request] {
      if {[string tolower $item] eq [string tolower $field]} {
        return $item
      }
    }
    return $field
  }
  method request {subcommand args} {
    my variable request
    switch $subcommand {
      dump {
        return $request
      }
      field {
        tailcall my RequestFind [lindex $args 0]
      }
      get {
        set field [my RequestFind [lindex $args 0]]
        if {![dict exists $request $field]} {
          return {}
        }
        tailcall dict get $request $field
      }
      getnull {
        set field [my RequestFind [lindex $args 0]]
        if {![dict exists $request $field]} {
          return {}
        }
        tailcall dict get $request $field
      }
      exists {
        set field [my RequestFind [lindex $args 0]]
        tailcall dict exists $request $field
      }
      parse {
        if {[catch {my MimeParse [lindex $args 0]} result]} {
          my error 400 $result
          tailcall my DoOutput
        }
        set request $result
      }
      replace {
        set request [lindex $args 0]
      }
      set {
        dict set request {*}$args
      }
      default {
        error "Unknown command $subcommand. Valid: field, get, getnull, exists, parse, replace, set"
      }
    }
  }
  method reply {subcommand args} {
    my variable reply
    switch $subcommand {
      dump {
        return $reply
      }
      exists {
        return [dict exists $reply {*}$args]
      }
      get -
      getnull {
        return [dict getnull $reply {*}$args]
      }
      replace {
        set reply [my HttpHeaders_Default]
        if {[llength $args]==1} {
          foreach {f v} [lindex $args 0] {
            dict set reply $f $v
          }
        } else {
          foreach {f v} $args {
            dict set reply $f $v
          }
        }
      }
      output {
        set result {}
        if {![dict exists $reply Status]} {
          set status {200 OK}
        } else {
          set status [dict get $reply Status]
        }
        set result "[my EncodeStatus $status]\n"
        foreach {f v} $reply {
          if {$f in {Status}} continue
          append result "[string trimright $f :]: $v\n"
        }
        #append result \n
        return $result
      }
      set {
        dict set reply {*}$args
      }
      default {
        error "Unknown command $subcommand. Valid: exists, get, getnull, output, replace, set"
      }
    }
  }
  method reset {} {
    my variable reply_body
    my reply replace    [my HttpHeaders_Default]
    my reply set Server [my <server> clay get server/ string]
    my reply set Date [my timestamp]
    set reply_body {}
  }
  method timeOutCheck {} {
    my variable dispatched_time
    if {([clock seconds]-$dispatched_time)>120} {
      ###
      # Something has lasted over 2 minutes. Kill this
      ###
      catch {
        my error 408 {Request Timed out}
        my DoOutput
      }
    }
  }
  method timestamp {} {
    return [clock format [clock seconds] -format {%a, %d %b %Y %T %Z}]
  }
}

###
# END: reply.tcl
###
###
# START: server.tcl
###
namespace eval ::httpd::object {
}
namespace eval ::httpd::coro {
}
::clay::define ::httpd::server {
  superclass ::httpd::mime
  clay set server/ port auto
  clay set server/ myaddr 127.0.0.1
  clay set server/ string [list TclHttpd $::httpd::version]
  clay set server/ name [info hostname]
  clay set server/ doc_root {}
  clay set server/ reverse_dns 0
  clay set server/ configuration_file {}
  clay set server/ protocol {HTTP/1.1}
  clay set socket/ buffersize   32768
  clay set socket/ translation  {auto crlf}
  clay set reply_class ::httpd::reply
  Array template
  Dict url_patterns {}
  constructor {
  {args {
    port        {default auto      comment {Port to listen on}}
    myaddr      {default 127.0.0.1 comment {IP address to listen on. "all" means all}}
    string      {default auto      comment {Value for SERVER_SOFTWARE in HTTP headers}}
    name        {default auto      comment {Value for SERVER_NAME in HTTP headers. Defaults to [info hostname]}}
    doc_root    {default {}        comment {File path to serve.}}
    reverse_dns {default 0         comment {Perform reverse DNS to convert IPs into hostnames}}
    configuration_file {default {} comment {Configuration file to load into server namespace}}
    protocol    {default {HTTP/1.1} comment {Value for SERVER_PROTOCOL in HTTP headers}}
  }}} {
    if {[llength $args]==1} {
      set arglist [lindex $args 0]
    } else {
      set arglist $args
    }
    foreach {var val} $arglist {
      my clay set server/ $var $val
    }
    my start
  }
  destructor {
    my stop
  }
  method connect {sock ip port} {
    ###
    # If an IP address is blocked drop the
    # connection
    ###
    if {[my Validate_Connection $sock $ip]} {
      catch {close $sock}
      return
    }
    set uuid [my Uuid_Generate]
    set coro [coroutine ::httpd::coro::$uuid {*}[namespace code [list my Connect $uuid $sock $ip]]]
    chan event $sock readable $coro
  }
  method ServerHeaders {ip http_request mimetxt} {
    set result {}
    dict set result HTTP_HOST {}
    dict set result CONTENT_LENGTH 0
    foreach {f v} [my MimeParse $mimetxt] {
      set fld [string toupper [string map {- _} $f]]
      if {$fld in {CONTENT_LENGTH CONTENT_TYPE}} {
        set qfld $fld
      } else {
        set qfld HTTP_$fld
      }
      dict set result $qfld $v
    }
    dict set result REMOTE_ADDR     $ip
    dict set result REMOTE_HOST     [my HostName $ip]
    dict set result REQUEST_METHOD  [lindex $http_request 0]
    set uriinfo [::uri::split [lindex $http_request 1]]
    dict set result uriinfo $uriinfo
    dict set result REQUEST_URI     [lindex $http_request 1]
    dict set result REQUEST_PATH    [dict get $uriinfo path]
    dict set result REQUEST_VERSION [lindex [split [lindex $http_request end] /] end]
    dict set result DOCUMENT_ROOT   [my clay get server/ doc_root]
    dict set result QUERY_STRING    [dict get $uriinfo query]
    dict set result REQUEST_RAW     $http_request
    dict set result SERVER_PORT     [my port_listening]
    dict set result SERVER_NAME     [my clay get server/ name]
    dict set result SERVER_PROTOCOL [my clay get server/ protocol]
    dict set result SERVER_SOFTWARE [my clay get server/ string]
    if {[string match 127.* $ip]} {
      dict set result LOCALHOST [expr {[lindex [split [dict getnull $result HTTP_HOST] :] 0] eq "localhost"}]
    }
    return $result
  }
  method Connect {uuid sock ip} {
    ::clay::cleanup
    yield [info coroutine]
    chan event $sock readable {}
    chan configure $sock \
      -blocking 0 \
      -translation {auto crlf} \
      -buffering line
    my counter url_hit
    try {
      set readCount [::coroutine::util::gets_safety $sock 4096 http_request]
      set mimetxt [my HttpHeaders $sock]
      dict set query UUID $uuid
      dict set query mimetxt $mimetxt
      dict set query mixin style [my clay get server/ style]
      dict set query http [my ServerHeaders $ip $http_request $mimetxt]
      my Headers_Process query
      set reply [my dispatch $query]
    } on error {err errdat} {
      my debug [list uri: [dict getnull $query REQUEST_URI] ip: $ip error: $err errorinfo: [dict get $errdat -errorinfo]]
      my log BadRequest $uuid [list ip: $ip error: $err errorinfo: [dict get $errdat -errorinfo]]
      catch {chan puts $sock "HTTP/1.0 400 Bad Request (The data is invalid)"}
      catch {chan close $sock}
      return
    }
    if {[dict size $reply]==0} {
      set reply $query
      my log BadLocation $uuid $query
      dict set reply http HTTP_STATUS {404 Not Found}
      dict set reply template notfound
      dict set reply mixin reply ::httpd::content.template
    }
    set pageobj [::httpd::reply create ::httpd::object::$uuid [self]]
    tailcall $pageobj dispatch $sock $reply
  }
  method counter which {
    my variable counters
    incr counters($which)
  }
  method CheckTimeout {} {
    foreach obj [info commands ::httpd::object::*] {
      try {
        $obj timeOutCheck
      } on error {} {
        $obj clay refcount_decr
      }
    }
    ::clay::cleanup
  }
  method debug args {}
  method dispatch {data} {
    set reply [my Dispatch_Local $data]
    if {[dict size $reply]} {
      return $reply
    }
    return [my Dispatch_Default $data]
  }
  method Dispatch_Default {reply} {
    ###
    # Fallback to docroot handling
    ###
    set doc_root [dict getnull $reply http DOCUMENT_ROOT]
    if {$doc_root ne {}} {
      ###
      # Fall back to doc_root handling
      ###
      dict set reply prefix {}
      dict set reply path $doc_root
      dict set reply mixin reply httpd::content.file
      return $reply
    }
    return {}
  }
  method Dispatch_Local data {}
  method Headers_Local {varname} {}
  method Headers_Process varname {}
  method HostName ipaddr {
    if {![my clay get server/ reverse_dns]} {
      return $ipaddr
    }
    set t [::dns::resolve $ipaddr]
    set result [::dns::name $t]
    ::dns::cleanup $t
    return $result
  }
  method log args {
    # Do nothing for now
  }
  method plugin {slot {class {}}} {
    if {$class eq {}} {
      set class ::httpd::plugin.$slot
    }
    if {[info command $class] eq {}} {
      error "Class $class for plugin $slot does not exist"
    }
    my clay mixinmap $slot $class
    set mixinmap [my clay mixinmap]

    ###
    # Perform action on load
    ###
    set script [$class clay search plugin/ load]
    eval $script

    ###
    # rebuild the dispatch method
    ###
    set body "\n try \{"
    append body \n {
  set reply [my Dispatch_Local $data]
  if {[dict size $reply]} {return $reply}
}

    foreach {slot class} $mixinmap {
      set script [$class clay search plugin/ dispatch]
      if {[string length $script]} {
        append body \n "# SLOT $slot"
        append body \n $script
      }
    }
    append body \n {  return [my Dispatch_Default $data]}
    append body \n "\} on error \{err errdat\} \{"
    append body \n {  puts [list DISPATCH ERROR [dict get $errdat -errorinfo]] ; return {}}
    append body \n "\}"
    oo::objdefine [self] method dispatch data $body
    ###
    # rebuild the Headers_Process method
    ###
    set body "\n try \{"
    append body \n "  upvar 1 \$varname query"
    append body \n {  my Headers_Local query}
    foreach {slot class} $mixinmap {
      set script [$class clay search plugin/ headers]
      if {[string length $script]} {
        append body \n "# SLOT $slot"
        append body \n $script
      }
    }
    append body \n "\} on error \{err errdat\} \{"
    append body \n {  puts [list HEADERS ERROR [dict get $errdat -errorinfo]] ; return {}}
    append body \n "\}"

    oo::objdefine [self] method Headers_Process varname $body

    ###
    # rebuild the Threads_Start method
    ###
    set body "\n try \{"
    foreach {slot class} $mixinmap {
      set script [$class clay search plugin/ thread]
      if {[string length $script]} {
        append body \n "# SLOT $slot"
        append body \n $script
      }
    }
    append body \n "\} on error \{err errdat\} \{"
    append body \n {  puts [list THREAD START ERROR [dict get $errdat -errorinfo]] ; return {}}
    append body \n "\}"
    oo::objdefine [self] method Thread_start {} $body
  }
  method port_listening {} {
    my variable port_listening
    return $port_listening
  }
  method PrefixNormalize prefix {
    set prefix [string trimright $prefix /]
    set prefix [string trimright $prefix *]
    set prefix [string trimright $prefix /]
    return $prefix
  }
  method source {filename} {
    source $filename
  }
  method start {} {
    # Build a namespace to contain replies
    namespace eval [namespace current]::reply {}

    my variable socklist port_listening
    if {[my clay get server/ configuration_file] ne {}} {
      source [my clay get server/ configuration_file]
    }
    set port [my clay get server/ port]
    if { $port in {auto {}} } {
      package require nettool
      set port [::nettool::allocate_port 8015]
    }
    set port_listening $port
    set myaddr [my clay get server/ myaddr]
    my debug [list [self] listening on $port $myaddr]

    if {$myaddr ni {all any * {}}} {
      foreach ip $myaddr {
        lappend socklist [socket -server [namespace code [list my connect]] -myaddr $ip $port]
      }
    } else {
      lappend socklist [socket -server [namespace code [list my connect]] $port]
    }
    ::cron::every [self] 120 [namespace code {my CheckTimeout}]
    my Thread_start
  }
  method stop {} {
    my variable socklist
    if {[info exists socklist]} {
      foreach sock $socklist {
        catch {close $sock}
      }
    }
    set socklist {}
    ::cron::cancel [self]
  }
  Ensemble SubObject::db {} {
    return [namespace current]::Sqlite_db
  }
  Ensemble SubObject::default {} {
    return [namespace current]::$method
  }
  method template page {
    my variable template
    if {[info exists template($page)]} {
      return $template($page)
    }
    set template($page) [my TemplateSearch $page]
    return $template($page)
  }
  method TemplateSearch page {
    set doc_root [my clay get server/ doc_root]
    if {$doc_root ne {} && [file exists [file join $doc_root $page.tml]]} {
      return [::fileutil::cat [file join $doc_root $page.tml]]
    }
    if {$doc_root ne {} && [file exists [file join $doc_root $page.html]]} {
      return [::fileutil::cat [file join $doc_root $page.html]]
    }
    switch $page {
      redirect {
return {
[my html_header "$HTTP_STATUS"]
The page you are looking for: <b>[my request get REQUEST_PATH]</b> has moved.
<p>
If your browser does not automatically load the new location, it is
<a href=\"$msg\">$msg</a>
[my html_footer]
}
      }
      internal_error {
        return {
[my html_header "$HTTP_STATUS"]
Error serving <b>[my request get REQUEST_PATH]</b>:
<p>
The server encountered an internal server error: <pre>$msg</pre>
<pre><code>
$errorInfo
</code></pre>
[my html_footer]
        }
      }
      notfound {
        return {
[my html_header "$HTTP_STATUS"]
The page you are looking for: <b>[my request get REQUEST_PATH]</b> does not exist.
[my html_footer]
        }
      }
    }
  }
  method Thread_start {} {}
  method Uuid_Generate {} {
    return [::clay::uuid::short]
  }
  method Validate_Connection {sock ip} {
    return 0
  }
}
::clay::define ::httpd::server::dispatch {
    superclass ::httpd::server
}

###
# END: server.tcl
###
###
# START: dispatch.tcl
###
::clay::define ::httpd::content.redirect {
  method reset {} {
    ###
    # Inject the location into the HTTP headers
    ###
    my variable reply_body
    set reply_body {}
    my reply replace    [my HttpHeaders_Default]
    my reply set Server [my <server> clay get server/ string]
    set msg [my clay get LOCATION]
    my reply set Location [my clay get LOCATION]
    set code  [my clay get REDIRECT_CODE]
    if {$code eq {}} {
      set code 301
    }
    my reply set Status [list $code [my http_code_string $code]]
  }
  method content {} {
    set template [my <server> template redirect]
    set msg [my clay get LOCATION]
    set HTTP_STATUS [my reply get Status]
    my puts [subst $msg]
  }
}
::clay::define ::httpd::content.cache {
  method Dispatch {} {
    my variable chan
    my wait writable $chan
    chan configure $chan  -translation {binary binary}
    chan puts -nonewline $chan [my clay get cache/ data]
  }
}
::clay::define ::httpd::content.template {
  method content {} {
    if {[my request get HTTP_STATUS] ne {}} {
      my reply set Status [my request get HTTP_STATUS]
    }
    set request [my request dump]
    dict with request {}
    my puts [subst [my <server> template [my clay get template]]]
  }
}

###
# END: dispatch.tcl
###
###
# START: file.tcl
###
::clay::define ::httpd::content.file {
  method FileName {} {
    # Some dispatchers will inject a fully qualified name during discovery
    if {[my clay exists FILENAME] && [file exists [my clay get FILENAME]]} {
      my request set PREFIX_URI [file dirname [my clay get FILENAME]]
      return [my clay get FILENAME]
    }
    set uri [string trimleft [my request get REQUEST_PATH] /]
    set path [my clay get path]
    set prefix [my clay get prefix]
    set fname [string range $uri [string length $prefix] end]
    if {$fname in "{} index.html index.md index index.tml index.tcl"} {
      return $path
    }
    if {[file exists [file join $path $fname]]} {
      return [file join $path $fname]
    }
    if {[file exists [file join $path $fname.md]]} {
      return [file join $path $fname.md]
    }
    if {[file exists [file join $path $fname.html]]} {
      return [file join $path $fname.html]
    }
    if {[file exists [file join $path $fname.tml]]} {
      return [file join $path $fname.tml]
    }
    if {[file exists [file join $path $fname.tcl]]} {
      return [file join $path $fname.tcl]
    }
    return {}
  }
  method DirectoryListing {local_file} {
    set uri [string trimleft [my request get REQUEST_PATH] /]
    set path [my clay get path]
    set prefix [my clay get prefix]
    set fname [string range $uri [string length $prefix] end]
    my puts [my html_header "Listing of /$fname/"]
    my puts "Listing contents of /$fname/"
    my puts "<TABLE>"
    if {$prefix ni {/ {}}} {
      set updir [file dirname $prefix]
      if {$updir ne {}} {
        my puts "<TR><TD><a href=\"/$updir\">..</a></TD><TD></TD></TR>"
      }
    }
    foreach file [glob -nocomplain [file join $local_file *]] {
      if {[file isdirectory $file]} {
        my puts "<TR><TD><a href=\"[file join / $uri [file tail $file]]\">[file tail $file]/</a></TD><TD></TD></TR>"
      } else {
        my puts "<TR><TD><a href=\"[file join / $uri [file tail $file]]\">[file tail $file]</a></TD><TD>[file size $file]</TD></TR>"
      }
    }
    my puts "</TABLE>"
    my puts [my html_footer]
  }
  method content {} {
    my variable reply_file
    set local_file [my FileName]
    if {$local_file eq {} || ![file exist $local_file]} {
      my log httpNotFound [my request get REQUEST_PATH]
      my error 404 {File Not Found}
      tailcall my DoOutput
    }
    if {[file isdirectory $local_file] || [file tail $local_file] in {index index.html index.tml index.md}} {
      my request set PREFIX_URI [my request get REQUEST_PATH]
      my request set LOCAL_DIR $local_file
      ###
      # Produce an index page
      ###
      set idxfound 0
      foreach name {
        index.tcl
        index.html
        index.tml
        index.md
        index.info
        index.clay
        content.htm
      } {
        if {[file exists [file join $local_file $name]]} {
          set idxfound 1
          set local_file [file join $local_file $name]
          break
        }
      }
      if {!$idxfound} {
        tailcall my DirectoryListing $local_file
      }
    } else {
      my request set PREFIX_URI [file dirname [my request get REQUEST_PATH]]
      my request set LOCAL_DIR [file dirname $local_file]
    }
    my request set LOCAL_FILE $local_file

    switch [file extension $local_file] {
      .apng {
        my reply set Content-Type {image/apng}
        set reply_file $local_file
      }
      .bmp {
        my reply set Content-Type {image/bmp}
        set reply_file $local_file
      }
      .css {
        my reply set Content-Type {text/css}
        set reply_file $local_file
      }
      .gif {
        my reply set Content-Type {image/gif}
        set reply_file $local_file
      }
      .cur - .ico {
        my reply set Content-Type {image/x-icon}
        set reply_file $local_file
      }
      .jpg - .jpeg - .jfif - .pjpeg - .pjp {
        my reply set Content-Type {image/jpg}
        set reply_file $local_file
      }
      .js {
        my reply set Content-Type {text/javascript}
        set reply_file $local_file
      }
      .md {
        package require Markdown
        my reply set Content-Type {text/html; charset=UTF-8}
        set mdtxt  [::fileutil::cat $local_file]
        my puts [::Markdown::convert $mdtxt]
      }
      .png {
        my reply set Content-Type {image/png}
        set reply_file $local_file
      }
      .svgz -
      .svg {
        # FU magic screws it up
        my reply set Content-Type {image/svg+xml}
        set reply_file $local_file
      }
      .tcl {
        my reply set Content-Type {text/html; charset=UTF-8}
        try {
          source $local_file
        } on error {err errdat} {
          my error 500 {Internal Error} [dict get $errdat -errorinfo]
        }
      }
      .tiff {
        my reply set Content-Type {image/tiff}
        set reply_file $local_file
      }
      .tml {
        my reply set Content-Type {text/html; charset=UTF-8}
        set tmltxt  [::fileutil::cat $local_file]
        set headers [my request dump]
        dict with headers {}
        my puts [subst $tmltxt]
      }
      .txt {
        my reply set Content-Type {text/plain}
        set reply_file $local_file
      }
      .webp {
        my reply set Content-Type {image/webp}
        set reply_file $local_file
      }
      default {
        ###
        # Assume we are returning a binary file
        ###
        my reply set Content-Type [::httpd::mime-type $local_file]
        set reply_file $local_file
      }
    }
  }
  method Dispatch {} {
    my variable reply_body reply_file reply_chan chan
    try {
      my reset
      # Invoke the URL implementation.
      my content
    } on error {err errdat} {
      my error 500 $err [dict get $errdat -errorinfo]
      catch {
        tailcall my DoOutput
      }
    }
    if {$chan eq {}} return
    catch {
      # Causing random issues. Technically a socket is always open for read and write
      # anyway
      #my wait writable $chan
      if {![info exists reply_file]} {
        tailcall my DoOutput
      }
      chan configure $chan  -translation {binary binary}
      my log HttpAccess {}
      ###
      # Return a stream of data from a file
      ###
      set size [file size $reply_file]
      my reply set Content-Length $size
      append result [my reply output] \n
      chan puts -nonewline $chan $result
      set reply_chan [open $reply_file r]
      my ChannelRegister $reply_chan
      my log SendReply [list length $size]
      ###
      # Output the file contents. With no -size flag, channel will copy until EOF
      ###
      chan configure $reply_chan -translation {binary binary} -buffersize 4096 -buffering full -blocking 0
      if {$size < 40960} {
        # Raw copy small files
        chan copy $reply_chan $chan
      } else {
        my ChannelCopy $reply_chan $chan -chunk 4096
      }
    }
  }
}

###
# END: file.tcl
###
###
# START: proxy.tcl
###
::clay::define ::httpd::content.exec {
  variable exename [list tcl [info nameofexecutable] .tcl [info nameofexecutable]]
  method CgiExec {execname script arglist} {
    if { $::tcl_platform(platform) eq "windows"} {
      if {[file extension $script] eq ".exe"} {
        return [open "|[list $script] $arglist" r+]
      } else {
        if {$execname eq {}} {
          set execname [my Cgi_Executable $script]
        }
        return [open "|[list $execname $script] $arglist" r+]
      }
    } else {
      if {$execname eq {}} {
        return [open "|[list $script] $arglist 2>@1" r+]
      } else {
        return [open "|[list $execname $script] $arglist 2>@1" r+]
      }
    }
    error "CGI Not supported"
  }
  method Cgi_Executable {script} {
    if {[string tolower [file extension $script]] eq ".exe"} {
      return $script
    }
    my variable exename
    set ext [file extension $script]
    if {$ext eq {}} {
      set which [file tail $script]
    } else {
      if {[dict exists exename $ext]} {
        return [dict get $exename $ext]
      }
      switch $ext {
        .pl {
          set which perl
        }
        .py {
          set which python
        }
        .php {
          set which php
        }
        .fossil - .fos {
          set which fossil
        }
        default {
          set which tcl
        }
      }
      if {[dict exists exename $which]} {
        set result [dict get $exename $which]
        dict set exename $ext $result
        return $result
      }
    }
    if {[dict exists exename $which]} {
      return [dict get $exename $which]
    }
    if {$which eq "tcl"} {
      if {[my clay get tcl_exe] ne {}} {
        dict set exename $which [my clay get tcl_exe]
      } else {
        dict set exename $which [info nameofexecutable]
      }
    } else {
      if {[my clay get ${which}_exe] ne {}} {
        dict set exename $which [my clay get ${which}_exe]
      } elseif {"$::tcl_platform(platform)" == "windows"} {
        dict set exename $which $which.exe
      } else {
        dict set exename $which $which
      }
    }
    set result [dict get $exename $which]
    if {$ext ne {}} {
      dict set exename $ext $result
    }
    return $result
  }
}
::clay::define ::httpd::content.proxy {
  superclass ::httpd::content.exec
  method proxy_channel {} {
    ###
    # This method returns a channel to the
    # proxied socket/stdout/etc
    ###
    error unimplemented
  }
  method proxy_path {} {
    set uri [string trimleft [my request get REQUEST_URI] /]
    set prefix [my clay get prefix]
    return /[string range $uri [string length $prefix] end]
  }
  method ProxyRequest {chana chanb} {
    chan event $chanb writable {}
    my log ProxyRequest {}
    chan puts $chanb "[my request get REQUEST_METHOD] [my proxy_path]"
    set mimetxt [my clay get mimetxt]
    chan puts $chanb [my clay get mimetxt]
    set length [my request get CONTENT_LENGTH]
    if {$length} {
      chan configure $chana -translation binary -blocking 0 -buffering full -buffersize 4096
      chan configure $chanb -translation binary -blocking 0 -buffering full -buffersize 4096
      ###
      # Send any POST/PUT/etc content
      ###
      my ChannelCopy $chana $chanb -size $length
    } else {
      chan flush $chanb
    }
    chan event $chanb readable [info coroutine]
    yield
  }
  method ProxyReply {chana chanb args} {
    my log ProxyReply [list args $args]
    chan event $chana readable {}
    set readCount [::coroutine::util::gets_safety $chana 4096 reply_status]
    set replyhead [my HttpHeaders $chana]
    set replydat  [my MimeParse $replyhead]

    ###
    # Read the first incoming line as the HTTP reply status
    # Return the rest of the headers verbatim
    ###
    set replybuffer "$reply_status\n"
    append replybuffer $replyhead
    chan configure $chanb -translation {auto crlf} -blocking 0 -buffering full -buffersize 4096
    chan puts $chanb $replybuffer
    ###
    # Output the body. With no -size flag, channel will copy until EOF
    ###
    chan configure $chana -translation binary -blocking 0 -buffering full -buffersize 4096
    chan configure $chanb -translation binary -blocking 0 -buffering full -buffersize 4096
    my ChannelCopy $chana $chanb -chunk 4096
  }
  method Dispatch {} {
    my variable sock chan
    if {[catch {my proxy_channel} sock errdat]} {
      my error 504 {Service Temporarily Unavailable} [dict get $errdat -errorinfo]
      tailcall my DoOutput
    }
    if {$sock eq {}} {
      my error 404 {Not Found}
      tailcall my DoOutput
    }
    my log HttpAccess {}
    chan event $sock writable [info coroutine]
    yield
    my ChannelRegister $sock
    my ProxyRequest $chan $sock
    my ProxyReply   $sock $chan
  }
}

###
# END: proxy.tcl
###
###
# START: cgi.tcl
###
::clay::define ::httpd::content.cgi {
  superclass ::httpd::content.proxy
  method FileName {} {
    set uri [string trimleft [my request get REQUEST_PATH] /]
    set path [my clay get path]
    set prefix [my clay get prefix]

    set fname [string range $uri [string length $prefix] end]
    if {[file exists [file join $path $fname]]} {
      return [file join $path $fname]
    }
    if {[file exists [file join $path $fname.fossil]]} {
      return [file join $path $fname.fossil]
    }
    if {[file exists [file join $path $fname.fos]]} {
      return [file join $path $fname.fos]
    }
    if {[file extension $fname] in {.exe .cgi .tcl .pl .py .php}} {
      return $fname
    }
    return {}
  }
  method proxy_channel {} {
    ###
    # When delivering static content, allow web caches to save
    ###
    set local_file [my FileName]
    if {$local_file eq {} || ![file exist $local_file]} {
      my log httpNotFound [my request get REQUEST_PATH]
      my error 404 {Not Found}
      tailcall my DoOutput
    }
    if {[file isdirectory $local_file]} {
      ###
      # Produce an index page... or error
      ###
      tailcall my DirectoryListing $local_file
    }

    set verbatim {
      CONTENT_LENGTH CONTENT_TYPE QUERY_STRING REMOTE_USER AUTH_TYPE
      REQUEST_METHOD REMOTE_ADDR REMOTE_HOST REQUEST_URI REQUEST_PATH
      REQUEST_VERSION  DOCUMENT_ROOT QUERY_STRING REQUEST_RAW
      GATEWAY_INTERFACE SERVER_PORT SERVER_HTTPS_PORT
      SERVER_NAME  SERVER_SOFTWARE SERVER_PROTOCOL
    }
    foreach item $verbatim {
      set ::env($item) {}
    }
    foreach item [array names ::env HTTP_*] {
      set ::env($item) {}
    }
    set ::env(SCRIPT_NAME) [my request get REQUEST_PATH]
    set ::env(SERVER_PROTOCOL) HTTP/1.0
    set ::env(HOME) $::env(DOCUMENT_ROOT)
    foreach {f v} [my request dump] {
      set ::env($f) $v
    }
  	set arglist $::env(QUERY_STRING)
    set pwd [pwd]
    cd [file dirname $local_file]
    set script_file $local_file
    if {[file extension $local_file] in {.fossil .fos}} {
      if {![file exists $local_file.cgi]} {
        set fout [open $local_file.cgi w]
        chan puts $fout "#!/usr/bin/fossil"
        chan puts $fout "repository: $local_file"
        close $fout
      }
      set script_file $local_file.cgi
      set EXE [my Cgi_Executable fossil]
    } else {
      set EXE [my Cgi_Executable $local_file]
    }
    set ::env(PATH_TRANSLATED) $script_file
    set pipe [my CgiExec $EXE $script_file $arglist]
    cd $pwd
    return $pipe
  }
  method ProxyRequest {chana chanb} {
    chan event $chanb writable {}
    my log ProxyRequest {}
    set length [my request get CONTENT_LENGTH]
    if {$length} {
      chan configure $chana -translation binary -blocking 0 -buffering full -buffersize 4096
      chan configure $chanb -translation binary -blocking 0 -buffering full -buffersize 4096
      ###
      # Send any POST/PUT/etc content
      ###
      my ChannelCopy $chana $chanb -size $length
    } else {
      chan flush $chanb
    }
    my clay refcount_incr
    chan event $chanb readable [info coroutine]
    yield
  }
  method ProxyReply {chana chanb args} {
    my log ProxyReply [list args $args]
    chan event $chana readable {}
    set replyhead [my HttpHeaders $chana]
    set replydat  [my MimeParse $replyhead]
    if {![dict exists $replydat Content-Length]} {
      set length 0
    } else {
      set length [dict get $replydat Content-Length]
    }
    ###
    # Convert the Status: header from the CGI process to
    # a standard service reply line from a web server, but
    # otherwise spit out the rest of the headers verbatim
    ###
    set replybuffer "HTTP/1.0 [dict get $replydat Status]\n"
    append replybuffer $replyhead
    chan configure $chanb -translation {auto crlf} -blocking 0 -buffering full -buffersize 4096
    chan puts $chanb $replybuffer
    ###
    # Output the body. With no -size flag, channel will copy until EOF
    ###
    chan configure $chana -translation binary -blocking 0 -buffering full -buffersize 4096
    chan configure $chanb -translation binary -blocking 0 -buffering full -buffersize 4096
    my ChannelCopy $chana $chanb -chunk 4096
    my clay refcount_decr
  }
  method DirectoryListing {local_file} {
    my error 403 {Not Allowed}
    tailcall my DoOutput
  }
}

###
# END: cgi.tcl
###
###
# START: scgi.tcl
###
::clay::define ::httpd::protocol.scgi {
  method EncodeStatus {status} {
    return "Status: $status"
  }
}
::clay::define ::httpd::content.scgi {
  superclass ::httpd::content.proxy
  method scgi_info {} {
    ###
    # This method should check if a process is launched
    # or launch it if needed, and return a list of
    # HOST PORT SCRIPT_NAME
    ###
    # return {localhost 8016 /some/path}
    error unimplemented
  }
  method proxy_channel {} {
    set sockinfo [my scgi_info]
    if {$sockinfo eq {}} {
      my error 404 {Not Found}
      tailcall my DoOutput
    }
    lassign $sockinfo scgihost scgiport scgiscript
    my clay set  SCRIPT_NAME $scgiscript
    if {![string is integer $scgiport]} {
      my error 404 {Not Found}
      tailcall my DoOutput
    }
    return [::socket $scgihost $scgiport]
  }
  method ProxyRequest {chana chanb} {
    chan event $chanb writable {}
    my log ProxyRequest {}
    chan configure $chana -translation binary -blocking 0 -buffering full -buffersize 4096
    chan configure $chanb -translation binary -blocking 0 -buffering full -buffersize 4096
    set info [dict create CONTENT_LENGTH 0 SCGI 1.0 SCRIPT_NAME [my clay get SCRIPT_NAME]]
    foreach {f v} [my request dump] {
      dict set info $f $v
    }
    set length [dict get $info CONTENT_LENGTH]
    set block {}
    foreach {f v} $info {
      append block [string toupper $f] \x00 $v \x00
    }
    chan puts -nonewline $chanb "[string length $block]:$block,"
    # Light off another coroutine
    #set cmd [list coroutine [my CoroName] {*}[namespace code [list my ProxyReply $chanb $chana]]]
    if {$length} {
      chan configure $chana -translation binary -blocking 0 -buffering full -buffersize 4096
      chan configure $chanb -translation binary -blocking 0 -buffering full -buffersize 4096
      ###
      # Send any POST/PUT/etc content
      ###
      my ChannelCopy $chana $chanb -size $length
      #chan copy $chana $chanb -size $length -command [info coroutine]
    } else {
      chan flush $chanb
    }
    chan event $chanb readable [info coroutine]
    yield
  }
  method ProxyReply {chana chanb args} {
    my log ProxyReply [list args $args]
    chan event $chana readable {}
    set replyhead [my HttpHeaders $chana]
    set replydat  [my MimeParse $replyhead]
    ###
    # Convert the Status: header from the CGI process to
    # a standard service reply line from a web server, but
    # otherwise spit out the rest of the headers verbatim
    ###
    set replybuffer "HTTP/1.0 [dict get $replydat Status]\n"
    append replybuffer $replyhead
    chan configure $chanb -translation {auto crlf} -blocking 0 -buffering full -buffersize 4096
    chan puts $chanb $replybuffer
    ###
    # Output the body. With no -size flag, channel will copy until EOF
    ###
    chan configure $chana -translation binary -blocking 0 -buffering full -buffersize 4096
    chan configure $chanb -translation binary -blocking 0 -buffering full -buffersize 4096
    my ChannelCopy $chana $chanb -chunk 4096
  }
}
::clay::define ::httpd::server.scgi {
  superclass ::httpd::server
  clay set socket/ buffersize   32768
  clay set socket/ blocking     0
  clay set socket/ translation  {binary binary}
  method debug args {
    puts $args
  }
  method Connect {uuid sock ip} {
    yield [info coroutine]
    chan event $sock readable {}
    chan configure $sock \
        -blocking 1 \
        -translation {binary binary} \
        -buffersize 4096 \
        -buffering none
    my counter url_hit
    try {
      # Read the SCGI request on byte at a time until we reach a ":"
      dict set query http HTTP_HOST {}
      dict set query http CONTENT_LENGTH 0
      dict set query http REQUEST_URI /
      dict set query http REMOTE_ADDR $ip
      dict set query http DOCUMENT_ROOT [my clay get server/ doc_root]
      set size {}
      while 1 {
        set char [::coroutine::util::read $sock 1]
        if {[chan eof $sock]} {
          catch {close $sock}
          return
        }
        if {$char eq ":"} break
        append size $char
      }
      # With length in hand, read the netstring encoded headers
      set inbuffer [::coroutine::util::read $sock [expr {$size+1}]]
      chan configure $sock -translation {auto crlf} -blocking 0 -buffersize 4096 -buffering full
      foreach {f v} [lrange [split [string range $inbuffer 0 end-1] \0] 0 end-1] {
        dict set query http $f $v
      }
      if {![dict exists $query http REQUEST_PATH]} {
        set uri [dict get $query http REQUEST_URI]
        set uriinfo [::uri::split $uri]
        dict set query http REQUEST_PATH    [dict get $uriinfo path]
      }
      set reply [my dispatch $query]
    } on error {err errdat} {
      my debug [list uri: [dict getnull $query http REQUEST_URI] ip: $ip error: $err errorinfo: [dict get $errdat -errorinfo]]
      my log BadRequest $uuid [list ip: $ip error: $err errorinfo: [dict get $errdat -errorinfo]]
      catch {chan puts $sock "HTTP/1.0 400 Bad Request (The data is invalid)"}
      catch {chan event readable $sock {}}
      catch {chan event writeable $sock {}}
      catch {chan close $sock}
      return
    }
    if {[dict size $reply]==0} {
      my log BadLocation $uuid $query
      dict set query http HTTP_STATUS 404
      dict set query template notfound
      dict set query mixin reply ::httpd::content.template
    }
    try {
      set pageobj [::httpd::reply create ::httpd::object::$uuid [self]]
      dict set reply mixin protocol ::httpd::protocol.scgi
      $pageobj dispatch $sock $reply
    } on error {err errdat} {
      my debug [list ip: $ip error: $err errorinfo: [dict get $errdat -errorinfo]]
      my log BadRequest $uuid [list ip: $ip error: $err errorinfo: [dict get $errdat -errorinfo]]
      $pageobj clay refcount_decr
      catch {chan event readable $sock {}}
      catch {chan event writeable $sock {}}
      catch {chan close $sock}
      return
    }
  }
}

###
# END: scgi.tcl
###
###
# START: websocket.tcl
###
::clay::define ::httpd::content.websocket {
}

###
# END: websocket.tcl
###
###
# START: plugin.tcl
###
::clay::define ::httpd::plugin {
  clay set plugin/ load {}
  clay set plugin/ headers {}
  clay set plugin/ dispatch {}
  clay set plugin/ local_config {}
  clay set plugin/ thread {}
}
::clay::define ::httpd::plugin.dict_dispatch {
  clay set plugin/ dispatch {
    set reply [my Dispatch_Dict $data]
    if {[dict size $reply]} {
      return $reply
    }
  }
  method Dispatch_Dict {data} {
    my variable url_patterns
    set vhost [lindex [split [dict get $data http HTTP_HOST] :] 0]
    set uri   [dict get $data http REQUEST_PATH]
    foreach {host hostpat} $url_patterns {
      if {![string match $host $vhost]} continue
      foreach {pattern info} $hostpat {
        if {![string match $pattern $uri]} continue
        set buffer $data
        foreach {f v} $info {
          dict set buffer $f $v
        }
        return $buffer
      }
    }
    return {}
  }
  Ensemble uri::add {vhosts patterns info} {
    my variable url_patterns
    foreach vhost $vhosts {
      foreach pattern $patterns {
        set data $info
        if {![dict exists $data prefix]} {
           dict set data prefix [my PrefixNormalize $pattern]
        }
        dict set url_patterns $vhost [string trimleft $pattern /] $data
      }
    }
  }
  Ensemble uri::direct {vhosts patterns info body} {
    my variable url_patterns url_stream
    set cbody {}
    if {[dict exists $info superclass]} {
      append cbody \n "superclass {*}[dict get $info superclass]"
      dict unset info superclass
    }
    append cbody \n [list method content {} $body]

    set class [namespace current]::${vhosts}/${patterns}
    set class [string map {* %} $class]
    ::clay::define $class $cbody
    dict set info mixin content $class
    my uri add $vhosts $patterns $info
  }
}
::clay::define ::httpd::reply.memchan {
  superclass ::httpd::reply
  method output {} {
    my variable reply_body
    return $reply_body
  }
  method DoOutput {} {}
  method close {} {
    # Neuter the channel closing mechanism we need the channel to stay alive
    # until the reader sucks out the info
  }
}
::clay::define ::httpd::plugin.local_memchan {
  clay set plugin/ load {
package require tcl::chan::events
package require tcl::chan::memchan
  }
  method local_memchan {command args} {
    my variable sock_to_coro
    switch $command {
      geturl {
        ###
        # Hook to allow a local process to ask for data without a socket
        ###
        set uuid [my Uuid_Generate]
        set ip 127.0.0.1
        set sock [::tcl::chan::memchan]
        set output [coroutine ::httpd::coro::$uuid {*}[namespace code [list my Connect_Local $uuid $sock GET {*}$args]]]
        return $output
      }
      default {
        error "Valid: connect geturl"
      }
    }
  }
  method Connect_Local {uuid sock args} {
    chan event $sock readable {}

    chan configure $sock \
      -blocking 0 \
      -translation {auto crlf} \
      -buffering line
    set ip 127.0.0.1
    dict set query UUID $uuid
    dict set query http UUID $uuid
    dict set query http HTTP_HOST       localhost
    dict set query http REMOTE_ADDR     127.0.0.1
    dict set query http REMOTE_HOST     localhost
    dict set query http LOCALHOST 1
    my counter url_hit

    dict set query http REQUEST_METHOD  [lindex $args 0]
    set uriinfo [::uri::split [lindex $args 1]]
    dict set query http REQUEST_URI     [lindex $args 1]
    dict set query http REQUEST_PATH    [dict get $uriinfo path]
    dict set query http REQUEST_VERSION [lindex [split [lindex $args end] /] end]
    dict set query http DOCUMENT_ROOT   [my clay get server/ doc_root]
    dict set query http QUERY_STRING    [dict get $uriinfo query]
    dict set query http REQUEST_RAW     $args
    dict set query http SERVER_PORT     [my port_listening]
    my Headers_Process query
    set reply [my dispatch $query]

    if {[llength $reply]==0} {
      my log BadLocation $uuid $query
      my log BadLocation $uuid $query
      dict set query http HTTP_STATUS 404
      dict set query template notfound
      dict set query mixin reply ::httpd::content.template
    }

    set class ::httpd::reply.memchan
    set pageobj [$class create ::httpd::object::$uuid [self]]
    if {[dict exists $reply mixin]} {
      set mixinmap [dict get $reply mixin]
    } else {
      set mixinmap {}
    }
    foreach item [dict keys $reply MIXIN_*] {
      set slot [string range $reply 6 end]
      dict set mixinmap [string tolower $slot] [dict get $reply $item]
    }
    $pageobj clay mixinmap {*}$mixinmap
    if {[dict exists $reply delegate]} {
      $pageobj clay delegate {*}[dict get $reply delegate]
    }
    $pageobj dispatch $sock $reply
    set output [$pageobj output]
    $pageobj clay refcount_decr
    return $output
  }
}

###
# END: plugin.tcl
###
###
# START: cuneiform.tcl
###

###
# END: cuneiform.tcl
###

    namespace eval ::httpd {
	namespace export *
    }

