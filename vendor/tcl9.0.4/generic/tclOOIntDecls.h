/*
 * This file is (mostly) automatically generated from tclOO.decls.
 */

#ifndef _TCLOOINTDECLS
#define _TCLOOINTDECLS

#if TCL_MAJOR_VERSION < 9
# define Tcl_MethodType2 void
#endif

/* !BEGIN!: Do not edit below this line. */

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Exported function declarations:
 */

/* 0 */
TCLAPI Tcl_Object	TclOOGetDefineCmdContext(Tcl_Interp *interp);
/* 1 */
TCLAPI Tcl_Method	TclOOMakeProcInstanceMethod(Tcl_Interp *interp,
				Object *oPtr, int flags, Tcl_Obj *nameObj,
				Tcl_Obj *argsObj, Tcl_Obj *bodyObj,
				const Tcl_MethodType *typePtr,
				void *clientData, Proc **procPtrPtr);
/* 2 */
TCLAPI Tcl_Method	TclOOMakeProcMethod(Tcl_Interp *interp,
				Class *clsPtr, int flags, Tcl_Obj *nameObj,
				const char *namePtr, Tcl_Obj *argsObj,
				Tcl_Obj *bodyObj,
				const Tcl_MethodType *typePtr,
				void *clientData, Proc **procPtrPtr);
/* 3 */
TCLAPI Method *		TclOONewProcInstanceMethod(Tcl_Interp *interp,
				Object *oPtr, int flags, Tcl_Obj *nameObj,
				Tcl_Obj *argsObj, Tcl_Obj *bodyObj,
				ProcedureMethod **pmPtrPtr);
/* 4 */
TCLAPI Method *		TclOONewProcMethod(Tcl_Interp *interp, Class *clsPtr,
				int flags, Tcl_Obj *nameObj,
				Tcl_Obj *argsObj, Tcl_Obj *bodyObj,
				ProcedureMethod **pmPtrPtr);
/* 5 */
TCLAPI int		TclOOObjectCmdCore(Object *oPtr, Tcl_Interp *interp,
				Tcl_Size objc, Tcl_Obj *const *objv,
				int publicOnly, Class *startCls);
/* 6 */
TCLAPI int		TclOOIsReachable(Class *targetPtr, Class *startPtr);
/* 7 */
TCLAPI Method *		TclOONewForwardMethod(Tcl_Interp *interp,
				Class *clsPtr, int isPublic,
				Tcl_Obj *nameObj, Tcl_Obj *prefixObj);
/* 8 */
TCLAPI Method *		TclOONewForwardInstanceMethod(Tcl_Interp *interp,
				Object *oPtr, int isPublic, Tcl_Obj *nameObj,
				Tcl_Obj *prefixObj);
/* 9 */
TCLAPI Tcl_Method	TclOONewProcInstanceMethodEx(Tcl_Interp *interp,
				Tcl_Object oPtr,
				TclOO_PreCallProc *preCallPtr,
				TclOO_PostCallProc *postCallPtr,
				ProcErrorProc *errProc, void *clientData,
				Tcl_Obj *nameObj, Tcl_Obj *argsObj,
				Tcl_Obj *bodyObj, int flags,
				void **internalTokenPtr);
/* 10 */
TCLAPI Tcl_Method	TclOONewProcMethodEx(Tcl_Interp *interp,
				Tcl_Class clsPtr,
				TclOO_PreCallProc *preCallPtr,
				TclOO_PostCallProc *postCallPtr,
				ProcErrorProc *errProc, void *clientData,
				Tcl_Obj *nameObj, Tcl_Obj *argsObj,
				Tcl_Obj *bodyObj, int flags,
				void **internalTokenPtr);
/* 11 */
TCLAPI int		TclOOInvokeObject(Tcl_Interp *interp,
				Tcl_Object object, Tcl_Class startCls,
				int publicPrivate, Tcl_Size objc,
				Tcl_Obj *const *objv);
/* 12 */
TCLAPI void		TclOOObjectSetFilters(Object *oPtr,
				Tcl_Size numFilters, Tcl_Obj *const *filters);
/* 13 */
TCLAPI void		TclOOClassSetFilters(Tcl_Interp *interp,
				Class *classPtr, Tcl_Size numFilters,
				Tcl_Obj *const *filters);
