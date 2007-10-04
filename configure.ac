AC_INIT(dash, 0.5.4)
AM_INIT_AUTOMAKE([foreign])
AC_CONFIG_SRCDIR([src/main.c])

AC_CONFIG_HEADERS(config.h)

dnl Checks for programs.
AC_PROG_CC
AC_GNU_SOURCE
AC_PROG_YACC

AC_MSG_CHECKING([for build system compiler])
if test "$cross_compiling" = yes; then
	CC_FOR_BUILD=${CC_FOR_BUILD-cc}
else
	CC_FOR_BUILD=${CC}
fi
AC_MSG_RESULT(${CC_FOR_BUILD})
AC_SUBST(CC_FOR_BUILD)

AC_ARG_ENABLE(static, AS_HELP_STRING(--enable-static, \
				     [Build statical linked program]))
if test "$enable_static" = "yes"; then
	export LDFLAGS="-static -Wl,--fatal-warnings"
fi

dnl Checks for libraries.

dnl Checks for header files.

dnl Checks for library functions.
AC_CHECK_FUNCS(bsearch getpwnam getrlimit isalpha killpg mempcpy sigsetmask \
	       stpcpy strchrnul strsignal strtod strtoimax strtoumax sysconf)

dnl Check for klibc signal.
AC_CHECK_FUNC(signal)
if test "$ac_cv_func_signal" != yes; then
	AC_CHECK_FUNC(bsd_signal,
		      [AC_DEFINE(signal, bsd_signal,
				 [klibc has bsd_signal instead of signal])])
fi

dnl Check for stat64 (dietlibc/klibc).
AC_CHECK_FUNC(stat64,, [
	AC_DEFINE(fstat64, fstat, [64-bit operations are the same as 32-bit])
	AC_DEFINE(lstat64, lstat, [64-bit operations are the same as 32-bit])
	AC_DEFINE(stat64, stat, [64-bit operations are the same as 32-bit])
	AC_DEFINE(open64, open, [64-bit operations are the same as 32-bit])
])

AC_ARG_WITH(libedit, AS_HELP_STRING(--with-libedit, [Compile with libedit support]))
use_libedit=
if test "$with_libedit" = "yes"; then
	AC_CHECK_LIB(edit, history_init, [
		AC_CHECK_HEADER([histedit.h], [use_libedit="yes"],
				AC_MSG_ERROR(
					[Can't find required header files.]))])
fi
if test "$use_libedit" != "yes"; then
	AC_DEFINE([SMALL], 1, [Define if you build with -DSMALL])
else
	export LIBS="$LIBS -ledit"
fi
AC_CONFIG_FILES([Makefile src/Makefile])
AC_OUTPUT
