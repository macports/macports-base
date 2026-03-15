# sum.tcl - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Provides a Tcl only implementation of the unix sum(1) command. There are
# a number of these and they use differing algorithms to get a checksum of
# the input data. We provide two: one using the BSD algorithm and the other
# using the SysV algorithm. More consistent results across multiple
# implementations can be obtained by using cksum(1).
#
# These commands have been checked against the GNU sum program from the GNU
# textutils package version 2.0 to ensure the same results.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require critcl
## @/sak notprovided sumc
# package provide sumc 1.1.3

namespace eval ::crc {
    critcl::ccommand SumSysV_c {dummy interp objc objv} {
        int r = TCL_OK;
        unsigned int t = 0;

        if (objc < 2 || objc > 3) {
            Tcl_WrongNumArgs(interp, 1, objv, "data ?seed?"); /* OK tcl9 */
            return TCL_ERROR;
        }
        if (objc == 3) {
            r = Tcl_GetIntFromObj(interp, objv[2], (int *)&t); /* OK tcl9 */
        }
        if (r == TCL_OK) {
            Tcl_Size cn, size;
            unsigned char *data;

            data = Tcl_GetBytesFromObj(interp, objv[1], &size); /* OK tcl9 */
            if (data == NULL) return TCL_ERROR;

            for (cn = 0; cn < size; cn++) t += data[cn];
        }

        t = t & 0xffffffffLU;
        t = (t & 0xffff) + (t >> 16);
        t = (t & 0xffff) + (t >> 16);

        Tcl_SetObjResult(interp, Tcl_NewIntObj(t)); /* OK tcl9 */
        return r;
    }

    critcl::ccommand SumBsd_c {dummy interp objc objv} {
        int r = TCL_OK;
        unsigned int t = 0;

        if (objc < 2 || objc > 3) {
            Tcl_WrongNumArgs(interp, 1, objv, "data ?seed?"); /* OK tcl9 */
            return TCL_ERROR;
        }
        if (objc == 3) {
            r = Tcl_GetIntFromObj(interp, objv[2], (int *)&t); /* OK tcl9 */
        }
        if (r == TCL_OK) {
            Tcl_Size cn, size;
            unsigned char *data;

            data = Tcl_GetBytesFromObj(interp, objv[1], &size); /* OK tcl9 */
            if (data == NULL) return TCL_ERROR;

            for (cn = 0; cn < size; cn++) {
               t = (t & 1) ? ((t >> 1) + 0x8000) : (t >> 1);
               t = (t + data[cn]) & 0xFFFF;
            }
        }

        Tcl_SetObjResult(interp, Tcl_NewIntObj(t & 0xFFFF)); /* OK tcl9 */
        return r;
    }
}

# -------------------------------------------------------------------------    
# Local Variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
