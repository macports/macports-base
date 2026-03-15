# crc32c.tcl -- Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# CRC32 Cyclic Redundancy Check. 
# (for algorithm see http://www.rad.com/networks/1994/err_con/crc.htm)
#
# From http://mini.net/tcl/2259.tcl
# Written by Wayland Augur and Pat Thoyts.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------
# This provides a critcl C implementation of CRC
#
# INSTALLATION
# ------------
# This package uses critcl (http://wiki.tcl.tk/critcl). To build do:
#  critcl -libdir <your-tcl-lib-dir> -pkg crcc crc32c.tcl sumc.tcl
#
# To build this for tcllib use sak.tcl:
#  tclsh sak.tcl critcl
# generates a tcllibc module.

package require critcl
# @sak notprovided crcc
package provide crcc 1.3.4

# -------------------------------------------------------------------------

# crc::Crc32_c --
#
#	A C version of the CRC-32 code using the same table. This is
#	designed to be compiled using critcl.
#

namespace eval ::crc {
    critcl::ccommand Crc32_c {dummy interp objc objv} {
        int r = TCL_OK;
        unsigned long t = 0xFFFFFFFFL;

        if (objc < 2 || objc > 3) {
            Tcl_WrongNumArgs(interp, 1, objv, "data ?seed?"); /* OK tcl9 */
            return TCL_ERROR;
        }
        if (objc == 3) {
            r = Tcl_GetLongFromObj(interp, objv[2], (long *)&t);
        }
        if (r == TCL_OK) {
            Tcl_Size cn, size, ndx;
            unsigned char *data;
            unsigned long lkp;
            Tcl_Obj *tblPtr, *lkpPtr;

            tblPtr = Tcl_GetVar2Ex(interp, "::crc::crc32_tbl", NULL,
                                   TCL_LEAVE_ERR_MSG );
            if (tblPtr == NULL) {
                r = TCL_ERROR;
            }
            if (r == TCL_OK) {
                data = Tcl_GetBytesFromObj(interp, objv[1], &size); /* OK tcl9 */
                if (data == NULL) return TCL_ERROR;
            }
            for (cn = 0; r == TCL_OK && cn < size; cn++) {
                ndx = (t ^ data[cn]) & 0xFF;
                r = Tcl_ListObjIndex(interp, tblPtr, ndx, &lkpPtr); /* OK tcl9 */
                if (r == TCL_OK) {
                    r = Tcl_GetLongFromObj(interp, lkpPtr, (long*) &lkp);
                }
                if (r == TCL_OK) {
                    t = lkp ^ (t >> 8);
                }
            }
        }

        if (r == TCL_OK) {
            Tcl_SetObjResult(interp, Tcl_NewLongObj(t ^ 0xFFFFFFFF));
        }
        return r;
    }
}

# -------------------------------------------------------------------------
#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
