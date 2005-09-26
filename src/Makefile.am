# $Id$

AM_CPPFLAGS = -include $(top_builddir)/config.h
AM_YFLAGS = -d

CFLAGS = -g -O2 -Wall
DEFS = \
	-DBSD=1 -DSMALL -DSHELL \
	-DGLOB_BROKEN -DFNMATCH_BROKEN -DIFS_BROKEN \
	-D__COPYRIGHT\(x\)= -D__RCSID\(x\)= -D_DIAGASSERT\(x\)=

bin_PROGRAMS = dash

dash_CFILES = \
	alias.c arith_yylex.c cd.c error.c eval.c exec.c expand.c \
	histedit.c input.c jobs.c mail.c main.c memalloc.c miscbltin.c \
	mystring.c options.c parser.c redir.c show.c trap.c output.c \
	bltin/printf.c system.c bltin/test.c bltin/times.c var.c
dash_SOURCES = \
	$(dash_CFILES) arith.y \
	alias.h bltin/bltin.h cd.h error.h eval.h exec.h expand.h hetio.h \
	init.h input.h jobs.h machdep.h mail.h main.h memalloc.h miscbltin.h \
	myhistedit.h mystring.h options.h output.h parser.h redir.h shell.h \
	show.h system.h trap.h var.h
dash_LDADD = builtins.o init.o nodes.o signames.o syntax.o

BUILT_SOURCES = arith.h builtins.h nodes.h syntax.h token.h
CLEANFILES = \
	$(BUILT_SOURCES) $(patsubst %.o,%.c,$(dash_LDADD)) \
	arith.c mkinit mknodes mksignames mksyntax

man_MANS = dash.1
EXTRA_DIST = \
	$(man_MANS) \
	mktokens mkbuiltins builtins.def mkinit.c \
	mknodes.c nodetypes nodes.c.pat mksyntax.c mksignames.c

token.h: mktokens
	sh $^

builtins.c builtins.h: mkbuiltins shell.h builtins.def
	sh $^ . '$(CFLAGS)'

init.c: mkinit $(dash_CFILES)
	./$^

nodes.c nodes.h: mknodes nodetypes nodes.c.pat
	./$^

syntax.c syntax.h: mksyntax
	./$^

signames.c: mksignames
	./$^
