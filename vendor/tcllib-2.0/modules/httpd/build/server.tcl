###
# An httpd server with a template engine and a shim to insert URL domains.
#
# This class is the root object of the webserver. It is responsible
# for opening the socket and providing the initial connection negotiation.
###
namespace eval ::httpd::object {}
namespace eval ::httpd::coro {}

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

  ###
  # Reply to an open socket. This method builds a coroutine to manage the remainder
  # of the connection. The coroutine's operations are driven by the [cmd Connect] method.
  ###
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

  ###
  # This method reads HTTP headers, and then consults the [cmd dispatch] method to
  # determine if the request is valid, and/or what kind of reply to generate. Under
  # normal cases, an object of class [cmd ::http::reply] is created, and that class's
  # [cmd dispatch] method.
  # This action passes control of the socket to
  # the reply object. The reply object manages the rest of the transaction, including
  # closing the socket.
  ###
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

  # Increment an internal counter.
  method counter which {
    my variable counters
    incr counters($which)
  }

  ###
  # Check open connections for a time out event.
  ###
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

  ###
  # Given a key/value list of information, return a data structure describing how
  # the server should reply.
  ###
  method dispatch {data} {
    set reply [my Dispatch_Local $data]
    if {[dict size $reply]} {
      return $reply
    }
    return [my Dispatch_Default $data]
  }

  ###
  # Method dispatch method of last resort before returning a 404 NOT FOUND error.
  # The default behavior is to look for a file in [emph DOCUMENT_ROOT] which
  # matches the query.
  ###
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

  ###
  # Method dispatch method invoked prior to invoking methods implemented by plugins.
  # If this method returns a non-empty dictionary, that structure will be passed to
  # the reply. The default is an empty implementation.
  ###
  method Dispatch_Local data {}

  ###
  # Introspect and possibly modify a data structure destined for a reply. This
  # method is invoked before invoking Header methods implemented by plugins.
  # The default implementation is empty.
  ###
  method Headers_Local {varname} {}

  ###
  # Introspect and possibly modify a data structure destined for a reply. This
  # method is built dynamically by the [cmd plugin] method.
  ###
  method Headers_Process varname {}

  ###
  # Convert an ip address to a host name. If the server/ reverse_dns flag
  # is false, this method simply returns the IP address back.
  # Internally, this method uses the [emph dns] module from tcllib.
  ###
  method HostName ipaddr {
    if {![my clay get server/ reverse_dns]} {
      return $ipaddr
    }
    set t [::dns::resolve $ipaddr]
    set result [::dns::name $t]
    ::dns::cleanup $t
    return $result
  }

  ###
  # Log an event. The input for args is free form. This method is intended
  # to be replaced by the user, and is a noop for a stock http::server object.
  ###
  method log args {
    # Do nothing for now
  }

  ###
  # Incorporate behaviors from a plugin.
  # This method dynamically rebuilds the [cmd Dispatch] and [cmd Headers]
  # method. For every plugin, the server looks for the following entries in
  # [emph "clay plugin/"]:
  # [para]
  # [emph load] - A script to invoke in the server's namespace during the [cmd plugin] method invokation.
  # [para]
  # [emph dispatch] - A script to stitch into the server's [cmd Dispatch] method.
  # [para]
  # [emph headers] - A script to stitch into the server's [cmd Headers] method.
  # [para]
  # [emph thread] - A script to stitch into the server's [cmd Thread_start] method.
  ###
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

  # Return the actual port that httpd is listening on.
  method port_listening {} {
    my variable port_listening
    return $port_listening
  }

  # For the stock version, trim trailing /'s and *'s from a prefix. This
  # method can be replaced by the end user to perform any other transformations
  # needed for the application.
  method PrefixNormalize prefix {
    set prefix [string trimright $prefix /]
    set prefix [string trimright $prefix *]
    set prefix [string trimright $prefix /]
    return $prefix
  }

  method source {filename} {
    source $filename
  }

  # Open the socket listener.
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

  # Shut off the socket listener, and destroy any pending replies.
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

  # Return a template for the string [arg page]
  method template page {
    my variable template
    if {[info exists template($page)]} {
      return $template($page)
    }
    set template($page) [my TemplateSearch $page]
    return $template($page)
  }

  # Perform a search for the template that best matches [arg page]. This
  # can include local file searches, in-memory structures, or even
  # database lookups. The stock implementation simply looks for files
  # with a .tml or .html extension in the [opt doc_root] directory.
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

  ###
  # Built by the [cmd plugin] method. Called by the [cmd start] method. Intended
  # to allow plugins to spawn worker threads.
  ###
  method Thread_start {} {}

  ###
  # Generate a GUUID. Used to ensure every request has a unique ID.
  # The default implementation is:
  # [example {
  #   return [::clay::uuid generate]
  # }]
  ###
  method Uuid_Generate {} {
    return [::clay::uuid::short]
  }

  ###
  # Given a socket and an ip address, return true if this connection should
  # be terminated, or false if it should be allowed to continue. The stock
  # implementation always returns 0. This is intended for applications to
  # be able to implement black lists and/or provide security based on IP
  # address.
  ###
  method Validate_Connection {sock ip} {
    return 0
  }
}

###
# Provide a backward compadible alias
###
::clay::define ::httpd::server::dispatch {
    superclass ::httpd::server
}
