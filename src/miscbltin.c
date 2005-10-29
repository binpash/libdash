/*-
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 * Copyright (c) 1997-2005
 *	Herbert Xu <herbert@gondor.apana.org.au>.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Kenneth Almquist.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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

/*
 * Miscelaneous builtins.
 */

#include <sys/types.h>		/* quad_t */
#include <sys/param.h>		/* BSD4_4 */
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <unistd.h>
#include <stdlib.h>
#include <ctype.h>
#include <stdint.h>

#include "shell.h"
#include "options.h"
#include "var.h"
#include "output.h"
#include "memalloc.h"
#include "error.h"
#include "miscbltin.h"
#include "mystring.h"
#include "main.h"

#undef rflag



/*
 * The read builtin.  The -e option causes backslashes to escape the
 * following character.
 *
 * This uses unbuffered input, which may be avoidable in some cases.
 */

int
readcmd(int argc, char **argv)
{
	char **ap;
	int backslash;
	char c;
	int rflag;
	char *prompt;
	const char *ifs;
	char *p;
	int startword;
	int status;
	int i;

	rflag = 0;
	prompt = NULL;
	while ((i = nextopt("p:r")) != '\0') {
		if (i == 'p')
			prompt = optionarg;
		else
			rflag = 1;
	}
	if (prompt && isatty(0)) {
		out2str(prompt);
#ifdef FLUSHERR
		flushall();
#endif
	}
	if (*(ap = argptr) == NULL)
		sh_error("arg count");
	if ((ifs = bltinlookup("IFS")) == NULL)
		ifs = defifs;
	status = 0;
	startword = 1;
	backslash = 0;
	STARTSTACKSTR(p);
	for (;;) {
		if (read(0, &c, 1) != 1) {
			status = 1;
			break;
		}
		if (c == '\0')
			continue;
		if (backslash) {
			backslash = 0;
			if (c != '\n')
				goto put;
			continue;
		}
		if (!rflag && c == '\\') {
			backslash++;
			continue;
		}
		if (c == '\n')
			break;
		if (startword && *ifs == ' ' && strchr(ifs, c)) {
			continue;
		}
		startword = 0;
		if (ap[1] != NULL && strchr(ifs, c) != NULL) {
			STACKSTRNUL(p);
			setvar(*ap, stackblock(), 0);
			ap++;
			startword = 1;
			STARTSTACKSTR(p);
		} else {
put:
			STPUTC(c, p);
		}
	}
	STACKSTRNUL(p);
	/* Remove trailing blanks */
	while ((char *)stackblock() <= --p && strchr(ifs, *p) != NULL)
		*p = '\0';
	setvar(*ap, stackblock(), 0);
	while (*++ap != NULL)
		setvar(*ap, nullstr, 0);
	return status;
}



/*
 * umask builtin
 *
 * This code was ripped from pdksh 5.2.14 and hacked for use with
 * dash by Herbert Xu.
 *
 * Public domain.
 */

int
umaskcmd(int argc, char **argv)
{
	char *ap;
	int mask;
	int i;
	int symbolic_mode = 0;

	while ((i = nextopt("S")) != '\0') {
		symbolic_mode = 1;
	}

	INTOFF;
	mask = umask(0);
	umask(mask);
	INTON;

	if ((ap = *argptr) == NULL) {
		if (symbolic_mode) {
			char buf[18];
			int j;

			mask = ~mask;
			ap = buf;
			for (i = 0; i < 3; i++) {
				*ap++ = "ugo"[i];
				*ap++ = '=';
				for (j = 0; j < 3; j++)
					if (mask & (1 << (8 - (3*i + j))))
						*ap++ = "rwx"[j];
				*ap++ = ',';
			}
			ap[-1] = '\0';
			out1fmt("%s\n", buf);
		} else {
			out1fmt("%.4o\n", mask);
		}
	} else {
		int new_mask;

		if (isdigit(*ap)) {
			new_mask = 0;
			do {
				if (*ap >= '8' || *ap < '0')
					sh_error(illnum, *argptr);
				new_mask = (new_mask << 3) + (*ap - '0');
			} while (*++ap != '\0');
		} else {
			int positions, new_val;
			char op;

			mask = ~mask;
			new_mask = mask;
			positions = 0;
			while (*ap) {
				while (*ap && strchr("augo", *ap))
					switch (*ap++) {
					case 'a': positions |= 0111; break;
					case 'u': positions |= 0100; break;
					case 'g': positions |= 0010; break;
					case 'o': positions |= 0001; break;
					}
				if (!positions)
					positions = 0111; /* default is a */
				if (!strchr("=+-", op = *ap))
					break;
				ap++;
				new_val = 0;
				while (*ap && strchr("rwxugoXs", *ap))
					switch (*ap++) {
					case 'r': new_val |= 04; break;
					case 'w': new_val |= 02; break;
					case 'x': new_val |= 01; break;
					case 'u': new_val |= mask >> 6;
						  break;
					case 'g': new_val |= mask >> 3;
						  break;
					case 'o': new_val |= mask >> 0;
						  break;
					case 'X': if (mask & 0111)
							new_val |= 01;
						  break;
					case 's': /* ignored */
						  break;
					}
				new_val = (new_val & 07) * positions;
				switch (op) {
				case '-':
					new_mask &= ~new_val;
					break;
				case '=':
					new_mask = new_val
					    | (new_mask & ~(positions * 07));
					break;
				case '+':
					new_mask |= new_val;
				}
				if (*ap == ',') {
					positions = 0;
					ap++;
				} else if (!strchr("=+-", *ap))
					break;
			}
			if (*ap) {
				sh_error("Illegal mode: %s", *argptr);
				return 1;
			}
			new_mask = ~new_mask;
		}
		umask(new_mask);
	}
	return 0;
}

