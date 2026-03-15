###
# Class to deliver Static content
# When utilized, this class is fed a local filename
# by the dispatcher
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
