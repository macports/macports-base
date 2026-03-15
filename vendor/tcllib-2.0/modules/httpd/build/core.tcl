###
# Author: Sean Woods, yoda@etoyoc.com
##
# Adapted from the "minihttpd.tcl" file distributed with Tclhttpd
#
# The working elements have been updated to operate as a TclOO object
# running with Tcl 8.6+. Global variables and hard coded tables are
# now resident with the object, allowing this server to be more easily
# embedded another program, as well as be adapted and extended to
# support the SCGI module
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

namespace eval httpd::content {}

namespace eval ::url {}
namespace eval ::httpd {}
namespace eval ::scgi {}

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

###
# A metaclass for MIME handling behavior across a live socket
###
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

  ###
  # Returns a block of HTML
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

  ###
  # Converts a block of mime encoded text to a key/value list. If an exception is encountered,
  # the method will generate its own call to the [cmd error] method, and immediately invoke
  # the [cmd output] method to produce an error code and close the connection.
  ###
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

  # De-httpizes a string.
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