#ifdef HAVE_GETRLIMIT
/*
 * ulimit builtin
 *
 * This code, originally by Doug Gwyn, Doug Kingston, Eric Gisin, and
 * Michael Rendell was ripped from pdksh 5.0.8 and hacked for use with
 * ash by J.T. Conklin.
 *
 * Public domain.
 */

struct limits {
	const char *name;
	int	cmd;
	int	factor;	/* multiply by to get rlim_{cur,max} values */
	char	option;
};

static const struct limits limits[] = {
#ifdef RLIMIT_CPU
	{ "time(seconds)",		RLIMIT_CPU,	   1, 't' },
#endif
#ifdef RLIMIT_FSIZE
	{ "file(blocks)",		RLIMIT_FSIZE,	 512, 'f' },
#endif
#ifdef RLIMIT_DATA
	{ "data(kbytes)",		RLIMIT_DATA,	1024, 'd' },
#endif
#ifdef RLIMIT_STACK
	{ "stack(kbytes)",		RLIMIT_STACK,	1024, 's' },
#endif
#ifdef RLIMIT_CORE
	{ "coredump(blocks)",		RLIMIT_CORE,	 512, 'c' },
#endif
#ifdef RLIMIT_RSS
	{ "memory(kbytes)",		RLIMIT_RSS,	1024, 'm' },
#endif
#ifdef RLIMIT_MEMLOCK
	{ "locked memory(kbytes)",	RLIMIT_MEMLOCK, 1024, 'l' },
#endif
#ifdef RLIMIT_NPROC
	{ "process",			RLIMIT_NPROC,      1, 'p' },
#endif
#ifdef RLIMIT_NOFILE
	{ "nofiles",			RLIMIT_NOFILE,     1, 'n' },
#endif
#ifdef RLIMIT_AS
	{ "vmemory(kbytes)",		RLIMIT_AS,	1024, 'v' },
#endif
#ifdef RLIMIT_LOCKS
	{ "locks",			RLIMIT_LOCKS,	   1, 'w' },
#endif
	{ (char *) 0,			0,		   0,  '\0' }
};

enum limtype { SOFT = 0x1, HARD = 0x2 };

static void printlim(enum limtype how, const struct rlimit *limit,
		     const struct limits *l)
{
	rlim_t val;

	val = limit->rlim_max;
	if (how & SOFT)
		val = limit->rlim_cur;

	if (val == RLIM_INFINITY)
		out1fmt("unlimited\n");
	else {
		val /= l->factor;
		out1fmt("%jd\n", (intmax_t) val);
	}
}

int
ulimitcmd(int argc, char **argv)
{
	int	c;
	rlim_t val = 0;
	enum limtype how = SOFT | HARD;
	const struct limits	*l;
	int		set, all = 0;
	int		optc, what;
	struct rlimit	limit;

	what = 'f';
	while ((optc = nextopt("HSa"
#ifdef RLIMIT_CPU
			       "t"
#endif
#ifdef RLIMIT_FSIZE
			       "f"
#endif
#ifdef RLIMIT_DATA
			       "d"
#endif
#ifdef RLIMIT_STACK
			       "s"
#endif
#ifdef RLIMIT_CORE
			       "c"
#endif
#ifdef RLIMIT_RSS
			       "m"
#endif
#ifdef RLIMIT_MEMLOCK
			       "l"
#endif
#ifdef RLIMIT_NPROC
			       "p"
#endif
#ifdef RLIMIT_NOFILE
			       "n"
#endif
#ifdef RLIMIT_AS
			       "v"
#endif
#ifdef RLIMIT_LOCKS
			       "w"
#endif
	)) != '\0')
		switch (optc) {
		case 'H':
			how = HARD;
			break;
		case 'S':
			how = SOFT;
			break;
		case 'a':
			all = 1;
			break;
		default:
			what = optc;
		}

	for (l = limits; l->option != what; l++)
		;

	set = *argptr ? 1 : 0;
	if (set) {
		char *p = *argptr;

		if (all || argptr[1])
			sh_error("too many arguments");
		if (strcmp(p, "unlimited") == 0)
			val = RLIM_INFINITY;
		else {
			val = (rlim_t) 0;

			while ((c = *p++) >= '0' && c <= '9')
			{
				val = (val * 10) + (long)(c - '0');
				if (val < (rlim_t) 0)
					break;
			}
			if (c)
				sh_error("bad number");
			val *= l->factor;
		}
	}
	if (all) {
		for (l = limits; l->name; l++) {
			getrlimit(l->cmd, &limit);
			out1fmt("%-20s ", l->name);
			printlim(how, &limit, l);
		}
		return 0;
	}

	getrlimit(l->cmd, &limit);
	if (set) {
		if (how & HARD)
			limit.rlim_max = val;
		if (how & SOFT)
			limit.rlim_cur = val;
		if (setrlimit(l->cmd, &limit) < 0)
			sh_error("error setting limit (%s)", strerror(errno));
	} else {
		printlim(how, &limit, l);
	}
	return 0;
}
#endif
