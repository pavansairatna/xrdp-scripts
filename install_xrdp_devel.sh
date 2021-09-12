#!/bin/bash

set -e

declare TARGET_DIR=~/xrdp
declare SOURCE_REPO='https://github.com/neutrinolabs/xrdp.git'
declare SCRIPTS_DIR=~/xrdp-scripts
declare SCRIPTS_REPO='https://github.com/matt335672/xrdpu-scripts.git'

declare OTHER_REPOS=" \
        matt ssh://git@github.com/matt335672/xrdp.git \
        "

# Removed flex, bison, intltool xsltproc xutils xml2-dev python-libxml2
declare -a DEPENDENCIES=()

# Development tools
DEPENDENCIES+=( autoconf libtool pkg-config gcc g++ nasm make )

# Libraries
DEPENDENCIES+=( libfuse-dev libimlib2-dev libjpeg-dev libmp3lame-dev \
	libpam0g-dev libpixman-1-dev libssl-dev libx11-dev \
	libxfixes-dev libxrandr-dev xutils-dev xserver-xorg-dev )

echo "- Installing dependencies"
sudo apt install -y ${DEPENDENCIES[@]}

# Check git is installed
if ! [ -x /usr/bin/git ]; then
    sudo apt install -y git
fi

# Clone the scripts dir, if it isn't already in place
if ! [ -d $SCRIPTS_DIR ]; then
    git clone "$SCRIPTS_REPO" "$SCRIPTS_DIR"
fi

git clone "$SOURCE_REPO" "$TARGET_DIR"
cd $TARGET_DIR
set -- $OTHER_REPOS
while [ $# -ge 2 ]; do
    git remote add $1 $2
    git fetch $1
    shift 2
done
$SCRIPTS_DIR/myconfig.sh .

./bootstrap
./myconfig.sh
gmake
sudo gmake install
sudo $SCRIPTS_DIR/link_exes_and_libs.sh "$TARGET_DIR"
