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

  ###
  # For most CGI applications a directory list is vorboten
  ###
  method DirectoryListing {local_file} {
    my error 403 {Not Allowed}
    tailcall my DoOutput
  }
}
