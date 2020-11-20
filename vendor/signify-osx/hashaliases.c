/*
 * OS X compilers seem to have trouble resolving MAKE_CLONE()es,
 * so just make explicit wrapper functions.
 */

#include <sha2.h>

/* MAKE_CLONE(SHA224Transform, SHA256Transform); */
void
SHA224Transform(u_int32_t state[8], const u_int8_t data[SHA256_BLOCK_LENGTH])
{
	SHA256Transform(state, data);
}

/* MAKE_CLONE(SHA224Update, SHA256Update); */
void
SHA224Update(SHA2_CTX *context, const u_int8_t *data, size_t len)
{
	SHA256Update(context, data, len);
}

/* MAKE_CLONE(SHA224Pad, SHA256Pad); */
void
SHA224Pad(SHA2_CTX *context)
{
	SHA256Pad(context);
}

/* MAKE_CLONE(SHA384Transform, SHA512Transform); */
void
SHA384Transform(u_int64_t state[8], const u_int8_t data[SHA512_BLOCK_LENGTH])
{
	SHA512Transform(state, data);
}

/* MAKE_CLONE(SHA384Update, SHA512Update); */
void
SHA384Update(SHA2_CTX *context, const u_int8_t *data, size_t len)
{
	SHA512Update(context, data, len);
}

/* MAKE_CLONE(SHA384Pad, SHA512Pad); */
void
SHA384Pad(SHA2_CTX *context)
{
	SHA512Pad(context);
}

/* MAKE_CLONE(SHA512_256Transform, SHA512Transform); */
void
SHA512_256Transform(u_int64_t state[8], const u_int8_t data[SHA512_BLOCK_LENGTH])
{
	SHA512Transform(state, data);
}

/* MAKE_CLONE(SHA512_256Update, SHA512Update); */
void
SHA512_256Update(SHA2_CTX *context, const u_int8_t *data, size_t len)
{
	SHA512Update(context, data, len);
}

/* MAKE_CLONE(SHA512_256Pad, SHA512Pad); */
void
SHA512_256Pad(SHA2_CTX *context)
{
	SHA512Pad(context);
}
