#!/bin/sh

: ${CC:=gcc} ${CFLAGS:=-g -fvar-tracking\ -Wl,-z,now}
export CC CFLAGS

cd $(dirname $0) || exit $?

if grep -q -- --enable-devel-all ./configure.ac; then
    flags="--enable-devel-all" ;#" --disable-devel-logging"
else
    # xrdp 0.9.16 or earlier
    flags="--enable-xrdpdebug"
fi
flags="$flags --enable-fuse --enable-pixman --enable-ipv6 --with-imlib2"
#flags="$flags --disable-pam"
#flags="$flags --disable-rfxcodec"

if [ $CC = "g++" ]; then
    CFLAGS="$CFLAGS -g -Werror"
    flags="$flags --disable-neutrinordp"
else
    flags="$flags --enable-neutrinordp"
fi
exec ./configure $flags
