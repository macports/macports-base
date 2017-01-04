[example {
                                           USER
                                            |
                                        Common API
                                            |
                +---------------------------+---------------------------+
                |                           |                           |

           Interpreted               Specialized Tcl              Specialized C
    +------------------------+  +------------------------+  +------------------------+
    | [container] +          |  | [snit or TclOO]        |  | C code alone or embed- |
    | pt::peg::interp        |  |                        |  | ded in Tcl (Critcl)    |
    +========================+  +========================+  |                        |
    | pt::rde                |  | pt::rde                |  |                        |
    |                        |  |                        |  |                        |
    | Tcl           | Critcl |  | Tcl           | Critcl |  |                        |
    +===============+        |  +===============+        |  |                        |
    | struct::stack |        |  | struct::stack |        |  |                        |
    |               |        |  |               |        |  |                        |
    | Tcl  | Critcl |        |  | Tcl  | Critcl |        |  |                        |
    +------+--------+--------+  +------+--------+--------+  +------------------------+
}]
