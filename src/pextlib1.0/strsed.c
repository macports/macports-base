/*
 * Strsed.c
 *
 *     ed(1)/tr(1)-like search, replace, transliterate. See the
 *     manpage for details. See the README for copyright information.
 *
 * Usage:
 *
 *        strsed(string, pattern, 0);
 *        char *string;
 *        char *pattern;
 * or
 *        strsed(string, pattern, range);
 *        char *string;
 *        char *pattern;
 *        int  range[2];
 *
 *
 * Terry Jones    
 * terry@distel.pcs.com
 * ...!{pyramid,unido}!pcsbst!distel!terry
 *
 * PCS Computer Systeme GmbH
 * Pfaelzer-Wald-Str 36
 * 8000 Muenchen 90
 * West Germany       49-89-68004288
 *
 * January 8th, 1990.
 *
 */

/*
 * strsed.c,v $
 *
 * Revision 2.4  90/04/19  15:40:38  terry
 * Made it possible to use any delimiter. E.g. s/ex/on/ is the same as
 * s.ex.on.
 * Fixed trailing backslash bugger. Made range always contain something
 * after search and replace to indicate if a substitute actually occurred.
 * 
 * Revision 2.3  90/04/17  19:36:12  terry
 * Made realloc ok too....
 * 
 * Revision 2.2  90/04/17  19:27:02  terry
 * Did things to make malloc() and free() calls more portable.
 * 
 * Revision 2.1  90/04/15  18:06:09  terry
 * Added changes suggested by John B. Thiel. Added empty regs and empty
 * regexp structs.
 * 
 * Revision 2.0  90/04/09  16:06:19  terry
 * Added dollops of #ifdef's to deal with Henry Spencer or
 * GNU regex packages. Also added optimisation that saves the
 * last compiled pattern. All seems to work fine except the
 * register reference inside a regex with the HS stuff.
 * 
 * Revision 1.19  90/04/09  11:57:01  terry
 * little things.
 * 
 * Revision 1.17  90/03/08  20:44:32  terry
 * Final cleanup.
 * 
 * Revision 1.16  90/03/07  15:46:35  terry
 * Changed backslash_eliminate to only malloc on 
 * REPLACEMENT type. Added ".*" optimisation so that
 * the regex functions are never called.
 * 
 * Revision 1.15  90/03/06  22:27:49  terry
 * Removed varargs stuff since the 3rd argument is now 
 * compulsory. Cleaned up. A few comments even.
 * 
 * Revision 1.14  90/03/06  21:50:28  terry
 * Touched up memory stuff. Added mem_find(). Changed
 * buf_sz and buf_inc to be a reasonable refelection
 * of the length of the input.
 * 
 * Revision 1.13  90/03/06  20:22:48  terry
 * Major rearrangements. Added mem(), mem_init(), mem_save(),
 * mem_free() to handle memory in a vastly improved fashion.
 * Calls to malloc are minimised as far as possible.
 * 
 * Revision 1.12  90/03/06  13:23:33  terry
 * Made map static.
 * 
 * Revision 1.11  90/01/10  15:51:12  terry
 * checked in with -k by terry at 90.01.18.20.03.08.
 * 
 * Revision 1.11  90/01/10  15:51:12  terry
 * *** empty log message ***
 * 
 * Revision 1.10  90/01/10  12:48:40  terry
 * Fixed handling of perverted character ranges in nextch().
 * a-f-c now means a-c.
 * 
 * Revision 1.9  90/01/10  12:03:48  terry
 * Pounded on space allocation, added more_space,
 * remove free() in build_map, tested tiny buffer sizes etc.
 * 
 * Revision 1.8  90/01/09  18:15:12  terry
 * added backslash elimination to str.
 * altered backslash_elimantion to take one of three types
 * REGEX, NORMAL or REPLACEMENT depending on the
 * elimination desired. Changed interpretation of \ 
 * followed by a single digit to be that character if the
 * type of elimination is NORMAL. i.e. \4 = ^D.
 * 
 * Revision 1.7  90/01/09  17:05:05  terry
 * Frozen version for release to comp.sources.unix
 * 
 * Revision 1.6  90/01/09  16:47:54  terry
 * Altered pure searching return values to be -1
 * 
 * Revision 1.5  90/01/09  14:54:34  terry
 * *** empty log message ***
 * 
 * Revision 1.4  90/01/09  14:51:04  terry
 * removed #include <stdio> silliness.
 * 
 * Revision 1.2  90/01/09  10:48:22  terry
 * Fixed handling of } and - metacharacters inside
 * transliteration request strings in backslash_eliminate().
 * 
 * Revision 1.1  90/01/08  17:41:35  terry
 * Initial revision
 * 
 *
 */

#define HS_REGEX	1

#include "strsed.h"

/* required for strdup(3) on Linux and macOS */
#define _XOPEN_SOURCE 600L
/* we're using this on raw strings, no escape sequences allowed */
#define ESCAPED_STRING

#include <ctype.h>
#include <string.h>
#include <stdlib.h>

