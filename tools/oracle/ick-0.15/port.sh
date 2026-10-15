#!/bin/sh
# Ports ick 0.15's K&R varargs.h code to stdarg so a current gcc accepts it.
set -eu
src="$1"

sed -i \
  -e 's/#include <varargs.h>/#include <stdarg.h>/' \
  -e 's/^char \*aref(va_alist) va_dcl/char *aref(unsigned int type, ...)/' \
  -e 's/^void resize(va_alist) va_dcl/void resize(unsigned int type, ...)/' \
  -e 's/^  va_start(ap);/  va_start(ap, type);/' \
  -e '/^  type = va_arg(ap, unsigned int);/d' \
  -e 's/forget = va_arg(ap, bool);/forget = va_arg(ap, int);/' \
  -e 's/^  unsigned int type;$/  /' \
  "$src/cesspool.c"

sed -i \
  -e 's/^extern char \*aref();/extern char *aref(unsigned int type, ...);/' \
  -e 's/^extern void resize();/extern void resize(unsigned int type, ...);/' \
  "$src/abcess.h"

sed -i -e 's/^int[[:space:]]*yylineno = 1;$//' "$src/lexer.l"
