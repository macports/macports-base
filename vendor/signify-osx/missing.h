#include <sys/types.h>

void explicit_bzero(void *, size_t);
void freezero(void *, size_t);

#ifndef HAVE_ARC4RANDOM_BUF
void arc4random_buf(void *, size_t);
#endif

#ifndef HAVE_GETENTROPY
int getentropy(void *, size_t);
#endif

#ifndef HAVE_TIMINGSAFE_BCMP
int timingsafe_bcmp(const void *, const void *, size_t);
#endif
