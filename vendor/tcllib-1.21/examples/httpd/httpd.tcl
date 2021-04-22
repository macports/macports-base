###
# "Simple" webserver example
###

set DIR [file dirname [file normalize [info script]]]
set DEMOROOT [file join $DIR htdocs]
set tcllibroot  [file normalize [file join $DIR .. ..]]
set auto_path [linsert $auto_path 0 [file normalize [file join $tcllibroot modules]]]
package require httpd 4.1
###
# This script creates two toplevel domains:
# * Hosting the tcllib embedded documentation as static content
# * Hosting a local fossil mirror of the tcllib repository
###
package require httpd

proc ::fossil-list {} {
  return [::fossil all list]
}
proc ::fossil args {
  if {![info exists ::fossil_exe]} {
    set ::fossil_exe fossil
  }
  if {[llength $args]==0} {
    return $::fossil_exe
  }
  return [exec ${::fossil_exe} {*}$args]
}

clay::define httpd::content.fossil_node_proxy {

  superclass httpd::content.proxy

  method FileName {} {
    set uri    [my request get REQUEST_URI]
    set prefix [my clay get prefix]
    set module [lindex [split $uri /] 2]
    if {![info exists ::fossil_process($module)]} {
      set dbfiles [::fossil-list]
      foreach file [lsort -dictionary $dbfiles]  {
        dict set result [file rootname [file tail $file]] $file
      }
      if {![dict exists $result $module]} {
        return {}
      }
      set dbfile [dict get $result $module]
      if {![file exists $dbfile]} {
        return {}
      }
      set ::fossil_process($module) $dbfile
    }
    return [list $module $::fossil_process($module)]
  }

  method proxy_path {} {
    set uri [string trimleft [my request get REQUEST_URI] /]
    set prefix [my clay get prefix]
    set module [lindex [split $uri /] 1]
    set path /[string range $uri [string length $prefix/$module] end]
    return $path
  }

  method proxy_channel {} {
    ###
    # This method returns a channel to the
    # proxied socket/stdout/etc
    ###
    lassign [my FileName] module dbfile
    set EXE [my Cgi_Executable fossil]
    set baseurl http://[my request get HTTP_HOST][my clay get prefix]/$module
    if { $::tcl_platform(platform) eq "windows"} {
      return [open "|fossil.exe http $dbfile -baseurl $baseurl" r+]
    } else {
      return [open "|fossil http $dbfile -baseurl $baseurl 2>@1" r+]
    }
  }
}

clay::define httpd::content.fossil_node_scgi {

  superclass httpd::content.scgi
  method scgi_info {} {
    set uri    [my request get REQUEST_URI]
    set prefix [my clay get prefix]
    set module [lindex [split $uri /] 2]
    file mkdir ~/tmp
    if {![info exists ::fossil_process($module)]} {
      package require processman
      package require nettool
      set port [::nettool::allocate_port 40000]
      set handle fossil:$port
      set dbfiles [::fossil-list]
      foreach file [lsort -dictionary $dbfiles]  {
        dict set result [file rootname [file tail $file]] $file
      }
      set dbfile [dict get $result $module]
      if {![file exists $dbfile]} {
        tailcall my error 400 {Not Found}
      }
      set mport [my <server> port_listening]
      set cmd [list [::fossil] server $dbfile --port $port --localhost --scgi 2>~/tmp/$module.err >~/tmp/$module.log]

      dict set ::fossil_process($module) port $port
      dict set ::fossil_process($module) handle $handle
      dict set ::fossil_process($module) cmd $cmd
      dict set ::fossil_process($module) SCRIPT_NAME $prefix/$module
    }
    dict with ::fossil_process($module) {}
    if {![::processman::running $handle]} {
      set process [::processman::spawn $handle {*}$cmd]
      my varname paused
      after 500
    }
    return [list localhost $port $SCRIPT_NAME]
  }
}

::clay::define ::docserver::server {
  superclass ::httpd::server

  method debug args {
    #puts [list DEBUG {*}$args]
  }
  method log args {
    #puts [list LOG {*}$args]
  }

}

set serveropts [::httpd::server clay get server/]
foreach {f v}  [::clay::args_to_options {*}$::argv] {
  if {[dict exists $serveropts $f]} {
    dict set serveropts $f $v
  }
}
if {[dict exists $serveropts fossil]} {
  set ::fossil_exe [dict get $serveropts fossil]
}

::docserver::server create appmain doc_root $DEMOROOT {*}$argv
appmain plugin basic_url ::httpd::plugin.dict_dispatch
appmain uri add * /tcllib* [list mixin {reply httpd::content.file} path [file join $tcllibroot embedded www]]
appmain uri direct * /fossil {} {
  my puts "<HTML><HEAD><TITLE>Local Fossil Repositories</TITLE></HEAD><BODY>"
  global recipe
  my puts "<UL>"
  set dbfiles [::fossil-list]
  foreach file [lsort -dictionary $dbfiles]  {
    dict set result [file rootname [file tail $file]] $file
  }
  foreach {module dbfile} [lsort -dictionary -stride 2 $result] {
    my puts "<li><a HREF=/fossil/$module>$module</a>"
  }
  my puts {</UL></BODY></HTML>}
}
appmain uri add * /fossil/* [list mixin {reply httpd::content.fossil_node_proxy}]
appmain uri direct * /upload {} {
  my puts "<HTML><HEAD><TITLE>IRM Dispatch Server</TITLE></HEAD><BODY>"
  my puts "<TABLE width=100%>"
  set FORMDAT [my FormData]
  foreach {f v} [my FormData] {
      my puts "<tr><th>$f</th><td>$v</td></tr>"
  }
  my puts "<tr><td colspan=10><hr></td></tr>"
  foreach {f v} [my clay dump] {
      my puts "<tr><th>$f</th><td>$v</td></tr>"
  }
  my puts "<tr><td colspan=10><hr></td></tr>"
  foreach part [dict getnull $FORMDAT MIME_PARTS] {
    my puts "<tr><td colspan=10><hr></td></tr>"
    foreach f [::mime::getheader $part -names] {
      my puts "<tr><th>$f</th><td>[mime::getheader $part $f]</td></tr>"
    }
    my puts "<tr><td colspan=10>[::mime::getbody $part -decode]</td></tr>"
  }
  my puts "<tr><th>File Size</th><td>[my request get CONTENT_LENGTH]</td></tr>"
  my puts </TABLE>
  my puts </BODY></HTML>
}
appmain uri direct * /dynamic {} {
  my puts "<HTML><HEAD><TITLE>IRM Dispatch Server</TITLE></HEAD><BODY>"
  my puts "<TABLE width=100%>"
  foreach {f v} [my request dump] {
    my puts "<tr><th>$f</th><td>$v</td></tr>"
  }
  my puts "<tr><td colspan=10><hr></td></tr>"
  foreach {f v} [my clay dump] {
    my puts "<tr><th>$f</th><td>$v</td></tr>"
  }
  my puts "<tr><th>File Size</th><td>[my request get CONTENT_LENGTH]</td></tr>"
  my puts </TABLE>
  my puts </BODY></HTML>
}

puts [list LISTENING on [appmain port_listening]]
cron::main
