###
# Author: Sean Woods, yoda@etoyoc.com
###
# This file provides the "application" side of the SCGI protocol
###

package require html
package require TclOO
package require httpd 4.0

namespace eval ::scgi {}

tool::class create ::scgi::reply {  
  superclass ::httpd::reply
  
  ###
  # A modified dispatch method from a standard HTTP reply
  # Unlike in HTTP, our headers were spoon fed to use from
  # the server
  ###
  method dispatch {newsock datastate} {
    my query_headers replace $datastate
    my variable chan rawrequest dipatched_time
    set chan $newsock
    chan event $chan readable {}
    chan configure $chan -translation {auto crlf} -buffering line
    set dispatched_time [clock seconds]
    try {
      # Dispatch to the URL implementation.
      my content
    } on error {err info} {
      puts stderr $::errorInfo
      my error 500 $err
    } finally {
      my output
    }
  }
  
  method EncodeStatus {status} {
    return "Status: $status"
  }
}

tool::class create scgi::app {
  superclass ::httpd::server

  property socket buffersize   32768
  property socket blocking     0
  property socket translation  {binary binary}
  
  property reply_class ::scgi::reply
  
  method connect {sock ip port} {
    ###
    # If an IP address is blocked
    # send a "go to hell" message
    ###
    if {[my validation Blocked_IP $sock $ip]} {
      catch {close $sock}
      return
    }
    set query {
      REQUEST_URI {NOT_POPULATED}
    }
    try {
      chan configure $sock \
        -blocking 1 \
        -translation {binary binary} \
        -buffersize 4096 \
        -buffering none
    
      # Read the SCGI request on byte at a time until we reach a ":"
      set size {}
      while 1 {
        set char [read $sock 1]
        if {[chan eof $sock]} {
          catch {close $sock}
          return
        }
        if {$char eq ":"} break
        append size $char
      }
      # With length in hand, read the netstring encoded headers
      set inbuffer [read $sock [expr $size+1]]
      chan configure $sock -blocking 0 -buffersize 4096 -buffering full
      set query [lrange [split [string range $inbuffer 0 end-1] \0] 0 end-1]
      set reply [my dispatch $query]
      dict with query {}
      if {[llength $reply]} {
        if {[dict exists $reply class]} {
          set class [dict get $reply class]          
        } else {
          set class [my cget reply_class]
        }  
        set pageobj [$class create [namespace current]::reply::[::tool::uuid_short] [self]]
        if {[dict exists $reply mixin]} {
          oo::objdefine $pageobj mixin [dict get $reply mixin]
        }
        $pageobj dispatch $sock $reply
        my log HttpAccess $REQUEST_URI
      } else {
        try {
          my log HttpMissing $REQUEST_URI
          puts $sock "Status: 404 NOT FOUND"
          dict with query {}
          set body [subst [my template notfound]]
          puts $sock "Content-length: [string length $body]"
          puts $sock
          puts $sock $body
        } on error {err errdat} {
          puts stderr "FAILED ON 404: $err"
        } finally {
          catch {close $sock}
        }
      }
    } on error {err errdat} {
      try {
        puts stderr $::errorInfo
        puts $sock "Status: 505 INTERNAL ERROR"
        dict with query {}
        set body [subst [my template internal_error]]
        puts $sock "Content-length: [string length $body]"
        puts $sock
        puts $sock $body
        my log HttpError $REQUEST_URI
      } on error {err errdat} {
        puts stderr "FAILED ON 505: $err $::errorInfo"
      } finally {
        catch {close $sock}
      }
    }
  }
}

package provide scgi::app 0.1
