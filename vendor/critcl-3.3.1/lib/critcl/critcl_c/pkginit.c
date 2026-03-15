
#ifdef __cplusplus
extern "C" {
#endif
      ${ext}
DLLEXPORT int
${ininame}_Init(Tcl_Interp *interp)
{
#define ip interp
#if USE_TCL_STUBS
  if (!MyInitTclStubs(interp)) return TCL_ERROR;
#endif
