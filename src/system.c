/*
 * Copyright (c) 2004
 *	Herbert Xu <herbert@gondor.apana.org.au>.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <signal.h>
#include <string.h>
#include "error.h"
#include "output.h"
#include "system.h"

#ifndef HAVE_MEMPCPY
void *mempcpy(void *dest, const void *src, size_t n)
{
	return memcpy(dest, src, n) + n;
}
#endif

#ifndef HAVE_STPCPY
char *stpcpy(char *dest, const char *src)
{
	return mempcpy(dest, src, strlen(src) + 1);
}
#endif

#ifndef HAVE_STRCHRNUL
char *strchrnul(const char *s, int c)
{
	char *p = strchr(s, c);
	if (!p)
		p = (char *)s + strlen(s);
	return p;
}
#endif

#ifndef HAVE_STRSIGNAL
char *strsignal(int sig)
{
	static char buf[19];

	if ((unsigned)sig < NSIG && sys_siglist[sig])
		return (char *)sys_siglist[sig];
	fmtstr(buf, sizeof(buf), "Signal %d", sig); 
	return buf;
}
#endif

#ifndef HAVE_BSEARCH
void *bsearch(const void *key, const void *base, size_t nmemb,
	      size_t size, int (*cmp)(const void *, const void *))
{
	while (nmemb) {
		size_t mididx = nmemb / 2;
		const void *midobj = base + mididx * size;
		int diff = cmp(key, midobj);

		if (diff == 0)
			return (void *)midobj;

		if (diff > 0) {
			base = midobj + size;
			nmemb -= mididx + 1;
		} else
			nmemb = mididx;
	}

	return 0;
}
#endif

#ifndef HAVE_SYSCONF
long sysconf(int name)
{
	sh_error("no sysconf for: %d", name);
}
#endif