#ifdef GNU_REGEX
#include "regex.h"
#endif

#ifdef HS_REGEX
#include <sys/types.h>
#include <regex.h>
#endif

#define BYTEWIDTH     8
#define REGEX         0
#define REPLACEMENT   1
#define NORMAL        2

/*
 * And this is supposed to make freeing easier. It's a little hard to
 * keep track of what can and cannot be freed in what follows, so I
 * ignore it and every time a malloc is done for one of the things
 * below (and these are the only ones possible) we free if need be and
 * then alloc some more if it can't be avoided. No-one (who is going 
 * to free) needs to call malloc then. And no-one need call free. 
 * Wonderful in theory...
 */

#define MEM_STR       0
#define MEM_PAT       1
#define MEM_FROM      2
#define MEM_TO        3
#define MEM_NEWSTR    4
#define MEM_MAP       5
#define MEM_MAP_SAVE  6

#define MEM_SLOTS     7

/*
 * This calls mem_free(), which free()s all the allocated storage EXCEPT
 * for the piece whose address is 'n'. If something goes wrong below
 * we call RETURN(0) and if we want to return some address we call RETURN
 * with the address to be returned.
 */

#define RETURN(n)     \
    mem_free(n);      \
    if (exp_regs != NULL) \
    free(exp_regs); \
    return (char *)n

static struct {
    char *s;
    int size;
    int used;
} mem_slots[MEM_SLOTS];


#define more_space(need)                                                   \
    if (need > 0 && space != -1){                                          \
        if (space - (need) < 0){                                           \
            buf_sz += buf_inc + (need) - space;                            \
            if (!(new_str = (char *)realloc(new_str, (unsigned)buf_sz))){  \
                RETURN(0);                                                 \
            }                                                              \
	    mem_slots[MEM_NEWSTR].s = new_str;                             \
	    mem_slots[MEM_NEWSTR].size = buf_sz;                           \
            space = buf_inc;                                               \
        }                                                                  \
        else{                                                              \
            space -= need;                                                 \
        }                                                                  \
    }

#ifdef GNU_REGEX
#define NO_MATCH -1
#define EMPTY_REGISTER -1
#endif
#ifdef HS_REGEX
#define NO_MATCH 0
#define EMPTY_REGISTER ((regoff_t) 0)
#endif

/* ------------------------------------------------------------------------- **
 * Prototypes
 * ------------------------------------------------------------------------- */
static char *mem(int, int);
static void mem_init(void);
static void mem_free(char *);
static char *build_map(char *, char *);
static char nextch(char *, int);
static void mem_save(int);
static int mem_find(int);
char *backslash_eliminate(char *, int, int);

/* ------------------------------------------------------------------------- **
 * strsed
 * ------------------------------------------------------------------------- */
