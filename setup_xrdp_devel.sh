#!/bin/sh
# Sets up a Debian based machine for xrdp development

cd ~

# Development tools
set -- \
    /usr/bin/gvim    vim-gtk3 \
    /usr/bin/meld    meld \
    /usr/bin/astyle  astyle

PACKAGES=
while [ $# -ge 2 ]; do
    if [ ! -x "$1" ]; then
        PACKAGES="$PACKAGES $2"
    fi
    shift 2
done
if [ -n "$PACKAGES" ]; then
    echo "- installing development tools"
    sudo apt install -y $PACKAGES || exit $?
fi

# Repos I can write to
for dir in xrdp xorgxrdp pulseaudio-module-xrdp; do
    if [ ! -d "$dir" ]; then
        echo "- Fetching $dir repo..."
        git clone https://github.com/neutrinolabs/$dir.git || exit $?
        cd $dir
        git remote add matt ssh://git@github.com/matt335672/$dir.git
        case "$dir" in
            xrdp)
                ln -s ../xrdp-scripts/myconfig.sh .
                ;;
        esac
        cd ..
    fi
done

# Repos I can't write to
for dir in NeutrinoRDP; do
    if [ ! -d "$dir" ]; then
        echo "- Fetching $dir repo..."
        git clone https://github.com/neutrinolabs/$dir.git || exit $?
        cd ..
    fi
done

echo "- Installing dependencies"
sudo xrdp/scripts/install_xrdp_build_dependencies_with_apt.sh max $(dpkg --print-architecture) || exit $?
sudo xrdp/scripts/install_cppcheck_dependencies_with_apt.sh || exit $?

if [ ! -x /usr/bin/gmake ]; then
    echo "- Setting up gmake link"
    sudo ln -s make /usr/bin/gmake
fi
