/*-
 * Copyright (c) 2002
 *	Herbert Xu.
 * Copyright (c) 1993
 *	The Regents of the University of California.  All rights reserved.
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

#include <stdlib.h>
#include "arith.h"
#include "expand.h"
#include "error.h"

extern int yylval;
extern const char *arith_buf, *arith_startbuf;

int
yylex()
{
	int value;
	const char *buf = arith_buf;

	for (;;) {
		switch (*buf) {
		case ' ':
		case '\t':
		case '\n':
			buf++;
			continue;
		default:
err:
			sh_error("arith: syntax error: \"%s\"", arith_startbuf);
			/* NOTREACHED */
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			yylval = strtoll(buf, (char **) &arith_buf, 0);
			return ARITH_NUM;
		case '=':
			if (*++buf != '=') {
				goto err;
			}
			value = ARITH_EQ;
			break;
		case '>':
			switch (*++buf) {
			case '=':
				value = ARITH_GE;
				break;
			case '>':
				value = ARITH_RSHIFT;
				break;
			default:
				value = ARITH_GT;
				goto out;
			}
			break;
		case '<':
			switch (*++buf) {
			case '=':
				value = ARITH_LE;
				break;
			case '<':
				value = ARITH_LSHIFT;
				break;
			default:
				value = ARITH_LT;
				goto out;
			}
			break;
		case '|':
			if (*++buf != '|') {
				value = ARITH_BOR;
				goto out;
			}
			value = ARITH_OR;
			break;
		case '&':
			if (*++buf != '&') {
				value = ARITH_BAND;
				goto out;
			}
			value = ARITH_AND;
			break;
		case '!':
			if (*++buf != '=') {
				value = ARITH_NOT;
				goto out;
			}
			value = ARITH_NE;
			break;
		case 0:
			value = 0;
			goto out;
		case '(':
			value = ARITH_LPAREN;
			break;
		case ')':
			value = ARITH_RPAREN;
			break;
		case '*':
			value = ARITH_MUL;
			break;
		case '/':
			value = ARITH_DIV;
			break;
		case '%':
			value = ARITH_REM;
			break;
		case '+':
			value = ARITH_ADD;
			break;
		case '-':
			value = ARITH_SUB;
			break;
		case '~':
			value = ARITH_BNOT;
			break;
		case '^':
			value = ARITH_BXOR;
			break;
		}
		break;
	}

	buf++;
out:
	arith_buf = buf;
	return value;
}
