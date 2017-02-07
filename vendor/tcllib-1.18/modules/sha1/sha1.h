/*	$NetBSD: sha1.h,v 1.5 2006/10/02 23:42:08 patthoyts Exp $	*/

/*
 * SHA-1 in C
 * By Steve Reid <steve@edmweb.com>
 * 100% Public Domain
 */

#ifndef _SYS_SHA1_H_
#define	_SYS_SHA1_H_

typedef unsigned int  my_int32_t;
typedef unsigned char my_char;

typedef struct {
	my_int32_t state[5];
	my_int32_t count[2];  
	my_char    buffer[64];
} SHA1_CTX;
  
void	SHA1Transform(my_int32_t state[5], const my_char buffer[64]);
void	SHA1Init(SHA1_CTX *context);
void	SHA1Update(SHA1_CTX *context, const my_char *data, my_int32_t len);
void	SHA1Final(my_char digest[20], SHA1_CTX *context);

#endif /* _SYS_SHA1_H_ */