char *
strsed(string, pattern, range)
register char *string;
register char *pattern;
int *range;
{

#ifdef GNU_REGEX
    extern char *re_compile_pattern();
    extern int re_search();
    static struct re_pattern_buffer re_comp_buf;
    struct re_registers regs;
    static struct re_registers empty_regs;
#endif

#ifdef HS_REGEX
    static regmatch_t *exp_regs = NULL;
    static regex_t exp;
#endif
    
    char *from;
    char *new_str;
    char *pat;
    char *str;
    char *tmp;
    char *to;
    static char map[1 << BYTEWIDTH];
    int buf_sz;
    int buf_inc;
    int global = 0;
    int match;
    int new_pos = 0;
    int search_only = 0;
    int seenbs = 0;
    int space;
    int match_all = 0;
    register int str_len;
    static int first_time = 1;
    static char *last_exp = (char *)0;
    int repeat;
    char delimiter;

    if (!string || !pattern){
        RETURN(0);
    }
    
    /*
     * If this is the first time we've been called, clear the memory slots.
     */
    if (first_time){
#ifdef GNU_REGEX
	register int i;
#endif
	mem_init();
#ifdef GNU_REGEX
	/* Zero the fake regs that we use if the regex is ".*" */
	for (i = 0; i < RE_NREGS; i++){
	    empty_regs.start[i] = empty_regs.end[i] = EMPTY_REGISTER;
	} 
#endif

#ifdef HS_REGEX
	/* We use first_time again if we are GNU_REGEX, and reset it later. */
	first_time = 0;

#endif
    }

    /*
     * Take our own copies of the string and pattern since we promised
     * in the man page not to hurt the originals.
     */
    str = mem(MEM_STR, strlen(string) + 1);
    str[0] = '\0';
    strcat(str, string);
    pat = mem(MEM_PAT, strlen(pattern) + 1);
    pat[0] = '\0';
    strcat(pat, pattern);

    /*
     * If escape sequences are not already removed elsewhere, remove
     * them from the string. If you don't know what you're doing here
     * or are in any doubt, don't define ESCAPED_STRING.
     */
#ifndef ESCAPED_STRING
    if (!(str = backslash_eliminate(str, NORMAL, MEM_STR))){
        RETURN(0);
    }
#endif

    str_len = strlen(str);
    
    /*
     * Set up the size of our buffer (in which we build the
     * newstring, and the size by which we increment it when
     * (and if) the need arises. There shouldn't be too much
     * growth in the average case. Of course some people will
     * go and do things like 
     *
     * strsed(string, "s/.*$/\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")
     *
     * and they will be somewhat penalised. Oh well.
     *
     */

    buf_sz = str_len < 8 ? 16 : str_len << 1;
    buf_inc = buf_sz;

    /*
     * Get the action. 
     * s = substitue and g = global.
     * anything else is invalid.
     *
     * If one of these is present, the next char is the delimiter.
     * Otherwise the character is taken as the delimiter itself.
     * This is more flexible, for example the following are all
     * legal:
     *
     *           s/pinto/bean/
     *           /pinto/bean
     *           /pinto/
     *           g/pinto/bean/
     *
     */
    switch (*pat){
	case 'g':{
	    global = 1;
	    pat++;
	    break;
	}
	case 's':{
	    pat++;
	    break;
	}
	default:{
	    break;
	}
    }

    if (!*pat){
        RETURN(0);
    }
    
    delimiter = *pat++;

    /*
     * Now split 'pat' into its two components. These are delimited (or
     * should be) by (unquoted) 'delimiter'. The first we point to with 'from' 
     * and the second with 'to'. 
     *
     * Someone should write a function to make this sort of thing trivial...
     *
     */
    
    from = to = pat;

    while (*to){
        if (seenbs){
            seenbs = 0;
        }
        else{
            if (*to == '\\'){
                seenbs = 1;
            }
            else if (*to == delimiter){
                break;
            }
        }
        to++;
    }

    if (!*to){
        RETURN(0);
    }

    *to++ = '\0';

    if (*to){
        tmp = to + strlen(to) - 1;

        /*
         * Make sure that the last character is the delimiter,
         * and wasn't preceded by \.
         *
	 */

        if (*tmp != delimiter || *(tmp - 1) == '\\'){
            RETURN(0);
        }

        *tmp = '\0';
    }
    else{
        /*
	 * Search only.
         * It doesn't make sense to say
         *
         * strsed(string, "g/abc/", range)
         *
         * because we are only searching and returning the 
         * matched indexes. So turn off global (in case it's on)
	 * so that we will return just the first instance.
	 *
	 * If no range has been given either, then there's no
	 * point in going on.
         *
         */
	
	if (!range){
	    RETURN(0);
	}
	
        global = 0;
        search_only = 1;
    }

    /*
     * Eliminate backslashes and character ranges etc.
     * Check that 'to' is a non-empty string before bothering
     * to try and eliminate things.
     *
     */

    if (!(from = backslash_eliminate(from, REGEX, MEM_FROM))){
        RETURN(0);
    }
    if (to && !(to = backslash_eliminate(to, REPLACEMENT, MEM_TO))){
        RETURN(0);
    }
    
    /*
     * If the first char of 'to' is '\0' then we are deleting or 
     * searching only. We don't have to worry about space since 
     * the transformed string will be less than or equal in length
     * to the original. We just overwrite.
     * We set space = -1 so that later on we can avoid worrying
     * about overflow etc.
     *
     * Otherwise, we are doing a substitution. Here we have to
     * worry about space because the replacement may be larger
     * than the original. malloc some room and if we overflow it 
     * later we will realloc. Slows things down if the new string
     * turns out to be too much bigger. Oh well.
     *
     */
    
    if (*to){
        if (!(new_str = mem(MEM_NEWSTR, buf_sz + 1))){
            RETURN(0);
        }
        space = buf_sz;
    }
    else{
        new_str = str;
        space = -1;
    }

    
    /*
     * Check to see if the regexp is the same as last time.
     * If so, we can save ourselves a call to regexec (or whatever
     * function your regex package uses).
     *
     */
    
    if (last_exp){
	if (!strcmp(from, last_exp)){
	    repeat = 1;
	}
	else{
	    free(last_exp);
	    last_exp = strdup(from);
	    repeat = 0;
	}
    }
    else {
	last_exp = strdup(from);
	repeat = 0;
    }
    
    /*
     * Initialise the range integers to -1, since they may be checked after we
     * return, even if we are not just searching.
     */
    if (range){
	range[0] = range[1] = -1;
    }
    
    /*
     * Check for the special case where the regex is ".*" since
     * then we can save a call to compile and to match, since we
     * know what will happen. We can just fake it.
     *
     */

    if (from[0] == '.' && from[1] == '*' && from[2] == '\0'){
	
	match_all = 1;
	
	/*
	 * For safety's sake, clear out the register values.
	 * There might be a register reference in the replacement. 
	 * There will be nothing in the registers (since the search
	 * pattern was ".*"). Since we aren't calling the regex 
	 * stuff we can't rely on it to set these to -1 (or 0 - as the
	 * case may be).
	 */
#ifdef GNU_REGEX
	regs = empty_regs;
#endif
    }


#ifdef GNU_REGEX
    /*
     * Do the first_time check for GNU. Notice the "else" here. We don't
     * want to do this if the regex is ".*", even if it is our first time.
     */
    else{
	if (first_time){
	    if (!(re_comp_buf.buffer = (char *)malloc((unsigned)200))){
		RETURN(0);
	    }
	    
	    re_comp_buf.allocated = 200;
	    
	    if (!(re_comp_buf.fastmap = (char *)malloc((unsigned)1 << BYTEWIDTH))){
		RETURN(0);
	    }
	    first_time = 0;
	}
	
	if (!repeat){
	    re_comp_buf.translate = 0;
	    re_comp_buf.used = 0;
	}
    }
#endif

    /*
     * If we are not optimising a ".*" or repeating the regex we had last time,
     * compile the regular expression.
     */

    if (!match_all && !repeat){
#ifdef GNU_REGEX
	if (re_compile_pattern(from, strlen(from), &re_comp_buf)){
	    RETURN(0);
	}
#endif

#ifdef HS_REGEX
	if (regcomp(&exp, from, 0) != 0){
	    RETURN(0);
	}
#endif
    }

    /*
     * Now get on with the matching/replacing etc.
     */

    do {
#ifdef HS_REGEX
	    /* XXX Not even trying to use custom memory routines */
	    if (!(exp_regs = calloc(str_len, sizeof(regmatch_t)))) {
		return 0;
	    }
#endif
	if (match_all){
	    /* Fake a match instead of calling re_search() or regexec(). */
	    match = 1;
#ifdef GNU_REGEX
	    regs.start[0] = 0;
	    regs.end[0] = str_len;
#endif
	}
	else{
#ifdef GNU_REGEX
	    match = re_search(&re_comp_buf, str, str_len, 0, str_len, &regs);
#endif
#ifdef HS_REGEX
	    match = regexec(&exp, str, str_len, exp_regs, 0) ? NO_MATCH : 1;
#endif
	}

        if (search_only){
            /*
             * Show what happened and return.
             */
	    
#ifdef GNU_REGEX
	    range[0] = match == NO_MATCH ? -1 : regs.start[0];
	    range[1] = match == NO_MATCH ? -1 : regs.end[0];
#endif
#ifdef HS_REGEX
	    range[0] = match == NO_MATCH ? -1 : exp_regs[0].rm_so;
	    range[1] = match == NO_MATCH ? -1 : exp_regs[0].rm_eo;
#endif
            RETURN(str);
        }

	
        if (match != NO_MATCH){
	    register int need;

	    /* Set up the range so it can be used later if the caller wants it. */
	    if (range){
#ifdef GNU_REGEX
	    range[0] = regs.start[0];
	    range[1] = regs.end[0];
#endif
#ifdef HS_REGEX
	    range[0] = exp_regs[0].rm_so;
	    range[1] = exp_regs[0].rm_eo;
#endif
	    }
	    
            /*
             * Copy that portion that was not matched. It will
             * be unchanged in the output string.
             *
             */
	    
#ifdef GNU_REGEX
	    need = regs.start[0];
#endif
#ifdef HS_REGEX
	    need = exp_regs[0].rm_so;
#endif

	    if (need > 0){
		more_space(need);
		memmove(new_str + new_pos, str, need);
		new_pos += need;
	    }

            /*
             * Put in the replacement text (if any).
             * We substitute the contents of 'to', watching for register
             * references.
             */

            tmp = to;
            while (*tmp){
                if (*tmp == '\\' && isdigit(*(tmp + 1))){

                    /* A register reference. */

                    register int reg = *(tmp + 1) - '0';
                    int translit = 0;
#ifdef GNU_REGEX
                    need = regs.end[reg] - regs.start[reg];
#endif
#ifdef HS_REGEX
                    need = exp_regs[reg].rm_eo - exp_regs[reg].rm_so;
#endif

                    /*
                     * Check for a transliteration request.
                     *
                     */
		    if (*(tmp + 2) == '{'){
			/* A transliteration table. Build the map. */
			if (!(tmp = build_map(tmp + 2, map))){
			    RETURN(0);
			}
			translit = 1;
		    }
		    else{
			tmp += 2;
			translit = 0;
		    }

		    more_space(need);
		    
		    /*
		     * Copy in the register contents (if it matched), transliterating if need be.
		     *
		     */
#ifdef GNU_REGEX
                    if (regs.start[reg] != EMPTY_REGISTER){
			register int i;
                        for (i = regs.start[reg]; i < regs.end[reg]; i++){
                            new_str[new_pos++] = translit ? map[str[i]] : str[i];
                        }
                    }
#endif

#ifdef HS_REGEX
                    if (exp_regs[0].rm_so != EMPTY_REGISTER){
			register regoff_t s;
                        for (s = exp_regs[0].rm_so; s < exp_regs[0].rm_eo; s++){
                            new_str[new_pos++] = translit ? map[s] : s;
                        }
		    }
#endif
                }
                else{
                    /* A plain character, put it in. */
                    more_space(1);
                    new_str[new_pos++] = *tmp++;
                }
            }

            /*
             * Move forward over the matched text.
             *
             */
#ifdef GNU_REGEX
            str += regs.end[0];
            str_len -= regs.end[0];
#endif
#ifdef HS_REGEX
            str += exp_regs[0].rm_eo;
            str_len -= (int)(exp_regs[0].rm_eo - exp_regs[0].rm_so);
#endif
        }
    } while (global && match != NO_MATCH && *str);

    /*
     * Copy the final portion of the string. This is the section that
     * was not matched (and hence which remains unchanged) by the last
     * match. Then we head off home.
     *
     */
    more_space(str_len);
    (void) memmove(new_str + new_pos, str, strlen(str) + 1);
    RETURN(new_str);
}

