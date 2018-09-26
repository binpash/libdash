#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#define DEBUG
#include "shell.h"
#include "parser.h"
#include "nodes.h"
#include "mystring.h"
#include "show.h"
#include "options.h"
#include "init.h"
#include "input.h"

/* This file is a mash-up of dash/src/show.c, compiling out a special
   version of dash into a shared library. The end goal is pulling out
   the dash parser so we can work with it in Ocaml.

   I mostly wrote this file to make sure I built the library
   correctly. Next step is getting the C AST into Ocaml.
*/

static void shtree(union node *, int, char *, FILE*);
static void shcmd(union node *, FILE *);
static void sharg(union node *, FILE *);
static void indent(int, char *, FILE *);
static void trstring(char *);

int main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s [command to evaluate]\n", argv[0]);
    return -1;
  }

  char *cmd = strdup(argv[1]);

  /* debugging unsigned char issues */
  // printf("CTLESC = %hhu\n", (unsigned char) CTLESC);
  // printf("CTLVAR = %hhu\n", (unsigned char) CTLVAR);
  // printf("CTLENDVAR = %hhu\n", (unsigned char) CTLENDVAR);
  // printf("CTLBACKQ = %hhu\n", (unsigned char) CTLBACKQ);
  // printf("CTLARI = %hhu\n", (unsigned char) CTLARI);
  // printf("CTLENDARI = %hhu\n", (unsigned char) CTLENDARI);
  // printf("CTLQUOTEMARK = %hhu\n", (unsigned char) CTLQUOTEMARK);
  
  init();

  setinputstring(cmd);

  union node *n = parsecmd(0);
  if (n != (union node *) EOF) {
    showtree(n);    
  } else {
    fprintf(stderr, "Hit eof...");

  }

  popfile();
  free(cmd);
  
  return 0;
}

void
showtree(union node *n)
{
	trputs("showtree called\n");
	shtree(n, 1, NULL, stdout);
}


static void
shtree(union node *n, int ind, char *pfx, FILE *fp)
{
	struct nodelist *lp;
	const char *s;

	if (n == NULL)
		return;

	indent(ind, pfx, fp);
	switch(n->type) {
	case NSEMI:
		s = "; ";
		goto binop;
	case NAND:
		s = " && ";
		goto binop;
	case NOR:
		s = " || ";
binop:
		shtree(n->nbinary.ch1, ind, NULL, fp);
	   /*    if (ind < 0) */
			fputs(s, fp);
		shtree(n->nbinary.ch2, ind, NULL, fp);
		break;
	case NCMD:
		shcmd(n, fp);
		if (ind >= 0)
			putc('\n', fp);
		break;
	case NPIPE:
		for (lp = n->npipe.cmdlist ; lp ; lp = lp->next) {
			shcmd(lp->n, fp);
			if (lp->next)
				fputs(" | ", fp);
		}
		if (n->npipe.backgnd)
			fputs(" &", fp);
		if (ind >= 0)
			putc('\n', fp);
		break;
        case NWHILE:
          fprintf(fp, "while\n");
          shtree(n->nbinary.ch1, ind+1, NULL, fp);
          indent(ind, pfx, fp);
          fprintf(fp, "do;\n");
          shtree(n->nbinary.ch2, ind+1, NULL, fp);
          indent(ind, pfx, fp);
          fprintf(fp,"done\n");
          break;
	default:
		fprintf(fp, "<node type %d>", n->type);
		if (ind >= 0)
			putc('\n', fp);
		break;
	}
}



static void
shcmd(union node *cmd, FILE *fp)
{
	union node *np;
	int first;
	const char *s;
	int dftfd;

	first = 1;
	for (np = cmd->ncmd.args ; np ; np = np->narg.next) {
		if (! first)
			putchar(' ');
		sharg(np, fp);
		first = 0;
	}
	for (np = cmd->ncmd.redirect ; np ; np = np->nfile.next) {
		if (! first)
			putchar(' ');
		switch (np->nfile.type) {
			case NTO:	s = ">";  dftfd = 1; break;
			case NCLOBBER:	s = ">|"; dftfd = 1; break;
			case NAPPEND:	s = ">>"; dftfd = 1; break;
			case NTOFD:	s = ">&"; dftfd = 1; break;
			case NFROM:	s = "<";  dftfd = 0; break;
			case NFROMFD:	s = "<&"; dftfd = 0; break;
			case NFROMTO:	s = "<>"; dftfd = 0; break;
			default:  	s = "*error*"; dftfd = 0; break;
		}
		if (np->nfile.fd != dftfd)
			fprintf(fp, "%d", np->nfile.fd);
		fputs(s, fp);
		if (np->nfile.type == NTOFD || np->nfile.type == NFROMFD) {
			fprintf(fp, "%d", np->ndup.dupfd);
		} else {
			sharg(np->nfile.fname, fp);
		}
		first = 0;
	}
}



