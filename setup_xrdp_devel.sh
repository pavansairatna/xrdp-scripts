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
        cd ..
        chmod 755 "$dir" || exit $?
    fi
done

echo "- Installing dependencies"
sudo xrdp/scripts/install_xrdp_build_dependencies_with_apt.sh max $(dpkg --print-architecture) || exit $?
sudo xrdp/scripts/install_cppcheck_dependencies_with_apt.sh || exit $?
sudo xorgxrdp/scripts/install_xorgxrdp_build_dependencies_with_apt.sh $(dpkg --print-architecture) || exit $?

if [ ! -x /usr/bin/gmake ]; then
    echo "- Setting up gmake link"
    sudo ln -s make /usr/bin/gmake
fi

echo "- Setting up links to development areas for xorgxrdp"
sudo ln -sf $HOME/xorgxrdp/module/.libs/libxorgxrdp.so /usr/lib/xorg/modules/libxorgxrdp.so
sudo ln -sf $HOME/xorgxrdp/xrdpdev/.libs/xrdpdev_drv.so /usr/lib/xorg/modules/drivers/xrdpdev_drv.so
sudo ln -sf $HOME/xorgxrdp/xrdpkeyb/.libs/xrdpkeyb_drv.so /usr/lib/xorg/modules/input/xrdpkeyb_drv.so
sudo ln -sf $HOME/xorgxrdp/xrdpmouse/.libs/xrdpmouse_drv.so /usr/lib/xorg/modules/input/xrdpmouse_drv.so
sudo ln -sf $HOME/xorgxrdp/xrdpdev/xrdp.conf /etc/X11/xrdp/