#define DIGIT(x) (isdigit(x) ? (x) - '0' : islower(x) ? (x) + 10 - 'a' : (x) + 10 - 'A')

char *
backslash_eliminate(str, type, who)
char *str;
int type;
int who;
{
    /*
     * Remove backslashes from the strings. Turn \040 etc. into a single
     * character (we allow eight bit values). Currently NUL is not
     * allowed.
     *
     * Turn "\n" and "\t" into '\n' and '\t' characters. Etc.
     *
     * The string may grow slightly here. Under normal circumstances
     * it will stay the same length or get shorter. It is only in the 
     * case where we have to turn {a-z}{A-Z} into \0{a-z}{A-Z} that
     * we add two chars. This only happens when we are doing a REPLACEMENT.
     * So we can't overwrite str, and we have to 
     * malloc. Sad, but the only ways I could find around it (at this
     * late stage) were really gross. I allowed an extra 
     * 100 bytes which should cover most idiotic behaviour.
     * I count the extra space and exit nicely if they do do something
     * extremely silly.
     *
     * 'i' is an index into new_str.
     *
     * 'type' tells us how to interpret escaped characters.
     *
     * type = REGEX 
     *        if the pattern is a regular expression. If it is then
     *        we leave escaped things alone (except for \n and \t and 
     *        friends).
     *
     * type = REPLACEMENT
     *        if this is a replacement pattern. In this case we change
     *        \( and \) to ( and ), but leave \1 etc alone as they are
     *        register references. - becomes a metacharacter between
     *        { and }.
     *
     * type = NORMAL
     *        We do \n and \t elimination, as well as \040 etc, plus
     *        all other characters that we find quoted we unquote.
     *        type = NORMAL when we do a backslash elimination on the
     *        string argument to strsed.
     *
     * who tells us where to tell mem where to stick the new string.
     *
     * \{m,n\} syntax (see ed(1)) is not supported.
     *
     */

    char *new_str;
    int extra = 100;
    int seenlb = 0;
    register int i = 0;
    register int seenbs = 0;
    int first_half = 0;

    if (type == REPLACEMENT){
	if (!(new_str = mem(who, strlen(str) + 1 + extra))){
	    return 0;
	}
    }
    else{
	new_str = str;
    }

    while (*str){
        if (seenbs){
            seenbs = 0;
            switch (*str){
                case '\\':{
                    new_str[i++] = '\\';
                    str++;
                    break;
                }

                case '-':{
                    if (seenlb){
                        /* Keep it quoted. */
                        new_str[i++] = '\\';
                    }
                    new_str[i++] = '-';
                    str++;
                    break;
                }

                case '}':{
                    if (seenlb){
                        /* Keep it quoted. */
                        new_str[i++] = '\\';
                    }
                    new_str[i++] = '}';
                    str++;
                    break;
                }

                case 'n':{
                    new_str[i++] = '\n';
                    str++;
                    break;
                }

                case 't':{
                    new_str[i++] = '\t';
                    str++;
                    break;
                }

                case 's':{
                    new_str[i++] = ' ';
                    str++;
                    break;
                }

                case 'r':{
                    new_str[i++] = '\r';
                    str++;
                    break;
                }

                case 'f':{
                    new_str[i++] = '\f';
                    str++;
                    break;
                }

                case 'b':{
                    new_str[i++] = '\b';
                    str++;
                    break;
                }

                case 'v':{
                    new_str[i++] = '\13';
                    str++;
                    break;
                }

                case 'z':{
                    str++;
                    break;
                }

                case '0': case '1': case '2': case '3': case '4':
                case '5': case '6': case '7': case '8': case '9':{

                    char val;

                    /*
                     * Three digit octal constant.
                     *
                     */
                    if (*str >= '0' && *str <= '3' && 
                        *(str + 1) >= '0' && *(str + 1) <= '7' &&
                        *(str + 2) >= '0' && *(str + 2) <= '7'){

                        val = (DIGIT(*str) << 6) + 
                              (DIGIT(*(str + 1)) << 3) + 
                               DIGIT(*(str + 2));

                        if (!val){
                            /*
                             * NUL is not allowed.
                             */
                            return 0;
                        }

                        new_str[i++] = val;
                        str += 3;
                        break;
                    }

                    /*
                     * One or two digit hex constant.
                     * If two are there they will both be taken.
                     * Use \z to split them up if this is not wanted.
                     *
                     */
                    if (*str == '0' && (*(str + 1) == 'x' || *(str + 1) == 'X') && isxdigit(*(str + 2))){
                        val = DIGIT(*(str + 2));
                        if (isxdigit(*(str + 3))){
                            val = (val << 4) + DIGIT(*(str + 3));
                            str += 4;
                        }
                        else{
                            str += 3;
                        }

                        if (!val){
                            return 0;
                        }

                        new_str[i++] = val;
                        break;
                    }

                    /*
                     * Two or three decimal digits.
                     * (One decimal digit is taken as either a register reference
                     * or as a decimal digit if NORMAL is true below.)
                     *
                     */
                    if (isdigit(*(str + 1))){
                        val = DIGIT(*str) * 10 + DIGIT(*(str + 1));
                        if (isdigit(*(str + 2))){
                            val = 10 * val + DIGIT(*(str + 2));
                            str += 3;
                        }
                        else{
                            str += 2;
                        }

                        if (!val){
                            return 0;
                        }

                        new_str[i++] = val;
                        break;
                    }

                    /*
                     * A register reference or else a single decimal digit if this
                     * is a normal string..
                     *
                     * Emit \4 (etc) if we are not NORMAL (unless the digit is a 0 
                     * and we are processing an r.e. This is because \0 makes no 
                     * sense in an r.e., only in a replacement. If we do have \0 
                     * and it is an r.e. we return.)
                     *
                     */
                    if (*str == '0' && type == REGEX){
                        return 0;
                    }

                    if (type == NORMAL){
                        if (!(val = DIGIT(*str))){
                            return 0;
                        }
                        new_str[i++] = val;
                        str++;
                    }
                    else{
                        new_str[i++] = '\\';
                        new_str[i++] = *str++;
                    }
                    break;
                }

                default:{
                    if (type == REGEX){
                        new_str[i++] = '\\';
                    }
                    new_str[i++] = *str++;
                    break;
                }
            }
        }
        else{
            if (*str == '\\'){
                seenbs = 1;
                str++;
            }
            else if (type == REPLACEMENT && *str == '}'){
                if (*(str + 1) == '{' && first_half){
                    new_str[i++] = *str++;
                    new_str[i++] = *str++;
		    first_half = 0;
                }
                else{
                    seenlb = 0;
                    new_str[i++] = *str++;
                }
            }
            else if (type == REPLACEMENT && !seenlb && *str == '{'){
                /*
                 * Within { and }, \- should be left as such. So we can differentiate
                 * between s/fred/\-/ and s/fred/{\-a-z}{+A-Z}
                 *
                 * We stick in a "\0" here in the case that \X has not just been
                 * seen. (X = 0..9) Which is to say, {a-z}{A-Z} defaults to 
                 * \0{a-z}{A-Z}
                 *
                 */

                seenlb = 1;
		first_half = 1;

                if (i < 2 || new_str[i - 2] != '\\' || !(new_str[i - 1] >= '0' && new_str[i - 1] <= '9')){
                    if ((extra -= 2) < 0){
                        /* ran out of extra room. */
                        return 0;
                    }
                    new_str[i++] = '\\';
                    new_str[i++] = '0';
                }
                new_str[i++] = *str++;
            }
            else{
                /* 
                 * A normal char.
                 *
                 */
                new_str[i++] = *str++;
            }
        }
    }

    if (seenbs){
        /*
         * The final character was a '\'. Put it in as a single backslash.
         *
         */
	new_str[i++] = '\\';
    }

    new_str[i] = '\0';
    return new_str;
}

