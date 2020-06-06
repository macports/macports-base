/*	$OpenBSD: helper.c,v 1.18 2019/06/28 13:32:41 deraadt Exp $ */

/*
 * Copyright (c) 2000 Poul-Henning Kamp <phk@FreeBSD.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * If we meet some day, and you think this stuff is worth it, you
 * can buy me a beer in return. Poul-Henning Kamp
 */

#include <sys/types.h>
#include <sys/stat.h>

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <sha2.h>

#define MINIMUM(a, b)	(((a) < (b)) ? (a) : (b))

char *
SHA512_256End(SHA2_CTX *ctx, char *buf)
{
	int i;
	u_int8_t digest[SHA512_256_DIGEST_LENGTH];
	static const char hex[] = "0123456789abcdef";

	if (buf == NULL && (buf = malloc(SHA512_256_DIGEST_STRING_LENGTH)) == NULL)
		return (NULL);

	SHA512_256Final(digest, ctx);
	for (i = 0; i < SHA512_256_DIGEST_LENGTH; i++) {
		buf[i + i] = hex[digest[i] >> 4];
		buf[i + i + 1] = hex[digest[i] & 0x0f];
	}
	buf[i + i] = '\0';
	explicit_bzero(digest, sizeof(digest));
	return (buf);
}
DEF_WEAK(SHA512_256End);

char *
SHA512_256FileChunk(const char *filename, char *buf, off_t off, off_t len)
{
	struct stat sb;
	u_char buffer[BUFSIZ];
	SHA2_CTX ctx;
	int fd, save_errno;
	ssize_t nr;

	SHA512_256Init(&ctx);

	if ((fd = open(filename, O_RDONLY)) == -1)
		return (NULL);
	if (len == 0) {
		if (fstat(fd, &sb) == -1) {
			save_errno = errno;
			close(fd);
			errno = save_errno;
			return (NULL);
		}
		len = sb.st_size;
	}
	if (off > 0 && lseek(fd, off, SEEK_SET) == -1) {
		save_errno = errno;
		close(fd);
		errno = save_errno;
		return (NULL);
	}

	while ((nr = read(fd, buffer, MINIMUM(sizeof(buffer), len))) > 0) {
		SHA512_256Update(&ctx, buffer, nr);
		if (len > 0 && (len -= nr) == 0)
			break;
	}

	save_errno = errno;
	close(fd);
	errno = save_errno;
	return (nr == -1 ? NULL : SHA512_256End(&ctx, buf));
}
DEF_WEAK(SHA512_256FileChunk);

char *
SHA512_256File(const char *filename, char *buf)
{
	return (SHA512_256FileChunk(filename, buf, 0, 0));
}
DEF_WEAK(SHA512_256File);

char *
SHA512_256Data(const u_char *data, size_t len, char *buf)
{
	SHA2_CTX ctx;

	SHA512_256Init(&ctx);
	SHA512_256Update(&ctx, data, len);
	return (SHA512_256End(&ctx, buf));
}
DEF_WEAK(SHA512_256Data);
