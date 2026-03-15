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

###
# Return data from an proxy process
###
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