static char *
build_map(s, map)
char *s;
char *map;
{
    /*
     * Produce a mapping table for the given transliteration.
     * We are passed something that looks like "{a-z}{A-Z}"
     * Look out for \ chars, these are used to quote } and -.
     *
     * Return a pointer to the char after the closing }.
     * We cannot clobber s.
     *
     * The building of maps is somewhat optimised.
     * If the string is the same as the last one we were 
     * called with then we don't do anything. It would be better
     * to remember all the transliterations we have seen, in
     * order (because in a global substitution we will
     * apply them in the same order repeatedly) and then we
     * could do the minimum amount of building. This is a 
     * compromise because it is a fairly safe bet that there will 
     * not be more than one transliteration done.
     *
     */

    char *in;
    char *out;
    char *str;
    char *tmp;
    char c;
    int i = 0;
    int range_count = 0;
    int seenbs = 0;
    static char *last = 0;
    static int last_len;

    out = 0;

    if (!s){
        return 0;
    }

    if (last && !strncmp(s, last, last_len)){
        /* Re-use the map. */
        return s + last_len;
    }
    else{
	/*
	 * Make a copy of s in both 'last' and 'str'
	 */
	int len = strlen(s) + 1;
        if (!(str = mem(MEM_MAP, len)) || !(last = mem(MEM_MAP_SAVE, len))){
            return 0;
        }
	str[0] = last[0] = '\0';
	strcat(str, s);
	strcat(last, s);
    }

    tmp = str + 1;
    in = str;

    while (*tmp){
        if (seenbs){
            if (*tmp == '-'){
                /* 
                 * Keep the \ before a - since this is the range
                 * separating metacharacter. We don't keep } quoted,
                 * we just put it in. Then it is passed as a normal
                 * char (no longer a metachar) to nextch().
                 *
                 */
                str[i++] = '\\';
            }
            str[i++] = *tmp++;
            seenbs = 0;
        }
        else{
            if (*tmp == '\\'){
                seenbs = 1;
                tmp++;
            }
            else if (*tmp == '}'){
                if (!range_count){
                    /* seen first range. */
                    range_count = 1;
                    str[i++] = '\0';
                    tmp++;
                    while (*tmp == ' ' || *tmp == '\t'){
                        tmp++;
                    }
                    if (*tmp != '{'){
                        return 0;
                    }
                    out = str + i;
                    tmp++;
                }
                else{
                    /* seen both ranges. */
                    str[i++] = '\0';
                    tmp++;
                    range_count = 2; 
                    break;
                }
            }
            else{
                /* A plain defenceless character. */
                str[i++] = *tmp++;
            }
        }
    }

    if (range_count != 2){
        return 0;
    }

    last_len = tmp - str;

    /*
     * Now 'out' and 'in' both point to character ranges.
     * These will look something like "A-Z" but may be 
     * more complicated and have {} and - in them elsewhere.
     *
     */
    
    for (i = 0; i < 1 << BYTEWIDTH; i++){
        map[i] = i;
    }

    /*
     * Ready the range expanding function.
     *
     */
    (void) nextch(in, 0);
    (void) nextch(out, 1);

    /*
     * For each char in 'in', assign it a value in
     * 'map' corresponding to the next char in 'out'.
     *
     */

    while ((c = nextch((char *)0, 0))){
        map[(int) c] = nextch((char *)0, 1);
    }

    return tmp;
}

