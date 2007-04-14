#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#include "config.h"
#ifndef HAVE_ASPRINTF
#include "asprintf.h"
#endif
#include "xar.h"

static int initted = 0;

int32_t xar_script_in(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen) {
	char *buf = *in;

	if( initted )
		return 0;

	if( (*inlen > 2) && (buf[0] == '#') && (buf[1] == '!') ) {
		char *exe;
		int i;

		exe = malloc(*inlen);
		if( !exe )
			return -1;
		memset(exe, 0, *inlen);
		
		for(i = 2; (i < *inlen) && (buf[i] != '\0') && (buf[i] != '\n') && (buf[i] != ' '); ++i) {
			exe[i-2] = buf[i];
		}

		xar_prop_set(f, "content/type", "script");
		xar_prop_set(f, "content/interpreter", exe);
		free(exe);
	}
	return 0;
}

int32_t xar_script_done(xar_t x, xar_file_t f, const char *attr) {
	initted = 0;
	return 0;
}
