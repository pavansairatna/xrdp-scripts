#!/bin/sh

case `uname` in
    Linux)
        : ${CC:=gcc} ${CFLAGS:=-g -fvar-tracking -Wl,-z,now}
        export CC CFLAGS
        ;;
    FreeBSD)
        : ${CC:=clang} ${CFLAGS:=-g}
        export CC CFLAGS
        ;;
    *) echo "**Warning: Unknown platform `uname`" >&2
esac

cd $(dirname $0) || exit $?

if grep -q -- --enable-devel-all ./configure.ac; then
    flags="--enable-devel-all" ;#" --disable-devel-logging"
else
    # xrdp 0.9.16 or earlier
    flags="--enable-xrdpdebug"
fi
flags="$flags --enable-fuse --enable-pixman"
flags="$flags --enable-ipv6"
#flags="$flags --with-imlib2"
#flags="$flags --disable-pam"
#flags="$flags --disable-rfxcodec"

if [ "$CC" = "g++" ]; then
    CFLAGS="$CFLAGS -g -Werror"
    flags="$flags --disable-neutrinordp"
elif [ "$CC" = "gcc" ]; then
    # If you enable coverage, you can run the tests, then
    # use something like:-
    # cd libipm
    # gcov -o .libs *.c
    #CFLAGS="$CFLAGS -coverage -Wl,-l,gcov"
    flags="$flags --enable-neutrinordp"
fi
exec ./configure $flags