static char
nextch(str, who)
char *str;
int who;
{
    /*
     * Given a range like {a-z0237-9}
     * return successive characters from the range on
     * successive calls. The first call (when str != 0)
     * sets things up.
     *
     * We must handle strange things like
     * {a-b-c-z}            = {a-z}
     * and {z-l-a}          = {z-a}
     * and {f-f-f-f-h}      = {f-h}
     * and {a-z-f-h-y-d-b}  = {a-b}
     *
     * and so on.
     *
     * This function will remember two strings and will return
     * the next charcter in the range specified by 'who'. This
     * makes the building of the transliteration table above
     * a trivial loop.
     *
     * I can't be bothered to comment this as much as it
     * deserves right now... 8-)
     *
     */

    static char *what[2] = {0, 0};
    static char last[2] = {0, 0};
    static int increment[2];
    static int pos[2];

    if (who < 0 || who > 1){
        return 0;
    }

    if (str){
        /* Set up for this string. */
        what[who] = str;
        pos[who] = 0;
        return 1;
    }
    else if (!what[who]){
        return 0;
    }

    if (!pos[who] && what[who][0] == '-'){
        return 0;
    }

    switch (what[who][pos[who]]){
        
        case '-':{
            /* we're in mid-range. */
            last[who] += increment[who];
            if (what[who][pos[who] + 1] == last[who]){
                pos[who] += 2;
            }
            return last[who];
        }

        case '\0':{
            /* 
             * We've finished. Keep on returning the
             * last thing you saw if who = 1.
             */
            if (who){
                return last[1];
            }
            return 0;
        }

        /* FALLTHROUGH */
        case '\\':{
            pos[who]++;
        }

        default:{
            last[who] = what[who][pos[who]++];
            /*
             * If we have reached a '-' then this is the start of a
             * range. Keep on moving forward until we see a sensible 
             * end of range character. Then set up increment so that
             * we do the right thing next time round. We leave pos
             * pointing at the '-' sign.
             *
             */

            while (what[who][pos[who]] == '-'){
                int inc = 1;
                if (what[who][pos[who] + inc] == '\\'){
                    inc++;
                }
                if (!what[who][pos[who] + inc]){
                    return 0;
                }
                if (what[who][pos[who] + inc + 1] == '-'){
                    pos[who] += inc + 1;
                    continue;
                }
                increment[who] = what[who][pos[who] + inc] - last[who];
                if (!increment[who]){
                    pos[who] += 2;
                    continue;
                }
                if (increment[who] > 0){
                    increment[who] = 1;
                    break;
                }
                else if (increment[who] < 0){
                    increment[who] = -1;
                    break;
                }
            }
            return last[who];
        }
    }
}

