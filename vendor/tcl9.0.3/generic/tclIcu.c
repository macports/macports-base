/*
 * tclIcu.c --
 *
 *	tclIcu.c implements various Tcl commands that make use of
 *	the ICU library if present on the system.
 *	(Adapted from tkIcu.c)
 *
 * Copyright © 2021 Jan Nijtmans
 * Copyright © 2024 Ashok P. Nadkarni
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

typedef uint16_t UCharx;
typedef uint32_t UChar32x;

/*
 * Runtime linking of libicu.
 */
typedef enum UBreakIteratorTypex {
    UBRK_CHARACTERX = 0,
    UBRK_WORDX = 1
} UBreakIteratorTypex;

typedef enum UErrorCodex {
    U_STRING_NOT_TERMINATED_WARNING = -124,
    U_AMBIGUOUS_ALIAS_WARNING = -122,
    U_ZERO_ERRORZ = 0, /**< No error, no warning. */
    U_BUFFER_OVERFLOW_ERROR = 15,
} UErrorCodex;

#define U_SUCCESS(x) ((x)<=U_ZERO_ERRORZ)
#define U_FAILURE(x) ((x)>U_ZERO_ERRORZ)

typedef enum {
    UCNV_UNASSIGNED = 0,
    UCNV_ILLEGAL = 1,
    UCNV_IRREGULAR = 2,
    UCNV_RESET = 3,
    UCNV_CLOSE = 4,
    UCNV_CLONE = 5
} UConverterCallbackReasonx;

typedef enum UNormalizationCheckResultx {
  UNORM_NO,
  UNORM_YES,
  UNORM_MAYBE
} UNormalizationCheckResultx;

typedef struct UEnumeration UEnumeration;
typedef struct UCharsetDetector UCharsetDetector;
typedef struct UCharsetMatch UCharsetMatch;
typedef struct UBreakIterator UBreakIterator;
typedef struct UNormalizer2 UNormalizer2;
typedef struct UConverter UConverter;
typedef struct UConverterFromUnicodeArgs UConverterFromUnicodeArgs;
typedef struct UConverterToUnicodeArgs UConverterToUnicodeArgs;
typedef void   (*UConverterFromUCallback)(const void *context,
					  UConverterFromUnicodeArgs *args,
					  const UCharx *codeUnits,
					  int32_t length, UChar32x codePoint,
					  UConverterCallbackReasonx reason,
					  UErrorCodex *pErrorCode);
typedef void   (*UConverterToUCallback)(const void *context,
					UConverterToUnicodeArgs *args,
					const char *codeUnits,
					int32_t length,
					UConverterCallbackReasonx reason,
					UErrorCodex *pErrorCode);
/*
 * Prototypes for ICU functions sorted by category.
 */
typedef void        (*fn_u_cleanup)(void);
typedef const char *(*fn_u_errorName)(UErrorCodex);
typedef UCharx *(*fn_u_strFromUTF32)(UCharx *dest,
				     int32_t destCapacity,
				     int32_t *pDestLength,
				     const UChar32x *src,
				     int32_t srcLength,
				     UErrorCodex *pErrorCode);
typedef UCharx *(*fn_u_strFromUTF32WithSub)(UCharx *dest,
					    int32_t destCapacity,
					    int32_t *pDestLength,
					    const UChar32x *src,
					    int32_t srcLength,
					    UChar32x subchar,
					    int32_t *pNumSubstitutions,
					    UErrorCodex *pErrorCode);
typedef UChar32x *(*fn_u_strToUTF32)(UChar32x *dest,
				     int32_t destCapacity,
				     int32_t *pDestLength,
				     const UCharx *src,
				     int32_t srcLength,
				     UErrorCodex *pErrorCode);
typedef UChar32x *(*fn_u_strToUTF32WithSub)(UChar32x *dest,
					    int32_t destCapacity,
					    int32_t *pDestLength,
					    const UCharx *src,
					    int32_t srcLength,
					    UChar32x subchar,
					    int32_t *pNumSubstitutions,
					    UErrorCodex *pErrorCode);

typedef void        (*fn_ucnv_close)(UConverter *);
typedef uint16_t    (*fn_ucnv_countAliases)(const char *, UErrorCodex *);
typedef int32_t     (*fn_ucnv_countAvailable)(void);
typedef int32_t     (*fn_ucnv_fromUChars)(UConverter *, char *dest,
	int32_t destCapacity, const UCharx *src, int32_t srcLen, UErrorCodex *);
typedef const char *(*fn_ucnv_getAlias)(const char *, uint16_t, UErrorCodex *);
typedef const char *(*fn_ucnv_getAvailableName)(int32_t);
typedef UConverter *(*fn_ucnv_open)(const char *converterName, UErrorCodex *);
typedef void        (*fn_ucnv_setFromUCallBack)(UConverter *,
						UConverterFromUCallback newAction,
						const void *newContext,
						UConverterFromUCallback *oldAction,
						const void **oldContext,
						UErrorCodex *err);
typedef void        (*fn_ucnv_setToUCallBack)(UConverter *,
						UConverterToUCallback newAction,
						const void *newContext,
						UConverterToUCallback *oldAction,
						const void **oldContext,
						UErrorCodex *err);
typedef int32_t     (*fn_ucnv_toUChars)(UConverter *, UCharx *dest,
					int32_t destCapacity, const char *src, int32_t srcLen, UErrorCodex *);
typedef UConverterFromUCallback fn_UCNV_FROM_U_CALLBACK_STOP;
typedef UConverterToUCallback   fn_UCNV_TO_U_CALLBACK_STOP;

typedef UBreakIterator *(*fn_ubrk_open)(
	UBreakIteratorTypex, const char *, const uint16_t *, int32_t,
	UErrorCodex *);
typedef void	(*fn_ubrk_close)(UBreakIterator *);
typedef int32_t	(*fn_ubrk_preceding)(UBreakIterator *, int32_t);
typedef int32_t	(*fn_ubrk_following)(UBreakIterator *, int32_t);
typedef int32_t	(*fn_ubrk_previous)(UBreakIterator *);
typedef int32_t	(*fn_ubrk_next)(UBreakIterator *);
typedef void	(*fn_ubrk_setText)(
	UBreakIterator *, const void *, int32_t, UErrorCodex *);

typedef UCharsetDetector * (*fn_ucsdet_open)(UErrorCodex *status);
typedef void               (*fn_ucsdet_close)(UCharsetDetector *ucsd);
typedef void               (*fn_ucsdet_setText)(UCharsetDetector *ucsd,
	const char *textIn, int32_t len, UErrorCodex *status);
typedef const char *       (*fn_ucsdet_getName)(
	const UCharsetMatch *ucsm, UErrorCodex *status);
typedef UEnumeration *     (*fn_ucsdet_getAllDetectableCharsets)(
	UCharsetDetector *ucsd, UErrorCodex *status);
