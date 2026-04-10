/*
 * tclUtil.c --
 *
 *	This file contains utility functions that are used by many Tcl
 *	commands.
 *
 * Copyright © 1987-1993 The Regents of the University of California.
 * Copyright © 1994-1998 Sun Microsystems, Inc.
 * Copyright © 2001 Kevin B. Kenny. All rights reserved.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclParse.h"
#include "tclStringTrim.h"
#include "tclTomMath.h"
#include <math.h>

#if defined(_MSC_VER) && defined(_WIN64)
#   include <intrin.h>
#   pragma intrinsic(_BitScanReverse64)
#endif

/*
 * The absolute pathname of the executable in which this Tcl library is
 * running.
 */

static ProcessGlobalValue executableName = {
    0, 0, NULL, NULL, NULL, NULL, NULL
};
#if !defined(STATIC_BUILD)
static ProcessGlobalValue shlibName = {
    0, 0, NULL, NULL, NULL, NULL, NULL
};
#endif

/*
 * The following values are used in the flags arguments of Tcl*Scan*Element
 * and Tcl*Convert*Element.  The values TCL_DONT_USE_BRACES and
 * TCL_DONT_QUOTE_HASH are defined in tcl.h, like so:
 *
#define TCL_DONT_USE_BRACES     1
#define TCL_DONT_QUOTE_HASH     8
 *
 * Those are public flag bits which callers of the public routines
 * Tcl_Convert*Element() can use to indicate:
 *
 * TCL_DONT_USE_BRACES -	1 means the caller is insisting that brace
 *				quoting not be used when converting the list
 *				element.
 * TCL_DONT_QUOTE_HASH -	1 means the caller insists that a leading hash
 *				character ('#') should *not* be quoted. This
 *				is appropriate when the caller can guarantee
 *				the element is not the first element of a
 *				list, so [eval] cannot mis-parse the element
 *				as a comment.
 *
 * The remaining values which can be carried by the flags of these routines
 * are for internal use only.  Make sure they do not overlap with the public
 * values above.
 *
 * The Tcl*Scan*Element() routines make a determination which of 4 modes of
 * conversion is most appropriate for Tcl*Convert*Element() to perform, and
 * sets two bits of the flags value to indicate the mode selected.
 *
 * For more details, see the comments on the Tcl*Scan*Element and
 * Tcl*Convert*Element routines.
 */

enum ConvertFlags {
    CONVERT_NONE = 0,		/* The element needs no quoting. Its literal
				 * string is suitable as is. */
    DONT_USE_BRACES = TCL_DONT_USE_BRACES,
				/* The caller is insisting that brace quoting
				 * not be used when converting the list
				 * element. */
    CONVERT_BRACE = 2,		/* The conversion should be enclosing the
				 * literal string in braces. */
    CONVERT_ESCAPE = 4,		/* The conversion should be using backslashes
				 * to escape any characters in the string that
				 * require it. */
    DONT_QUOTE_HASH = TCL_DONT_QUOTE_HASH,
				/* The caller insists that a leading hash
				 * character ('#') should *not* be quoted. This
				 * is appropriate when the caller can guarantee
				 * the element is not the first element of a
				 * list, so [eval] cannot mis-parse the element
				 * as a comment.*/
    CONVERT_MASK = CONVERT_BRACE | CONVERT_ESCAPE,
				/* A mask value used to extract the conversion
				 * mode from the flags argument.
				 *
				 * Also indicates a strange conversion mode
				 * where all special characters are escaped
				 * with backslashes *except for braces*. This
				 * is a strange and unnecessary case, but it's
				 * part of the historical way in which lists
				 * have been formatted in Tcl. To experiment
				 * with removing this case, define the value of
				 * COMPAT to be 0. */
    CONVERT_ANY = 16		/* The caller of TclScanElement() declares it
				 * can make no promise about what public flags
				 * will be passed to the matching call of
				 * TclConvertElement(). As such,
				 * TclScanElement() has to determine the worst
				 * case destination buffer length over all
				 * possibilities, and in other cases this means
				 * an overestimate of the required size.
				 *
				 * Used only by callers of TclScanElement().
				 * The flag value produced by a call to
				 * Tcl*Scan*Element() will never leave this
				 * bit set. */
};
#ifndef COMPAT
#define COMPAT 1
#endif

/*
 * Prototypes for functions defined later in this file.
 */

static void		ClearHash(Tcl_HashTable *tablePtr);
static void		FreeProcessGlobalValue(void *clientData);
static void		FreeThreadHash(void *clientData);
static int		GetEndOffsetFromObj(Tcl_Interp *interp, Tcl_Obj *objPtr,
			    Tcl_WideInt endValue, Tcl_WideInt *indexPtr);
static Tcl_HashTable *	GetThreadHash(Tcl_ThreadDataKey *keyPtr);
static int		GetWideForIndex(Tcl_Interp *interp, Tcl_Obj *objPtr,
			    Tcl_WideInt endValue, Tcl_WideInt *widePtr);
static int		FindElement(Tcl_Interp *interp, const char *string,
			    Tcl_Size stringLength, const char *typeStr,
			    const char *typeCode, const char **elementPtr,
			    const char **nextPtr, Tcl_Size *sizePtr,
			    int *literalPtr);
/*
 * The following is the Tcl object type definition for an object that
 * represents a list index in the form, "end-offset". It is used as a
 * performance optimization in Tcl_GetIntForIndex. The internal rep is
 * stored directly in the wideValue, so no memory management is required
 * for it. This is a caching internalrep, keeping the result of a parse
 * around. This type is only created from a pre-existing string, so an
 * updateStringProc will never be called and need not exist. The type
 * is unregistered, so has no need of a setFromAnyProc either.
 */

static const Tcl_ObjType endOffsetType = {
    "end-offset",			/* name */
    NULL,				/* freeIntRepProc */
    NULL,				/* dupIntRepProc */
    NULL,				/* updateStringProc */
    NULL,				/* setFromAnyProc */
    TCL_OBJTYPE_V1(TclLengthOne)
};

Tcl_Size
TclLengthOne(
    TCL_UNUSED(Tcl_Obj *))
{
    return 1;
}

/*
 *	*	STRING REPRESENTATION OF LISTS	*	*	*
 *
 * The next several routines implement the conversions of strings to and from
 * Tcl lists. To understand their operation, the rules of parsing and
 * generating the string representation of lists must be known.  Here we
 * describe them in one place.
 *
 * A list is made up of zero or more elements. Any string is a list if it is
 * made up of alternating substrings of element-separating ASCII whitespace
 * and properly formatted elements.
 *
 * The ASCII characters which can make up the whitespace between list elements
 * are:
 *
 *	\u0009	\t	TAB
 *	\u000A	\n	NEWLINE
 *	\u000B	\v	VERTICAL TAB
 *	\u000C	\f	FORM FEED
 *	\u000D	\r	CARRIAGE RETURN
 *	\u0020		SPACE
 *
 * NOTE: differences between this and other places where Tcl defines a role
 * for "whitespace".
 *
 *	* Unlike command parsing, here NEWLINE is just another whitespace
 *	  character; its role as a command terminator in a script has no
 *	  importance here.
 *
 *	* Unlike command parsing, the BACKSLASH NEWLINE sequence is not
 *	  considered to be a whitespace character.
 *
 *	* Other Unicode whitespace characters (recognized by [string is space]
 *	  or Tcl_UniCharIsSpace()) do not play any role as element separators
 *	  in Tcl lists.
 *
 *	* The NUL byte ought not appear, as it is not in strings properly
 *	  encoded for Tcl, but if it is present, it is not treated as
 *	  separating whitespace, or a string terminator. It is just another
 *	  character in a list element.
 *
 * The interpretation of a formatted substring as a list element follows rules
 * similar to the parsing of the words of a command in a Tcl script. Backslash
 * substitution plays a key role, and is defined exactly as it is in command
 * parsing. The same routine, TclParseBackslash() is used in both command
 * parsing and list parsing.
 *
 * NOTE: This means that if and when backslash substitution rules ever change
 * for command parsing, the interpretation of strings as lists also changes.
 *
 * Backslash substitution replaces an "escape sequence" of one or more
 * characters starting with
 *		\u005c	\	BACKSLASH
 * with a single character. The one character escape sequence case happens only
 * when BACKSLASH is the last character in the string. In all other cases, the
 * escape sequence is at least two characters long.
 *
 * The formatted substrings are interpreted as element values according to the
 * following cases:
 *
 * * If the first character of a formatted substring is
 *		\u007b	{	OPEN BRACE
 *   then the end of the substring is the matching
 *		\u007d	}	CLOSE BRACE
 *   character, where matching is determined by counting nesting levels, and
 *   not including any brace characters that are contained within a backslash
 *   escape sequence in the nesting count. Having found the matching brace,
 *   all characters between the braces are the string value of the element.
 *   If no matching close brace is found before the end of the string, the
 *   string is not a Tcl list. If the character following the close brace is
 *   not an element separating whitespace character, or the end of the string,
 *   then the string is not a Tcl list.
 *
 *   NOTE: this differs from a brace-quoted word in the parsing of a Tcl
 *   command only in its treatment of the backslash-newline sequence. In a
 *   list element, the literal characters in the backslash-newline sequence
 *   become part of the element value. In a script word, conversion to a
 *   single SPACE character is done.
 *
 *   NOTE: Most list element values can be represented by a formatted
 *   substring using brace quoting. The exceptions are any element value that
 *   includes an unbalanced brace not in a backslash escape sequence, and any
 *   value that ends with a backslash not itself in a backslash escape
 *   sequence.
 *
 * * If the first character of a formatted substring is
 *		\u0022	"	QUOTE
 *   then the end of the substring is the next QUOTE character, not counting
 *   any QUOTE characters that are contained within a backslash escape
 *   sequence. If no next QUOTE is found before the end of the string, the
 *   string is not a Tcl list. If the character following the closing QUOTE is
 *   not an element separating whitespace character, or the end of the string,
 *   then the string is not a Tcl list. Having found the limits of the
 *   substring, the element value is produced by performing backslash
 *   substitution on the character sequence between the open and close QUOTEs.
 *
 *   NOTE: Any element value can be represented by this style of formatting,
 *   given suitable choice of backslash escape sequences.
 *
 * * All other formatted substrings are terminated by the next element
 *   separating whitespace character in the string.  Having found the limits
 *   of the substring, the element value is produced by performing backslash
 *   substitution on it.
 *
 *   NOTE: Any element value can be represented by this style of formatting,
 *   given suitable choice of backslash escape sequences, with one exception.
 *   The empty string cannot be represented as a list element without the use
 *   of either braces or quotes to delimit it.
 *
 * This collection of parsing rules is implemented in the routine
 * FindElement().
 *
 * In order to produce lists that can be parsed by these rules, we need the
 * ability to distinguish between characters that are part of a list element
 * value from characters providing syntax that define the structure of the
 * list. This means that our code that generates lists must at a minimum be
 * able to produce escape sequences for the 10 characters identified above
 * that have significance to a list parser.
 *
 *	*	*	CANONICAL LISTS	*	*	*	*	*
 *
 * In addition to the basic rules for parsing strings into Tcl lists, there
 * are additional properties to be met by the set of list values that are
 * generated by Tcl.  Such list values are often said to be in "canonical
 * form":
 *
 * * When any canonical list is evaluated as a Tcl script, it is a script of
 *   either zero commands (an empty list) or exactly one command. The command
 *   word is exactly the first element of the list, and each argument word is
 *   exactly one of the following elements of the list. This means that any
 *   characters that have special meaning during script evaluation need
 *   special treatment when canonical lists are produced:
 *
 *	* Whitespace between elements may not include NEWLINE.
 *	* The command terminating character,
 *		\u003b	;	SEMICOLON
 *	  must be BRACEd, QUOTEd, or escaped so that it does not terminate the
 *	  command prematurely.
 *	* Any of the characters that begin substitutions in scripts,
 *		\u0024	$	DOLLAR
 *		\u005b	[	OPEN BRACKET
 *		\u005c	\	BACKSLASH
 *	  need to be BRACEd or escaped.
 *	* In any list where the first character of the first element is
 *		\u0023	#	HASH
 *	  that HASH character must be BRACEd, QUOTEd, or escaped so that it
 *	  does not convert the command into a comment.
 *	* Any list element that contains the character sequence BACKSLASH
 *	  NEWLINE cannot be formatted with BRACEs. The BACKSLASH character
 *	  must be represented by an escape sequence, and unless QUOTEs are
 *	  used, the NEWLINE must be as well.
 *
 * * It is also guaranteed that one can use a canonical list as a building
 *   block of a larger script within command substitution, as in this example:
 *	set script "puts \[[list $cmd $arg]]"; eval $script
 *   To support this usage, any appearance of the character
 *		\u005d	]	CLOSE BRACKET
 *   in a list element must be BRACEd, QUOTEd, or escaped.
 *
 * * Finally it is guaranteed that enclosing a canonical list in braces
 *   produces a new value that is also a canonical list.  This new list has
 *   length 1, and its only element is the original canonical list.  This same
 *   guarantee also makes it possible to construct scripts where an argument
 *   word is given a list value by enclosing the canonical form of that list
 *   in braces:
 *	set script "puts {[list $one $two $three]}"; eval $script
 *   This sort of coding was once fairly common, though it's become more
 *   idiomatic to see the following instead:
 *	set script [list puts [list $one $two $three]]; eval $script
 *   In order to support this guarantee, every canonical list must have
 *   balance when counting those braces that are not in escape sequences.
 *
 * Within these constraints, the canonical list generation routines
 * TclScanElement() and TclConvertElement() attempt to generate the string for
 * any list that is easiest to read. When an element value is itself
 * acceptable as the formatted substring, it is usually used (CONVERT_NONE).
 * When some quoting or escaping is required, use of BRACEs (CONVERT_BRACE) is
 * usually preferred over the use of escape sequences (CONVERT_ESCAPE). There
 * are some exceptions to both of these preferences for reasons of code
 * simplicity, efficiency, and continuation of historical habits. Canonical
 * lists never use the QUOTE formatting to delimit their elements because that
 * form of quoting does not nest, which makes construction of nested lists far
 * too much trouble.  Canonical lists always use only a single SPACE character
 * for element-separating whitespace.
 *
 *	*	*	FUTURE CONSIDERATIONS	*	*	*
 *
 * When a list element requires quoting or escaping due to a CLOSE BRACKET
 * character or an internal QUOTE character, a strange formatting mode is
 * recommended. For example, if the value "a{b]c}d" is converted by the usual
 * modes:
 *
 *	CONVERT_BRACE:	a{b]c}d		=> {a{b]c}d}
 *	CONVERT_ESCAPE:	a{b]c}d		=> a\{b\]c\}d
 *
 * we get perfectly usable formatted list elements. However, this is not what
 * Tcl releases have been producing. Instead, we have:
 *
 *	CONVERT_MASK:	a{b]c}d		=> a{b\]c}d
 *
 * where the CLOSE BRACKET is escaped, but the BRACEs are not. The same effect
 * can be seen replacing ] with " in this example. There does not appear to be
 * any functional or aesthetic purpose for this strange additional mode. The
 * sole purpose I can see for preserving it is to keep generating the same
 * formatted lists programmers have become accustomed to, and perhaps written
 * tests to expect. That is, compatibility only. The additional code
 * complexity required to support this mode is significant. The lines of code
 * supporting it are delimited in the routines below with #if COMPAT
 * directives. This makes it easy to experiment with eliminating this
 * formatting mode simply with "#define COMPAT 0" above. I believe this is
 * worth considering.
 *
 * Another consideration is the treatment of QUOTE characters in list
 * elements. TclConvertElement() must have the ability to produce the escape
 * sequence \" so that when a list element begins with a QUOTE we do not
 * confuse that first character with a QUOTE used as list syntax to define
 * list structure. However, that is the only place where QUOTE characters need
 * quoting. In this way, handling QUOTE could really be much more like the way
 * we handle HASH which also needs quoting and escaping only in particular
 * situations. Following up this could increase the set of list elements that
 * can use the CONVERT_NONE formatting mode.
 *
 * More speculative is that the demands of canonical list form require brace
 * balance for the list as a whole, while the current implementation achieves
 * this by establishing brace balance for every element.
 *
 * Finally, a reminder that the rules for parsing and formatting lists are
 * closely tied together with the rules for parsing and evaluating scripts,
 * and will need to evolve in sync.
 */

