#define _FILE_OFFSET_BITS 64
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>
#include <inttypes.h>
#include <sys/types.h>

#include "xar.h"
#include "filetree.h"
#include "archive.h"
#include "io.h"

#ifndef O_EXLOCK
#define O_EXLOCK 0
#endif

static int Fd;

int32_t xar_data_read(xar_t x, xar_file_t f, void *inbuf, size_t bsize) {
	int32_t r;

	while(1) {
		r = read(Fd, inbuf, bsize);
		if( (r < 0) && (errno == EINTR) )
			continue;
		return r;
	}
}

int32_t xar_data_write(xar_t x, xar_file_t f, void *buf, size_t len) {
	int32_t r;
	size_t off = 0;
	do {
		r = write(Fd, buf+off, len-off);
		if( (r < 0) && (errno != EINTR) )
			return r;
		off += r;
	} while( off < len );
	return off;
}

/* xar_data_archive
 * This is the arcmod archival entry point for archiving the file's
 * data into the heap file.
 */
int32_t xar_data_archive(xar_t x, xar_file_t f, const char *file) {
	const char *opt;
	int32_t retval = 0;

	xar_prop_get(f, "type", &opt);
	if(!opt) return 0;
	if( strcmp(opt, "file") != 0 ) {
		if( strcmp(opt, "hardlink") == 0 ) {
			opt = xar_attr_get(f, "type", "link");
			if( !opt )
				return 0;
			if( strcmp(opt, "original") != 0 )
				return 0;
			/* else, we're an original hardlink, so keep going */
		} else
			return 0;
	}

	Fd = open(file, O_RDONLY);
	if( Fd < 0 ) {
		xar_err_new(x);
		xar_err_set_file(x, f);
		xar_err_set_string(x, "io: Could not open file");
		xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_CREATION);
		return -1;
	}

	retval = xar_attrcopy_to_heap(x, f, "data", xar_data_read);

	close(Fd);
	return retval;
}

int32_t xar_data_extract(xar_t x, xar_file_t f, const char *file) {
	const char *opt;

        /* Only regular files are copied in and out of the heap here */
        xar_prop_get(f, "type", &opt);
        if( !opt ) return 0;
        if( strcmp(opt, "file") != 0 ) {
                if( strcmp(opt, "hardlink") == 0 ) {
                        opt = xar_attr_get(f, "type", "link");
                        if( !opt )
                                return 0;
                        if( strcmp(opt, "original") != 0 )
                                return 0; 
                        /* else, we're an original hardlink, so keep going */
                } else
                        return 0;
        }

        /* mode 600 since other modules may need to operate on the file
         * prior to the real permissions being set.
         */
TRYAGAIN:
        Fd = open(file, O_RDWR|O_TRUNC|O_EXLOCK, 0600);
        if( Fd < 0 ) {
		if( errno == ENOENT ) {
			xar_file_t parent = XAR_FILE(f)->parent;
			if( parent && (xar_extract(x, parent) == 0) )
				goto TRYAGAIN;
		}
			
               	xar_err_new(x);
               	xar_err_set_file(x, f);
               	xar_err_set_string(x, "io: Could not create file");
               	xar_err_callback(x, XAR_SEVERITY_NONFATAL, XAR_ERR_ARCHIVE_EXTRACTION);
               	return -1;
        }

	xar_attrcopy_from_heap(x, f, "data", xar_data_write);
	close(Fd);
	return 0;
}