typedef const UCharsetMatch *  (*fn_ucsdet_detect)(
	UCharsetDetector *ucsd, UErrorCodex *status);
typedef const UCharsetMatch ** (*fn_ucsdet_detectAll)(
	UCharsetDetector *ucsd, int32_t *matchesFound, UErrorCodex *status);

typedef void        (*fn_uenum_close)(UEnumeration *);
typedef int32_t     (*fn_uenum_count)(UEnumeration *, UErrorCodex *);
typedef const char *(*fn_uenum_next)(UEnumeration *, int32_t *, UErrorCodex *);

typedef UNormalizer2 *(*fn_unorm2_getNFCInstance)(UErrorCodex *);
typedef UNormalizer2 *(*fn_unorm2_getNFDInstance)(UErrorCodex *);
typedef UNormalizer2 *(*fn_unorm2_getNFKCInstance)(UErrorCodex *);
typedef UNormalizer2 *(*fn_unorm2_getNFKDInstance)(UErrorCodex *);
typedef int32_t (*fn_unorm2_normalize)(const UNormalizer2 *,
				       const UCharx *,
				       int32_t,
				       UCharx *,
				       int32_t,
				       UErrorCodex *);

#define FIELD(name) fn_ ## name _ ## name

static struct {
    size_t nopen;		/* Total number of references to ALL libraries */
    /*
     * Depending on platform, ICU symbols may be distributed amongst
     * multiple libraries. For current functionality at most 2 needed.
     * Order of library loading is not guaranteed.
     */
    Tcl_LoadHandle      libs[2];

    FIELD(u_cleanup);
    FIELD(u_errorName);
    FIELD(u_strFromUTF32);
    FIELD(u_strFromUTF32WithSub);
    FIELD(u_strToUTF32);
    FIELD(u_strToUTF32WithSub);

    FIELD(ubrk_open);
    FIELD(ubrk_close);
    FIELD(ubrk_preceding);
    FIELD(ubrk_following);
    FIELD(ubrk_previous);
    FIELD(ubrk_next);
    FIELD(ubrk_setText);

    FIELD(ucnv_close);
    FIELD(ucnv_countAliases);
    FIELD(ucnv_countAvailable);
    FIELD(ucnv_fromUChars);
    FIELD(ucnv_getAlias);
    FIELD(ucnv_getAvailableName);
    FIELD(ucnv_open);
    FIELD(ucnv_setFromUCallBack);
    FIELD(ucnv_setToUCallBack);
    FIELD(ucnv_toUChars);
    FIELD(UCNV_FROM_U_CALLBACK_STOP);
    FIELD(UCNV_TO_U_CALLBACK_STOP);

    FIELD(ucsdet_close);
    FIELD(ucsdet_detect);
    FIELD(ucsdet_detectAll);
    FIELD(ucsdet_getAllDetectableCharsets);
    FIELD(ucsdet_getName);
    FIELD(ucsdet_open);
    FIELD(ucsdet_setText);

    FIELD(uenum_close);
    FIELD(uenum_count);
    FIELD(uenum_next);
    FIELD(unorm2_getNFCInstance);
    FIELD(unorm2_getNFDInstance);
    FIELD(unorm2_getNFKCInstance);
    FIELD(unorm2_getNFKDInstance);
    FIELD(unorm2_normalize);
} icu_fns = {
    0,    {NULL, NULL}, /* Reference count, library handles */
    NULL, NULL, NULL, NULL, NULL, NULL,                     /* u_* */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,               /* ubrk* */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,   /* ucnv_* .. */
    NULL, NULL, NULL,                                       /* .. ucnv_ */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,               /* ucsdet* */
    NULL, NULL, NULL,                                       /* uenum_* */
    NULL, NULL, NULL, NULL, NULL,                           /* unorm2_* */
};

#define u_cleanup        icu_fns._u_cleanup
#define u_errorName      icu_fns._u_errorName
#define u_strFromUTF32   icu_fns._u_strFromUTF32
#define u_strFromUTF32WithSub icu_fns._u_strFromUTF32WithSub
#define u_strToUTF32          icu_fns._u_strToUTF32
#define u_strToUTF32WithSub   icu_fns._u_strToUTF32WithSub

#define ubrk_open        icu_fns._ubrk_open
#define ubrk_close       icu_fns._ubrk_close
#define ubrk_preceding   icu_fns._ubrk_preceding
#define ubrk_following   icu_fns._ubrk_following
#define ubrk_previous    icu_fns._ubrk_previous
#define ubrk_next        icu_fns._ubrk_next
#define ubrk_setText     icu_fns._ubrk_setText

#define ucnv_close            icu_fns._ucnv_close
#define ucnv_countAliases     icu_fns._ucnv_countAliases
#define ucnv_countAvailable   icu_fns._ucnv_countAvailable
#define ucnv_fromUChars       icu_fns._ucnv_fromUChars
#define ucnv_getAlias         icu_fns._ucnv_getAlias
#define ucnv_getAvailableName icu_fns._ucnv_getAvailableName
#define ucnv_open             icu_fns._ucnv_open
#define ucnv_setFromUCallBack icu_fns._ucnv_setFromUCallBack
#define ucnv_setToUCallBack   icu_fns._ucnv_setToUCallBack
#define ucnv_toUChars         icu_fns._ucnv_toUChars
#define UCNV_FROM_U_CALLBACK_STOP icu_fns._UCNV_FROM_U_CALLBACK_STOP
#define UCNV_TO_U_CALLBACK_STOP   icu_fns._UCNV_TO_U_CALLBACK_STOP

#define ucsdet_close     icu_fns._ucsdet_close
#define ucsdet_detect    icu_fns._ucsdet_detect
#define ucsdet_detectAll icu_fns._ucsdet_detectAll
#define ucsdet_getAllDetectableCharsets icu_fns._ucsdet_getAllDetectableCharsets
#define ucsdet_getName   icu_fns._ucsdet_getName
#define ucsdet_open      icu_fns._ucsdet_open
#define ucsdet_setText   icu_fns._ucsdet_setText

#define uenum_next       icu_fns._uenum_next
#define uenum_close      icu_fns._uenum_close
#define uenum_count      icu_fns._uenum_count

#define unorm2_getNFCInstance  icu_fns._unorm2_getNFCInstance
#define unorm2_getNFDInstance  icu_fns._unorm2_getNFDInstance
#define unorm2_getNFKCInstance icu_fns._unorm2_getNFKCInstance
#define unorm2_getNFKDInstance icu_fns._unorm2_getNFKDInstance
#define unorm2_normalize       icu_fns._unorm2_normalize

TCL_DECLARE_MUTEX(icu_mutex);

/* Options used by multiple normalization functions */
static const char *normalizationForms[] = {"nfc", "nfd", "nfkc", "nfkd", NULL};
typedef enum { MODE_NFC, MODE_NFD, MODE_NFKC, MODE_NFKD } NormalizationMode;


/* Error handlers. */

