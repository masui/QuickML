AC_DEFUN(AM_PATH_RUBYDIR,
 [dnl # 
  dnl # Check Ruby directory
  dnl #
  AC_SUBST(rubydir)
  AC_ARG_WITH(rubydir,
    [  --with-rubydir=DIR      Ruby library files go to DIR [[guessed]]],
    [case "${withval}" in
       yes)	rubydir= ;;
       no)	AC_MSG_ERROR(rubydir is not available) ;;
       *)	rubydir=${withval} ;;
     esac], rubydir=)
  AC_MSG_CHECKING([where .rb files should go])
  if test "x$rubydir" = x; then
    changequote(<<, >>)
    rubydir=`ruby -rrbconfig -e 'puts Config::CONFIG["sitelibdir"]'`
    changequote([, ])
  fi
  AC_MSG_RESULT($rubydir)
  AC_SUBST(rubydir)])