static char *
mem(who, size)
int who;
int size;
{
    /*
     * Get 'size' bytes of memeory one way or another.
     *
     * The 'mem_slots' array holds currently allocated hunks.
     * If we can use one that's already in use then do so, otherwise
     * try and find a hunk not in use somewhere else in the table.
     * As a last resort call malloc. All a bit specialised and
     * not too clear. Seems to works fine though.
     */
    
    if (who < 0 || who >= MEM_SLOTS){
	return 0;
    }
    
    if (mem_slots[who].used){
	/*
	 * There is already something here. Either move/free it or
	 * return it if it is already big enough to hold this request.
	 */
	if (mem_slots[who].size >= size){
	    /* It is already big enough. */
	    return mem_slots[who].s;
	}
	else{
	    mem_save(who);
	}
    }
    else{
	/*
	 * The slot was not in use. Check to see if there is space
	 * allocated here already that we can use. If there is and
	 * we can, use it, if there is and it's not big enough try to
	 * save it. if there isn't then try to find it in another free slot,
	 * otherwise don't worry, the malloc below will get us some.
	 */
	if (mem_slots[who].s && mem_slots[who].size >= size){
	    /* We'll take it. */
	    mem_slots[who].used = 1;
	    return mem_slots[who].s;
	}
	
	if (mem_slots[who].s){
	    mem_save(who);
	}
	else{
	    int x = mem_find(size);
	    if (x != -1){
		mem_slots[who].s = mem_slots[x].s;
		mem_slots[who].size = mem_slots[x].size;
		mem_slots[who].used = 1;
		mem_slots[x].s = (char *)0;
		return mem_slots[who].s;
	    }
	}
    }
    
    /*
     * Have to use malloc 8-(
     */

    if (!(mem_slots[who].s = (char *)malloc((unsigned)size))){
	return 0;
    }
    mem_slots[who].size = size;
    mem_slots[who].used = 1;
    
    return mem_slots[who].s;
}