static int
FunctionNotAvailableError(
    Tcl_Interp *interp)
{
    if (interp) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"ICU function not available", TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "TCL", "ICU", "UNSUPPORTED_OP", NULL);
    }
    return TCL_ERROR;
}

static int
IcuError(
    Tcl_Interp *interp,
    const char *message,
    UErrorCodex code)
{
    if (interp) {
	const char *codeMessage = NULL;
	if (u_errorName) {
	    codeMessage = u_errorName(code);
	}
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"%s%sICU error (%d): %s",
		message ? message : "",
		message ? ". " : "",
		code,
		codeMessage ? codeMessage : ""));
	Tcl_SetErrorCode(interp, "TCL", "ICU", codeMessage, NULL);
    }
    return TCL_ERROR;
}

/*
 * Detect the likely encoding of the string encoded in the given byte array.
 */
static int
DetectEncoding(
    Tcl_Interp *interp,
    Tcl_Obj *objPtr,
    int all)
{
    Tcl_Size len;
    const char *bytes;
    const UCharsetMatch *match;
    const UCharsetMatch **matches;
    int nmatches;
    int ret;

    // Confirm we have the profile of functions we need.
    if (ucsdet_open == NULL ||
	    ucsdet_setText == NULL ||
	    ucsdet_detect == NULL ||
	    ucsdet_detectAll == NULL ||
	    ucsdet_getName == NULL ||
	    ucsdet_close == NULL) {
	return FunctionNotAvailableError(interp);
    }

    bytes = (char *)Tcl_GetBytesFromObj(interp, objPtr, &len);
    if (bytes == NULL) {
	return TCL_ERROR;
    }
    if (len > INT_MAX) {
	Tcl_SetObjResult(interp,
		Tcl_NewStringObj("Max length supported by ICU exceeded.", TCL_INDEX_NONE));
	return TCL_ERROR;
    }
    UErrorCodex status = U_ZERO_ERRORZ;

    UCharsetDetector* csd = ucsdet_open(&status);
    if (U_FAILURE(status)) {
	return IcuError(interp, "Could not open charset detector", status);
    }

    ucsdet_setText(csd, bytes, (int)len, &status);
    if (U_FAILURE(status)) {
	IcuError(interp, "Could not set detection text", status);
	ucsdet_close(csd);
	return TCL_ERROR;
    }

    if (all) {
	matches = ucsdet_detectAll(csd, &nmatches, &status);
    } else {
	match = ucsdet_detect(csd, &status);
	matches = &match;
	nmatches = match ? 1 : 0;
    }

    if (U_FAILURE(status) || nmatches == 0) {
	ret = IcuError(interp, "Could not detect character set", status);
    } else {
	int i;
	Tcl_Obj *resultObj = Tcl_NewListObj(nmatches, NULL);

	for (i = 0; i < nmatches; ++i) {
	    const char *name = ucsdet_getName(matches[i], &status);
	    if (U_FAILURE(status) || name == NULL) {
		name = "unknown";
		status = U_ZERO_ERRORZ; /* Reset on failure */
	    }
	    Tcl_ListObjAppendElement(
		    NULL, resultObj, Tcl_NewStringObj(name, TCL_AUTO_LENGTH));
	}
	Tcl_SetObjResult(interp, resultObj);
	ret = TCL_OK;
    }

    ucsdet_close(csd);
    return ret;
}

static int
DetectableEncodings(
    Tcl_Interp *interp)
{
    // Confirm we have the profile of functions we need.
    if (ucsdet_open == NULL ||
	    ucsdet_getAllDetectableCharsets == NULL ||
	    ucsdet_close == NULL ||
	    uenum_next == NULL ||
	    uenum_count == NULL ||
	    uenum_close == NULL) {
	return FunctionNotAvailableError(interp);
    }
    UErrorCodex status = U_ZERO_ERRORZ;
    UCharsetDetector *csd = ucsdet_open(&status);

    if (U_FAILURE(status)) {
	return IcuError(interp, "Could not open charset detector", status);
    }

    int ret;
    UEnumeration *enumerator = ucsdet_getAllDetectableCharsets(csd, &status);
    if (U_FAILURE(status) || enumerator == NULL) {
	IcuError(interp, "Could not get list of detectable encodings", status);
	ret = TCL_ERROR;
    } else {
	int32_t count = uenum_count(enumerator, &status);

	if (U_FAILURE(status)) {
	    IcuError(interp, "Could not get charset enumerator count", status);
	    ret = TCL_ERROR;
	} else {
	    int i;
	    Tcl_Obj *resultObj = Tcl_NewListObj(0, NULL);

	    for (i = 0; i < count; ++i) {
		const char *name;
		int32_t len;

		name = uenum_next(enumerator, &len, &status);
		if (name == NULL || U_FAILURE(status)) {
		    name = "unknown";
		    len = 7;
		    status = U_ZERO_ERRORZ; /* Reset on error */
		}
		Tcl_ListObjAppendElement(
			NULL, resultObj, Tcl_NewStringObj(name, len));
	    }
	    Tcl_SetObjResult(interp, resultObj);
	    ret = TCL_OK;
	}
	uenum_close(enumerator);
    }

    ucsdet_close(csd);
    return ret;
}

/*
 *------------------------------------------------------------------------
 *
 * IcuObjToUCharDString --
 *
 *    Encodes a Tcl_Obj value in ICU UChars and stores in dsPtr.
 *
 * Results:
 *    Return TCL_OK / TCL_ERROR.
 *
 * Side effects:
 *    *dsPtr should be cleared by caller only if return code is TCL_OK.
 *
 *------------------------------------------------------------------------
 */
static int
IcuObjToUCharDString(
    Tcl_Interp *interp,
    Tcl_Obj *objPtr,
    int strict,
    Tcl_DString *dsPtr)
{
    Tcl_Encoding encoding;

    /*
     * TODO - not the most efficient to get an encoding every time.
     * However, we cannot use Tcl_UtfToChar16DString as that blithely
     * ignores invalid or ill-formed UTF8 strings.
     */
    encoding = Tcl_GetEncoding(interp, "utf-16");
    if (encoding == NULL) {
	return TCL_ERROR;
    }

    int result;
    char *s;
    Tcl_Size len;
    s = Tcl_GetStringFromObj(objPtr, &len);
    result = Tcl_UtfToExternalDStringEx(interp,
					encoding,
					s,
					len,
					strict ? TCL_ENCODING_PROFILE_STRICT
					       : TCL_ENCODING_PROFILE_REPLACE,
					dsPtr,
					NULL);
    if (result != TCL_OK) {
	Tcl_DStringFree(dsPtr); /* Must be done on error */
	/* TCL_CONVER_* errors -> TCL_ERROR */
	result = TCL_ERROR;
    }

    Tcl_FreeEncoding(encoding);
    return result;
}

