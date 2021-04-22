###
# Create an object to represent the local environment
###
set ::practcl::MAIN ::practcl::LOCAL
# Defer the creation of the ::practcl::LOCAL object until it is called
# in order to allow packages to
set ::auto_index(::practcl::LOCAL) {
  ::practcl::project create ::practcl::LOCAL
  ::practcl::LOCAL define set [::practcl::local_os]
  ::practcl::LOCAL define set LOCAL 1

  # Until something better comes along, use ::practcl::LOCAL
  # as our main project
  # Add tclconfig as a project of record
  ::practcl::LOCAL add_tool tclconfig {
    name tclconfig tag practcl class subproject.source fossil_url http://core.tcl.tk/tclconfig
  }
  # Add tcllib as a project of record
  ::practcl::LOCAL add_tool tcllib {
    tag trunk class sak fossil_url http://core.tcl.tk/tcllib
  }
  ::practcl::LOCAL add_tool kettle {
    tag trunk class sak fossil_url http://fossil.etoyoc.com/fossil/kettle
  }
  ::practcl::LOCAL add_tool tclvfs {
    tag trunk class tea
    fossil_url http://fossil.etoyoc.com/fossil/tclvfs
  }
  ::practcl::LOCAL add_tool critcl {
    tag master class subproject.binary
    git_url http://github.com/andreas-kupries/critcl
    modules lib
  } {
    method env-bootstrap {} {
      package require critcl::app
    }
    method env-install {} {
      my unpack
      set prefix [my <project> define get prefix [file join [file normalize ~] tcl]]
      set srcdir [my define get srcdir]
      ::practcl::dotclexec [file join $srcdir build.tcl] install [file join $prefix lib]
    }
  }
  ::practcl::LOCAL add_tool odie {
    tag trunk class subproject.source
    fossil_url http://fossil.etoyoc.com/fossil/odie
  }
  ::practcl::LOCAL add_tool tcl {
    tag release class subproject.core
    fossil_url http://core.tcl.tk/tcl
  }
  ::practcl::LOCAL add_tool tk {
    tag release class subproject.core
    fossil_url http://core.tcl.tk/tcl
  }
  ::practcl::LOCAL add_tool sqlite {
    tag practcl
    class subproject.tea
    pkg_name sqlite3
    fossil_url http://fossil.etoyoc.com/fossil/sqlite
  }
}