static int
mem_find(size)
int size;
{
    /*
     * See if we can find an unused but allocated slot with 'size' 
     * (or more) space available. Return the index, or -1 if not.
     */
     
    register int i;
    
    for (i = 0; i < MEM_SLOTS; i++){
	if (!mem_slots[i].used && mem_slots[i].s && mem_slots[i].size >= size){
	    return i;
	}
    }
    return -1;
}

static void
mem_save(x)
int x;
{
    /*
     * There is some memory in mem_slots[x] and we try to save it rather
     * than free it. In order we try to
     *
     * 1) put it in an unused slot that has no allocation.
     * 2) put it in an unused slot that has an allocation smaller than x's
     * 3) free it since there are no free slots and all the full ones are bigger.
     *
     */

    register int i;
    register int saved = 0;
    
    /*
     * First we try to find somewhere unused and with no present allocation.
     */
    for (i = 0; i < MEM_SLOTS; i++){
	if (!mem_slots[i].used && !mem_slots[i].s){
	    saved = 1;
	    mem_slots[i].s = mem_slots[x].s;
	    mem_slots[i].size = mem_slots[x].size;
	    mem_slots[i].used = 0;
	    break;
	}
    }
    
    /*
     * No luck yet. Try for a place that is not being used but which has
     * space allocated, and which is smaller than us (and all other such spots). 
     * Pick on the smallest, yeah.
     */
    if (!saved){
	register int small = -1;
	register int small_val = 32767; /* Be nice to 16 bit'ers. Non-crucial if it's too low. */
	for (i = 0; i < MEM_SLOTS; i++){
	    if (!mem_slots[i].used && mem_slots[i].size < mem_slots[x].size && mem_slots[i].size < small_val){
		small_val = mem_slots[i].size;
		small = i;
	    }
	}
	
	if (small != -1){
	    saved = 1;
	    /* We got one, now clobber it... */
	    free(mem_slots[small].s);
	    /* and move on in. */
	    mem_slots[small].s = mem_slots[x].s;
	    mem_slots[small].size = mem_slots[x].size;
	    mem_slots[small].used = 0;
	}
    }
    
    if (!saved){
	/* Have to toss it away. */
	free(mem_slots[x].s);
    }
}

static void
mem_init()
{
    /*
     * Clear all the memory slots.
     */

    register int i;
    
    for (i = 0; i < MEM_SLOTS; i++){
	mem_slots[i].s = (char *)0;
	mem_slots[i].used = 0;
    }
}

static void
mem_free(except)
char *except;
{
    /*
     * "Clear out" all the memory slots. Actually we do no freeing since
     * we may well be called again. We just mark the slots as unused. Next
     * time round they might be useful - the addresses and sizes are still there.
     *
     * For the slot (if any) whose address is 'except', we actually set the
     * address to 0. This is done because we are called ONLY from the macro
     * RETURN() in strsed() and we intend to return the value in 'except'.
     * Once this is done, strsed should (in theory) have no knowledge at all
     * of the address it passed back last time. That way we won't clobber it
     * and cause all sorts of nasty problems.
     */

    register int i;
    
    for (i = 0; i < MEM_SLOTS; i++){
	mem_slots[i].used = 0;
	if (mem_slots[i].s == except){
	    mem_slots[i].s = (char *)0;
	    mem_slots[i].size = 0;
	}
    } 
}