/*
 *------------------------------------------------------------------------
 *
 * IcuObjFromUCharDString --
 *
 *    Stores a Tcl_Obj value by decoding ICU UChars in dsPtr.
 *
 * Results:
 *    Return Tcl_Obj or NULL on error.
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
static Tcl_Obj *
IcuObjFromUCharDString(
    Tcl_Interp *interp,
    Tcl_DString *dsPtr,
    int strict)
{
    Tcl_Encoding encoding;

    /*
     * TODO - not the most efficient to get an encoding every time.
     * However, we cannot use Tcl_UtfToChar16DString as that blithely
     * ignores invalid or ill-formed UTF8 strings.
     */
    encoding = Tcl_GetEncoding(interp, "utf-16");
    if (encoding == NULL) {
	return NULL;
    }
    Tcl_Obj *objPtr = NULL;
    char *s = Tcl_DStringValue(dsPtr);
    Tcl_Size len = Tcl_DStringLength(dsPtr);
    Tcl_DString dsOut;
    int result;
    result  = Tcl_ExternalToUtfDStringEx(interp,
					encoding,
					s,
					len,
					strict ? TCL_ENCODING_PROFILE_STRICT
					       : TCL_ENCODING_PROFILE_REPLACE,
					&dsOut,
					NULL);

    if (result == TCL_OK) {
	objPtr = Tcl_DStringToObj(&dsOut); /* Clears dsPtr! */
    }

    Tcl_FreeEncoding(encoding);
    return objPtr;
}

/*
 *------------------------------------------------------------------------
 *
 * IcuDetectObjCmd --
 *
 *	Implements the Tcl command ::tcl::unsupported::icu::detect.
 *	  ::tcl::unsupported::icu::detect - returns names of all detectable encodings
 *	  ::tcl::unsupported::icu::detect BYTES ?-all? - return detected encoding(s)
 *
 * Results:
 *	TCL_OK    - Success.
 *	TCL_ERROR - Error.
 *
 * Side effects:
 *	Interpreter result holds result or error message.
 *
 *------------------------------------------------------------------------
 */
static int
IcuDetectObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc > 3) {
	Tcl_WrongNumArgs(interp, 1 , objv, "?bytes ?-all??");
	return TCL_ERROR;
    }

    if (objc == 1) {
	return DetectableEncodings(interp);
    }

    int all = 0;
    if (objc == 3) {
	if (strcmp("-all", Tcl_GetString(objv[2]))) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "Invalid option %s, must be \"-all\"",
		    Tcl_GetString(objv[2])));
	    return TCL_ERROR;
	}
	all = 1;
    }

    return DetectEncoding(interp, objv[1], all);
}

/*
 *------------------------------------------------------------------------
 *
 * IcuConverterNamesObjCmd --
 *
 *	Sets interp result to list of available ICU converters.
 *
 * Results:
 *	TCL_OK    - Success.
 *	TCL_ERROR - Error.
 *
 * Side effects:
 *	Interpreter result holds list of converter names.
 *
 *------------------------------------------------------------------------
 */