/*
 *----------------------------------------------------------------------
 *
 * TclMaxListLength --
 *
 *	Given 'bytes' pointing to 'numBytes' bytes, scan through them and
 *	count the number of whitespace runs that could be list element
 *	separators. If 'numBytes' is TCL_INDEX_NONE, scan to the terminating
 *	'\0'. Not a full list parser. Typically used to get a quick and dirty
 *	overestimate of length size in order to allocate space for an actual
 *	list parser to operate with.
 *
 * Results:
 *	Returns the largest number of list elements that could possibly be in
 *	this string, interpreted as a Tcl list. If 'endPtr' is not NULL,
 *	writes a pointer to the end of the string scanned there.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclMaxListLength(
    const char *bytes,
    Tcl_Size numBytes,
    const char **endPtr)
{
    Tcl_Size count = 0;

    if ((numBytes == 0) || ((numBytes == TCL_INDEX_NONE) && (*bytes == '\0'))) {
	/* Empty string case - quick exit */
	goto done;
    }

    /*
     * No list element before leading white space.
     */

    count += 1 - TclIsSpaceProcM(*bytes);

    /*
     * Count white space runs as potential element separators.
     */

    while (numBytes) {
	if ((numBytes == TCL_INDEX_NONE) && (*bytes == '\0')) {
	    break;
	}
	if (TclIsSpaceProcM(*bytes)) {
	    /*
	     * Space run started; bump count.
	     */

	    count++;
	    do {
		bytes++;
		numBytes -= (numBytes != TCL_INDEX_NONE);
	    } while (numBytes && TclIsSpaceProcM(*bytes));
	    if ((numBytes == 0) || ((numBytes == TCL_INDEX_NONE) && (*bytes == '\0'))) {
		break;
	    }

	    /*
	     * (*bytes) is non-space; return to counting state.
	     */
	}
	bytes++;
	numBytes -= (numBytes != TCL_INDEX_NONE);
    }

    /*
     * No list element following trailing white space.
     */

    count -= TclIsSpaceProcM(bytes[-1]);

  done:
    if (endPtr) {
	*endPtr = bytes;
    }
    return count;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFindElement --
 *
 *	Given a pointer into a Tcl list, locate the first (or next) element in
 *	the list.
 *
 * Results:
 *	The return value is normally TCL_OK, which means that the element was
 *	successfully located. If TCL_ERROR is returned it means that list
 *	didn't have proper list structure; the interp's result contains a more
 *	detailed error message.
 *
 *	If TCL_OK is returned, then *elementPtr will be set to point to the
 *	first element of list, and *nextPtr will be set to point to the
 *	character just after any white space following the last character
 *	that's part of the element. If this is the last argument in the list,
 *	then *nextPtr will point just after the last character in the list
 *	(i.e., at the character at list+listLength). If sizePtr is non-NULL,
 *	*sizePtr is filled in with the number of bytes in the element. If the
 *	element is in braces, then *elementPtr will point to the character
 *	after the opening brace and *sizePtr will not include either of the
 *	braces. If there isn't an element in the list, *sizePtr will be zero,
 *	and both *elementPtr and *nextPtr will point just after the last
 *	character in the list. If literalPtr is non-NULL, *literalPtr is set
 *	to a boolean value indicating whether the substring returned as the
 *	values of **elementPtr and *sizePtr is the literal value of a list
 *	element. If not, a call to TclCopyAndCollapse() is needed to produce
 *	the actual value of the list element. Note: this function does NOT
 *	collapse backslash sequences, but uses *literalPtr to tell callers
 *	when it is required for them to do so.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclFindElement(
    Tcl_Interp *interp,		/* Interpreter to use for error reporting. If
				 * NULL, then no error message is left after
				 * errors. */
    const char *list,		/* Points to the first byte of a string
				 * containing a Tcl list with zero or more
				 * elements (possibly in braces). */
    Tcl_Size listLength,	/* Number of bytes in the list's string. */
    const char **elementPtr,	/* Where to put address of first significant
				 * character in first element of list. */
    const char **nextPtr,	/* Fill in with location of character just
				 * after all white space following end of
				 * argument (next arg or end of list). */
    Tcl_Size *sizePtr,		/* If non-zero, fill in with size of
				 * element. */
    int *literalPtr)		/* If non-zero, fill in with non-zero/zero to
				 * indicate that the substring of *sizePtr
				 * bytes starting at **elementPtr is/is not
				 * the literal list element and therefore
				 * does not/does require a call to
				 * TclCopyAndCollapse() by the caller. */
{
    return FindElement(interp, list, listLength, "list", "LIST", elementPtr,
	    nextPtr, sizePtr, literalPtr);
}

int
TclFindDictElement(
    Tcl_Interp *interp,		/* Interpreter to use for error reporting. If
				 * NULL, then no error message is left after
				 * errors. */
    const char *dict,		/* Points to the first byte of a string
				 * containing a Tcl dictionary with zero or
				 * more keys and values (possibly in
				 * braces). */
    Tcl_Size dictLength,	/* Number of bytes in the dict's string. */
    const char **elementPtr,	/* Where to put address of first significant
				 * character in the first element (i.e., key
				 * or value) of dict. */
    const char **nextPtr,	/* Fill in with location of character just
				 * after all white space following end of
				 * element (next arg or end of list). */
    Tcl_Size *sizePtr,		/* If non-zero, fill in with size of
				 * element. */
    int *literalPtr)		/* If non-zero, fill in with non-zero/zero to
				 * indicate that the substring of *sizePtr
				 * bytes starting at **elementPtr is/is not
				 * the literal key or value and therefore
				 * does not/does require a call to
				 * TclCopyAndCollapse() by the caller. */
{
    return FindElement(interp, dict, dictLength, "dict", "DICTIONARY",
	    elementPtr, nextPtr, sizePtr, literalPtr);
}

static int
FindElement(
    Tcl_Interp *interp,		/* Interpreter to use for error reporting. If
				 * NULL, then no error message is left after
				 * errors. */
    const char *string,		/* Points to the first byte of a string
				 * containing a Tcl list or dictionary with
				 * zero or more elements (possibly in
				 * braces). */
    Tcl_Size stringLength,	/* Number of bytes in the string. */
    const char *typeStr,	/* The name of the type of thing we are
				 * parsing, for error messages. */
    const char *typeCode,	/* The type code for thing we are parsing, for
				 * error messages. */
    const char **elementPtr,	/* Where to put address of first significant
				 * character in first element. */
    const char **nextPtr,	/* Fill in with location of character just
				 * after all white space following end of
				 * argument (next arg or end of list/dict). */
    Tcl_Size *sizePtr,		/* If non-zero, fill in with size of
				 * element. */
    int *literalPtr)		/* If non-zero, fill in with non-zero/zero to
				 * indicate that the substring of *sizePtr
				 * bytes starting at **elementPtr is/is not
				 * the literal list/dict element and therefore
				 * does not/does require a call to
				 * TclCopyAndCollapse() by the caller. */
{
    const char *p = string;
    const char *elemStart;	/* Points to first byte of first element. */
    const char *limit;		/* Points just after list/dict's last byte. */
    Tcl_Size openBraces = 0;	/* Brace nesting level during parse. */
    int inQuotes = 0;
    Tcl_Size size = 0;
    Tcl_Size numChars;
    int literal = 1;
    const char *p2;

    /*
     * Skim off leading white space and check for an opening brace or quote.
     * We treat embedded NULLs in the list/dict as bytes belonging to a list
     * element (or dictionary key or value).
     */

    limit = (string + stringLength);
    while ((p < limit) && (TclIsSpaceProcM(*p))) {
	p++;
    }
    if (p == limit) {		/* no element found */
	elemStart = limit;
	goto done;
    }

    if (*p == '{') {
	openBraces = 1;
	p++;
    } else if (*p == '"') {
	inQuotes = 1;
	p++;
    }
    elemStart = p;

    /*
     * Find element's end (a space, close brace, or the end of the string).
     */

    while (p < limit) {
	switch (*p) {
	    /*
	     * Open brace: don't treat specially unless the element is in
	     * braces. In this case, keep a nesting count.
	     */

	case '{':
	    if (openBraces != 0) {
		openBraces++;
	    }
	    break;

	    /*
	     * Close brace: if element is in braces, keep nesting count and
	     * quit when the last close brace is seen.
	     */

	case '}':
	    if (openBraces > 1) {
		openBraces--;
	    } else if (openBraces == 1) {
		size = (p - elemStart);
		p++;
		if ((p >= limit) || TclIsSpaceProcM(*p)) {
		    goto done;
		}

		/*
		 * Garbage after the closing brace; return an error.
		 */

		if (interp != NULL) {
		    p2 = p;
		    while ((p2 < limit) && (!TclIsSpaceProcM(*p2))
			    && (p2 < p+20)) {
			p2++;
		    }
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "%s element in braces followed by \"%.*s\" "
			    "instead of space", typeStr, (int) (p2-p), p));
		    Tcl_SetErrorCode(interp, "TCL", "VALUE", typeCode, "JUNK",
			    (char *)NULL);
		}
		return TCL_ERROR;
	    }
	    break;

	    /*
	     * Backslash: skip over everything up to the end of the backslash
	     * sequence.
	     */

	case '\\':
	    if (openBraces == 0) {
		/*
		 * A backslash sequence not within a brace quoted element
		 * means the value of the element is different from the
		 * substring we are parsing. A call to TclCopyAndCollapse() is
		 * needed to produce the element value. Inform the caller.
		 */

		literal = 0;
	    }
	    TclParseBackslash(p, limit - p, &numChars, NULL);
	    p += (numChars - 1);
	    break;

	    /*
	     * Double-quote: if element is in quotes then terminate it.
	     */

	case '"':
	    if (inQuotes) {
		size = (p - elemStart);
		p++;
		if ((p >= limit) || TclIsSpaceProcM(*p)) {
		    goto done;
		}

		/*
		 * Garbage after the closing quote; return an error.
		 */

		if (interp != NULL) {
		    p2 = p;
		    while ((p2 < limit) && (!TclIsSpaceProcM(*p2))
			    && (p2 < p+20)) {
			p2++;
		    }
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "%s element in quotes followed by \"%.*s\" "
			    "instead of space", typeStr, (int) (p2-p), p));
		    Tcl_SetErrorCode(interp, "TCL", "VALUE", typeCode, "JUNK",
			    (char *)NULL);
		}
		return TCL_ERROR;
	    }
	    break;

	default:
	    if (TclIsSpaceProcM(*p)) {
		/*
		 * Space: ignore if element is in braces or quotes;
		 * otherwise terminate element.
		 */
		if ((openBraces == 0) && !inQuotes) {
		    size = (p - elemStart);
		    goto done;
		}
	    }
	    break;

	}
	p++;
    }

    /*
     * End of list/dict: terminate element.
     */

    if (p == limit) {
	if (openBraces != 0) {
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"unmatched open brace in %s", typeStr));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", typeCode, "BRACE",
			(char *)NULL);
	    }
	    return TCL_ERROR;
	} else if (inQuotes) {
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"unmatched open quote in %s", typeStr));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", typeCode, "QUOTE",
			(char *)NULL);
	    }
	    return TCL_ERROR;
	}
	size = (p - elemStart);
    }

  done:
    while ((p < limit) && (TclIsSpaceProcM(*p))) {
	p++;
    }
    *elementPtr = elemStart;
    *nextPtr = p;
    if (sizePtr != 0) {
	*sizePtr = size;
    }
    if (literalPtr != 0) {
	*literalPtr = literal;
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclCopyAndCollapse --
 *
 *	Copy a string and substitute all backslash escape sequences
 *
 * Results:
 *	Count bytes get copied from src to dst. Along the way, backslash
 *	sequences are substituted in the copy. After scanning count bytes from
 *	src, a null character is placed at the end of dst. Returns the number
 *	of bytes that got written to dst.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclCopyAndCollapse(
    Tcl_Size count,		/* Number of byte to copy from src. */
    const char *src,		/* Copy from here... */
    char *dst)			/* ... to here. */
{
    Tcl_Size newCount = 0;

    while (count > 0) {
	char c = *src;

	if (c == '\\') {
	    char buf[4] = "";
	    Tcl_Size numRead;
	    Tcl_Size backslashCount = TclParseBackslash(src, count, &numRead, buf);

	    memcpy(dst, buf, backslashCount);
	    dst += backslashCount;
	    newCount += backslashCount;
	    src += numRead;
	    count -= numRead;
	} else {
	    *dst = c;
	    dst++;
	    newCount++;
	    src++;
	    count--;
	}
    }
    *dst = 0;
    return newCount;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SplitList --
 *
 *	Splits a list up into its constituent fields.
 *
 * Results
 *	The return value is normally TCL_OK, which means that the list was
 *	successfully split up. If TCL_ERROR is returned, it means that "list"
 *	didn't have proper list structure; the interp's result will contain a
 *	more detailed error message.
 *
 *	*argvPtr will be filled in with the address of an array whose elements
 *	point to the elements of list, in order. *argcPtr will get filled in
 *	with the number of valid elements in the array. A single block of
 *	memory is dynamically allocated to hold both the argv array and a copy
 *	of the list (with backslashes and braces removed in the standard way).
 *	The caller must eventually free this memory by calling Tcl_Free() on
 *	*argvPtr. Note: *argvPtr and *argcPtr are only modified if the
 *	function returns normally.
 *
 * Side effects:
 *	Memory is allocated.
 *
 *----------------------------------------------------------------------
 */

#undef Tcl_SplitList
int
Tcl_SplitList(
    Tcl_Interp *interp,		/* Interpreter to use for error reporting. If
				 * NULL, no error message is left. */
    const char *list,		/* Pointer to string with list structure. */
    Tcl_Size *argcPtr,		/* Pointer to location to fill in with the
				 * number of elements in the list. */
    const char ***argvPtr)	/* Pointer to place to store pointer to array
				 * of pointers to list elements. */
{
    const char **argv, *end, *element;
    char *p;
    int result;
    Tcl_Size length, size, i, elSize;

    /*
     * Allocate enough space to work in. A (const char *) for each (possible)
     * list element plus one more for terminating NULL, plus as many bytes as
     * in the original string value, plus one more for a terminating '\0'.
     * Space used to hold element separating white space in the original
     * string gets re-purposed to hold '\0' characters in the argv array.
     */

    size = TclMaxListLength(list, TCL_INDEX_NONE, &end) + 1;
    length = end - list;
    if (size >= (Tcl_Size) (TCL_SIZE_MAX/sizeof(char *)) ||
	length > (Tcl_Size) (TCL_SIZE_MAX - 1 - (size * sizeof(char *)))) {
	if (interp) {
	    Tcl_SetResult(
		interp, "memory allocation limit exceeded", TCL_STATIC);
	}
	return TCL_ERROR;
    }
    argv = (const char **)Tcl_Alloc((size * sizeof(char *)) + length + 1);

    for (i = 0, p = ((char *) argv) + size*sizeof(char *);
	    *list != 0;  i++) {
	const char *prevList = list;
	int literal;

	result = TclFindElement(interp, list, length, &element, &list,
		&elSize, &literal);
	length -= (list - prevList);
	if (result != TCL_OK) {
	    Tcl_Free((void *)argv);
	    return result;
	}
	if (*element == 0) {
	    break;
	}
	if (i >= size) {
	    Tcl_Free((void *)argv);
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"internal error in Tcl_SplitList", -1));
		Tcl_SetErrorCode(interp, "TCL", "INTERNAL", "Tcl_SplitList",
			(char *)NULL);
	    }
	    return TCL_ERROR;
	}
	argv[i] = p;
	if (literal) {
	    memcpy(p, element, elSize);
	    p += elSize;
	    *p = 0;
	    p++;
	} else {
	    p += 1 + TclCopyAndCollapse(elSize, element, p);
	}
    }

    argv[i] = NULL;
    *argvPtr = argv;
    *argcPtr = i;
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ScanElement --
 *
 *	This function is a companion function to Tcl_ConvertElement. It scans
 *	a string to see what needs to be done to it (e.g. add backslashes or
 *	enclosing braces) to make the string into a valid Tcl list element.
 *
 * Results:
 *	The return value is an overestimate of the number of bytes that will
 *	be needed by Tcl_ConvertElement to produce a valid list element from
 *	src. The word at *flagPtr is filled in with a value needed by
 *	Tcl_ConvertElement when doing the actual conversion.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
