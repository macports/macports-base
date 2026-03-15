###
# Return data from an SCGI process
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

###
# Act as an  SCGI Server
###
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