static void
sharg(union node *arg, FILE *fp)
{
	char *p;
	struct nodelist *bqlist;
	int subtype;

	if (arg->type != NARG) {
		printf("<node type %d>\n", arg->type);
		abort();
	}
	bqlist = arg->narg.backquote;
	for (p = arg->narg.text ; *p ; p++) {
		switch ((signed char)*p) {
		case CTLESC:
			putc(*++p, fp);
			break;
		case CTLVAR:
			putc('$', fp);
			putc('{', fp);
			subtype = *++p;
			if (subtype == VSLENGTH)
				putc('#', fp);

			while (*p != '=')
				putc(*p++, fp);

			if (subtype & VSNUL)
				putc(':', fp);

			switch (subtype & VSTYPE) {
			case VSNORMAL:
				putc('}', fp);
				break;
			case VSMINUS:
				putc('-', fp);
				break;
			case VSPLUS:
				putc('+', fp);
				break;
			case VSQUESTION:
				putc('?', fp);
				break;
			case VSASSIGN:
				putc('=', fp);
				break;
			case VSTRIMLEFT:
				putc('#', fp);
				break;
			case VSTRIMLEFTMAX:
				putc('#', fp);
				putc('#', fp);
				break;
			case VSTRIMRIGHT:
				putc('%', fp);
				break;
			case VSTRIMRIGHTMAX:
				putc('%', fp);
				putc('%', fp);
				break;
			case VSLENGTH:
				break;
			default:
				printf("<subtype %d>", subtype);
			}
			break;
		case CTLENDVAR:
		     putc('}', fp);
		     break;
		case CTLBACKQ:
			putc('$', fp);
			putc('(', fp);
			shtree(bqlist->n, -1, NULL, fp);
			putc(')', fp);
			break;
		default:
			putc(*p, fp);
			break;
		}
	}
}


static void
indent(int amount, char *pfx, FILE *fp)
{
	int i;

	for (i = 0 ; i < amount ; i++) {
		if (pfx && i == amount - 1)
			fputs(pfx, fp);
		putc('\t', fp);
	}
}



/*
 * Debugging stuff.
 */


FILE *tracefile;


void
trputc(int c)
{
	if (debug != 1)
		return;
	putc(c, tracefile);
}

void
trace(const char *fmt, ...)
{
	va_list va;

	if (debug != 1)
		return;
	va_start(va, fmt);
	(void) vfprintf(tracefile, fmt, va);
	va_end(va);
}

void
tracev(const char *fmt, va_list va)
{
	if (debug != 1)
		return;
	(void) vfprintf(tracefile, fmt, va);
}


void
trputs(const char *s)
{
	if (debug != 1)
		return;
	fputs(s, tracefile);
}


static void
trstring(char *s)
{
	char *p;
	char c;

	if (debug != 1)
		return;
	putc('"', tracefile);
	for (p = s ; *p ; p++) {
		switch ((signed char)*p) {
		case '\n':  c = 'n';  goto backslash;
		case '\t':  c = 't';  goto backslash;
		case '\r':  c = 'r';  goto backslash;
		case '"':  c = '"';  goto backslash;
		case '\\':  c = '\\';  goto backslash;
		case CTLESC:  c = 'e';  goto backslash;
		case CTLVAR:  c = 'v';  goto backslash;
		case CTLBACKQ:  c = 'q';  goto backslash;
backslash:	  putc('\\', tracefile);
			putc(c, tracefile);
			break;
		default:
			if (*p >= ' ' && *p <= '~')
				putc(*p, tracefile);
			else {
				putc('\\', tracefile);
				putc(*p >> 6 & 03, tracefile);
				putc(*p >> 3 & 07, tracefile);
				putc(*p & 07, tracefile);
			}
			break;
		}
	}
	putc('"', tracefile);
}


void
trargs(char **ap)
{
	if (debug != 1)
		return;
	while (*ap) {
		trstring(*ap++);
		if (*ap)
			putc(' ', tracefile);
		else
			putc('\n', tracefile);
	}
}


void
opentrace(void)
{
	char s[100];
#ifdef O_APPEND
	int flags;
#endif

	if (debug != 1) {
		if (tracefile)
			fflush(tracefile);
		/* leave open because libedit might be using it */
		return;
	}
#ifdef not_this_way
	{
		char *p;
		if ((p = getenv(homestr)) == NULL) {
			if (geteuid() == 0)
				p = "/";
			else
				p = "/tmp";
		}
		scopy(p, s);
		strcat(s, "/trace");
	}
#else
	scopy("./trace", s);
#endif /* not_this_way */
	if (tracefile) {
#ifndef __KLIBC__
		if (!freopen(s, "a", tracefile)) {
#else
		if (!(!fclose(tracefile) && (tracefile = fopen(s, "a")))) {
#endif /* __KLIBC__ */
			fprintf(stderr, "Can't re-open %s\n", s);
			debug = 0;
			return;
		}
	} else {
		if ((tracefile = fopen(s, "a")) == NULL) {
			fprintf(stderr, "Can't open %s\n", s);
			debug = 0;
			return;
		}
	}
#ifdef O_APPEND
	if ((flags = fcntl(fileno(tracefile), F_GETFL, 0)) >= 0)
		fcntl(fileno(tracefile), F_SETFL, flags | O_APPEND);
#endif
#ifndef __KLIBC__
	setlinebuf(tracefile);
#endif /* __KLIBC__ */
	fputs("\nTracing started.\n", tracefile);
}

