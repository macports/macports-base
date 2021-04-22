
::clay::define ::practcl::subproject.core {
  superclass ::practcl::subproject.binary

  method env-bootstrap {} {}

  method env-present {} {
    set PREFIX [my <project> define get prefix]
    set name [my define get name]
    set fname [file join $PREFIX lib ${name}Config.sh]
    return [file exists $fname]
  }

  method env-install {} {
    my unpack
    set os [::practcl::local_os]

    set prefix [my <project> define get prefix [file normalize [file join ~ tcl]]]
    lappend options --prefix $prefix --exec-prefix $prefix
    my define set config_opts $options
    puts [list [self] OS [dict get $os TEACUP_OS] options $options]
    my go
    my compile
    my make install {}
  }

  method go {} {
    my define set core_binary 1
    next
  }

  method linktype {} {
    return {subordinate core.library}
  }
}
