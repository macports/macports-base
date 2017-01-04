###
# Standard library of HTTP/SCGI content
# Each of these classes are intended to be mixed into
# either an HTTPD or SCGI reply
###
package require Markdown
package require fileutil::magic::mimetype
package require tool 0.4
package require fileutil
namespace eval httpd::content {}

###
# Class to deliver Static content
# When utilized, this class is fed a local filename
# by the dispatcher
###
::tool::define ::httpd::content::file {
  
  method FileName {} {
    set uri [string trimleft [my query_headers get REQUEST_URI] /]
    set path [my query_headers get path]
    set prefix [my query_headers get prefix]
    set fname [string range $uri [string length $prefix] end]
    if {$fname in "{} index.html index.md index"} {
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
    return {}
  }
  
  
  method DirectoryListing {local_file} {
    my puts "<HTML><BODY><TABLE>"
    foreach file [glob -nocomplain [file join $local_file *]] {
      my puts "<TR><TD><a href=\"[file tail $file]\">[file tail $file]</a></TD><TD>[file size $file]</TD></TR>"
    }
    my puts "</TABLE></BODY></HTML>"
  }
  
  method dispatch {newsock datastate} {
    # No need to process the rest of the headers
    my variable chan dipatched_time
    set dispatched_time [clock seconds]
    my query_headers replace $datastate
    set chan $newsock
    my content
    my output
  }

  method content {} {
    my reset
    ###
    # When delivering static content, allow web caches to save
    ###
    my reply_headers set Cache-Control: {max-age=3600}
    my variable reply_file
    set local_file [my FileName]
    if {$local_file eq {} || ![file exist $local_file]} {
      my <server> log httpNotFound [my query_headers get REQUEST_URI]
       tailcall my error 404 {Not Found}
    }
    if {[file isdirectory $local_file]} {
      ###
      # Produce an index page
      ###
      set idxfound 0
      foreach name {
        index.html
        index.tml
        index.md
      } {
        if {[file exists [file join $local_file $name]]} {
          set idxfound 1
          set local_file [file join $local_file $name]
          break
        }
      }
      if {!$idxfound} {
        tailcall DirectoryListing $local_file
      }
    }
    switch [file extension $local_file] {
      .md {
        package require Markdown
        my reply_headers set Content-Type: {text/html; charset=ISO-8859-1}
        set mdtxt  [::fileutil::cat $local_file]
        my puts [::Markdown::convert $mdtxt]
      }
      .tml {
        my reply_headers set Content-Type: {text/html; charset=ISO-8859-1}
        set tmltxt  [::fileutil::cat $local_file]
        set headers [my query_headers dump]
        dict with headers {}
        my puts [subst $tmltxt]        
      }
      default {
        ###
        # Assume we are returning a binary file
        ###
        my reply_headers set Content-Type: [::fileutil::magic::mimetype $local_file]
        set reply_file $local_file
      }
    }
  }

  ###
  # Output the result or error to the channel
  # and destroy this object
  ###
  method output {} {
    my variable reply_body reply_file reply_chan chan
    chan configure $chan  -translation {binary binary}

    set headers [my reply_headers dump]
    if {[dict exists $headers Status:]} {
      set result "[my EncodeStatus [dict get $headers Status:]]\n"
    } else {
      set result "[my EncodeStatus {505 Internal Error}]\n"

    }
    foreach {key value} $headers {
      # Ignore Status and Content-length, if given
      if {$key in {Status: Content-length:}} continue
      append result "$key $value" \n
    }
    if {![info exists reply_file] || [string length $reply_body]} {
      ###
      # Return dynamic content
      ###
      set reply_body [string trim $reply_body]
      append result "Content-length: [string length $reply_body]" \n \n
      append result $reply_body
      puts -nonewline $chan $result
      chan flush $chan    
      my destroy
    } else {
      ###
      # Return a stream of data from a file
      ###
      set size [file size $reply_file]
      append result "Content-length: $size" \n \n
      puts -nonewline $chan $result
      set reply_chan [open $reply_file r]
      chan configure $reply_chan  -translation {binary binary}
      chan copy $reply_chan $chan -command [namespace code [list my TransferComplete $reply_chan]]
    }
  }
}

###
# Return data from an SCGI process
###
::tool::define ::httpd::content::scgi {

  method scgi_info {} {
    ###
    # This method should check if a process is launched
    # or launch it if needed, and return a list of
    # HOST PORT SCRIPT_NAME
    ###
    # return {localhost 8016 /some/path}
    error unimplemented
  }
  
  method content {} {
    my variable sock chan
    set sockinfo [my scgi_info]
    if {$sockinfo eq {}} {
      my error 404 {Not Found}
      return
    }
    lassign $sockinfo scgihost scgiport scgiscript
    set sock [::socket $scgihost $scgiport]
    # Add a few headers that SCGI needs
    my query_headers set SCRIPT_NAME $scgiscript
    my query_headers set SCGI 1.0    

    chan configure $chan -translation binary -blocking 0 -buffering full -buffersize 4096
    chan configure $sock -translation binary -blocking 0 -buffering full -buffersize 4096
    ###
    # Convert our query headers into netstring format. Note that
    # MimeParse as already rigged it such that CONTENT_LENGTH is first
    # and always populated (even if zero), per SCGI requirements
    ###
    set block [my query_headers netstring]
    puts -nonewline $sock $block
    set length [my query_headers get CONTENT_LENGTH]
    if {$length} {
      ###
      # Send any POST/PUT/etc content
      ###
      chan copy $chan $sock -size $length
    }
    chan flush $sock
    ###
    # Wake this object up after the SCGI process starts to respond
    ###
    #chan configure $sock -translation {auto crlf} -blocking 0 -buffering line
    chan event $sock readable [namespace code {my output}]
  }
  
  method output {} {
    if {[my query_headers getnull HTTP_ERROR] ne {}} {
      ###
      # If something croaked internally, handle this page as a normal reply
      ###
      next
    }
    my variable sock chan
    set replyhead [my HttpHeaders $sock]
    set replydat  [my MimeParse $replyhead]
    ###
    # Convert the Status: header from the SCGI service to
    # a standard service reply line from a web server, but
    # otherwise spit out the rest of the headers verbatim
    ###
    set replybuffer "HTTP/1.1 [dict get $replydat HTTP_STATUS]\n"
    append replybuffer $replyhead
    chan configure $chan -translation {auto crlf} -blocking 0 -buffering full -buffersize 4096
    puts $chan $replybuffer
    ###
    # Output the body
    ###
    chan configure $sock -translation binary -blocking 0 -buffering full -buffersize 4096
    chan configure $chan -translation binary -blocking 0 -buffering full -buffersize 4096
    set length [dict get $replydat CONTENT_LENGTH]
    if {$length} {
      ###
      # Send any POST/PUT/etc content
      ###
      chan copy $sock $chan -command [namespace code [list my TransferComplete $sock]]
    } else {
      catch {close $sock}
      chan flush $chan
      my destroy
    }
  }
}

# Act as a proxy server
::tool::define ::httpd::content::proxy {

  method proxy_info {} {
    ###
    # This method should check if a process is launched
    # or launch it if needed, and return a list of
    # HOST PORT PROXYURI
    ###
    # return {localhost 8016 /some/path}
    error unimplemented
  }
  
  method content {} {
    my variable chan sock rawrequest
    set sockinfo [my proxy_info]
    if {$sockinfo eq {}} {
      tailcall my error 404 {Not Found}
    }
    lassign $sockinfo proxyhost proxyport proxyscript
    set sock [::socket $proxyhost $proxyport]
    
    chan configure $chan -translation binary -blocking 0 -buffering full -buffersize 4096
    chan configure $sock -translation {auto crlf} -blocking 1 -buffering line

    # Pass along our modified METHOD URI PROTO
    puts $sock "$proxyscript"
    # Pass along the headers as we saw them
    puts $sock $rawrequest
    set length [my query_headers get CONTENT_LENGTH]
    if {$length} {
      ###
      # Send any POST/PUT/etc content
      ###
      chan copy $chan $sock -size $length
    }
    chan flush $sock
    ###
    # Wake this object up after the proxied process starts to respond
    ###
    chan configure $sock -translation {auto crlf} -blocking 1 -buffering line
    chan event $sock readable [namespace code {my output}]
  }
  
  method output {} {
    if {[my query_headers getnull HTTP_ERROR] ne {}} {
      ###
      # If something croaked internally, handle this page as a normal reply
      ###
      next
    }
    my variable sock chan
    set length 0
    chan configure $sock -translation {crlf crlf} -blocking 1
    set replystatus [gets $sock]
    set replyhead [my HttpHeaders $sock]
    set replydat  [my MimeParse $replyhead]
    
    ###
    # Pass along the status line and MIME headers
    ###
    set replybuffer "$replystatus\n"
    append replybuffer $replyhead
    chan configure $chan -translation {auto crlf} -blocking 0 -buffering full -buffersize 4096
    puts $chan $replybuffer
    ###
    # Output the body
    ###
    chan configure $sock -translation binary -blocking 0 -buffering full -buffersize 4096
    chan configure $chan -translation binary -blocking 0 -buffering full -buffersize 4096
    set length [dict get $replydat CONTENT_LENGTH]
    if {$length} {
      ###
      # Send any POST/PUT/etc content
      ###
      chan copy $sock $chan -command [namespace code [list my TransferComplete $sock]]
    } else {
      catch {close $sock}
      chan flush $chan
      my destroy
    }
  }
}

###
# Modified httpd server with a template engine
# and a shim to insert URL domains
###
::tool::define ::httpd::server::dispatch {
  array template
  option doc_root {default {}}
  variable url_patterns {}
  
  method add_uri {pattern info} {
    my variable url_patterns
    dict set url_patterns $pattern $info
  }
  
  method PrefixNormalize prefix {
    set prefix [string trimright $prefix /]
    set prefix [string trimright $prefix *]
    set prefix [string trimright $prefix /]
    return $prefix
  }
  
  method dispatch {data} {
    set reply $data
    set uri [dict get $data REQUEST_PATH]
    # Search from longest pattern to shortest
    my variable url_patterns
    foreach {pattern info} $url_patterns {
      if {[string match ${pattern} /$uri]} {
        set reply [dict merge $data $info]
        if {![dict exists $reply prefix]} {
          dict set reply prefix [my PrefixNormalize $pattern]
        }
        return $reply
      }
    }
    set doc_root [my cget doc_root]
    if {$doc_root ne {}} {
      ###
      # Fall back to doc_root handling
      ###
      dict set reply prefix {}
      dict set reply path $doc_root
      dict set reply mixin httpd::content::file
      return $reply
    }
    return {}
  }
  
  method TemplateSearch page {
    set doc_root [my cget doc_root]
    if {$doc_root ne {} && [file exists [file join $doc_root $page.tml]]} {
      return [::fileutil::cat [file join $doc_root $page.tml]]
    }
    if {$doc_root ne {} && [file exists [file join $doc_root $page.html]]} {
      return [::fileutil::cat [file join $doc_root $page.html]]
    }
    return [next $page]
  }
}

package provide httpd::content 4.0
