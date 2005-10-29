AC_INIT(dash, 0.5.2)
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

dnl Checks for libraries.

dnl Checks for header files.

dnl Checks for library functions.
AC_CHECK_FUNCS(mempcpy sigsetmask stpcpy strchrnul strtoimax strtoumax)

AC_CONFIG_FILES([Makefile src/Makefile])
AC_OUTPUT
