/* ---------------------------------------------------------------------- */

#define ns__aproc0 "::aproc"
static void c__aproc0(int x, int y)
{

}

static int
tcl__aproc0(ClientData cd, Tcl_Interp *interp, Tcl_Size oc, Tcl_Obj *CONST ov[])
{
  int _x;
  int _y;

  critcl_trace_cmd_args (ns__aproc0, oc, ov);

  if (oc != 3) {
    Tcl_WrongNumArgs(interp, 1, ov, "x y");
    return critcl_trace_cmd_result (TCL_ERROR, interp);
  }

  /* (int x) - - -- --- ----- -------- */
	{
	if (Tcl_GetIntFromObj(interp, ov[1], &_x) != TCL_OK) return critcl_trace_cmd_result (TCL_ERROR, interp); }


  /* (int y) - - -- --- ----- -------- */
	{
	if (Tcl_GetIntFromObj(interp, ov[2], &_y) != TCL_OK) return critcl_trace_cmd_result (TCL_ERROR, interp); }

  /* Call - - -- --- ----- -------- */
  c__aproc0(_x, _y);

  /* (void return) - - -- --- ----- -------- */
	return critcl_trace_cmd_result (TCL_OK, interp);
}
