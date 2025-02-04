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

  if (oc != 3) {
    Tcl_WrongNumArgs(interp, 1, ov, "x y");
    return TCL_ERROR;
  }

  /* (int x) - - -- --- ----- -------- */
	{
	if (Tcl_GetIntFromObj(interp, ov[1], &_x) != TCL_OK) return TCL_ERROR; }


  /* (int y) - - -- --- ----- -------- */
	{
	if (Tcl_GetIntFromObj(interp, ov[2], &_y) != TCL_OK) return TCL_ERROR; }

  /* Call - - -- --- ----- -------- */
  c__aproc0(_x, _y);

  /* (void return) - - -- --- ----- -------- */
	return TCL_OK;
}
