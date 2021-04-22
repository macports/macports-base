###
# A class which shephards a request through the process of generating a
# reply.
#
# The socket associated with the reply is available at all times as the [arg chan]
# variable.
#
# The process of generating a reply begins with an [cmd httpd::server] generating a
# [cmd http::class] object, mixing in a set of behaviors and then invoking the reply
# object's [cmd dispatch] method.
#
# In normal operations the [cmd dispatch] method:
#
# [list_begin enumerated]
# [enum]
# Invokes the [cmd reset] method for the object to populate default headers.
# [enum]
# Invokes the [cmd HttpHeaders] method to stream the MIME headers out of the socket
# [enum]
# Invokes the [cmd {request parse}] method to convert the stream of MIME headers into a
# dict that can be read via the [cmd request] method.
# [enum]
# Stores the raw stream of MIME headers in the [arg rawrequest] variable of the object.
# [enum]
# Invokes the [cmd content] method for the object, generating an call to the [cmd error]
# method if an exception is raised.
# [enum]
# Invokes the [cmd output] method for the object
# [list_end]
# [para]
#
# Developers have the option of streaming output to a buffer via the [cmd puts] method of the
# reply, or simply populating the [arg reply_body] variable of the object.
# The information returned by the [cmd content] method is not interpreted in any way.
#
# If an exception is thrown (via the [cmd error] command in Tcl, for example) the caller will
# auto-generate a 500 {Internal Error} message.
#
# A typical implementation of [cmd content] look like:
#
# [example {
#
# clay::define ::test::content.file {
# 	superclass ::httpd::content.file
# 	# Return a file
# 	# Note: this is using the content.file mixin which looks for the reply_file variable
# 	# and will auto-compute the Content-Type
# 	method content {} {
# 	  my reset
#     set doc_root [my request get DOCUMENT_ROOT]
#     my variable reply_file
#     set reply_file [file join $doc_root index.html]
# 	}
# }
# clay::define ::test::content.time {
#   # return the current system time
# 	method content {} {
# 		my variable reply_body
#     my reply set Content-Type text/plain
# 		set reply_body [clock seconds]
# 	}
# }
# clay::define ::test::content.echo {
# 	method content {} {
# 		my variable reply_body
#     my reply set Content-Type [my request get CONTENT_TYPE]
# 		set reply_body [my PostData [my request get CONTENT_LENGTH]]
# 	}
# }
# clay::define ::test::content.form_handler {
# 	method content {} {
# 	  set form [my FormData]
# 	  my reply set Content-Type {text/html; charset=UTF-8}
#     my puts [my html_header {My Dynamic Page}]
#     my puts "<BODY>"
#     my puts "You Sent<p>"
#     my puts "<TABLE>"
#     foreach {f v} $form {
#       my puts "<TR><TH>$f</TH><TD><verbatim>$v</verbatim></TD>"
#     }
#     my puts "</TABLE><p>"
#     my puts "Send some info:<p>"
#     my puts "<FORM action=/[my request get REQUEST_PATH] method POST>"
#     my puts "<TABLE>"
#     foreach field {name rank serial_number} {
#       set line "<TR><TH>$field</TH><TD><input name=\"$field\" "
#       if {[dict exists $form $field]} {
#         append line " value=\"[dict get $form $field]\"""
#       }
#       append line " /></TD></TR>"
#       my puts $line
#     }
#     my puts "</TABLE>"
#     my puts [my html footer]
# 	}
# }
#
# }]
###
::clay::define ::httpd::reply {
  superclass ::httpd::mime
  Variable ChannelRegister {}

  Delegate <server> {
    description {The server object which spawned this reply}
  }

  ###
  # A dictionary which will converted into the MIME headers of the reply
  ###
  Dict reply {}

  ###
  # A dictionary containing the SCGI transformed HTTP headers for the request
  ###
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

  ###
  # clean up on exit
  ###
  destructor {
    my close
  }

  # Registers a channel to be closed by the close method
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

  ###
  # Close channels opened by this object
  ###
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

  ###
  # Record a dispatch event
  ###
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

  ###
  # Accept the handoff from the server object of the socket
  # [emph newsock] and feed it the state [emph datastate].
  # Fields the [emph datastate] are looking for in particular are:
  # [para]
  # * [const mixin] - A key/value list of slots and classes to be mixed into the
  # object prior to invoking [cmd Dispatch].
  # [para]
  # * [const http] - A key/value list of values to populate the object's [emph request]
  # ensemble
  # [para]
  # All other fields are passed along to the [method clay] structure of the object.
  ###
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


  ###
  # REPLACE ME:
  # This method is the "meat" of your application.
  # It writes to the result buffer via the "puts" method
  # and can tweak the headers via "clay put header_reply"
  ###
  method content {} {
    my puts [my html_header {Hello World!}]
    my puts "<H1>HELLO WORLD!</H1>"
    my puts [my html_footer]
  }

  ###
  # Formulate a standard HTTP status header from he string provided.
  ###
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

  ###
  # Generates the the HTTP reply, streams that reply back across [arg chan],
  # and destroys the object.
  ###
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

  ###
  # For GET requests, converts the QUERY_DATA header into a key/value list.
  #
  # For POST requests, reads the Post data and converts that information to
  # a key/value list for application/x-www-form-urlencoded posts. For multipart
  # posts, it composites all of the MIME headers of the post to a singular key/value
  # list, and provides MIME_* information as computed by the [cmd mime] package, including
  # the MIME_TOKEN, which can be fed back into the mime package to read out the contents.
  ###
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

  # Stream [arg length] bytes from the [arg chan] socket, but only of the request is a
  # POST or PUSH. Returns an empty string otherwise.
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

  # Manage session data
  method Session_Load {} {}

  # Appends the value of [arg string] to the end of [arg reply_body], as well as a trailing newline
  # character.
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

  # Clear the contents of the [arg reply_body] variable, and reset all headers in the [cmd reply]
  # structure back to the defaults for this object.
  method reset {} {
    my variable reply_body
    my reply replace    [my HttpHeaders_Default]
    my reply set Server [my <server> clay get server/ string]
    my reply set Date [my timestamp]
    set reply_body {}
  }

  # Called from the [cmd http::server] object which spawned this reply. Checks to see
  # if too much time has elapsed while waiting for data or generating a reply, and issues
  # a timeout error to the request if it has, as well as destroy the object and close the
  # [arg chan] socket.
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

  ###
  # Return the current system time in the format: [example {%a, %d %b %Y %T %Z}]
  ###
  method timestamp {} {
    return [clock format [clock seconds] -format {%a, %d %b %Y %T %Z}]
  }
}