static int
IcuConverterNamesObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1 , objv, "");
	return TCL_ERROR;
    }
    if (ucnv_countAvailable == NULL || ucnv_getAvailableName == NULL) {
	return FunctionNotAvailableError(interp);
    }

    int32_t count = ucnv_countAvailable();
    if (count <= 0) {
	return TCL_OK;
    }
    Tcl_Obj *resultObj = Tcl_NewListObj(count, NULL);
    int32_t i;

    for (i = 0; i < count; ++i) {
	const char *name = ucnv_getAvailableName(i);
	if (name) {
	    Tcl_ListObjAppendElement(NULL, resultObj,
		    Tcl_NewStringObj(name, TCL_AUTO_LENGTH));
	}
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * IcuConverterAliasesObjCmd --
 *
 *	Sets interp result to list of available ICU converters.
 *
 * Results:
 *	TCL_OK    - Success.
 *	TCL_ERROR - Error.
 *
 * Side effects:
 *	Interpreter result holds list of converter names.
 *
 *------------------------------------------------------------------------
 */
static int
IcuConverterAliasesObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1 , objv, "convertername");
	return TCL_ERROR;
    }
    if (ucnv_countAliases == NULL || ucnv_getAlias == NULL) {
	return FunctionNotAvailableError(interp);
    }

    const char *name = Tcl_GetString(objv[1]);
    UErrorCodex status = U_ZERO_ERRORZ;
    uint16_t count = ucnv_countAliases(name, &status);
    if (status != U_AMBIGUOUS_ALIAS_WARNING && U_FAILURE(status)) {
	return IcuError(interp, "Could not get aliases", status);
    }
    if (count <= 0) {
	return TCL_OK;
    }

    Tcl_Obj *resultObj = Tcl_NewListObj(count, NULL);
    uint16_t i;

    for (i = 0; i < count; ++i) {
	status = U_ZERO_ERRORZ; /* Reset in case U_AMBIGUOUS_ALIAS_WARNING */
	const char *aliasName = ucnv_getAlias(name, i, &status);

	if (status != U_AMBIGUOUS_ALIAS_WARNING && U_FAILURE(status)) {
	    status = U_ZERO_ERRORZ; /* Reset error for next iteration */
	    continue;
	}
	if (aliasName) {
	    Tcl_ListObjAppendElement(NULL, resultObj,
		    Tcl_NewStringObj(aliasName, TCL_AUTO_LENGTH));
	}
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * IcuConverttoDString --
 *
 *    Converts a string in ICU default encoding to the specified encoding.
 *
 * Results:
 *    TCL_OK / TCL_ERROR
 *
 * Side effects:
 *    On success, encoded string is stored in output dsOutPtr
 *
 *------------------------------------------------------------------------
 */
static int
IcuConverttoDString(
    Tcl_Interp *interp,
    Tcl_DString *dsInPtr,	/* Input UTF16 */
    const char *icuEncName,
    int strict,
    Tcl_DString *dsOutPtr)	/* Output encoded string. */
{
    if (ucnv_open == NULL || ucnv_close == NULL ||
	ucnv_fromUChars == NULL || UCNV_FROM_U_CALLBACK_STOP == NULL) {
	return FunctionNotAvailableError(interp);
    }

    UErrorCodex status = U_ZERO_ERRORZ;
    UConverter *ucnvPtr = ucnv_open(icuEncName, &status);
    if (ucnvPtr == NULL) {
	return IcuError(interp, "Could not get encoding converter", status);
    }
    if (strict) {
	ucnv_setFromUCallBack(ucnvPtr, UCNV_FROM_U_CALLBACK_STOP, NULL, NULL, NULL, &status);
	if (U_FAILURE(status)) {
	    /* TODO - use ucnv_getInvalidUChars to retrieve failing chars */
	    ucnv_close(ucnvPtr);
	    return IcuError(interp, "Could not set conversion callback", status);
	}
    }

    UCharx *utf16 = (UCharx *) Tcl_DStringValue(dsInPtr);
    Tcl_Size utf16len = Tcl_DStringLength(dsInPtr) / sizeof(UCharx);
    Tcl_Size dstLen, dstCapacity;
    if (utf16len > INT_MAX) {
	Tcl_SetObjResult(interp,
		Tcl_NewStringObj("Max length supported by ICU exceeded.", TCL_INDEX_NONE));
	return TCL_ERROR;
    }

    dstCapacity = utf16len;
    Tcl_DStringInit(dsOutPtr);
    Tcl_DStringSetLength(dsOutPtr, dstCapacity);
    dstLen = ucnv_fromUChars(ucnvPtr, Tcl_DStringValue(dsOutPtr), (int)dstCapacity,
			     utf16, (int)utf16len, &status);
    if (U_FAILURE(status)) {
	switch (status) {
	case U_STRING_NOT_TERMINATED_WARNING:
	    break; /* We don't care */
	case U_BUFFER_OVERFLOW_ERROR:
	    Tcl_DStringSetLength(dsOutPtr, (int)dstLen);
	    status = U_ZERO_ERRORZ; /* Reset before call */
	    dstLen = ucnv_fromUChars(ucnvPtr, Tcl_DStringValue(dsOutPtr), (int)dstLen,
				     utf16, (int)utf16len, &status);
	    if (U_SUCCESS(status)) {
		break;
	    }
	    TCL_FALLTHROUGH();
	default:
	    Tcl_DStringFree(dsOutPtr);
	    ucnv_close(ucnvPtr);
	    return IcuError(interp, "ICU error while encoding", status);
	}
    }
    Tcl_DStringSetLength(dsOutPtr, dstLen);
    ucnv_close(ucnvPtr);
    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * IcuBytesToUCharDString --
 *
 *    Converts encoded bytes to ICU UChars in a Tcl_DString
 *
 * Results:
 *    TCL_OK / TCL_ERROR
 *
 * Side effects:
 *    On success, encoded string is stored in output dsOutPtr
 *
 *------------------------------------------------------------------------
 */
static int
IcuBytesToUCharDString(
    Tcl_Interp *interp,
    const unsigned char *bytes,
    Tcl_Size nbytes,
    const char *icuEncName,
    int strict,
    Tcl_DString *dsOutPtr)	/* Output UChar string. */
{
    if (ucnv_open == NULL || ucnv_close == NULL ||
	ucnv_toUChars == NULL || UCNV_TO_U_CALLBACK_STOP == NULL) {
	return FunctionNotAvailableError(interp);
    }

    if (nbytes > INT_MAX) {
	Tcl_SetObjResult(interp,
		Tcl_NewStringObj("Max length supported by ICU exceeded.", TCL_INDEX_NONE));
	return TCL_ERROR;
    }

    UErrorCodex status = U_ZERO_ERRORZ;
    UConverter *ucnvPtr = ucnv_open(icuEncName, &status);
    if (ucnvPtr == NULL) {
	return IcuError(interp, "Could not get encoding converter", status);
    }
    if (strict) {
	ucnv_setToUCallBack(ucnvPtr, UCNV_TO_U_CALLBACK_STOP, NULL, NULL, NULL, &status);
	if (U_FAILURE(status)) {
	    /* TODO - use ucnv_getInvalidUChars to retrieve failing chars */
	    ucnv_close(ucnvPtr);
	    return IcuError(interp, "Could not set conversion callback", status);
	}
    }

    int dstLen;
    int dstCapacity = (int)nbytes; /* In UChar's */
    Tcl_DStringInit(dsOutPtr);
    Tcl_DStringSetLength(dsOutPtr, dstCapacity);
    dstLen = ucnv_toUChars(ucnvPtr, (UCharx *)Tcl_DStringValue(dsOutPtr), dstCapacity,
			   (const char *)bytes, (int)nbytes, &status);
    if (U_FAILURE(status)) {
	switch (status) {
	case U_STRING_NOT_TERMINATED_WARNING:
	    break; /* We don't care */
	case U_BUFFER_OVERFLOW_ERROR:
	    dstCapacity = sizeof(UCharx) * dstLen;
	    Tcl_DStringSetLength(dsOutPtr, dstCapacity);
	    status = U_ZERO_ERRORZ; /* Reset before call */
	    dstLen = ucnv_toUChars(ucnvPtr, (UCharx *)Tcl_DStringValue(dsOutPtr), dstCapacity,
				   (const char *)bytes, (int)nbytes, &status);
	    if (U_SUCCESS(status)) {
		break;
	    }
	    TCL_FALLTHROUGH();
	default:
	    Tcl_DStringFree(dsOutPtr);
	    ucnv_close(ucnvPtr);
	    return IcuError(interp, "ICU error while decoding", status);
	}
    }
    Tcl_DStringSetLength(dsOutPtr, sizeof(UCharx)*dstLen);
    ucnv_close(ucnvPtr);
    return TCL_OK;
}


/*
 *------------------------------------------------------------------------
 *
 * IcuNormalizeUCharDString --
 *
 *    Normalizes the UTF-16 encoded data
 *
 * Results:
 *    TCL_OK / TCL_ERROR
 *
 * Side effects:
 *    Normalized data is stored in dsOutPtr which should only be
 *    Tcl_DStringFree-ed if return code is TCL_OK.
 *
 *------------------------------------------------------------------------
 */
static int
IcuNormalizeUCharDString(
    Tcl_Interp *interp,
    Tcl_DString *dsInPtr,	/* Input UTF16 */
    NormalizationMode mode,
    Tcl_DString *dsOutPtr)	/* Output normalized UTF16. */
{
    typedef UNormalizer2 *(*normFn)(UErrorCodex *);
    normFn fn = NULL;

    switch (mode) {
    case MODE_NFC:
	fn = unorm2_getNFCInstance;
	break;
    case MODE_NFD:
	fn = unorm2_getNFDInstance;
	break;
    case MODE_NFKC:
	fn = unorm2_getNFKCInstance;
	break;
    case MODE_NFKD:
	fn = unorm2_getNFKDInstance;
	break;
    }
    if (fn == NULL || unorm2_normalize == NULL) {
	return FunctionNotAvailableError(interp);
    }

    UErrorCodex status = U_ZERO_ERRORZ;
    UNormalizer2 *normalizer = fn(&status);
    if (U_FAILURE(status)) {
	return IcuError(interp, "Could not get ICU normalizer", status);
    }

    UCharx *utf16;
    Tcl_Size utf16len;
    UCharx *normPtr;
    int32_t normLen;

    utf16 = (UCharx *) Tcl_DStringValue(dsInPtr);
    utf16len = Tcl_DStringLength(dsInPtr) / sizeof(UCharx);
    if (utf16len > INT_MAX) {
	Tcl_SetObjResult(interp,
		Tcl_NewStringObj("Max length supported by ICU exceeded.", TCL_INDEX_NONE));
	return TCL_ERROR;
    }
    Tcl_DStringInit(dsOutPtr);
    Tcl_DStringSetLength(dsOutPtr, utf16len * sizeof(UCharx));
    normPtr = (UCharx *) Tcl_DStringValue(dsOutPtr);

    normLen = unorm2_normalize(
	normalizer, utf16, (int)utf16len, normPtr, (int)utf16len, &status);
    if (U_FAILURE(status)) {
	switch (status) {
	case U_STRING_NOT_TERMINATED_WARNING:
	    /* No problem, don't need it terminated */
	    break;
	case U_BUFFER_OVERFLOW_ERROR:
	    /* Expand buffer */
	    Tcl_DStringSetLength(dsOutPtr, normLen * sizeof(UCharx));
	    normPtr = (UCharx *) Tcl_DStringValue(dsOutPtr);
	    status = U_ZERO_ERRORZ; /* Need to clear error! */
	    normLen = unorm2_normalize(
		normalizer, utf16, (int)utf16len, normPtr, normLen, &status);
	    if (U_SUCCESS(status)) {
		break;
	    }
	    TCL_FALLTHROUGH();
	default:
	    Tcl_DStringFree(dsOutPtr);
	    return IcuError(interp, "String normalization failed", status);
	}
    }

    Tcl_DStringSetLength(dsOutPtr, normLen * sizeof(UCharx));
    return TCL_OK;
}

/*
 * Common function for parsing convert options.
 */
static int IcuParseConvertOptions(
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[],
    int *strictPtr,
    Tcl_Obj **failindexVarPtr)
{
    if (objc < 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "?-profile PROFILE? ICUENCNAME STRING");
	return TCL_ERROR;
    }
    objc -= 2; /* truncate fixed arguments */

    /* Use GetIndexFromObj for option parsing so -failindex can be added later */

    static const char *optNames[] = {"-profile", "-failindex", NULL};
    enum { OPT_PROFILE, OPT_FAILINDEX } opt;
    int i;
    int strict = 1;
    for (i = 1; i < objc; ++i) {
	if (Tcl_GetIndexFromObj(
		interp, objv[i], optNames, "option", 0, &opt) != TCL_OK) {
	    return TCL_ERROR;
	}
	++i;
	if (i == objc) {
	    Tcl_SetObjResult(interp,
			     Tcl_ObjPrintf("Missing value for option %s.",
					   Tcl_GetString(objv[i - 1])));
	    return TCL_ERROR;
	}
	const char *s = Tcl_GetString(objv[i]);
	switch (opt) {
	case OPT_PROFILE:
	    if (!strcmp(s, "replace")) {
		strict = 0;
	    } else if (strcmp(s, "strict")) {
		Tcl_SetObjResult(interp,
		    Tcl_ObjPrintf("Invalid value \"%s\" supplied for option"
			 " \"-profile\". Must be \"strict\" or \"replace\".",
			 s));
		return TCL_ERROR;
	    }
	    break;
	case OPT_FAILINDEX:
	    /* TBD */
	    Tcl_SetObjResult(interp,
		    Tcl_NewStringObj("Option -failindex not implemented.", TCL_INDEX_NONE));
	    return TCL_ERROR;
	default:
	    TCL_UNREACHABLE();
	}
    }
    *strictPtr = strict;
    *failindexVarPtr = NULL;
    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * IcuConvertfromObjCmd --
 *
 *    Implements the Tcl command "icu convertfrom"
 *        icu convertfrom ?-profile replace|strict? encoding string
 *
 * Results:
 *    TCL_OK    - Success.
 *    TCL_ERROR - Error.
 *
 * Side effects:
 *    Interpreter result holds result or error message.
 *
 *------------------------------------------------------------------------
 */
static int
IcuConvertfromObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int strict;
    Tcl_Obj *failindexVar;

    if (IcuParseConvertOptions(interp, objc, objv, &strict, &failindexVar) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_Size nbytes;
    const unsigned char *bytes = Tcl_GetBytesFromObj(interp, objv[objc-1], &nbytes);
    if (bytes == NULL) {
	return TCL_ERROR;
    }

    Tcl_DString ds;
    if (IcuBytesToUCharDString(interp, bytes, nbytes,
	    Tcl_GetString(objv[objc-2]), strict, &ds) != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_Obj *resultObj = IcuObjFromUCharDString(interp, &ds, strict);
    if (resultObj) {
	Tcl_SetObjResult(interp, resultObj);
	return TCL_OK;
    } else {
	return TCL_ERROR;
    }
}

/*
 *------------------------------------------------------------------------
 *
 * IcuConverttoObjCmd --
 *
 *    Implements the Tcl command "icu convertto"
 *        icu convertto ?-profile replace|strict? encoding string
 *
 * Results:
 *    TCL_OK    - Success.
 *    TCL_ERROR - Error.
 *
 * Side effects:
 *    Interpreter result holds result or error message.
 *
 *------------------------------------------------------------------------
 */
static int
IcuConverttoObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int strict;
    Tcl_Obj *failindexVar;

    if (IcuParseConvertOptions(interp, objc, objv, &strict, &failindexVar) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_DString dsIn;
    Tcl_DString dsOut;
    if (IcuObjToUCharDString(interp, objv[objc - 1], strict, &dsIn) != TCL_OK ||
	IcuConverttoDString(interp, &dsIn,
	    Tcl_GetString(objv[objc-2]), strict, &dsOut) != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp,
	Tcl_NewByteArrayObj((unsigned char *)Tcl_DStringValue(&dsOut),
			    Tcl_DStringLength(&dsOut)));
    Tcl_DStringFree(&dsOut);
    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * IcuNormalizeObjCmd --
 *
 *    Implements the Tcl command "icu normalize"
 *        icu normalize ?-profile replace|strict? ?-mode nfc|nfd|nfkc|nfkd? string
 *
 * Results:
 *    TCL_OK    - Success.
 *    TCL_ERROR - Error.
 *
 * Side effects:
 *    Interpreter result holds result or error message.
 *
 *------------------------------------------------------------------------
 */
static int
IcuNormalizeObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    static const char *optNames[] = {"-profile", "-mode", NULL};
    enum { OPT_PROFILE, OPT_MODE } opt;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?-profile PROFILE? ?-mode MODE? STRING");
	return TCL_ERROR;
    }

    int i;
    int strict = 1;
    NormalizationMode mode = MODE_NFC;
    for (i = 1; i < objc - 1; ++i) {
	if (Tcl_GetIndexFromObj(
		interp, objv[i], optNames, "option", 0, &opt) != TCL_OK) {
	    return TCL_ERROR;
	}
	++i;
	if (i == (objc-1)) {
	    Tcl_SetObjResult(interp,
			     Tcl_ObjPrintf("Missing value for option %s.",
					   Tcl_GetString(objv[i - 1])));
	    return TCL_ERROR;
	}
	const char *s = Tcl_GetString(objv[i]);
	switch (opt) {
	case OPT_PROFILE:
	    if (!strcmp(s, "replace")) {
		strict = 0;
	    } else if (strcmp(s, "strict")) {
		Tcl_SetObjResult(interp,
		    Tcl_ObjPrintf("Invalid value \"%s\" supplied for option \"-profile\". Must be "
				  "\"strict\" or \"replace\".",
				  s));
		return TCL_ERROR;
	    }
	    break;
	case OPT_MODE:
	    if (Tcl_GetIndexFromObj(interp, objv[i], normalizationForms, "normalization mode", 0, &mode) != TCL_OK) {
		return TCL_ERROR;
	    }
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }

    Tcl_DString dsIn;
    Tcl_DString dsNorm;
    if (IcuObjToUCharDString(interp, objv[objc - 1], strict, &dsIn) != TCL_OK ||
	IcuNormalizeUCharDString(interp, &dsIn, mode, &dsNorm) != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_DStringFree(&dsIn);
    Tcl_Obj *objPtr = IcuObjFromUCharDString(interp, &dsNorm, strict);
    Tcl_DStringFree(&dsNorm);
    if (objPtr) {
	Tcl_SetObjResult(interp, objPtr);
	return TCL_OK;
    } else {
	return TCL_ERROR;
    }
}

/*
 *------------------------------------------------------------------------
 *
 * TclIcuCleanup --
 *
 *	Called whenever a command referencing the ICU function table is
 *	deleted. When the reference count drops to zero, the table is released
 *	and the ICU shared libraries are unloaded.
 *
 *------------------------------------------------------------------------
 */
static void
TclIcuCleanup(
    TCL_UNUSED(void *))
{
    Tcl_MutexLock(&icu_mutex);
    if (icu_fns.nopen-- <= 1) {
	int i;
	if (u_cleanup != NULL) {
	    u_cleanup();
	}
	for (i = 0; i < (int)(sizeof(icu_fns.libs) / sizeof(icu_fns.libs[0]));
		++i) {
	    if (icu_fns.libs[i] != NULL) {
		Tcl_FSUnloadFile(NULL, icu_fns.libs[i]);
	    }
	}
	memset(&icu_fns, 0, sizeof(icu_fns));
    }
    Tcl_MutexUnlock(&icu_mutex);
}

/*
 *------------------------------------------------------------------------
 *
 * IcuFindSymbol --
 *
 *	Finds an ICU symbol in a shared library and returns its value.
 *
 *      Caller must be holding icu_mutex lock.
 *
 * Results:
 *	Returns the symbol value or NULL if not found.
 *
 *------------------------------------------------------------------------
 */
static void *
IcuFindSymbol(
    Tcl_LoadHandle loadH,	/* Handle to shared library containing symbol */
    const char *name,		/* Name of function */
    const char *suffix)		/* Suffix that may be present */
{
    /*
     * ICU symbols may have a version suffix depending on how it was built.
     * Rather than try both forms every time, suffixConvention remembers if a
     * suffix is needed (all functions will have it, or none will)
     * 0 - don't know, 1 - have suffix, -1 - no suffix
     */
    static int suffixConvention = 0;
    char symbol[256];
    void *value = NULL;

    /* Note we only update suffixConvention on a positive result */

    strcpy(symbol, name);
    if (suffixConvention <= 0) {
	/* Either don't need suffix or don't know if we do */
	value = Tcl_FindSymbol(NULL, loadH, symbol);
	if (value) {
	    suffixConvention = -1; /* Remember that no suffixes present */
	    return value;
	}
    }
    if (suffixConvention >= 0) {
	/* Either need suffix or don't know if we do */
	strcat(symbol, suffix);
	value = Tcl_FindSymbol(NULL, loadH, symbol);
	if (value) {
	    suffixConvention = 1;
	}
    }
    return value;
}

/*
 *------------------------------------------------------------------------
 *
 * TclIcuInit --
 *
 *	Load the ICU commands into the given interpreter. If the ICU
 *	commands have never previously been loaded, the ICU libraries are
 *	loaded first.
 *
 *------------------------------------------------------------------------
 */
static void
TclIcuInit(
    Tcl_Interp *interp)
{
    Tcl_MutexLock(&icu_mutex);
    char icuversion[4] = "_80"; /* Highest ICU version + 1 */

    /*
     * The initialization below clones the one from Tk. May need revisiting.
     * ICU shared library names as well as function names *may* be versioned.
     * See https://unicode-org.github.io/icu/userguide/icu4c/packaging.html
     * for the gory details.
     */
    if (icu_fns.nopen == 0) {
	int i = 0;
	Tcl_Obj *nameobj;
	static const char *iculibs[] = {
#if defined(_WIN32)
#  define DLLNAME "icu%s%s.dll"
	    "icuuc??.dll", /* Windows, user-provided */
	    NULL,
	    "cygicuuc??.dll", /* When running under Cygwin */
#elif defined(__CYGWIN__)
#  define DLLNAME "cygicu%s%s.dll"
	    "cygicuuc??.dll",
#elif defined(MAC_OSX_TCL)
#  define DLLNAME "libicu%s.%s.dylib"
	    "libicuuc.??.dylib",
#else
#  define DLLNAME "libicu%s.so.%s"
	    "libicuuc.so.??",
#endif
	    NULL
	};

	/* Going back down to ICU version 60 */
	while ((icu_fns.libs[0] == NULL) && (icuversion[1] >= '6')) {
	    if (--icuversion[2] < '0') {
		icuversion[1]--;
		icuversion[2] = '9';
	    }
#if defined(__CYGWIN__)
	    i = 2;
#else
	    i = 0;
#endif
	    while (iculibs[i] != NULL) {
		Tcl_ResetResult(interp);
		nameobj = Tcl_NewStringObj(iculibs[i], TCL_AUTO_LENGTH);
		char *nameStr = Tcl_GetString(nameobj);
		char *p = strchr(nameStr, '?');

		if (p != NULL) {
		    memcpy(p, icuversion+1, 2);
		}
		Tcl_IncrRefCount(nameobj);
		if (Tcl_LoadFile(interp, nameobj, NULL, 0, NULL,
			&icu_fns.libs[0]) == TCL_OK) {
		    if (p == NULL) {
			icuversion[0] = '\0';
		    }
		    Tcl_DecrRefCount(nameobj);
		    break;
		}
		Tcl_DecrRefCount(nameobj);
		++i;
	    }
	}
	if (icu_fns.libs[0] != NULL) {
	    /* Loaded icuuc, load others with the same version */
	    nameobj = Tcl_ObjPrintf(DLLNAME, "i18n", icuversion+1);
	    Tcl_IncrRefCount(nameobj);
	    /* Ignore errors. Calls to contained functions will fail. */
	    (void) Tcl_LoadFile(interp, nameobj, NULL, 0, NULL, &icu_fns.libs[1]);
	    Tcl_DecrRefCount(nameobj);
	}
#ifdef _WIN32
	/*
	 * On Windows, if no ICU install found, look for the system's
	 * (Win10 1703 or later). There are two cases. Newer systems
	 * have icu.dll containing all functions. Older systems have
	 * icucc.dll and icuin.dll
	 */
	if (icu_fns.libs[0] == NULL) {
	    Tcl_ResetResult(interp);
	    nameobj = Tcl_NewStringObj("icu.dll", TCL_AUTO_LENGTH);
	    Tcl_IncrRefCount(nameobj);
	    if (Tcl_LoadFile(interp, nameobj, NULL, 0, NULL, &icu_fns.libs[0])
		    == TCL_OK) {
		/* Reload same for second set of functions. */
		(void) Tcl_LoadFile(interp, nameobj, NULL, 0, NULL,
			&icu_fns.libs[1]);
		/* Functions do NOT have version suffixes */
		icuversion[0] = '\0';
	    }
	    Tcl_DecrRefCount(nameobj);
	}
	if (icu_fns.libs[0] == NULL) {
	    /* No icu.dll. Try last fallback */
	    Tcl_ResetResult(interp);
	    nameobj = Tcl_NewStringObj("icuuc.dll", TCL_AUTO_LENGTH);
	    Tcl_IncrRefCount(nameobj);
	    if (Tcl_LoadFile(interp, nameobj, NULL, 0, NULL, &icu_fns.libs[0])
		    == TCL_OK) {
		Tcl_DecrRefCount(nameobj);
		nameobj = Tcl_NewStringObj("icuin.dll", TCL_AUTO_LENGTH);
		Tcl_IncrRefCount(nameobj);
		(void) Tcl_LoadFile(interp, nameobj, NULL, 0, NULL,
			&icu_fns.libs[1]);
		/* Functions do NOT have version suffixes */
		icuversion[0] = '\0';
	    }
	    Tcl_DecrRefCount(nameobj);
	}
#endif // _WIN32

	/* Symbol may have version (Linux), or not (Windows, FreeBSD) */

#define ICUUC_SYM(name)                                                   \
    do {                                                                  \
	icu_fns._##name =                                                 \
	    (fn_##name)IcuFindSymbol(icu_fns.libs[0], #name, icuversion); \
    } while (0)

	if (icu_fns.libs[0] != NULL) {
	    ICUUC_SYM(u_cleanup);
	    ICUUC_SYM(u_errorName);
	    ICUUC_SYM(u_strFromUTF32);
	    ICUUC_SYM(u_strFromUTF32WithSub);
	    ICUUC_SYM(u_strToUTF32);
	    ICUUC_SYM(u_strToUTF32WithSub);

	    ICUUC_SYM(ucnv_close);
	    ICUUC_SYM(ucnv_countAliases);
	    ICUUC_SYM(ucnv_countAvailable);
	    ICUUC_SYM(ucnv_fromUChars);
	    ICUUC_SYM(ucnv_getAlias);
	    ICUUC_SYM(ucnv_getAvailableName);
	    ICUUC_SYM(ucnv_open);
	    ICUUC_SYM(ucnv_setFromUCallBack);
	    ICUUC_SYM(ucnv_setToUCallBack);
	    ICUUC_SYM(ucnv_toUChars);
	    ICUUC_SYM(UCNV_FROM_U_CALLBACK_STOP);
	    ICUUC_SYM(UCNV_TO_U_CALLBACK_STOP);

	    ICUUC_SYM(ubrk_open);
	    ICUUC_SYM(ubrk_close);
	    ICUUC_SYM(ubrk_preceding);
	    ICUUC_SYM(ubrk_following);
	    ICUUC_SYM(ubrk_previous);
	    ICUUC_SYM(ubrk_next);
	    ICUUC_SYM(ubrk_setText);

	    ICUUC_SYM(uenum_close);
	    ICUUC_SYM(uenum_count);
	    ICUUC_SYM(uenum_next);

	    ICUUC_SYM(unorm2_getNFCInstance);
	    ICUUC_SYM(unorm2_getNFDInstance);
	    ICUUC_SYM(unorm2_getNFKCInstance);
	    ICUUC_SYM(unorm2_getNFKDInstance);
	    ICUUC_SYM(unorm2_normalize);
#undef ICUUC_SYM
	}

#define ICUIN_SYM(name)                                                   \
    do {                                                                  \
	icu_fns._##name =                                                 \
	    (fn_##name)IcuFindSymbol(icu_fns.libs[1], #name, icuversion); \
    } while (0)

	if (icu_fns.libs[1] != NULL) {
	    ICUIN_SYM(ucsdet_close);
	    ICUIN_SYM(ucsdet_detect);
	    ICUIN_SYM(ucsdet_detectAll);
	    ICUIN_SYM(ucsdet_getName);
	    ICUIN_SYM(ucsdet_getAllDetectableCharsets);
	    ICUIN_SYM(ucsdet_open);
	    ICUIN_SYM(ucsdet_setText);
#undef ICUIN_SYM
	}
    }

    if (icu_fns.libs[0] != NULL) {
	/*
	 * Note refcounts updated BEFORE command definition to protect
	 * against self redefinition.
	 */
	if (icu_fns.libs[1] != NULL) {
	    /* Commands needing both libraries */

	    /* Ref count number of commands */
	    icu_fns.nopen += 3;
	    Tcl_CreateObjCommand(interp,  "::tcl::unsupported::icu::convertto",
				 IcuConverttoObjCmd, 0, TclIcuCleanup);
	    Tcl_CreateObjCommand(interp,  "::tcl::unsupported::icu::convertfrom",
				 IcuConvertfromObjCmd, 0, TclIcuCleanup);
	    Tcl_CreateObjCommand(interp,  "::tcl::unsupported::icu::detect",
		    IcuDetectObjCmd, 0, TclIcuCleanup);
	}

	/* Commands needing only libs[0] (icuuc) */

	/* Ref count number of commands */
	icu_fns.nopen += 3; /* UPDATE AS CMDS ADDED/DELETED BELOW */
	Tcl_CreateObjCommand(interp, "::tcl::unsupported::icu::converters",
		IcuConverterNamesObjCmd, 0, TclIcuCleanup);
	Tcl_CreateObjCommand(interp, "::tcl::unsupported::icu::aliases",
		IcuConverterAliasesObjCmd, 0, TclIcuCleanup);
	Tcl_CreateObjCommand(interp, "::tcl::unsupported::icu::normalize",
		IcuNormalizeObjCmd, 0, TclIcuCleanup);
    }

    Tcl_MutexUnlock(&icu_mutex);
}

/*
 *------------------------------------------------------------------------
 *
 * TclLoadIcuObjCmd --
 *
 *	Loads and initializes ICU
 *
 * Results:
 *	TCL_OK    - Success.
 *	TCL_ERROR - Error.
 *
 * Side effects:
 *	Interpreter result holds result or error message.
 *
 *------------------------------------------------------------------------
 */
int
TclLoadIcuObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1 , objv, "");
	return TCL_ERROR;
    }
    TclIcuInit(interp);
    return TCL_OK;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * coding: utf-8
 * End:
 */