/* 14 */
TCLAPI void		TclOOObjectSetMixins(Object *oPtr,
				Tcl_Size numMixins, Class *const *mixins);
/* 15 */
TCLAPI void		TclOOClassSetMixins(Tcl_Interp *interp,
				Class *classPtr, Tcl_Size numMixins,
				Class *const *mixins);
/* 16 */
TCLAPI Tcl_Method	TclOOMakeProcInstanceMethod2(Tcl_Interp *interp,
				Object *oPtr, int flags, Tcl_Obj *nameObj,
				Tcl_Obj *argsObj, Tcl_Obj *bodyObj,
				const Tcl_MethodType2 *typePtr,
				void *clientData, Proc **procPtrPtr);
/* 17 */
TCLAPI Tcl_Method	TclOOMakeProcMethod2(Tcl_Interp *interp,
				Class *clsPtr, int flags, Tcl_Obj *nameObj,
				const char *namePtr, Tcl_Obj *argsObj,
				Tcl_Obj *bodyObj,
				const Tcl_MethodType2 *typePtr,
				void *clientData, Proc **procPtrPtr);

typedef struct TclOOIntStubs {
    int magic;
    void *hooks;

    Tcl_Object (*tclOOGetDefineCmdContext) (Tcl_Interp *interp); /* 0 */
    Tcl_Method (*tclOOMakeProcInstanceMethod) (Tcl_Interp *interp, Object *oPtr, int flags, Tcl_Obj *nameObj, Tcl_Obj *argsObj, Tcl_Obj *bodyObj, const Tcl_MethodType *typePtr, void *clientData, Proc **procPtrPtr); /* 1 */
    Tcl_Method (*tclOOMakeProcMethod) (Tcl_Interp *interp, Class *clsPtr, int flags, Tcl_Obj *nameObj, const char *namePtr, Tcl_Obj *argsObj, Tcl_Obj *bodyObj, const Tcl_MethodType *typePtr, void *clientData, Proc **procPtrPtr); /* 2 */
    Method * (*tclOONewProcInstanceMethod) (Tcl_Interp *interp, Object *oPtr, int flags, Tcl_Obj *nameObj, Tcl_Obj *argsObj, Tcl_Obj *bodyObj, ProcedureMethod **pmPtrPtr); /* 3 */
    Method * (*tclOONewProcMethod) (Tcl_Interp *interp, Class *clsPtr, int flags, Tcl_Obj *nameObj, Tcl_Obj *argsObj, Tcl_Obj *bodyObj, ProcedureMethod **pmPtrPtr); /* 4 */
    int (*tclOOObjectCmdCore) (Object *oPtr, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const *objv, int publicOnly, Class *startCls); /* 5 */
    int (*tclOOIsReachable) (Class *targetPtr, Class *startPtr); /* 6 */
    Method * (*tclOONewForwardMethod) (Tcl_Interp *interp, Class *clsPtr, int isPublic, Tcl_Obj *nameObj, Tcl_Obj *prefixObj); /* 7 */
    Method * (*tclOONewForwardInstanceMethod) (Tcl_Interp *interp, Object *oPtr, int isPublic, Tcl_Obj *nameObj, Tcl_Obj *prefixObj); /* 8 */
    Tcl_Method (*tclOONewProcInstanceMethodEx) (Tcl_Interp *interp, Tcl_Object oPtr, TclOO_PreCallProc *preCallPtr, TclOO_PostCallProc *postCallPtr, ProcErrorProc *errProc, void *clientData, Tcl_Obj *nameObj, Tcl_Obj *argsObj, Tcl_Obj *bodyObj, int flags, void **internalTokenPtr); /* 9 */
    Tcl_Method (*tclOONewProcMethodEx) (Tcl_Interp *interp, Tcl_Class clsPtr, TclOO_PreCallProc *preCallPtr, TclOO_PostCallProc *postCallPtr, ProcErrorProc *errProc, void *clientData, Tcl_Obj *nameObj, Tcl_Obj *argsObj, Tcl_Obj *bodyObj, int flags, void **internalTokenPtr); /* 10 */
    int (*tclOOInvokeObject) (Tcl_Interp *interp, Tcl_Object object, Tcl_Class startCls, int publicPrivate, Tcl_Size objc, Tcl_Obj *const *objv); /* 11 */
    void (*tclOOObjectSetFilters) (Object *oPtr, Tcl_Size numFilters, Tcl_Obj *const *filters); /* 12 */
    void (*tclOOClassSetFilters) (Tcl_Interp *interp, Class *classPtr, Tcl_Size numFilters, Tcl_Obj *const *filters); /* 13 */
    void (*tclOOObjectSetMixins) (Object *oPtr, Tcl_Size numMixins, Class *const *mixins); /* 14 */
    void (*tclOOClassSetMixins) (Tcl_Interp *interp, Class *classPtr, Tcl_Size numMixins, Class *const *mixins); /* 15 */
    Tcl_Method (*tclOOMakeProcInstanceMethod2) (Tcl_Interp *interp, Object *oPtr, int flags, Tcl_Obj *nameObj, Tcl_Obj *argsObj, Tcl_Obj *bodyObj, const Tcl_MethodType2 *typePtr, void *clientData, Proc **procPtrPtr); /* 16 */
    Tcl_Method (*tclOOMakeProcMethod2) (Tcl_Interp *interp, Class *clsPtr, int flags, Tcl_Obj *nameObj, const char *namePtr, Tcl_Obj *argsObj, Tcl_Obj *bodyObj, const Tcl_MethodType2 *typePtr, void *clientData, Proc **procPtrPtr); /* 17 */
} TclOOIntStubs;

