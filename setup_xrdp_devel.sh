#!/bin/sh
# Sets up a Debian based machine for xrdp development

cd ~

DISTRIBUTION=$(lsb_release -si)
RELEASE=$(lsb_release -sr)

case "$DISTRIBUTION-$RELEASE" in
    Ubuntu-22.04)
        ;;
    *)  echo "** This script is not tested on $DISTRIBUTION $RELEASE" 2>&2
        ;;
esac

# Development tools
#
# To get meld icons working over X11 forwarding you might have to install
# a Mint theme, or set up a link in ~/.icons. No good workaround has
# been found for this.
set -- \
    /usr/bin/gvim    vim-gtk3 \
    /usr/bin/meld    meld \
    /usr/bin/astyle  astyle \
    /usr/bin/chronyc  chrony \
    /usr/share/man/man2/waitpid.2.gz manpages-dev \

PACKAGES=
while [ $# -ge 2 ]; do
    if [ ! -x "$1" ]; then
        PACKAGES="$PACKAGES $2"
    fi
    shift 2
done
if [ -n "$PACKAGES" ]; then
    if [ -x /usr/bin/apt ]; then
        echo "- installing development tools"
        sudo apt install -y $PACKAGES || exit $?
    else
        echo "- Can't install$PACKAGES - not a dpkg-based system"
    fi
fi

# Allow the testuser to read our home directory
echo "- Setting permissions on home directory"
chmod 751 $HOME || exit $?

# Other changes
echo "- Setting old scrollbar behaviour"
cat <<EOF >~/.config/gtk-3.0/settings.ini
[Settings]
gtk-primary-button-warps-slider = false
EOF

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
        chmod 755 "$dir" || exit $?
    fi
done

# Repos I can't write to
for dir in NeutrinoRDP; do
    if [ ! -d "$dir" ]; then
        echo "- Fetching $dir repo..."
        git clone https://github.com/neutrinolabs/$dir.git || exit $?
        chmod 755 "$dir" || exit $?
    fi
done

if [ ! -x /usr/bin/apt ]; then
    echo "- Can't install xrdp dependencies - not a dpkg-based system"
else
    echo "- Installing dependencies"
    sudo xrdp/scripts/install_xrdp_build_dependencies_with_apt.sh max $(dpkg --print-architecture) || exit $?
    sudo xrdp/scripts/install_cppcheck_dependencies_with_apt.sh || exit $?
    sudo xorgxrdp/scripts/install_xorgxrdp_build_dependencies_with_apt.sh $(dpkg --print-architecture) || exit $?
fi

if [ ! -x /usr/bin/gmake ]; then
    echo "- Setting up gmake link"
    sudo ln -s make /usr/bin/gmake
fi

echo "- Setting up links to development areas for xorgxrdp"
MODULES_DIR=/usr/lib64/xorg/modules
if [ ! -d $MODULES_DIR ]; then
    MODULES_DIR=/usr/lib/xorg/modules
fi
sudo ln -sf $HOME/xorgxrdp/module/.libs/libxorgxrdp.so $MODULES_DIR/libxorgxrdp.so
sudo ln -sf $HOME/xorgxrdp/xrdpdev/.libs/xrdpdev_drv.so $MODULES_DIR/drivers/xrdpdev_drv.so
sudo ln -sf $HOME/xorgxrdp/xrdpkeyb/.libs/xrdpkeyb_drv.so $MODULES_DIR/input/xrdpkeyb_drv.so
sudo ln -sf $HOME/xorgxrdp/xrdpmouse/.libs/xrdpmouse_drv.so $MODULES_DIR/input/xrdpmouse_drv.so
if [ ! -d /etc/X11/xrdp/ ]; then
    sudo install -dm 755 -o root -g root /etc/X11/xrdp/
fi

sudo ln -sf $HOME/xorgxrdp/xrdpdev/xorg.conf /etc/X11/xrdp/

case "$DISTRIBUTION-$RELEASE" in
    Ubuntu-22.04)
        # Use gcc 12 by default
        sudo apt install gcc-12 g++-12
        sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100 --slave /usr/bin/g++ g++ /usr/bin/g++-11 --slave /usr/bin/gcov gcov /usr/bin/gcov-11
        sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 150 --slave /usr/bin/g++ g++ /usr/bin/g++-12 --slave /usr/bin/gcov gcov /usr/bin/gcov-12
        ;;
esac
