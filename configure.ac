AC_INIT(quickml.in)
AM_INIT_AUTOMAKE(quickml, 0.7)

AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET

AC_PATH_PROG(RUBY, ruby, no)
if test "$RUBY" = "no"; then
    AC_MSG_ERROR(ruby not found)
fi

AC_ARG_WITH(
    user,
    [  --with-user=USER        quickml runs as USER [[root]]],
    [USER=${withval}], [USER='root']
)
AC_SUBST(USER)

AC_ARG_WITH(
    group,
    [  --with-group=GROUP      quickml runs as GROUP [[root]]],
    [GROUP=${withval}], [GROUP='root']
)
AC_SUBST(GROUP)

AC_ARG_WITH(
    pidfile,
    [  --with-pidfile=FILE     PID is stored in FILE  [[/var/run/quickml.pid]]],
    [PIDFILE=${withval}], [PIDFILE='/var/run/quickml.pid']
)
AC_SUBST(PIDFILE)

AC_ARG_WITH(
    logfile,
    [  --with-logfile=FILE     Log is recorded in FILE [[/var/log/quickml.log]]],
    [LOGFILE=${withval}], [LOGFILE='/var/log/quickml.log']
)
AC_SUBST(LOGFILE)

AM_PATH_RUBYDIR
AM_MAINTAINER_MODE

AC_OUTPUT([	Makefile
                lib/Makefile
                lib/quickml/Makefile])
