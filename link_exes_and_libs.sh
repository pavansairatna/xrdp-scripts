#!/bin/bash

if [ -z "$1" ]; then
    echo "** Need to specify build directory to link into" >&2
    exit 1
fi
BUILD_DIR=$1
shift

if [ -z "$1" ]; then
    PREFIX=/usr/local
else
    PREFIX=$1
fi

declare -a SBIN_EXE=(
    xrdp/.libs/xrdp
    sesman/.libs/xrdp-sesman
    sesman/chansrv/.libs/xrdp-chansrv
    )

declare -a BIN_EXE=(
    sesman/tools/.libs/xrdp-dis
    genkeymap/xrdp-genkeymap
    keygen/.libs/xrdp-keygen
    sesman/tools/.libs/xrdp-sesadmin
    sesman/tools/.libs/xrdp-sesrun
    )

declare -a XRDP_LIBS=(
    common/.libs/libcommon.so.0.0.0
    sesman/libscp/.libs/libscp.so.0.0.0
    xrdpapi/.libs/libxrdpapi.so.0.0.0
    libxrdp/.libs/libxrdp.so.0.0.0
    )

XRDP_LIBS+=( \
    mc/.libs/libmc.so
    neutrinordp/.libs/libxrdpneutrinordp.so
    vnc/.libs/libvnc.so
    xup/.libs/libxup.so
    )

declare -a OTHER_LIBS=(
    libpainter/src/.libs/libpainter.so.0.0.0
    librfxcodec/src/.libs/librfxencode.so.0.0.0
    )

for exe in ${SBIN_EXE[@]}; do
    if [ ! -x $BUILD_DIR/$exe ]; then
        echo "** Warning : $BUILD_DIR/$exe is not present" >&2
    fi

    targ=$PREFIX/sbin/${exe##*/}
    rm -f $targ
    ln -s $BUILD_DIR/$exe $targ
done

for exe in ${BIN_EXE[@]}; do
    if [ ! -x $BUILD_DIR/$exe ]; then
        echo "** Warning : $BUILD_DIR/$exe is not present" >&2
    fi

    targ=$PREFIX/bin/${exe##*/}
    rm -f $targ
    ln -s $BUILD_DIR/$exe $targ
done

for lib in ${XRDP_LIBS[@]}; do
    if [ ! -x $BUILD_DIR/$lib ]; then
        echo "** Warning : $BUILD_DIR/$lib is not present" >&2
    fi

    targ=$PREFIX/lib/xrdp/${lib##*/}
    rm -f $targ
    ln -s $BUILD_DIR/$lib $targ
done

for lib in ${OTHER_LIBS[@]}; do
    if [ ! -x $BUILD_DIR/$lib ]; then
        echo "** Warning : $BUILD_DIR/$lib is not present" >&2
    fi

    targ=$PREFIX/lib/${lib##*/}
    rm -f $targ
    ln -s $BUILD_DIR/$lib $targ
done