extern const TclOOIntStubs *tclOOIntStubsPtr;

#ifdef __cplusplus
}
#endif

#if defined(USE_TCLOO_STUBS)

/*
 * Inline function declarations:
 */

#define TclOOGetDefineCmdContext \
	(tclOOIntStubsPtr->tclOOGetDefineCmdContext) /* 0 */
#define TclOOMakeProcInstanceMethod \
	(tclOOIntStubsPtr->tclOOMakeProcInstanceMethod) /* 1 */
#define TclOOMakeProcMethod \
	(tclOOIntStubsPtr->tclOOMakeProcMethod) /* 2 */
#define TclOONewProcInstanceMethod \
	(tclOOIntStubsPtr->tclOONewProcInstanceMethod) /* 3 */
#define TclOONewProcMethod \
	(tclOOIntStubsPtr->tclOONewProcMethod) /* 4 */
#define TclOOObjectCmdCore \
	(tclOOIntStubsPtr->tclOOObjectCmdCore) /* 5 */
#define TclOOIsReachable \
	(tclOOIntStubsPtr->tclOOIsReachable) /* 6 */
#define TclOONewForwardMethod \
	(tclOOIntStubsPtr->tclOONewForwardMethod) /* 7 */
#define TclOONewForwardInstanceMethod \
	(tclOOIntStubsPtr->tclOONewForwardInstanceMethod) /* 8 */
#define TclOONewProcInstanceMethodEx \
	(tclOOIntStubsPtr->tclOONewProcInstanceMethodEx) /* 9 */
#define TclOONewProcMethodEx \
	(tclOOIntStubsPtr->tclOONewProcMethodEx) /* 10 */
#define TclOOInvokeObject \
	(tclOOIntStubsPtr->tclOOInvokeObject) /* 11 */
#define TclOOObjectSetFilters \
	(tclOOIntStubsPtr->tclOOObjectSetFilters) /* 12 */
#define TclOOClassSetFilters \
	(tclOOIntStubsPtr->tclOOClassSetFilters) /* 13 */
#define TclOOObjectSetMixins \
	(tclOOIntStubsPtr->tclOOObjectSetMixins) /* 14 */
#define TclOOClassSetMixins \
	(tclOOIntStubsPtr->tclOOClassSetMixins) /* 15 */
#define TclOOMakeProcInstanceMethod2 \
	(tclOOIntStubsPtr->tclOOMakeProcInstanceMethod2) /* 16 */
#define TclOOMakeProcMethod2 \
	(tclOOIntStubsPtr->tclOOMakeProcMethod2) /* 17 */

#endif /* defined(USE_TCLOO_STUBS) */

/* !END!: Do not edit above this line. */

#if TCL_MAJOR_VERSION < 9
#undef Tcl_MethodType2
#undef TclOOMakeProcInstanceMethod2
#undef TclOOMakeProcMethod2
#endif

#endif /* _TCLOOINTDECLS */