Tcl_ScanElement(
    const char *src,	/* String to convert to list element. */
    int *flagPtr)	/* Where to store information to guide
			 * Tcl_ConvertCountedElement. */
{
    return Tcl_ScanCountedElement(src, TCL_INDEX_NONE, flagPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ScanCountedElement --
 *
 *	This function is a companion function to Tcl_ConvertCountedElement. It
 *	scans a string to see what needs to be done to it (e.g. add
 *	backslashes or enclosing braces) to make the string into a valid Tcl
 *	list element. If length is TCL_INDEX_NONE, then the string is scanned
 *	from src up to the first null byte.
 *
 * Results:
 *	The return value is an overestimate of the number of bytes that will
 *	be needed by Tcl_ConvertCountedElement to produce a valid list element
 *	from src. The word at *flagPtr is filled in with a value needed by
 *	Tcl_ConvertCountedElement when doing the actual conversion.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
Tcl_ScanCountedElement(
    const char *src,		/* String to convert to Tcl list element. */
    Tcl_Size length,		/* Number of bytes in src, or TCL_INDEX_NONE. */
    int *flagPtr)		/* Where to store information to guide
				 * Tcl_ConvertElement. */
{
    char flags = CONVERT_ANY;
    Tcl_Size numBytes = TclScanElement(src, length, &flags);

    *flagPtr = flags;
    return numBytes;
}

/*
 *----------------------------------------------------------------------
 *
 * TclScanElement --
 *
 *	This function is a companion function to TclConvertElement. It scans a
 *	string to see what needs to be done to it (e.g. add backslashes or
 *	enclosing braces) to make the string into a valid Tcl list element. If
 *	length is TCL_INDEX_NONE, then the string is scanned from src up to the first null
 *	byte. A NULL value for src is treated as an empty string. The incoming
 *	value of *flagPtr is a report from the caller what additional flags it
 *	will pass to TclConvertElement().
 *
 * Results:
 *	The recommended formatting mode for the element is determined and a
 *	value is written to *flagPtr indicating that recommendation. This
 *	recommendation is combined with the incoming flag values in *flagPtr
 *	set by the caller to determine how many bytes will be needed by
 *	TclConvertElement() in which to write the formatted element following
 *	the recommendation modified by the flag values. This number of bytes
 *	is the return value of the routine.  In some situations it may be an
 *	overestimate, but so long as the caller passes the same flags to
 *	TclConvertElement(), it will be large enough.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclScanElement(
    const char *src,		/* String to convert to Tcl list element. */
    Tcl_Size length,		/* Number of bytes in src, or TCL_INDEX_NONE. */
    char *flagPtr)		/* Where to store information to guide
				 * Tcl_ConvertElement. */
{
    const char *p = src;
    Tcl_Size nestingLevel = 0;	/* Brace nesting count */
    int forbidNone = 0;		/* Do not permit CONVERT_NONE mode. Something
				 * needs protection or escape. */
    int requireEscape = 0;	/* Force use of CONVERT_ESCAPE mode.  For some
				 * reason bare or brace-quoted form fails. */
    Tcl_Size extra = 0;		/* Count of number of extra bytes needed for
				 * formatted element, assuming we use escape
				 * sequences in formatting. */
    Tcl_Size bytesNeeded;	/* Buffer length computed to complete the
				 * element formatting in the selected mode. */
#if COMPAT
    int preferEscape = 0;	/* Use preferences to track whether to use */
    int preferBrace = 0;	/* CONVERT_MASK mode. */
    int braceCount = 0;		/* Count of all braces '{' '}' seen. */
#endif /* COMPAT */

    if ((p == NULL) || (length == 0) || ((*p == '\0') && (length == TCL_INDEX_NONE))) {
	/*
	 * Empty string element must be brace quoted.
	 */

	*flagPtr = CONVERT_BRACE;
	return 2;
    }

#if COMPAT
    /*
     * We have an established history in TclConvertElement() when quoting
     * because of a leading hash character to force what would be the
     * CONVERT_MASK mode into the CONVERT_BRACE mode. That is, we format
     * the element #{a"b} like this:
     *			{#{a"b}}
     * and not like this:
     *			\#{a\"b}
     * This is inconsistent with [list x{a"b}], but we will not change that now.
     * Set that preference here so that we compute a tight size requirement.
     */
    if ((*src == '#') && !(*flagPtr & DONT_QUOTE_HASH)) {
	preferBrace = 1;
    }
#endif

    if ((*p == '{') || (*p == '"')) {
	/*
	 * Must escape or protect so leading character of value is not
	 * misinterpreted as list element delimiting syntax.
	 */

	forbidNone = 1;
#if COMPAT
	preferBrace = 1;
#endif /* COMPAT */
    }

    while (length) {
	if (CHAR_TYPE(*p) != TYPE_NORMAL) {
	    switch (*p) {
	    case '{':	/* TYPE_BRACE */
#if COMPAT
		braceCount++;
#endif /* COMPAT */
		extra++;			/* Escape '{' => '\{' */
		nestingLevel++;
		break;
	    case '}':	/* TYPE_BRACE */
#if COMPAT
		braceCount++;
#endif /* COMPAT */
		extra++;			/* Escape '}' => '\}' */
		if (nestingLevel-- < 1) {
		    /*
		     * Unbalanced braces!  Cannot format with brace quoting.
		     */

		    requireEscape = 1;
		}
		break;
	    case ']':	/* TYPE_CLOSE_BRACK */
	    case '"':	/* TYPE_SPACE */
#if COMPAT
		forbidNone = 1;
		extra++;	/* Escapes all just prepend a backslash */
		preferEscape = 1;
		break;
#else
		TCL_FALLTHROUGH();
#endif /* COMPAT */
	    case '[':	/* TYPE_SUBS */
	    case '$':	/* TYPE_SUBS */
	    case ';':	/* TYPE_COMMAND_END */
		forbidNone = 1;
		extra++;	/* Escape sequences all one byte longer. */
#if COMPAT
		preferBrace = 1;
#endif /* COMPAT */
		break;
	    case '\\':	/* TYPE_SUBS */
		extra++;			/* Escape '\' => '\\' */
		if ((length == 1) ||
			((length == TCL_INDEX_NONE) && (p[1] == '\0'))) {
		    /*
		     * Final backslash. Cannot format with brace quoting.
		     */

		    requireEscape = 1;
		    break;
		}
		if (p[1] == '\n') {
		    extra++;	/* Escape newline => '\n', one byte longer */

		    /*
		     * Backslash newline sequence.  Brace quoting not permitted.
		     */

		    requireEscape = 1;
		    length -= (length > 0);
		    p++;
		    break;
		}
		if ((p[1] == '{') || (p[1] == '}') || (p[1] == '\\')) {
		    extra++;	/* Escape sequences all one byte longer. */
		    length -= (length > 0);
		    p++;
		}
		forbidNone = 1;
#if COMPAT
		preferBrace = 1;
#endif /* COMPAT */
		break;
	    case '\0':	/* TYPE_SUBS */
		if (length == TCL_INDEX_NONE) {
		    goto endOfString;
		}
		/* TODO: Panic on improper encoding? */
		break;
	    default:
		if (TclIsSpaceProcM(*p)) {
		    forbidNone = 1;
		    extra++;	/* Escape sequences all one byte longer. */
#if COMPAT
		    preferBrace = 1;
#endif
		}
		break;
	    }
	}
	length -= (length > 0);
	p++;
    }

  endOfString:
    if (nestingLevel > 0) {
	/*
	 * Unbalanced braces!  Cannot format with brace quoting.
	 */

	requireEscape = 1;
    }

    /*
     * We need at least as many bytes as are in the element value...
     */

    bytesNeeded = p - src;

    if (requireEscape) {
	/*
	 * We must use escape sequences.  Add all the extra bytes needed to
	 * have room to create them.
	 */

	bytesNeeded += extra;

	/*
	 * Make room to escape leading #, if needed.
	 */

	if ((*src == '#') && !(*flagPtr & DONT_QUOTE_HASH)) {
	    bytesNeeded++;
	}
	*flagPtr = CONVERT_ESCAPE;
	return bytesNeeded;
    }
    if (*flagPtr & CONVERT_ANY) {
	/*
	 * The caller has not let us know what flags it will pass to
	 * TclConvertElement() so compute the max size we might need for any
	 * possible choice.  Normally the formatting using escape sequences is
	 * the longer one, and a minimum "extra" value of 2 makes sure we
	 * don't request too small a buffer in those edge cases where that's
	 * not true.
	 */

	if (extra < 2) {
	    extra = 2;
	}
	*flagPtr &= ~CONVERT_ANY;
	*flagPtr |= DONT_USE_BRACES;
    }
    if (forbidNone) {
	/*
	 * We must request some form of quoting of escaping...
	 */

#if COMPAT
	if (preferEscape && !preferBrace) {
	    /*
	     * If we are quoting solely due to ] or internal " characters use
	     * the CONVERT_MASK mode where we escape all special characters
	     * except for braces. "extra" counted space needed to escape
	     * braces too, so subtract "braceCount" to get our actual needs.
	     */

	    bytesNeeded += (extra - braceCount);
	    /* Make room to escape leading #, if needed. */
	    if ((*src == '#') && !(*flagPtr & DONT_QUOTE_HASH)) {
		bytesNeeded++;
	    }

	    /*
	     * If the caller reports it will direct TclConvertElement() to
	     * use full escapes on the element, add back the bytes needed to
	     * escape the braces.
	     */

	    if (*flagPtr & DONT_USE_BRACES) {
		bytesNeeded += braceCount;
	    }
	    *flagPtr = CONVERT_MASK;
	    return bytesNeeded;
	}
#endif /* COMPAT */
	if (*flagPtr & DONT_USE_BRACES) {
	    /*
	     * If the caller reports it will direct TclConvertElement() to
	     * use escapes, add the extra bytes needed to have room for them.
	     */

	    bytesNeeded += extra;

	    /*
	     * Make room to escape leading #, if needed.
	     */

	    if ((*src == '#') && !(*flagPtr & DONT_QUOTE_HASH)) {
		bytesNeeded++;
	    }
	} else {
	    /*
	     * Add 2 bytes for room for the enclosing braces.
	     */

	    bytesNeeded += 2;
	}
	*flagPtr = CONVERT_BRACE;
	return bytesNeeded;
    }

    /*
     * So far, no need to quote or escape anything.
     */

    if ((*src == '#') && !(*flagPtr & DONT_QUOTE_HASH)) {
	/*
	 * If we need to quote a leading #, make room to enclose in braces.
	 */

	bytesNeeded += 2;
    }
    *flagPtr = CONVERT_NONE;
    return bytesNeeded;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ConvertElement --
 *
 *	This is a companion function to Tcl_ScanElement. Given the information
 *	produced by Tcl_ScanElement, this function converts a string to a list
 *	element equal to that string.
 *
 * Results:
 *	Information is copied to *dst in the form of a list element identical
 *	to src (i.e. if Tcl_SplitList is applied to dst it will produce a
 *	string identical to src). The return value is a count of the number of
 *	characters copied (not including the terminating NULL character).
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
Tcl_ConvertElement(
    const char *src,		/* Source information for list element. */
    char *dst,			/* Place to put list-ified element. */
    int flags)			/* Flags produced by Tcl_ScanElement. */
{
    return Tcl_ConvertCountedElement(src, TCL_INDEX_NONE, dst, flags);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ConvertCountedElement --
 *
 *	This is a companion function to Tcl_ScanCountedElement. Given the
 *	information produced by Tcl_ScanCountedElement, this function converts
 *	a string to a list element equal to that string.
 *
 * Results:
 *	Information is copied to *dst in the form of a list element identical
 *	to src (i.e. if Tcl_SplitList is applied to dst it will produce a
 *	string identical to src). The return value is a count of the number of
 *	characters copied (not including the terminating NULL character).
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
Tcl_ConvertCountedElement(
    const char *src,		/* Source information for list element. */
    Tcl_Size length,		/* Number of bytes in src, or TCL_INDEX_NONE. */
    char *dst,			/* Place to put list-ified element. */
    int flags)			/* Flags produced by Tcl_ScanElement. */
{
    Tcl_Size numBytes = TclConvertElement(src, length, dst, flags);
    dst[numBytes] = '\0';
    return numBytes;
}

/*
 *----------------------------------------------------------------------
 *
 * TclConvertElement --
 *
 *	This is a companion function to TclScanElement. Given the information
 *	produced by TclScanElement, this function converts a string to a list
 *	element equal to that string.
 *
 * Results:
 *	Information is copied to *dst in the form of a list element identical
 *	to src (i.e. if Tcl_SplitList is applied to dst it will produce a
 *	string identical to src). The return value is a count of the number of
 *	characters copied (not including the terminating NULL character).
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclConvertElement(
    const char *src,		/* Source information for list element. */
    Tcl_Size length,		/* Number of bytes in src, or TCL_INDEX_NONE. */
    char *dst,			/* Place to put list-ified element. */
    int flags)			/* Flags produced by Tcl_ScanElement. */
{
    int conversion = flags & CONVERT_MASK;
    char *p = dst;

    /*
     * Let the caller demand we use escape sequences rather than braces.
     */

    if ((flags & DONT_USE_BRACES) && (conversion & CONVERT_BRACE)) {
	conversion = CONVERT_ESCAPE;
    }

    /*
     * No matter what the caller demands, empty string must be braced!
     */

    if ((src == NULL) || (length == 0) || (*src == '\0' && length == TCL_INDEX_NONE)) {
	p[0] = '{';
	p[1] = '}';
	return 2;
    }

    /*
     * Escape leading hash as needed and requested.
     */

    if ((*src == '#') && !(flags & DONT_QUOTE_HASH)) {
	if (conversion == CONVERT_ESCAPE) {
	    p[0] = '\\';
	    p[1] = '#';
	    p += 2;
	    src++;
	    length -= (length > 0);
	} else {
	    conversion = CONVERT_BRACE;
	}
    }

    /*
     * No escape or quoting needed.  Copy the literal string value.
     */

    if (conversion == CONVERT_NONE) {
	if (length == TCL_INDEX_NONE) {
	    /* TODO: INT_MAX overflow? */
	    while (*src) {
		*p++ = *src++;
	    }
	    return p - dst;
	} else {
	    memcpy(dst, src, length);
	    return length;
	}
    }

    /*
     * Formatted string is original string enclosed in braces.
     */

    if (conversion == CONVERT_BRACE) {
	*p = '{';
	p++;
	if (length == TCL_INDEX_NONE) {
	    /* TODO: INT_MAX overflow? */
	    while (*src) {
		*p++ = *src++;
	    }
	} else {
	    memcpy(p, src, length);
	    p += length;
	}
	*p = '}';
	p++;
	return (p - dst);
    }

    /* conversion == CONVERT_ESCAPE or CONVERT_MASK */

    /*
     * Formatted string is original string converted to escape sequences.
     */

    for ( ; length; src++, length -= (length > 0)) {
	switch (*src) {
	case ']':
	case '[':
	case '$':
	case ';':
	case ' ':
	case '\\':
	case '"':
	    *p = '\\';
	    p++;
	    break;
	case '{':
	case '}':
#if COMPAT
	    if (conversion == CONVERT_ESCAPE)
#endif /* COMPAT */
	    {
		*p = '\\';
		p++;
	    }
	    break;
	case '\f':
	    *p = '\\';
	    p++;
	    *p = 'f';
	    p++;
	    continue;
	case '\n':
	    *p = '\\';
	    p++;
	    *p = 'n';
	    p++;
	    continue;
	case '\r':
	    *p = '\\';
	    p++;
	    *p = 'r';
	    p++;
	    continue;
	case '\t':
	    *p = '\\';
	    p++;
	    *p = 't';
	    p++;
	    continue;
	case '\v':
	    *p = '\\';
	    p++;
	    *p = 'v';
	    p++;
	    continue;
	case '\0':
	    if (length == TCL_INDEX_NONE) {
		return (p - dst);
	    }

	    /*
	     * If we reach this point, there's an embedded NULL in the string
	     * range being processed, which should not happen when the
	     * encoding rules for Tcl strings are properly followed.  If the
	     * day ever comes when we stop tolerating such things, this is
	     * where to put the Tcl_Panic().
	     */

	    break;
	}
	*p = *src;
	p++;
    }
    return (p - dst);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_Merge --
 *
 *	Given a collection of strings, merge them together into a single
 *	string that has proper Tcl list structured (i.e. Tcl_SplitList may be
 *	used to retrieve strings equal to the original elements, and Tcl_Eval
 *	will parse the string back into its original elements).
 *
 * Results:
 *	The return value is the address of a dynamically-allocated string
 *	containing the merged list.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

char *
Tcl_Merge(
    Tcl_Size argc,		/* How many strings to merge. */
    const char *const *argv)	/* Array of string values. */
{
#define LOCAL_SIZE 64
    char localFlags[LOCAL_SIZE], *flagPtr = NULL;
    Tcl_Size i;
    size_t bytesNeeded = 0;
    char *result, *dst;

    /*
     * Handle empty list case first, so logic of the general case can be
     * simpler.
     */

    if (argc <= 0) {
	if (argc < 0) {
	    Tcl_Panic("Tcl_Merge called with negative argc (%" TCL_SIZE_MODIFIER "d)", argc);
	}
	result = (char *)Tcl_Alloc(1);
	result[0] = '\0';
	return result;
    }

    /*
     * Pass 1: estimate space, gather flags.
     */

    if (argc <= LOCAL_SIZE) {
	flagPtr = localFlags;
    } else {
	flagPtr = (char *)Tcl_Alloc(argc);
    }
    for (i = 0; i < argc; i++) {
	flagPtr[i] = ( i ? DONT_QUOTE_HASH : 0 );
	bytesNeeded += TclScanElement(argv[i], TCL_INDEX_NONE, &flagPtr[i]);
    }
    bytesNeeded += argc;

    /*
     * Pass two: copy into the result area.
     */

    result = (char *)Tcl_Alloc(bytesNeeded);
    dst = result;
    for (i = 0; i < argc; i++) {
	if (i) {
	    flagPtr[i] |= DONT_QUOTE_HASH;
	}
	dst += TclConvertElement(argv[i], TCL_INDEX_NONE, dst, flagPtr[i]);
	*dst = ' ';
	dst++;
    }
    dst[-1] = 0;

    if (flagPtr != localFlags) {
	Tcl_Free(flagPtr);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * TclTrimRight --
 *	Takes two counted strings in the Tcl encoding.  Conceptually
 *	finds the sub string (offset) to trim from the right side of the
 *	first string all characters found in the second string.
 *
 * Results:
 *	The number of bytes to be removed from the end of the string.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclTrimRight(
    const char *bytes,		/* String to be trimmed... */
    Tcl_Size numBytes,		/* ...and its length in bytes */
				/* Calls to TclUtfToUniChar() in this routine
				 * rely on (bytes[numBytes] == '\0'). */
    const char *trim,		/* String of trim characters... */
    Tcl_Size numTrim)		/* ...and its length in bytes */
				/* Calls to TclUtfToUniChar() in this routine
				 * rely on (trim[numTrim] == '\0'). */
{
    const char *pp, *p = bytes + numBytes;
    int ch1, ch2;

    /* Empty strings -> nothing to do */
    if ((numBytes == 0) || (numTrim == 0)) {
	return 0;
    }

    /*
     * Outer loop: iterate over string to be trimmed.
     */

    do {
	const char *q = trim;
	Tcl_Size pInc = 0, bytesLeft = numTrim;

	pp = Tcl_UtfPrev(p, bytes);
	do {
	    pp += pInc;
	    pInc = TclUtfToUniChar(pp, &ch1);
	} while (pp + pInc < p);

	/*
	 * Inner loop: scan trim string for match to current character.
	 */

	do {
	    pInc = TclUtfToUniChar(q, &ch2);

	    if (ch1 == ch2) {
		break;
	    }

	    q += pInc;
	    bytesLeft -= pInc;
	} while (bytesLeft);

	if (bytesLeft == 0) {
	    /*
	     * No match; trim task done; *p is last non-trimmed char.
	     */

	    break;
	}
	p = pp;
    } while (p > bytes);

    return numBytes - (p - bytes);
}

/*
 *----------------------------------------------------------------------
 *
 * TclTrimLeft --
 *
 *	Takes two counted strings in the Tcl encoding.  Conceptually
 *	finds the sub string (offset) to trim from the left side of the
 *	first string all characters found in the second string.
 *
 * Results:
 *	The number of bytes to be removed from the start of the string.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclTrimLeft(
    const char *bytes,		/* String to be trimmed... */
    Tcl_Size numBytes,		/* ...and its length in bytes */
				/* Calls to TclUtfToUniChar() in this routine
				 * rely on (bytes[numBytes] == '\0'). */
    const char *trim,		/* String of trim characters... */
    Tcl_Size numTrim)		/* ...and its length in bytes */
				/* Calls to TclUtfToUniChar() in this routine
				 * rely on (trim[numTrim] == '\0'). */
{
    const char *p = bytes;
    int ch1, ch2;

    /* Empty strings -> nothing to do */
    if ((numBytes == 0) || (numTrim == 0)) {
	return 0;
    }

    /*
     * Outer loop: iterate over string to be trimmed.
     */

    do {
	Tcl_Size pInc = TclUtfToUniChar(p, &ch1);
	const char *q = trim;
	Tcl_Size bytesLeft = numTrim;

	/*
	 * Inner loop: scan trim string for match to current character.
	 */

	do {
	    Tcl_Size qInc = TclUtfToUniChar(q, &ch2);

	    if (ch1 == ch2) {
		break;
	    }

	    q += qInc;
	    bytesLeft -= qInc;
	} while (bytesLeft);

	if (bytesLeft == 0) {
	    /*
	     * No match; trim task done; *p is first non-trimmed char.
	     */

	    break;
	}

	p += pInc;
	numBytes -= pInc;
    } while (numBytes > 0);

    return p - bytes;
}

/*
 *----------------------------------------------------------------------
 *
 * TclTrim --
 *	Finds the sub string (offset) to trim from both sides of the
 *	first string all characters found in the second string.
 *
 * Results:
 *	The number of bytes to be removed from the start of the string
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclTrim(
    const char *bytes,		/* String to be trimmed... */
    Tcl_Size numBytes,		/* ...and its length in bytes */
				/* Calls in this routine
				 * rely on (bytes[numBytes] == '\0'). */
    const char *trim,		/* String of trim characters... */
    Tcl_Size numTrim,		/* ...and its length in bytes */
				/* Calls in this routine
				 * rely on (trim[numTrim] == '\0'). */
    Tcl_Size *trimRightPtr)	/* Offset from the end of the string. */
{
    Tcl_Size trimLeft = 0, trimRight = 0;

    /* Empty strings -> nothing to do */
    if ((numBytes > 0) && (numTrim > 0)) {

	/* When bytes is NUL-terminated, returns 0 <= trimLeft <= numBytes */
	trimLeft = TclTrimLeft(bytes, numBytes, trim, numTrim);
	numBytes -= trimLeft;

	/* If we did not trim the whole string, it starts with a character
	 * that we will not trim. Skip over it. */
	if (numBytes > 0) {
	    int ch;
	    const char *first = bytes + trimLeft;
	    bytes += TclUtfToUniChar(first, &ch);
	    numBytes -= (bytes - first);

	    if (numBytes > 0) {
		/* When bytes is NUL-terminated, returns
		 * 0 <= trimRight <= numBytes */
		trimRight = TclTrimRight(bytes, numBytes, trim, numTrim);
	    }
	}
    }
    *trimRightPtr = trimRight;
    return trimLeft;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_Concat --
 *
 *	Concatenate a set of strings into a single large string.
 *
 * Results:
 *	The return value is dynamically-allocated string containing a
 *	concatenation of all the strings in argv, with spaces between the
 *	original argv elements.
 *
 * Side effects:
 *	Memory is allocated for the result; the caller is responsible for
 *	freeing the memory.
 *
 *----------------------------------------------------------------------
 */

/* The whitespace characters trimmed during [concat] operations */
#define CONCAT_WS_SIZE (sizeof(CONCAT_TRIM_SET "") - 1)

char *
Tcl_Concat(
    Tcl_Size argc,		/* Number of strings to concatenate. */
    const char *const *argv)	/* Array of strings to concatenate. */
{
    Tcl_Size i, needSpace = 0, bytesNeeded = 0;
    char *result, *p;

    /*
     * Dispose of the empty result corner case first to simplify later code.
     */

    if (argc == 0) {
	result = (char *) Tcl_Alloc(1);
	result[0] = '\0';
	return result;
    }

    /*
     * First allocate the result buffer at the size required.
     */

    for (i = 0;  i < argc;  i++) {
	bytesNeeded += strlen(argv[i]);
	if (bytesNeeded < 0) {
	    Tcl_Panic("Tcl_Concat: max size of Tcl value exceeded");
	}
    }

    /*
     * All element bytes + (argc - 1) spaces + 1 terminating NULL.
     */
    if (bytesNeeded + argc - 1 < 0) {
	/*
	 * Panic test could be tighter, but not going to bother for this
	 * legacy routine.
	 */

	Tcl_Panic("Tcl_Concat: max size of Tcl value exceeded");
    }

    result = (char *)Tcl_Alloc(bytesNeeded + argc);

    for (p = result, i = 0;  i < argc;  i++) {
	Tcl_Size triml, trimr, elemLength;
	const char *element;

	element = argv[i];
	elemLength = strlen(argv[i]);

	/* Trim away the leading/trailing whitespace. */
	triml = TclTrim(element, elemLength, CONCAT_TRIM_SET,
		CONCAT_WS_SIZE, &trimr);
	element += triml;
	elemLength -= triml + trimr;

	/* Do not permit trimming to expose a final backslash character. */
	elemLength += trimr && (element[elemLength - 1] == '\\');

	/*
	 * If we're left with empty element after trimming, do nothing.
	 */

	if (elemLength == 0) {
	    continue;
	}

	/*
	 * Append to the result with space if needed.
	 */

	if (needSpace) {
	    *p++ = ' ';
	}
	memcpy(p, element, elemLength);
	p += elemLength;
	needSpace = 1;
    }
    *p = '\0';
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ConcatObj --
 *
 *	Concatenate the strings from a set of objects into a single string
 *	object with spaces between the original strings.
 *
 * Results:
 *	The return value is a new string object containing a concatenation of
 *	the strings in objv. Its ref count is zero.
 *
 * Side effects:
 *	A new object is created.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_ConcatObj(
    Tcl_Size objc,		/* Number of objects to concatenate. */
    Tcl_Obj *const objv[])	/* Array of objects to concatenate. */
{
    int needSpace = 0;
    Tcl_Size i, bytesNeeded = 0, elemLength;
    const char *element;
    Tcl_Obj *objPtr, *resPtr;

    /*
     * Check first to see if all the items are of list type or empty. If so,
     * we will concat them together as lists, and return a list object. This
     * is only valid when the lists are in canonical form.
     */

    for (i = 0;  i < objc;  i++) {
	Tcl_Size length;

	objPtr = objv[i];
	if (TclListObjIsCanonical(objPtr) ||
		TclObjTypeHasProc(objPtr, indexProc)) {
	    continue;
	}
	(void)TclGetStringFromObj(objPtr, &length);
	if (length > 0) {
	    break;
	}
    }
    if (i == objc) {
	resPtr = NULL;
	for (i = 0;  i < objc;  i++) {
	    objPtr = objv[i];
	    if (!TclListObjIsCanonical(objPtr) &&
		    !TclObjTypeHasProc(objPtr, indexProc)) {
		continue;
	    }
	    if (resPtr) {
		Tcl_Obj *elemPtr = NULL;

		Tcl_ListObjIndex(NULL, objPtr, 0, &elemPtr);
		if (elemPtr == NULL) {
		    continue;
		}
		if (TclGetString(elemPtr)[0] == '#' || TCL_OK
			!= Tcl_ListObjAppendList(NULL, resPtr, objPtr)) {
		    /* Abandon ship! */
		    Tcl_DecrRefCount(resPtr);
		    Tcl_BounceRefCount(elemPtr); // could be an abstract list element
		    goto slow;
		}
		Tcl_BounceRefCount(elemPtr); // could be an an abstract list element
	    } else {
		resPtr = TclListObjCopy(NULL, objPtr);
	    }
	}
	if (!resPtr) {
	    TclNewObj(resPtr);
	}
	return resPtr;
    }

  slow:
    /*
     * Something cannot be determined to be safe, so build the concatenation
     * the slow way, using the string representations.
     *
     * First try to preallocate the size required.
     */

    for (i = 0;  i < objc;  i++) {
	element = TclGetStringFromObj(objv[i], &elemLength);
	if (bytesNeeded > (TCL_SIZE_MAX - elemLength)) {
	    break; /* Overflow. Do not preallocate. See comment below. */
	}
	bytesNeeded += elemLength;
    }

    /*
     * Does not matter if this fails, will simply try later to build up the
     * string with each Append reallocating as needed with the usual string
     * append algorithm.  When that fails it will report the error.
     */

    TclNewObj(resPtr);
    (void) Tcl_AttemptSetObjLength(resPtr, bytesNeeded + objc - 1);
    Tcl_SetObjLength(resPtr, 0);

    for (i = 0;  i < objc;  i++) {
	Tcl_Size triml, trimr;

	element = TclGetStringFromObj(objv[i], &elemLength);

	/* Trim away the leading/trailing whitespace. */
	triml = TclTrim(element, elemLength, CONCAT_TRIM_SET,
		CONCAT_WS_SIZE, &trimr);
	element += triml;
	elemLength -= triml + trimr;

	/* Do not permit trimming to expose a final backslash character. */
	elemLength += trimr && (element[elemLength - 1] == '\\');

	/*
	 * If we're left with empty element after trimming, do nothing.
	 */

	if (elemLength == 0) {
	    continue;
	}

	/*
	 * Append to the result with space if needed.
	 */

	if (needSpace) {
	    Tcl_AppendToObj(resPtr, " ", 1);
	}
	Tcl_AppendToObj(resPtr, element, elemLength);
	needSpace = 1;
    }
    return resPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_StringCaseMatch --
 *
 *	See if a particular string matches a particular pattern. Allows case
 *	insensitivity.
 *
 * Results:
 *	The return value is 1 if string matches pattern, and 0 otherwise. The
 *	matching operation permits the following special characters in the
 *	pattern: *?\[] (see the manual entry for details on what these mean).
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_StringCaseMatch(
    const char *str,		/* String. */
    const char *pattern,	/* Pattern, which may contain special
				 * characters. */
    int nocase)			/* 0 for case sensitive, 1 for insensitive */
{
    Tcl_Size charLen;
    int p, ch1 = 0, ch2 = 0;

    while (1) {
	p = *pattern;

	/*
	 * See if we're at the end of both the pattern and the string. If so,
	 * we succeeded. If we're at the end of the pattern but not at the end
	 * of the string, we failed.
	 */

	if (p == '\0') {
	    return (*str == '\0');
	}
	if ((*str == '\0') && (p != '*')) {
	    return 0;
	}

	/*
	 * Check for a "*" as the next pattern character. It matches any
	 * substring. We handle this by calling ourselves recursively for each
	 * postfix of string, until either we match or we reach the end of the
	 * string.
	 */

	if (p == '*') {
	    /*
	     * Skip all successive *'s in the pattern
	     */

	    while (*(++pattern) == '*');
	    p = *pattern;
	    if (p == '\0') {
		return 1;
	    }

	    /*
	     * This is a special case optimization for single-byte utf.
	     */

	    if (UCHAR(*pattern) < 0x80) {
		ch2 = (int)
			(nocase ? tolower(UCHAR(*pattern)) : UCHAR(*pattern));
	    } else {
		TclUtfToUniChar(pattern, &ch2);
		if (nocase) {
		    ch2 = Tcl_UniCharToLower(ch2);
		}
	    }

	    while (1) {
		/*
		 * Optimization for matching - cruise through the string
		 * quickly if the next char in the pattern isn't a special
		 * character
		 */

		if ((p != '[') && (p != '?') && (p != '\\')) {
		    if (nocase) {
			while (*str) {
			    charLen = TclUtfToUniChar(str, &ch1);
			    if (ch2==ch1 || ch2==Tcl_UniCharToLower(ch1)) {
				break;
			    }
			    str += charLen;
			}
		    } else {
			/*
			 * There's no point in trying to make this code
			 * shorter, as the number of bytes you want to compare
			 * each time is non-constant.
			 */

			while (*str) {
			    charLen = TclUtfToUniChar(str, &ch1);
			    if (ch2 == ch1) {
				break;
			    }
			    str += charLen;
			}
		    }
		}
		if (Tcl_StringCaseMatch(str, pattern, nocase)) {
		    return 1;
		}
		if (*str == '\0') {
		    return 0;
		}
		str += TclUtfToUniChar(str, &ch1);
	    }
	}

	/*
	 * Check for a "?" as the next pattern character. It matches any
	 * single character.
	 */

	if (p == '?') {
	    pattern++;
	    str += TclUtfToUniChar(str, &ch1);
	    continue;
	}

	/*
	 * Check for a "[" as the next pattern character. It is followed by a
	 * list of characters that are acceptable, or by a range (two
	 * characters separated by "-").
	 */

	if (p == '[') {
	    int startChar = 0, endChar = 0;

	    pattern++;
	    if (UCHAR(*str) < 0x80) {
		ch1 = (int)
			(nocase ? tolower(UCHAR(*str)) : UCHAR(*str));
		str++;
	    } else {
		str += TclUtfToUniChar(str, &ch1);
		if (nocase) {
		    ch1 = Tcl_UniCharToLower(ch1);
		}
	    }
	    while (1) {
		if ((*pattern == ']') || (*pattern == '\0')) {
		    return 0;
		}
		if (UCHAR(*pattern) < 0x80) {
		    startChar = (int) (nocase
			    ? tolower(UCHAR(*pattern)) : UCHAR(*pattern));
		    pattern++;
		} else {
		    pattern += TclUtfToUniChar(pattern, &startChar);
		    if (nocase) {
			startChar = Tcl_UniCharToLower(startChar);
		    }
		}
		if (*pattern == '-') {
		    pattern++;
		    if (*pattern == '\0') {
			return 0;
		    }
		    if (UCHAR(*pattern) < 0x80) {
			endChar = (int) (nocase
				? tolower(UCHAR(*pattern)) : UCHAR(*pattern));
			pattern++;
		    } else {
			pattern += TclUtfToUniChar(pattern, &endChar);
			if (nocase) {
			    endChar = Tcl_UniCharToLower(endChar);
			}
		    }
		    if (((startChar <= ch1) && (ch1 <= endChar))
			    || ((endChar <= ch1) && (ch1 <= startChar))) {
			/*
			 * Matches ranges of form [a-z] or [z-a].
			 */

			break;
		    }
		} else if (startChar == ch1) {
		    break;
		}
	    }
	    /* If we reach here, we matched. Need to move past closing ] */
	    while (*pattern != ']') {
		if (*pattern == '\0') {
		    /* We ran out of pattern after matching something in
		     * (unclosed!) brackets. So long as we ran out of string
		     * at the same time, we have a match. Otherwise, not. */
		    return (*str == '\0');
		}
		pattern++;
	    }
	    pattern++;
	    continue;
	}

	/*
	 * If the next pattern character is '\', just strip off the '\' so we
	 * do exact matching on the character that follows.
	 */

	if (p == '\\') {
	    pattern++;
	    if (*pattern == '\0') {
		return 0;
	    }
	}

	/*
	 * There's no special character. Just make sure that the next bytes of
	 * each string match.
	 */

	str += TclUtfToUniChar(str, &ch1);
	pattern += TclUtfToUniChar(pattern, &ch2);
	if (nocase) {
	    if (Tcl_UniCharToLower(ch1) != Tcl_UniCharToLower(ch2)) {
		return 0;
	    }
	} else if (ch1 != ch2) {
	    return 0;
	}
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclByteArrayMatch --
 *
 *	See if a particular string matches a particular pattern.  Does not
 *	allow for case insensitivity.
 *	Parallels tclUtf.c:TclUniCharMatch, adjusted for char* and sans nocase.
 *
 * Results:
 *	The return value is 1 if string matches pattern, and 0 otherwise. The
 *	matching operation permits the following special characters in the
 *	pattern: *?\[] (see the manual entry for details on what these mean).
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclByteArrayMatch(
    const unsigned char *string,/* String. */
    Tcl_Size strLen,		/* Length of String */
    const unsigned char *pattern,
				/* Pattern, which may contain special
				 * characters. */
    Tcl_Size ptnLen,		/* Length of Pattern */
    TCL_UNUSED(int) /*flags*/)
{
    const unsigned char *stringEnd, *patternEnd;
    unsigned char p;

    stringEnd = string + strLen;
    patternEnd = pattern + ptnLen;

    while (1) {
	/*
	 * See if we're at the end of both the pattern and the string. If so,
	 * we succeeded. If we're at the end of the pattern but not at the end
	 * of the string, we failed.
	 */

	if (pattern == patternEnd) {
	    return (string == stringEnd);
	}
	p = *pattern;
	if ((string == stringEnd) && (p != '*')) {
	    return 0;
	}

	/*
	 * Check for a "*" as the next pattern character. It matches any
	 * substring. We handle this by skipping all the characters up to the
	 * next matching one in the pattern, and then calling ourselves
	 * recursively for each postfix of string, until either we match or we
	 * reach the end of the string.
	 */

	if (p == '*') {
	    /*
	     * Skip all successive *'s in the pattern.
	     */

	    while ((++pattern < patternEnd) && (*pattern == '*')) {
		/* empty body */
	    }
	    if (pattern == patternEnd) {
		return 1;
	    }
	    p = *pattern;
	    while (1) {
		/*
		 * Optimization for matching - cruise through the string
		 * quickly if the next char in the pattern isn't a special
		 * character.
		 */

		if ((p != '[') && (p != '?') && (p != '\\')) {
		    while ((string < stringEnd) && (p != *string)) {
			string++;
		    }
		}
		if (TclByteArrayMatch(string, stringEnd - string,
			pattern, patternEnd - pattern, 0)) {
		    return 1;
		}
		if (string == stringEnd) {
		    return 0;
		}
		string++;
	    }
	}

	/*
	 * Check for a "?" as the next pattern character. It matches any
	 * single character.
	 */

	if (p == '?') {
	    pattern++;
	    string++;
	    continue;
	}

	/*
	 * Check for a "[" as the next pattern character. It is followed by a
	 * list of characters that are acceptable, or by a range (two
	 * characters separated by "-").
	 */

	if (p == '[') {
	    unsigned char ch1, startChar, endChar;

	    pattern++;
	    ch1 = *string;
	    string++;
	    while (1) {
		if ((*pattern == ']') || (pattern == patternEnd)) {
		    return 0;
		}
		startChar = *pattern;
		pattern++;
		if (*pattern == '-') {
		    pattern++;
		    if (pattern == patternEnd) {
			return 0;
		    }
		    endChar = *pattern;
		    pattern++;
		    if (((startChar <= ch1) && (ch1 <= endChar))
			    || ((endChar <= ch1) && (ch1 <= startChar))) {
			/*
			 * Matches ranges of form [a-z] or [z-a].
			 */

			break;
		    }
		} else if (startChar == ch1) {
		    break;
		}
	    }
	    while (*pattern != ']') {
		if (pattern == patternEnd) {
		    pattern--;
		    break;
		}
		pattern++;
	    }
	    pattern++;
	    continue;
	}

	/*
	 * If the next pattern character is '\', just strip off the '\' so we
	 * do exact matching on the character that follows.
	 */

	if (p == '\\') {
	    if (++pattern == patternEnd) {
		return 0;
	    }
	}

	/*
	 * There's no special character. Just make sure that the next bytes of
	 * each string match.
	 */

	if (*string != *pattern) {
	    return 0;
	}
	string++;
	pattern++;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclStringMatchObj --
 *
 *	See if a particular string matches a particular pattern. Allows case
 *	insensitivity. This is the generic multi-type handler for the various
 *	matching algorithms.
 *
 * Results:
 *	The return value is 1 if string matches pattern, and 0 otherwise. The
 *	matching operation permits the following special characters in the
 *	pattern: *?\[] (see the manual entry for details on what these mean).
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclStringMatchObj(
    Tcl_Obj *strObj,		/* string object. */
    Tcl_Obj *ptnObj,		/* pattern object. */
    int flags)			/* Only TCL_MATCH_NOCASE should be passed, or
				 * 0. */
{
    int match;
    Tcl_Size length = 0, plen = 0;

    /*
     * Promote based on the type of incoming object.
     * XXX: Currently doesn't take advantage of exact-ness that
     * XXX: TclReToGlob tells us about
    trivial = nocase ? 0 : TclMatchIsTrivial(TclGetString(ptnObj));
     */

    if (TclHasInternalRep(strObj, &tclStringType) || (strObj->typePtr == NULL)) {
	Tcl_UniChar *udata, *uptn;

	udata = Tcl_GetUnicodeFromObj(strObj, &length);
	uptn  = Tcl_GetUnicodeFromObj(ptnObj, &plen);
	match = TclUniCharMatch(udata, length, uptn, plen, flags);
    } else if (TclIsPureByteArray(strObj) && TclIsPureByteArray(ptnObj)
		&& !flags) {
	unsigned char *data, *ptn;

	data = Tcl_GetBytesFromObj(NULL, strObj, &length);
	ptn  = Tcl_GetBytesFromObj(NULL, ptnObj, &plen);
	match = TclByteArrayMatch(data, length, ptn, plen, 0);
    } else {
	match = Tcl_StringCaseMatch(TclGetString(strObj),
		TclGetString(ptnObj), flags);
    }
    return match;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringInit --
 *
 *	Initializes a dynamic string, discarding any previous contents of the
 *	string (Tcl_DStringFree should have been called already if the dynamic
 *	string was previously in use).
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The dynamic string is initialized to be empty.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DStringInit(
    Tcl_DString *dsPtr)		/* Pointer to structure for dynamic string. */
{
    dsPtr->string = dsPtr->staticSpace;
    dsPtr->length = 0;
    dsPtr->spaceAvl = TCL_DSTRING_STATIC_SIZE;
    dsPtr->staticSpace[0] = '\0';
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringAppend --
 *
 *	Append more bytes to the current value of a dynamic string.
 *
 * Results:
 *	The return value is a pointer to the dynamic string's new value.
 *
 * Side effects:
 *	Length bytes from "bytes" (or all of "bytes" if length is less than
 *	zero) are added to the current value of the string. Memory gets
 *	reallocated if needed to accomodate the string's new size.
 *
 *----------------------------------------------------------------------
 */

char *
Tcl_DStringAppend(
    Tcl_DString *dsPtr,		/* Structure describing dynamic string. */
    const char *bytes,		/* String to append. If length is
				 * TCL_INDEX_NONE then this must be
				 * null-terminated. */
    Tcl_Size length)		/* Number of bytes from "bytes" to append. If
				 * TCL_INDEX_NONE, then append all of bytes, up
				 * to null at end. */
{
    Tcl_Size newSize;

    if (length < 0) {
	length = strlen(bytes);
    }

    if (length > (TCL_SIZE_MAX - dsPtr->length - 1)) {
	Tcl_Panic("max size for a Tcl value (%" TCL_SIZE_MODIFIER
		"d bytes) exceeded",
		TCL_SIZE_MAX);
	return NULL; /* NOTREACHED */
    }
    newSize = length + dsPtr->length + 1;

    if (newSize > dsPtr->spaceAvl) {
	if (dsPtr->string == dsPtr->staticSpace) {
	    char *newString;
	    newString = (char *) TclAllocEx(newSize, &dsPtr->spaceAvl);
	    memcpy(newString, dsPtr->string, dsPtr->length);
	    dsPtr->string = newString;
	} else {
	    Tcl_Size offset = -1;

	    /* See [16896d49fd] */
	    if (bytes >= dsPtr->string
		    && bytes <= dsPtr->string + dsPtr->length) {
		/* Source string is within this DString. Note offset */
		offset = bytes - dsPtr->string;
	    }
	    dsPtr->string =
		(char *)TclReallocEx(dsPtr->string, newSize, &dsPtr->spaceAvl);
	    if (offset >= 0) {
		bytes = dsPtr->string + offset;
	    }
	}
    }

    /*
     * Copy the new string into the buffer at the end of the old one.
     */

    memcpy(dsPtr->string + dsPtr->length, bytes, length);
    dsPtr->length += length;
    dsPtr->string[dsPtr->length] = '\0';
    return dsPtr->string;
}

/*
 *----------------------------------------------------------------------
 *
 * TclDStringAppendObj, TclDStringAppendDString --
 *
 *	Simple wrappers round Tcl_DStringAppend that make it easier to append
 *	from particular sources of strings.
 *
 *----------------------------------------------------------------------
 */

char *
TclDStringAppendObj(
    Tcl_DString *dsPtr,
    Tcl_Obj *objPtr)
{
    Tcl_Size length;
    const char *bytes = TclGetStringFromObj(objPtr, &length);

    return Tcl_DStringAppend(dsPtr, bytes, length);
}

char *
TclDStringAppendDString(
    Tcl_DString *dsPtr,
    Tcl_DString *toAppendPtr)
{
    return Tcl_DStringAppend(dsPtr, Tcl_DStringValue(toAppendPtr),
	    Tcl_DStringLength(toAppendPtr));
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringAppendElement --
 *
 *	Append a list element to the current value of a dynamic string.
 *
 * Results:
 *	The return value is a pointer to the dynamic string's new value.
 *
 * Side effects:
 *	String is reformatted as a list element and added to the current value
 *	of the string. Memory gets reallocated if needed to accomodate the
 *	string's new size.
 *
 *----------------------------------------------------------------------
 */

char *
Tcl_DStringAppendElement(
    Tcl_DString *dsPtr,		/* Structure describing dynamic string. */
    const char *element)	/* String to append. Must be
				 * null-terminated. */
{
    char *dst = dsPtr->string + dsPtr->length;
    int needSpace = TclNeedSpace(dsPtr->string, dst);
    char flags = 0;
    int quoteHash = 1;
    Tcl_Size newSize;

    if (needSpace) {
	/*
	 * If we need a space to separate the new element from something
	 * already ending the string, we're not appending the first element
	 * of any list, so we need not quote any leading hash character.
	 */
	quoteHash = 0;
    } else {
	/*
	 * We don't need a space, maybe because there's some already there.
	 * Checking whether we might be appending a first element is a bit
	 * more involved.
	 *
	 * Backtrack over all whitespace.
	 */
	while ((--dst >= dsPtr->string) && TclIsSpaceProcM(*dst)) {
	}

	/* Call again without whitespace to confound things. */
	quoteHash = !TclNeedSpace(dsPtr->string, dst+1);
    }
    if (!quoteHash) {
	flags |= DONT_QUOTE_HASH;
    }
    newSize = dsPtr->length + needSpace + TclScanElement(element, TCL_INDEX_NONE, &flags);
    if (!quoteHash) {
	flags |= DONT_QUOTE_HASH;
    }

    /*
     * Allocate a larger buffer for the string if the current one isn't large
     * enough. Allocate extra space in the new buffer so that there will be
     * room to grow before we have to allocate again. SPECIAL NOTE: must use
     * memcpy, not strcpy, to copy the string to a larger buffer, since there
     * may be embedded NULLs in the string in some cases.
     */
    newSize += 1; /* For terminating nul */
    if (newSize > dsPtr->spaceAvl) {
	if (dsPtr->string == dsPtr->staticSpace) {
	    char *newString = (char *) TclAllocEx(newSize, &dsPtr->spaceAvl);
	    memcpy(newString, dsPtr->string, dsPtr->length);
	    dsPtr->string = newString;
	} else {
	    Tcl_Size offset = -1;

	    /* See [16896d49fd] */
	    if (element >= dsPtr->string
		    && element <= dsPtr->string + dsPtr->length) {
		/* Source string is within this DString. Note offset */
		offset = element - dsPtr->string;
	    }
	    dsPtr->string =
		    (char *)TclReallocEx(dsPtr->string, newSize, &dsPtr->spaceAvl);
	    if (offset >= 0) {
		element = dsPtr->string + offset;
	    }
	}
    }
    dst = dsPtr->string + dsPtr->length;

    /*
     * Convert the new string to a list element and copy it into the buffer at
     * the end, with a space, if needed.
     */

    if (needSpace) {
	*dst = ' ';
	dst++;
	dsPtr->length++;
    }

    dsPtr->length += TclConvertElement(element, TCL_INDEX_NONE, dst, flags);
    dsPtr->string[dsPtr->length] = '\0';
    return dsPtr->string;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringSetLength --
 *
 *	Change the length of a dynamic string. This can cause the string to
 *	either grow or shrink, depending on the value of length.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The length of dsPtr is changed to length and a null byte is stored at
 *	that position in the string.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DStringSetLength(
    Tcl_DString *dsPtr,		/* Structure describing dynamic string. */
    Tcl_Size length)		/* New length for dynamic string. */
{
    Tcl_Size newsize;

    if (length < 0) {
	length = 0;
    }
    if (length >= dsPtr->spaceAvl) {
	/*
	 * There are two interesting cases here. In the first case, the user
	 * may be trying to allocate a large buffer of a specific size. It
	 * would be wasteful to overallocate that buffer, so we just allocate
	 * enough for the requested size plus the trailing null byte. In the
	 * second case, we are growing the buffer incrementally, so we need
	 * behavior similar to Tcl_DStringAppend.
	 * TODO - the above makes no sense to me. How does the code below
	 * translate into distinguishing the two cases above? IMO, if caller
	 * specifically sets the length, there is no cause for overallocation.
	 */

	if (length >= TCL_SIZE_MAX) {
	    Tcl_Panic("Tcl_Concat: max size of Tcl value exceeded");
	}
	newsize = TclUpsizeAlloc(dsPtr->spaceAvl, length + 1, TCL_SIZE_MAX);
	if (length < newsize) {
	    dsPtr->spaceAvl = newsize;
	} else {
	    dsPtr->spaceAvl = length + 1;
	}
	if (dsPtr->string == dsPtr->staticSpace) {
	    char *newString = (char *)Tcl_Alloc(dsPtr->spaceAvl);

	    memcpy(newString, dsPtr->string, dsPtr->length);
	    dsPtr->string = newString;
	} else {
	    dsPtr->string = (char *)Tcl_Realloc(dsPtr->string, dsPtr->spaceAvl);
	}
    }
    dsPtr->length = length;
    dsPtr->string[length] = 0;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringFree --
 *
 *	Frees up any memory allocated for the dynamic string and reinitializes
 *	the string to an empty state.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The previous contents of the dynamic string are lost, and the new
 *	value is an empty string.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DStringFree(
    Tcl_DString *dsPtr)		/* Structure describing dynamic string. */
{
    if (dsPtr->string != dsPtr->staticSpace) {
	Tcl_Free(dsPtr->string);
    }
    dsPtr->string = dsPtr->staticSpace;
    dsPtr->length = 0;
    dsPtr->spaceAvl = TCL_DSTRING_STATIC_SIZE;
    dsPtr->staticSpace[0] = '\0';
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringResult --
 *
 *	This function moves the value of a dynamic string into an interpreter
 *	as its string result. Afterwards, the dynamic string is reset to an
 *	empty string.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The string is "moved" to interp's result, and any existing string
 *	result for interp is freed. dsPtr is reinitialized to an empty string.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DStringResult(
    Tcl_Interp *interp,		/* Interpreter whose result is to be reset. */
    Tcl_DString *dsPtr)		/* Dynamic string that is to become the
				 * result of interp. */
{
    Tcl_SetObjResult(interp, Tcl_DStringToObj(dsPtr));
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringGetResult --
 *
 *	This function moves an interpreter's result into a dynamic string.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The interpreter's string result is cleared, and the previous contents
 *	of dsPtr are freed.
 *
 *	If the string result is empty, the object result is moved to the
 *	string result, then the object result is reset.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DStringGetResult(
    Tcl_Interp *interp,		/* Interpreter whose result is to be reset. */
    Tcl_DString *dsPtr)		/* Dynamic string that is to become the result
				 * of interp. */
{
    Tcl_Obj *obj = Tcl_GetObjResult(interp);
    const char *bytes = TclGetString(obj);

    Tcl_DStringFree(dsPtr);
    Tcl_DStringAppend(dsPtr, bytes, obj->length);
    Tcl_ResetResult(interp);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringToObj --
 *
 *	This function moves a dynamic string's contents to a new Tcl_Obj. Be
 *	aware that this function does *not* check that the encoding of the
 *	contents of the dynamic string is correct; this is the caller's
 *	responsibility to enforce.
 *
 * Results:
 *	The newly-allocated untyped (i.e., typePtr==NULL) Tcl_Obj with a
 *	reference count of zero.
 *
 * Side effects:
 *	The string is "moved" to the object. dsPtr is reinitialized to an
 *	empty string; it does not need to be Tcl_DStringFree'd after this if
 *	not used further.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_DStringToObj(
    Tcl_DString *dsPtr)
{
    Tcl_Obj *result;

    if (dsPtr->string == dsPtr->staticSpace) {
	if (dsPtr->length == 0) {
	    TclNewObj(result);
	} else {
	    /*
	     * Static buffer, so must copy.
	     */

	    TclNewStringObj(result, dsPtr->string, dsPtr->length);
	}
    } else {
	/*
	 * Dynamic buffer, so transfer ownership and reset.
	 */

	TclNewObj(result);
	result->bytes = dsPtr->string;
	result->length = dsPtr->length;
    }

    /*
     * Re-establish the DString as empty with no buffer allocated.
     */

    dsPtr->string = dsPtr->staticSpace;
    dsPtr->spaceAvl = TCL_DSTRING_STATIC_SIZE;
    dsPtr->length = 0;
    dsPtr->staticSpace[0] = '\0';

    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringStartSublist --
 *
 *	This function adds the necessary information to a dynamic string
 *	(e.g. " {") to start a sublist. Future element appends will be in the
 *	sublist rather than the main list.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Characters get added to the dynamic string.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DStringStartSublist(
    Tcl_DString *dsPtr)		/* Dynamic string. */
{
    if (TclNeedSpace(dsPtr->string, dsPtr->string + dsPtr->length)) {
	TclDStringAppendLiteral(dsPtr, " {");
    } else {
	TclDStringAppendLiteral(dsPtr, "{");
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DStringEndSublist --
 *
 *	This function adds the necessary characters to a dynamic string to end
 *	a sublist (e.g. "}"). Future element appends will be in the enclosing
 *	(sub)list rather than the current sublist.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DStringEndSublist(
    Tcl_DString *dsPtr)		/* Dynamic string. */
{
    TclDStringAppendLiteral(dsPtr, "}");
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_PrintDouble --
 *
 *	Given a floating-point value, this function converts it to an ASCII
 *	string using.
 *
 * Results:
 *	The ASCII equivalent of "value" is written at "dst". It is guaranteed
 *	to contain a decimal point or exponent, so that it looks like a
 *	floating-point value and not an integer.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_PrintDouble(
    TCL_UNUSED(Tcl_Interp *),
    double value,		/* Value to print as string. */
    char *dst)			/* Where to store converted value; must have
				 * at least TCL_DOUBLE_SPACE characters. */
{
    char *p, c;
    int exponent;
    int signum;
    char *digits;
    char *end;

    /*
     * Handle NaN.
     */

    if (isnan(value)) {
	TclFormatNaN(value, dst);
	return;
    }

    /*
     * Handle infinities.
     */

    if (isinf(value)) {
	/*
	 * Remember to copy the terminating NUL too.
	 */

	if (value < 0) {
	    memcpy(dst, "-Inf", 5);
	} else {
	    memcpy(dst, "Inf", 4);
	}
	return;
    }

    /*
     * Ordinary (normal and denormal) values.
     */

    digits = TclDoubleDigits(value, -1, TCL_DD_SHORTEST,
	    &exponent, &signum, &end);
    if (signum) {
	*dst++ = '-';
    }
    p = digits;
    if (exponent < -4 || exponent > 16) {
	/*
	 * E format for numbers < 1e-3 or >= 1e17.
	 */

	*dst++ = *p++;
	c = *p;
	if (c != '\0') {
	    *dst++ = '.';
	    while (c != '\0') {
		*dst++ = c;
		c = *++p;
	    }
	}

	snprintf(dst, TCL_DOUBLE_SPACE, "e%+d", exponent);
    } else {
	/*
	 * F format for others.
	 */

	if (exponent < 0) {
	    *dst++ = '0';
	}
	c = *p;
	while (exponent-- >= 0) {
	    if (c != '\0') {
		*dst++ = c;
		c = *++p;
	    } else {
		*dst++ = '0';
	    }
	}
	*dst++ = '.';
	if (c == '\0') {
	    *dst++ = '0';
	} else {
	    while (++exponent < -1) {
		*dst++ = '0';
	    }
	    while (c != '\0') {
		*dst++ = c;
		c = *++p;
	    }
	}
	*dst++ = '\0';
    }
    Tcl_Free(digits);
}

/*
 *----------------------------------------------------------------------
 *
 * TclNeedSpace --
 *
 *	This function checks to see whether it is appropriate to add a space
 *	before appending a new list element to an existing string.
 *
 * Results:
 *	The return value is 1 if a space is appropriate, 0 otherwise.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclNeedSpace(
    const char *start,		/* First character in string. */
    const char *end)		/* End of string (place where space will be
				 * added, if appropriate). */
{
    /*
     * A space is needed unless either:
     * (a) we're at the start of the string, or
     *
     * (NOTE: This check is now absorbed into the loop below.)
     *

    if (end == start) {
	return 0;
    }

     *
     */

    /*
     * (b) we're at the start of a nested list-element, quoted with an open
     *	   curly brace; we can be nested arbitrarily deep, so long as the
     *	   first curly brace starts an element, so backtrack over open curly
     *	   braces that are trailing characters of the string; and
     *
     *  (NOTE: Every character our parser is looking for is a proper
     *  single-byte encoding of an ASCII value. It does not accept
     *  overlong encodings.  Given that, there's no benefit using
     *  Tcl_UtfPrev. If it would find what we seek, so would byte-by-byte
     *  backward scan. Save routine call overhead and risk of wrong
     *  results should the behavior of Tcl_UtfPrev change in unexpected ways.
     *	Reconsider this if we ever start treating non-ASCII Unicode
     *	characters as meaningful list syntax, expanded Unicode spaces as
     *	element separators, for example.)
     *

    end = Tcl_UtfPrev(end, start);
    while (*end == '{') {
	if (end == start) {
	    return 0;
	}
	end = Tcl_UtfPrev(end, start);
    }

     *
     */

    while ((--end >= start) && (*end == '{')) {
    }
    if (end < start) {
	return 0;
    }

    /*
     * (c) the trailing character of the string is already a list-element
     *	   separator, Use the same testing routine as TclFindElement to
     *	   enforce consistency.
     */

    if (TclIsSpaceProcM(*end)) {
	int result = 0;

	/*
	 * Trailing whitespace might be part of a backslash escape
	 * sequence. Handle that possibility.
	 */

	while ((--end >= start) && (*end == '\\')) {
	    result = !result;
	}
	return result;
    }
    return 1;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFormatInt --
 *
 *	This procedure formats an integer into a sequence of decimal digit
 *	characters in a buffer. If the integer is negative, a minus sign is
 *	inserted at the start of the buffer. A null character is inserted at
 *	the end of the formatted characters. It is the caller's responsibility
 *	to ensure that enough storage is available. This procedure has the
 *	effect of sprintf(buffer, "%ld", n) but is faster as proven in
 *	benchmarks.  This is key to UpdateStringOfInt, which is a common path
 *	for a lot of code (e.g. int-indexed arrays).
 *
 * Results:
 *	An integer representing the number of characters formatted, not
 *	including the terminating \0.
 *
 * Side effects:
 *	The formatted characters are written into the storage pointer to by
 *	the "buffer" argument.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclFormatInt(
    char *buffer,		/* Points to the storage into which the
				 * formatted characters are written. */
    Tcl_WideInt n)		/* The integer to format. */
{
    Tcl_WideUInt intVal;
    int i = 0, numFormatted, j;
    static const char digits[] = "0123456789";

    /*
     * Generate the characters of the result backwards in the buffer.
     */

    intVal = (n < 0 ? -(Tcl_WideUInt)n : (Tcl_WideUInt)n);
    do {
	buffer[i++] = digits[intVal % 10];
	intVal = intVal / 10;
    } while (intVal > 0);
    if (n < 0) {
	buffer[i++] = '-';
    }
    buffer[i] = '\0';
    numFormatted = i--;

    /*
     * Now reverse the characters.
     */

    for (j = 0;  j < i;  j++, i--) {
	char tmp = buffer[i];

	buffer[i] = buffer[j];
	buffer[j] = tmp;
    }
    return numFormatted;
}

/*
 *----------------------------------------------------------------------
 *
 * GetWideForIndex --
 *
 *	This function produces a wide integer value corresponding to the
 *	index value held in *objPtr. The parsing supports all values
 *	recognized as any size of integer, and the syntaxes end[-+]$integer
 *	and $integer[-+]$integer. The argument endValue is used to give
 *	the meaning of the literal index value "end". Index arithmetic
 *	on arguments outside the wide integer range are only accepted
 *	when interp is a working interpreter, not NULL.
 *
 * Results:
 *	When parsing of *objPtr successfully recognizes an index value,
 *	TCL_OK is returned, and the wide integer value corresponding to
 *	the recognized index value is written to *widePtr. When parsing
 *	fails, TCL_ERROR is returned and error information is written to
 *	interp, if non-NULL.
 *
 * Side effects:
 *	The type of *objPtr may change.
 *
 *----------------------------------------------------------------------
 */

static int
GetWideForIndex(
    Tcl_Interp *interp,		/* Interpreter to use for error reporting. If
				 * NULL, then no error message is left after
				 * errors. */
    Tcl_Obj *objPtr,		/* Points to the value to be parsed */
    Tcl_WideInt endValue,	/* The value to be stored at *widePtr if
				 * objPtr holds "end".
				 * NOTE: this value may be TCL_INDEX_NONE. */
    Tcl_WideInt *widePtr)	/* Location filled in with a wide integer
				 * representing an index. */
{
    int numType;
    void *cd;
    int code = Tcl_GetNumberFromObj(NULL, objPtr, &cd, &numType);

    if (code == TCL_OK) {
	if (numType == TCL_NUMBER_INT) {
	    /* objPtr holds an integer in the signed wide range */
	    *widePtr = *(Tcl_WideInt *)cd;
	    if ((*widePtr < 0)) {
		*widePtr = (endValue == -1) ? WIDE_MIN : -1;
	    }
	    return TCL_OK;
	}
	if (numType == TCL_NUMBER_BIG) {
	    /* objPtr holds an integer outside the signed wide range */
	    /* Truncate to the signed wide range. */
	    *widePtr = ((mp_isneg((mp_int *)cd)) ? WIDE_MIN : WIDE_MAX);
	    return TCL_OK;
	}
    }

    /* objPtr does not hold a number, check the end+/- format... */
    return GetEndOffsetFromObj(interp, objPtr, endValue, widePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetIntForIndex --
 *
 *	Provides an integer corresponding to the list index held in a Tcl
 *	object. The string value 'objPtr' is expected have the format
 *	integer([+-]integer)? or end([+-]integer)?.
 *
 *	If the computed index lies within the valid range of Tcl indices
 *	(0..TCL_SIZE_MAX) it is returned. Higher values are returned as
 *	TCL_SIZE_MAX. Negative values are returned as TCL_INDEX_NONE (-1).
 *
 *	Callers should pass reasonable values for endValue - one in the
 *      valid index range or TCL_INDEX_NONE (-1), for example for an empty
 *	list.
 *
 * Results:
 *	TCL_OK
 *
 *	    The index is stored at the address given by 'indexPtr'.
 *
 *	TCL_ERROR
 *
 *	    The value of 'objPtr' does not have one of the expected formats. If
 *	    'interp' is non-NULL, an error message is left in the interpreter's
 *	    result object.
 *
 * Side effects:
 *
 *	The internal representation contained within objPtr may shimmer.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_GetIntForIndex(
    Tcl_Interp *interp,		/* Interpreter to use for error reporting. If
				 * NULL, then no error message is left after
				 * errors. */
    Tcl_Obj *objPtr,		/* Points to an object containing either "end"
				 * or an integer. */
    Tcl_Size endValue,		/* The value corresponding to the "end" index */
    Tcl_Size *indexPtr)		/* Location filled in with an integer
				 * representing an index. May be NULL.*/
{
    Tcl_WideInt wide;

    if (GetWideForIndex(interp, objPtr, endValue, &wide) == TCL_ERROR) {
	return TCL_ERROR;
    }
    if (indexPtr != NULL) {
	/* Note: check against TCL_SIZE_MAX needed for 32-bit builds */
	if (wide >= 0 && wide <= TCL_SIZE_MAX) {
	    *indexPtr = (Tcl_Size)wide; /* A valid index */
	} else if (wide > TCL_SIZE_MAX) {
	    *indexPtr = TCL_SIZE_MAX;   /* Beyond max possible index */
	} else if (wide < -1-TCL_SIZE_MAX) {
	    *indexPtr = -1-TCL_SIZE_MAX; /* Below most negative index */
	} else if ((wide < 0) && (endValue >= 0)) {
	    *indexPtr = TCL_INDEX_NONE; /* No clue why this special case */
	} else {
	    *indexPtr = (Tcl_Size) wide;
	}
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * GetEndOffsetFromObj --
 *
 *	Look for a string of the form "end[+-]offset" or "offset[+-]offset" and
 *	convert it to an internal representation.
 *
 *	The internal representation (wideValue) uses the following encoding:
 *
 *	WIDE_MIN:   Index value TCL_INDEX_NONE (or -1)
 *	WIDE_MIN+1: Index value n, for any n < -1  (usually same effect as -1)
 *	-$n:        Index "end-[expr {$n-1}]"
 *	-2:         Index "end-1"
 *	-1:         Index "end"
 *	0:          Index "0"
 *	WIDE_MAX-1: Index "end+n", for any n > 1. Distinguish from end+1 for
 *                  commands like lset.
 *	WIDE_MAX:   Index "end+1"
 *
 * Results:
 *	Tcl return code.
 *
 * Side effects:
 *	May store a Tcl_ObjType.
 *
 *----------------------------------------------------------------------
 */

static int
GetEndOffsetFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *objPtr,		/* Pointer to the object to parse */
    Tcl_WideInt endValue,	/* The value to be stored at "widePtr" if
				 * "objPtr" holds "end". */
    Tcl_WideInt *widePtr)	/* Location filled in with an integer
				 * representing an index. */
{
    Tcl_ObjInternalRep *irPtr;
    Tcl_WideInt offset = -1;	/* Offset in the "end-offset" expression - 1 */
    void *cd;

    while ((irPtr = TclFetchInternalRep(objPtr, &endOffsetType)) == NULL) {
	Tcl_ObjInternalRep ir;
	Tcl_Size length;
	const char *bytes = TclGetStringFromObj(objPtr, &length);

	if (*bytes != 'e') {
	    int numType;
	    const char *opPtr;
	    int t1 = 0, t2 = 0;

	    /* Value doesn't start with "e" */

	    /* If we reach here, the string rep of objPtr exists. */

	    /*
	     * The valid index syntax does not include any value that is
	     * a list of more than one element. This is necessary so that
	     * lists of index values can be reliably distinguished from any
	     * single index value.
	     */

	    /*
	     * Quick scan to see if multi-value list is even possible.
	     * This relies on TclGetString() returning a NUL-terminated string.
	     */
	    if ((TclMaxListLength(bytes, TCL_INDEX_NONE, NULL) > 1)
		    /* If it's possible, do the full list parse. */
		    && (TCL_OK == TclListObjLength(NULL, objPtr, &length))
		    && (length > 1)) {
		goto parseError;
	    }

	    /* Passed the list screen, so parse for index arithmetic expression */
	    if (TCL_OK == TclParseNumber(NULL, objPtr, NULL, NULL, TCL_INDEX_NONE, &opPtr,
		    TCL_PARSE_INTEGER_ONLY)) {
		Tcl_WideInt w1=0, w2=0;

		/* value starts with valid integer... */

		if ((*opPtr == '-') || (*opPtr == '+')) {
		    /* ... value continues with [-+] ... */

		    /* Save first integer as wide if possible */
		    Tcl_GetNumberFromObj(NULL, objPtr, &cd, &t1);
		    if (t1 == TCL_NUMBER_INT) {
			w1 = (*(Tcl_WideInt *)cd);
		    }

		    if (TCL_OK == TclParseNumber(NULL, objPtr, NULL, opPtr + 1,
			    TCL_INDEX_NONE, NULL, TCL_PARSE_INTEGER_ONLY)) {
			/* ... value concludes with second valid integer */

			/* Save second integer as wide if possible */
			Tcl_GetNumberFromObj(NULL, objPtr, &cd, &t2);
			if (t2 == TCL_NUMBER_INT) {
			    w2 = (*(Tcl_WideInt *)cd);
			}
		    }
		}
		/* Clear invalid internalreps left by TclParseNumber */
		TclFreeInternalRep(objPtr);

		if (t1 && t2) {
		    /* We have both integer values */
		    if ((t1 == TCL_NUMBER_INT) && (t2 == TCL_NUMBER_INT)) {
			/* Both are wide, do wide-integer math */
			if (*opPtr == '-') {
			    if (w2 == WIDE_MIN) {
				goto extreme;
			    }
			    w2 = -w2;
			}

			if ((w1 ^ w2) < 0) {
			    /* Different signs, sum cannot overflow */
			    offset = w1 + w2;
			} else if (w1 >= 0) {
			    if (w1 < WIDE_MAX - w2) {
				offset = w1 + w2;
			    } else {
				offset = WIDE_MAX;
			    }
			} else {
			    if (w1 > WIDE_MIN - w2) {
				offset = w1 + w2;
			    } else {
				offset = WIDE_MIN;
			    }
			}
		    } else {
			/*
			 * At least one is big, do bignum math. Little reason to
			 * value performance here. Re-use code.  Parse has verified
			 * objPtr is an expression. Compute it.
			 */

			Tcl_Obj *sum;

		    extreme:
			if (interp) {
			    Tcl_ExprObj(interp, objPtr, &sum);
			} else {
			    Tcl_Interp *compute = Tcl_CreateInterp();
			    Tcl_ExprObj(compute, objPtr, &sum);
			    Tcl_DeleteInterp(compute);
			}
			Tcl_GetNumberFromObj(NULL, sum, &cd, &numType);

			if (numType == TCL_NUMBER_INT) {
			    /* sum holds an integer in the signed wide range */
			    offset = *(Tcl_WideInt *)cd;
			} else {
			    /* sum holds an integer outside the signed wide range */
			    /* Truncate to the signed wide range. */
			    if (mp_isneg((mp_int *)cd)) {
				offset = WIDE_MIN;
			    } else {
				offset = WIDE_MAX;
			    }
			}
			Tcl_DecrRefCount(sum);
		    }
		    if (offset < 0) {
			offset = (offset == -1) ? WIDE_MIN : WIDE_MIN+1;
		    }
		    goto parseOK;
		}
	    }
	    goto parseError;
	}

	if ((length < 3) || (length == 4) || (strncmp(bytes, "end", 3) != 0)) {
	    /* Doesn't start with "end" */
	    goto parseError;
	}
	if (length > 4) {
	    int t;

	    /* Parse for the "end-..." or "end+..." formats */

	    if ((bytes[3] != '-') && (bytes[3] != '+')) {
		/* No operator where we need one */
		goto parseError;
	    }
	    if (TclIsSpaceProc(bytes[4])) {
		/* Space after + or - not permitted. */
		goto parseError;
	    }

	    /* Parse the integer offset */
	    if (TCL_OK != TclParseNumber(NULL, objPtr, NULL,
		    bytes + 4, length - 4, NULL, TCL_PARSE_INTEGER_ONLY)) {
		/* Not a recognized integer format */
		goto parseError;
	    }

	    /* Got an integer offset; pull it from where parser left it. */
	    Tcl_GetNumberFromObj(NULL, objPtr, &cd, &t);

	    if (t == TCL_NUMBER_BIG) {
		/* Truncate to the signed wide range. */
		if (mp_isneg((mp_int *)cd)) {
		    offset = (bytes[3] == '-') ? WIDE_MAX : WIDE_MIN;
		} else {
		    offset = (bytes[3] == '-') ? WIDE_MIN : WIDE_MAX;
		}
	    } else {
		/* assert (t == TCL_NUMBER_INT); */
		offset = (*(Tcl_WideInt *)cd);
		if (bytes[3] == '-') {
		    offset = (offset == WIDE_MIN) ? WIDE_MAX : -offset;
		}
		if (offset == 1) {
		    offset = WIDE_MAX; /* "end+1" */
		} else if (offset > 1) {
		    offset = WIDE_MAX - 1; /* "end+n", out of range */
		} else if (offset != WIDE_MIN) {
		    offset--;
		}
	    }
	}

    parseOK:
	/* Success. Store the new internal rep. */
	ir.wideValue = offset;
	Tcl_StoreInternalRep(objPtr, &endOffsetType, &ir);
    }

    offset = irPtr->wideValue;

    if (offset == WIDE_MAX) {
	/*
	 * Encodes end+1. This is distinguished from end+n as noted
	 * in function header.
	 * NOTE: this may wrap around if the caller passes (as lset does)
	 * listLen-1 as endValue and listLen is 0. The -1 will be
	 * interpreted as FF...FF and adding 1 will result in 0 which
	 * is what we want. Callers like lset which pass in listLen-1 == -1
	 * as endValue will have to adjust accordingly.
	 */
	*widePtr = (endValue == -1) ? WIDE_MAX : endValue + 1;
    } else if (offset == WIDE_MIN) {
	*widePtr = (endValue == -1) ? WIDE_MIN : -1;
    } else if (offset < 0) {
	/* end-(n-1) - Different signs, sum cannot overflow */
	*widePtr = endValue + offset + 1;
    } else {
	/* 0:WIDE_MAX - plain old index. */
	*widePtr = offset;
    }
    return TCL_OK;

    /* Report a parse error. */
  parseError:
    if (interp != NULL) {
	char * bytes = TclGetString(objPtr);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"bad index \"%s\": must be integer?[+-]integer? or"
		" end?[+-]integer?", bytes));
	if (!strncmp(bytes, "end-", 4)) {
	    bytes += 4;
	}
	Tcl_SetErrorCode(interp, "TCL", "VALUE", "INDEX", (char *)NULL);
    }

    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * TclIndexEncode --
 *      IMPORTANT: function only encodes indices in the range that fits within
 *      an "int" type. Do NOT change this as the byte code compiler and engine
 *      which call this function cannot handle wider index types. Indices
 *      outside the range will result in the function returning an error.
 *
 *      Parse objPtr to determine if it is an index value. Two cases
 *	are possible.  The value objPtr might be parsed as an absolute
 *	index value in the Tcl_Size range.  Note that this includes
 *	index values that are integers as presented and it includes index
 *      arithmetic expressions.
 *
 *      The largest string supported in Tcl 8 has byte length TCL_SIZE_MAX.
 *      This means the largest supported character length is also TCL_SIZE_MAX,
 *      and the index of the last character in a string of length TCL_SIZE_MAX
 *      is TCL_SIZE_MAX-1. Thus the absolute index values that can be
 *	directly meaningful as an index into either a list or a string are
 *	integer values in the range 0 to TCL_SIZE_MAX - 1.
 *
 *      This function however can only handle integer indices in the range
 *      0 : INT_MAX-1.
 *
 *      Any absolute index value parsed outside that range is encoded
 *      using the before and after values passed in by the
 *      caller as the encoding to use for indices that are either
 *      less than or greater than the usable index range. TCL_INDEX_NONE
 *      is available as a good choice for most callers to use for
 *      after. Likewise, the value TCL_INDEX_NONE is good for
 *      most callers to use for before.  Other values are possible
 *      when the caller knows it is helpful in producing its own behavior
 *      for indices before and after the indexed item.
 *
 *      A token can also be parsed as an end-relative index expression.
 *      All end-relative expressions that indicate an index larger
 *      than end (end+2, end--5) point beyond the end of the indexed
 *      collection, and can be encoded as after.  The end-relative
 *      expressions that indicate an index less than or equal to end
 *      are encoded relative to the value TCL_INDEX_END (-2).  The
 *      index "end" is encoded as -2, down to the index "end-0x7FFFFFFE"
 *      which is encoded as INT_MIN. Since the largest index into a
 *      string possible in Tcl 8 is 0x7FFFFFFE, the interpretation of
 *      "end-0x7FFFFFFE" for that largest string would be 0.  Thus,
 *      if the tokens "end-0x7FFFFFFF" or "end+-0x80000000" are parsed,
 *      they can be encoded with the before value.
 *
 * Returns:
 *      TCL_OK if parsing succeeded, and TCL_ERROR if it failed or the
 *      index does not fit in an int type.
 *
 * Side effects:
 *      When TCL_OK is returned, the encoded index value is written
 *      to *indexPtr.
 *
 *----------------------------------------------------------------------
 */

int
TclIndexEncode(
    Tcl_Interp *interp,		/* For error reporting, may be NULL */
    Tcl_Obj *objPtr,		/* Index value to parse */
    int before,			/* Value to return for index before beginning */
    int after,			/* Value to return for index after end */
    int *indexPtr)		/* Where to write the encoded answer, not NULL */
{
    Tcl_WideInt wide;
    int idx;
    const Tcl_WideInt ENDVALUE = 2 * (Tcl_WideInt) INT_MAX;

    assert(ENDVALUE < WIDE_MAX);
    if (TCL_OK != GetWideForIndex(interp, objPtr, ENDVALUE, &wide)) {
	return TCL_ERROR;
    }
    /*
     * We passed 2*INT_MAX as the "end value" to GetWideForIndex. The computed
     * index will be in one of the following ranges that need to be
     * distinguished for encoding purposes in the following code.
     * (1) 0:INT_MAX when
     *     (a) objPtr was a pure non-negative numeric value in that range
     *     (b) objPtr was a numeric computation M+/-N with a result in that range
     *     (c) objPtr was of the form end-N where N was in range INT_MAX:2*INT_MAX
     * (2) INT_MAX+1:2*INT_MAX when
     *     (a,b) as above
     *     (c) objPtr was of the form end-N where N was in range 0:INT_MAX-1
     * (3) 2*INT_MAX:WIDE_MAX when
     *     (a,b) as above
     *     (c) objPtr was of the form end+N
     * (4) (2*INT_MAX)-TCL_SIZE_MAX : -1 when
     *     (a,b) as above
     *     (c) objPtr was of the form end-N where N was in the range 0:TCL_SIZE_MAX
     * (5) WIDE_MIN:(2*INT_MAX)-TCL_SIZE_MAX
     *     (a,b) as above
     *     (c) objPtr was of the form end-N where N was > TCL_SIZE_MAX
     *
     * For all cases (b) and (c), the internal representation of objPtr
     * will be shimmered to endOffsetType. That allows us to distinguish between
     * (for example) 1a (encodable) and 1c (not encodable) though the computed
     * index value is the same.
     *
     * Further note, the values TCL_SIZE_MAX < N < WIDE_MAX come into play
     * only in the 32-bit builds as TCL_SIZE_MAX == WIDE_MAX for 64-bits.
     */

    const Tcl_ObjInternalRep *irPtr =
	TclFetchInternalRep(objPtr, &endOffsetType);

    if (irPtr && irPtr->wideValue >= 0) {
	/*
	 * "int[+-]int" syntax, works the same here as "int".
	 * Note same does not hold for negative integers.
	 * Distinguishes 1b and 1c where wide will be in 0:INT_MAX for
	 * both but irPtr->wideValue will be negative for 1c.
	 */
	irPtr = NULL;
    }

    if (irPtr == NULL) {
	/* objPtr can be treated as a purely numeric value. */

	/*
	 * On 64-bit systems, indices in the range INT_MAX:TCL_SIZE_MAX are
	 * valid indices but are not in the encodable range. Thus an
	 * error is raised. On 32-bit systems, indices in that range indicate
	 * the position after the end and so do not raise an error.
	 */
	if ((sizeof(int) != sizeof(Tcl_Size)) &&
		(wide > INT_MAX) && (wide < WIDE_MAX-1)) {
	    /* 2(a,b) on 64-bit systems*/
	    goto rangeerror;
	}
	if (wide > INT_MAX) {
	    /*
	     * 3(a,b) on 64-bit systems and 2(a,b), 3(a,b) on 32-bit systems
	     * Because of the check above, this case holds for indices
	     * greater than INT_MAX on 32-bit systems and > TCL_SIZE_MAX
	     * on 64-bit systems. Always maps to the element after the end.
	     */
	    idx = after;
	} else if (wide < 0) {
	    /* 4(a,b) (32-bit systems), 5(a,b) - before the beginning */
	    idx = before;
	} else {
	    /* 1(a,b) Encodable range */
	    idx = (int)wide;
	}
    } else {
	/* objPtr is not purely numeric (end etc.) */

	/*
	 * On 64-bit systems, indices in the range end-LIST_MAX:end-INT_MAX
	 * are valid indices (with max size strings/lists) but are not in
	 * the encodable range. Thus an error is raised. On 32-bit systems,
	 * indices in that range indicate the position before the beginning
	 * and so do not raise an error.
	 */
	if ((sizeof(int) != sizeof(Tcl_Size)) &&
		(wide > (ENDVALUE - LIST_MAX)) && (wide <= INT_MAX)) {
	    /* 1(c), 4(a,b) on 64-bit systems */
	    goto rangeerror;
	}
	if (wide > ENDVALUE) {
	    /*
	     * 2(c) (32-bit systems), 3(c)
	     * All end+positive or end-negative expressions
	     * always indicate "after the end".
	     * Note we will not reach here for a pure numeric value in this
	     * range because irPtr will be NULL in that case.
	     */
	    idx = after;
	} else if (wide <= INT_MAX) {
	    /* 1(c) (32-bit systems), 4(c) (32-bit systems), 5(c) */
	    idx = before;
	} else {
	    /* 2(c) Encodable end-positive (or end+negative) */
	    idx = (int)wide;
	}
    }
    *indexPtr = idx;
    return TCL_OK;

rangeerror:
    if (interp) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf("index \"%s\" out of range", TclGetString(objPtr)));
	Tcl_SetErrorCode(interp, "TCL", "VALUE", "INDEX", "OUTOFRANGE", (char *)NULL);
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * TclIndexDecode --
 *
 *	Decodes a value previously encoded by TclIndexEncode.  The argument
 *	endValue indicates what value of "end" should be used in the
 *	decoding.
 *
 * Results:
 *	The decoded index value.
 *
 *----------------------------------------------------------------------
 */

Tcl_Size
TclIndexDecode(
    int encoded,		/* Value to decode */
    Tcl_Size endValue)		/* Meaning of "end" to use, > TCL_INDEX_END */
{
    if (encoded > TCL_INDEX_END) {
	return encoded;
    }
    endValue += encoded - TCL_INDEX_END;
    if (endValue >= 0) {
	return endValue;
    }
    return TCL_INDEX_NONE;
}

/*
 *------------------------------------------------------------------------
 *
 * TclCommandWordLimitErrpr --
 *
 *    Generates an error message limit on number of command words exceeded.
 *
 * Results:
 *    Always return TCL_ERROR.
 *
 * Side effects:
 *    If interp is not-NULL, an error message is stored in it.
 *
 *------------------------------------------------------------------------
 */
int
TclCommandWordLimitError(
    Tcl_Interp *interp,		/* May be NULL */
    Tcl_Size count)		/* If <= 0, "unknown" */
{
    if (interp) {
	if (count > 0) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "Number of words (%" TCL_SIZE_MODIFIER
		    "d) in command exceeds limit %" TCL_SIZE_MODIFIER "d.",
		    count, (Tcl_Size)INT_MAX));
	} else {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "Number of words in command exceeds limit %"
		    TCL_SIZE_MODIFIER "d.",
		    (Tcl_Size)INT_MAX));
	}
    }
    return TCL_ERROR; /* Always */
}

/*
 *----------------------------------------------------------------------
 *
 * ClearHash --
 *
 *	Remove all the entries in the hash table *tablePtr.
 *
 *----------------------------------------------------------------------
 */

static void
ClearHash(
    Tcl_HashTable *tablePtr)
{
    Tcl_HashSearch search;
    Tcl_HashEntry *hPtr;

    for (hPtr = Tcl_FirstHashEntry(tablePtr, &search); hPtr != NULL;
	    hPtr = Tcl_NextHashEntry(&search)) {
	Tcl_Obj *objPtr = (Tcl_Obj *)Tcl_GetHashValue(hPtr);

	Tcl_DecrRefCount(objPtr);
	Tcl_DeleteHashEntry(hPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * GetThreadHash --
 *
 *	Get a thread-specific (Tcl_HashTable *) associated with a thread data
 *	key.
 *
 * Results:
 *	The Tcl_HashTable * corresponding to *keyPtr.
 *
 * Side effects:
 *	The first call on a keyPtr in each thread creates a new Tcl_HashTable,
 *	and registers a thread exit handler to dispose of it.
 *
 *----------------------------------------------------------------------
 */

static Tcl_HashTable *
GetThreadHash(
    Tcl_ThreadDataKey *keyPtr)
{
    Tcl_HashTable **tablePtrPtr =
	    (Tcl_HashTable **)Tcl_GetThreadData(keyPtr, sizeof(Tcl_HashTable *));

    if (NULL == *tablePtrPtr) {
	*tablePtrPtr = (Tcl_HashTable *)Tcl_Alloc(sizeof(Tcl_HashTable));
	Tcl_CreateThreadExitHandler(FreeThreadHash, *tablePtrPtr);
	Tcl_InitHashTable(*tablePtrPtr, TCL_ONE_WORD_KEYS);
    }
    return *tablePtrPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * FreeThreadHash --
 *
 *	Thread exit handler used by GetThreadHash to dispose of a thread hash
 *	table.
 *
 * Side effects:
 *	Frees a Tcl_HashTable.
 *
 *----------------------------------------------------------------------
 */

static void
FreeThreadHash(
    void *clientData)
{
    Tcl_HashTable *tablePtr = (Tcl_HashTable *)clientData;

    ClearHash(tablePtr);
    Tcl_DeleteHashTable(tablePtr);
    Tcl_Free(tablePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * FreeProcessGlobalValue --
 *
 *	Exit handler used by Tcl(Set|Get)ProcessGlobalValue to cleanup a
 *	ProcessGlobalValue at exit.
 *
 *----------------------------------------------------------------------
 */

static void
FreeProcessGlobalValue(
    void *clientData)
{
    ProcessGlobalValue *pgvPtr = (ProcessGlobalValue *)clientData;

    pgvPtr->epoch++;
    pgvPtr->numBytes = 0;
    Tcl_Free(pgvPtr->value);
    pgvPtr->value = NULL;
    if (pgvPtr->encoding) {
	Tcl_FreeEncoding(pgvPtr->encoding);
	pgvPtr->encoding = NULL;
    }
    Tcl_MutexFinalize(&pgvPtr->mutex);
}

/*
 *----------------------------------------------------------------------
 *
 * TclSetProcessGlobalValue --
 *
 *	Utility routine to set a global value shared by all threads in the
 *	process while keeping a thread-local copy as well.
 *
 *----------------------------------------------------------------------
 */

void
TclSetProcessGlobalValue(
    ProcessGlobalValue *pgvPtr,
    Tcl_Obj *newValue)
{
    const char *bytes;
    Tcl_HashTable *cacheMap;
    Tcl_HashEntry *hPtr;
    int dummy;
    Tcl_DString ds;

    Tcl_MutexLock(&pgvPtr->mutex);

    /*
     * Fill the global string value.
     */

    pgvPtr->epoch++;
    if (NULL != pgvPtr->value) {
	Tcl_Free(pgvPtr->value);
    } else {
	Tcl_CreateExitHandler(FreeProcessGlobalValue, pgvPtr);
    }
    bytes = TclGetString(newValue);
    pgvPtr->numBytes = newValue->length;
    Tcl_UtfToExternalDStringEx(NULL, NULL, bytes, pgvPtr->numBytes,
	    TCL_ENCODING_PROFILE_TCL8, &ds, NULL);
    pgvPtr->numBytes = Tcl_DStringLength(&ds);
    pgvPtr->value = (char *)Tcl_Alloc(pgvPtr->numBytes + 1);
    memcpy(pgvPtr->value, Tcl_DStringValue(&ds), pgvPtr->numBytes + 1);
    Tcl_DStringFree(&ds);
    if (pgvPtr->encoding) {
	Tcl_FreeEncoding(pgvPtr->encoding);
    }
    pgvPtr->encoding = NULL;

    /*
     * Fill the local thread copy directly with the Tcl_Obj value to avoid
     * loss of the internalrep. Increment newValue refCount early to handle case
     * where we set a PGV to itself.
     */

    Tcl_IncrRefCount(newValue);
    cacheMap = GetThreadHash(&pgvPtr->key);
    ClearHash(cacheMap);
    hPtr = Tcl_CreateHashEntry(cacheMap, INT2PTR(pgvPtr->epoch), &dummy);
    Tcl_SetHashValue(hPtr, newValue);
    Tcl_MutexUnlock(&pgvPtr->mutex);
}

/*
 *----------------------------------------------------------------------
 *
 * TclGetProcessGlobalValue --
 *
 *	Retrieve a global value shared among all threads of the process,
 *	preferring a thread-local copy as long as it remains valid.
 *
 * Results:
 *	Returns a (Tcl_Obj *) that holds a copy of the global value.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclGetProcessGlobalValue(
    ProcessGlobalValue *pgvPtr)
{
    Tcl_Obj *value = NULL;
    Tcl_HashTable *cacheMap;
    Tcl_HashEntry *hPtr;
    Tcl_Size epoch = pgvPtr->epoch;
    Tcl_DString newValue;

    if (pgvPtr->encoding) {
	Tcl_Encoding current = Tcl_GetEncoding(NULL, NULL);

	if (pgvPtr->encoding != current) {
	    /*
	     * The system encoding has changed since the global string value
	     * was saved. Convert the global value to be based on the new
	     * system encoding.
	     */

	    Tcl_DString native;

	    Tcl_MutexLock(&pgvPtr->mutex);
	    epoch = ++pgvPtr->epoch;
	    Tcl_UtfToExternalDStringEx(NULL, pgvPtr->encoding, pgvPtr->value,
		pgvPtr->numBytes, TCL_ENCODING_PROFILE_TCL8, &native, NULL);
	    Tcl_ExternalToUtfDStringEx(NULL, current, Tcl_DStringValue(&native),
		Tcl_DStringLength(&native), TCL_ENCODING_PROFILE_TCL8,
		&newValue, NULL);
	    Tcl_DStringFree(&native);
	    Tcl_Free(pgvPtr->value);
	    pgvPtr->value = (char *)Tcl_Alloc(Tcl_DStringLength(&newValue) + 1);
	    memcpy(pgvPtr->value, Tcl_DStringValue(&newValue),
		    Tcl_DStringLength(&newValue) + 1);
	    Tcl_DStringFree(&newValue);
	    Tcl_FreeEncoding(pgvPtr->encoding);
	    pgvPtr->encoding = current;
	    Tcl_MutexUnlock(&pgvPtr->mutex);
	} else {
	    Tcl_FreeEncoding(current);
	}
    }
    cacheMap = GetThreadHash(&pgvPtr->key);
    hPtr = Tcl_FindHashEntry(cacheMap, INT2PTR(epoch));
    if (NULL == hPtr) {
	int dummy;

	/*
	 * No cache for the current epoch - must be a new one.
	 *
	 * First, clear the cacheMap, as anything in it must refer to some
	 * expired epoch.
	 */

	ClearHash(cacheMap);

	/*
	 * If no thread has set the shared value, call the initializer.
	 */

	Tcl_MutexLock(&pgvPtr->mutex);
	if ((NULL == pgvPtr->value) && (pgvPtr->proc)) {
	    pgvPtr->epoch++;
	    pgvPtr->proc(&pgvPtr->value,&pgvPtr->numBytes,&pgvPtr->encoding);
	    if (pgvPtr->value == NULL) {
		Tcl_Panic("PGV Initializer did not initialize");
	    }
	    Tcl_CreateExitHandler(FreeProcessGlobalValue, pgvPtr);
	}

	/*
	 * Store a copy of the shared value (but then in utf-8)
	 * in our epoch-indexed cache.
	 */

	Tcl_ExternalToUtfDString(NULL, pgvPtr->value, pgvPtr->numBytes, &newValue);
	value = Tcl_DStringToObj(&newValue);
	hPtr = Tcl_CreateHashEntry(cacheMap,
		INT2PTR(pgvPtr->epoch), &dummy);
	Tcl_MutexUnlock(&pgvPtr->mutex);
	Tcl_SetHashValue(hPtr, value);
	Tcl_IncrRefCount(value);
    }
    return (Tcl_Obj *)Tcl_GetHashValue(hPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * TclSetObjNameOfExecutable --
 *
 *	This function stores the absolute pathname of the executable file
 *	(normally as computed by TclpFindExecutable).
 *
 *	Starting with Tcl 9.0, encoding parameter is not used any more.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores the executable name.
 *
 *----------------------------------------------------------------------
 */

void
TclSetObjNameOfExecutable(
    Tcl_Obj *name,
    TCL_UNUSED(Tcl_Encoding))
{
    TclSetProcessGlobalValue(&executableName, name);
}

/*
 *----------------------------------------------------------------------
 *
 * TclGetObjNameOfExecutable --
 *
 *	This function retrieves the absolute pathname of the application in
 *	which the Tcl library is running, usually as previously stored by
 *	TclpFindExecutable(). This function call is the C API equivalent to
 *	the "info nameofexecutable" command.
 *
 * Results:
 *	A pointer to an "fsPath" Tcl_Obj, or to an empty Tcl_Obj if the
 *	pathname of the application is unknown.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclGetObjNameOfExecutable(void)
{
    return TclGetProcessGlobalValue(&executableName);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetNameOfExecutable --
 *
 *	This function retrieves the absolute pathname of the application in
 *	which the Tcl library is running, and returns it in string form.
 *
 *	The returned string belongs to Tcl and should be copied if the caller
 *	plans to keep it, to guard against it becoming invalid.
 *
 * Results:
 *	A pointer to the internal string or NULL if the internal full path
 *	name has not been computed or unknown.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

const char *
Tcl_GetNameOfExecutable(void)
{
    Tcl_Obj *obj = TclGetObjNameOfExecutable();
    const char *bytes = TclGetString(obj);

    if (obj->length == 0) {
	return NULL;
    }
    return bytes;
}

#if !defined(STATIC_BUILD)
/*
 * TclSetObjNameOfShlib --
 *
 *	This function stores the absolute pathname of the Tcl shared library.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores the shared library name in the process global database.
 */

void
TclSetObjNameOfShlib(
    Tcl_Obj *name,
    TCL_UNUSED(Tcl_Encoding))
{
    TclSetProcessGlobalValue(&shlibName, name);
}

/*
 *----------------------------------------------------------------------
 *
 * TclGetObjNameOfShlib --
 *
 *	This function retrieves the absolute pathname of the Tcl shared
 *	library.
 *
 * Results:
 *	A pointer to an "fsPath" Tcl_Obj, or to an empty Tcl_Obj if the
 *	pathname of the shared library is unknown.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclGetObjNameOfShlib(void)
{
    return TclGetProcessGlobalValue(&shlibName);
}

#endif /* !STATIC_BUILD - Tcl{Get,Set}NameOfShlib */
/*
 *----------------------------------------------------------------------
 *
 * TclGetPlatform --
 *
 *	This is a kludge that allows the test library to get access the
 *	internal tclPlatform variable.
 *
 * Results:
 *	Returns a pointer to the tclPlatform variable.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TclPlatformType *
TclGetPlatform(void)
{
    return &tclPlatform;
}

/*
 *----------------------------------------------------------------------
 *
 * TclReToGlob --
 *
 *	Attempt to convert a regular expression to an equivalent glob pattern.
 *
 * Results:
 *	Returns TCL_OK on success, TCL_ERROR on failure. If interp is not
 *	NULL, an error message is placed in the result. On success, the
 *	DString will contain an exact equivalent glob pattern. The caller is
 *	responsible for calling Tcl_DStringFree on success. If exactPtr is not
 *	NULL, it will be 1 if an exact match qualifies.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclReToGlob(
    Tcl_Interp *interp,
    const char *reStr,
    Tcl_Size reStrLen,
    Tcl_DString *dsPtr,
    int *exactPtr,
    int *quantifiersFoundPtr)
{
    int anchorLeft, anchorRight, lastIsStar, numStars;
    char *dsStr, *dsStrStart;
    const char *msg, *p, *strEnd, *code;

    strEnd = reStr + reStrLen;
    Tcl_DStringInit(dsPtr);
    if (quantifiersFoundPtr != NULL) {
	*quantifiersFoundPtr = 0;
    }

    /*
     * "***=xxx" == "*xxx*", watch for glob-sensitive chars.
     */

    if ((reStrLen >= 4) && (memcmp("***=", reStr, 4) == 0)) {
	/*
	 * At most, the glob pattern has length 2*reStrLen + 2 to backslash
	 * escape every character and have * at each end.
	 */

	Tcl_DStringSetLength(dsPtr, reStrLen + 2);
	dsStr = dsStrStart = Tcl_DStringValue(dsPtr);
	*dsStr++ = '*';
	for (p = reStr + 4; p < strEnd; p++) {
	    switch (*p) {
	    case '\\': case '*': case '[': case ']': case '?':
		/* Only add \ where necessary for glob */
		*dsStr++ = '\\';
		TCL_FALLTHROUGH();
	    default:
		*dsStr++ = *p;
		break;
	    }
	}
	*dsStr++ = '*';
	Tcl_DStringSetLength(dsPtr, dsStr - dsStrStart);
	if (exactPtr) {
	    *exactPtr = 0;
	}
	return TCL_OK;
    }

    /*
     * At most, the glob pattern has length reStrLen + 2 to account for
     * possible * at each end.
     */

    Tcl_DStringSetLength(dsPtr, reStrLen + 2);
    dsStr = dsStrStart = Tcl_DStringValue(dsPtr);

    /*
     * Check for anchored REs (ie ^foo$), so we can use string equal if
     * possible. Do not alter the start of str so we can free it correctly.
     *
     * Keep track of the last char being an unescaped star to prevent multiple
     * instances.  Simpler than checking that the last star may be escaped.
     */

    msg = NULL;
    code = NULL;
    p = reStr;
    anchorRight = 0;
    lastIsStar = 0;
    numStars = 0;

    if (*p == '^') {
	anchorLeft = 1;
	p++;
    } else {
	anchorLeft = 0;
	*dsStr++ = '*';
	lastIsStar = 1;
    }

    for ( ; p < strEnd; p++) {
	switch (*p) {
	case '\\':
	    p++;
	    switch (*p) {
	    case 'a':
		*dsStr++ = '\a';
		break;
	    case 'b':
		*dsStr++ = '\b';
		break;
	    case 'f':
		*dsStr++ = '\f';
		break;
	    case 'n':
		*dsStr++ = '\n';
		break;
	    case 'r':
		*dsStr++ = '\r';
		break;
	    case 't':
		*dsStr++ = '\t';
		break;
	    case 'v':
		*dsStr++ = '\v';
		break;
	    case 'B': case '\\':
		*dsStr++ = '\\';
		*dsStr++ = '\\';
		anchorLeft = 0; /* prevent exact match */
		break;
	    case '*': case '[': case ']': case '?':
		/* Only add \ where necessary for glob */
		*dsStr++ = '\\';
		anchorLeft = 0; /* prevent exact match */
		TCL_FALLTHROUGH();
	    case '{': case '}': case '(': case ')': case '+':
	    case '.': case '|': case '^': case '$':
		*dsStr++ = *p;
		break;
	    default:
		msg = "invalid escape sequence";
		code = "BADESCAPE";
		goto invalidGlob;
	    }
	    break;
	case '.':
	    if (quantifiersFoundPtr != NULL) {
		*quantifiersFoundPtr = 1;
	    }
	    anchorLeft = 0; /* prevent exact match */
	    if (p+1 < strEnd) {
		if (p[1] == '*') {
		    p++;
		    if (!lastIsStar) {
			*dsStr++ = '*';
			lastIsStar = 1;
			numStars++;
		    }
		    continue;
		} else if (p[1] == '+') {
		    p++;
		    *dsStr++ = '?';
		    *dsStr++ = '*';
		    lastIsStar = 1;
		    numStars++;
		    continue;
		}
	    }
	    *dsStr++ = '?';
	    break;
	case '$':
	    if (p+1 != strEnd) {
		msg = "$ not anchor";
		code = "NONANCHOR";
		goto invalidGlob;
	    }
	    anchorRight = 1;
	    break;
	case '*': case '+': case '?': case '|': case '^':
	case '{': case '}': case '(': case ')': case '[': case ']':
	    msg = "unhandled RE special char";
	    code = "UNHANDLED";
	    goto invalidGlob;
	default:
	    *dsStr++ = *p;
	    break;
	}
	lastIsStar = 0;
    }
    if (numStars > 1) {
	/*
	 * Heuristic: if >1 non-anchoring *, the risk is large that glob
	 * matching is slower than the RE engine, so report invalid.
	 */

	msg = "excessive recursive glob backtrack potential";
	code = "OVERCOMPLEX";
	goto invalidGlob;
    }

    if (!anchorRight && !lastIsStar) {
	*dsStr++ = '*';
    }
    Tcl_DStringSetLength(dsPtr, dsStr - dsStrStart);

    if (exactPtr) {
	*exactPtr = (anchorLeft && anchorRight);
    }

    return TCL_OK;

  invalidGlob:
    if (interp != NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(msg, -1));
	Tcl_SetErrorCode(interp, "TCL", "RE2GLOB", code, (char *)NULL);
    }
    Tcl_DStringFree(dsPtr);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * TclMSB --
 *
 *	Given a unsigned long long non-zero value n, return the index of
 *	the most significant bit in n that is set.  This is equivalent to
 *	returning trunc(log2(n)).  It's also equivalent to the largest
 *	integer k such that 2^k <= n.
 *
 *	This routine is adapted from Andrej Brodnik, "Computation of the
 *	Least Significant Set Bit", pp 7-10, Proceedings of the 2nd
 *	Electrotechnical and Computer Science Conference, Portoroz,
 *	Slovenia, 1993.  The adaptations permit the computation to take
 *	place within unsigned long long values without the need for double
 *	length	buffers for calculation.  They also fill in a number of
 *	details the paper omits or leaves unclear.
 *
 * Results:
 *	The index of the most significant set bit in n, a value between
 *	0 and 63, inclusive.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclMSB(
    unsigned long long n)
{
    /* assert ( 64 == CHAR_BIT * sizeof(unsigned long long) ); */
    /* assert ( n != 0 ); */

    /*
     * Many platforms offer access to this functionality through
     * compiler specific incantations that exploit processor
     * instructions.  Add more as appropriate.
     */

#if defined(_MSC_VER) && defined(_WIN64)
	unsigned long result;

	(void) _BitScanReverse64(&result, (unsigned __int64)n);
	return (int)result;

#elif defined(__GNUC__) && ((__GNUC__ > 3) || (__GNUC__ == 3 && __GNUC_MINOR__ >= 4))

	/*
	 * The GNU Compiler Collection offers this builtin routine
	 * starting with version 3.4, released 2004.
	 * clzll() = Count of Leading Zeroes in a Long Long
	 * NOTE: we rely on input constraint (n != 0).
	 */

	return 63 - __builtin_clzll(n);

#else

	/*
	 * For a byte, consider two masks, C1 = 10000000 selecting just
	 * the high bit, and C2 = 01111111 selecting all other bits.
	 * Then for any byte value n, the computation
	 *	LEAD(n) = C1 & (n | (C2 + (n & C2)))
	 * will leave all bits but the high bit unset, and will have the
	 * high bit set iff n!=0.  The whole thing is an 8-bit test
	 * for being non-zero.  For an 8-byte n, each byte can have
	 * the test applied all at once, with combined masks.
	 */
	const unsigned long long C1 = 0x8080808080808080;
	const unsigned long long C2 = 0x7F7F7F7F7F7F7F7F;
#define LEAD(n) (C1 & (n | (C2 + (n & C2))))

	/*
	 * To shift a bit to a new place, multiplication by 2^k will do.
	 * To shift the top 7 bits produced by the LEAD test to the high
	 * 7 bits of the entire long long, multiply by the right sum of
	 * powers of 2.  In this case
	 * Q = 1 + 2^7 + 2^14 + 2^21 + 2^28 + 2^35 + 2^42
	 * Then shift those 7 bits down to the low 7 bits of the long long.
	 * The key to making this work is that none of the shifted bits
	 * collide with each other in the top 7-bit destination.
	 * Note that we lose the bit that indicates whether the low byte
	 * is non-zero.  That doesn't matter because we require the original
	 * value n to be non-zero, so if all other bytes signal to be zero,
	 * we know the low byte is non-zero, and if one of the other bytes
	 * signals non-zero, we just don't care what the low byte is.
	 */
	const unsigned long long Q = 0x0000040810204081;

	/*
	 * To place a copy of a 7-bit value in each of 7 bytes in
	 * a long long, just multply by the right value.  In this case
	 *  P = 0x00 01 01 01 01 01 01 01
	 * We don't put a copy in the high byte since analysis of the
	 * remaining steps in the algorithm indicates we do not need it.
	 */
	const unsigned long long P = 0x0001010101010101;

	/*
	 * With 7 copies of the LEAD value, we can now apply 7 masks
	 * to it in a single step by an & against the right value.
	 * B =	00000000 01111111 01111110 01111100
	 *	01111000 01110000 01100000 01000000
	 * The higher the MSB of the copied value is, the more of the
	 * B-masked bytes stored in t will be non-zero.
	 */
	const unsigned long long B = 0x007F7E7C78706040;
	unsigned long long t = B & P * (LEAD(n) * Q >> 57);

	/*
	 * We want to get a count of the non-zero bytes stored in t.
	 * First use LEAD(t) to create a set of high bits signaling
	 * non-zero values as before.  Call this value
	 * X = x6*2^55 +x5*2^47 +x4*2^39 +x3*2^31 +x2*2^23 +x1*2^15 +x0*2^7
	 * Then notice what multiplication by
	 * P =    2^48 +   2^40 +   2^32 +   2^24 +   2^16 +   2^8 + 1
	 * produces:
	 * P*X = x0*2^7 + (x0 + x1)*2^15 + ...
	 *       ... + (x0 + x1 + x2 + x3 + x4 + x5 + x6) * 2^55 + ...
	 *	 ... + (x5 + x6)*2^95 + x6*2^103
	 * The high terms of this product are going to overflow the long long
	 * and get lost, but we don't care about them.  What we care is that
	 * the 2^55 term is exactly the sum we seek.  We shift the product
	 * down by 55 bits and then mask away all but the bottom 3 bits
	 * (Max sum can be 7) we get exactly the count of non-zero B-masked
	 * bytes.  By design of the mask, this count is the index of the
	 * MSB of the LEAD value.  It indicates which byte of the original
	 * value contains the MSB of the original value.
	 */
#define SUM(t) (0x7 & (int)(LEAD(t) * P >> 55));

	/*
	 * Multiply by 8 to get the number of bits to shift to place
	 * that MSB-containing byte in the low byte.
	 */
	int k = 8 * SUM(t);

	/*
	 * Shift the MSB byte to the low byte.  Then shift one more bit.
	 * Since we know the MSB byte is non-zero we only need to compute
	 * the MSB of the top 7 bits.  If all top 7 bits are zero, we know
	 * the bottom bit is the 1 and the correct index is 0.  Compute the
	 * MSB of that value by the same steps we did before.
	 */
	t = B & P * (n >> k >> 1);

	/*
	 * Add the index of the MSB of the byte to the index of the low
	 * bit of that byte computed before to get the final answer.
	 */
	return k + SUM(t);

	/* Total operations: 33
	 * 10 bit-ands, 6 multiplies, 4 adds, 5 rightshifts,
	 * 3 assignments, 3 bit-ors, 2 typecasts.
	 *
	 * The whole task is one direct computation.
	 * No branches. No loops.
	 *
	 * 33 operations cannot beat one instruction, so assembly
	 * wins and should be used wherever possible, but this isn't bad.
	 */

#undef SUM
#undef LEAD
#endif
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
