#!/bin/sh
# Sets up a Debian based machine for xrdp development

cd ~

if [ ! -d xrdp ]; then
    echo "- Fetching xrdp repo..."
    git clone https://github.com/neutrinolabs/xrdp.git || exit $?
    cd xrdp
    git remote add matt	ssh://git@github.com/matt335672/xrdp.git
    ln -s ../xrdp-scripts/myconfig.sh .
    cd ..
fi

if [ ! -d xorgxrdp ]; then
    echo "- Fetching xorgxrdp repo..."
    git clone https://github.com/neutrinolabs/xorgxrdp.git || exit $?
    cd xorgxrdp
    git remote add matt	ssh://git@github.com/matt335672/xorgxrdp.git
    cd ..
fi

echo "- Installing dependencies"
if [ ! -x /usr/bin/astyle ]; then
    # Still supported(!)
    sudo apt-get -y install astyle || exit $?
fi
sudo xrdp/scripts/install_xrdp_build_dependencies_with_apt.sh max $(dpkg --print-architecture) || exit $?
sudo xrdp/scripts/install_cppcheck_dependencies_with_apt.sh || exit $?

if [ ! -d NeutrinoRDP ]; then
    echo "- Fetching NeutrinoRDP..."
    git clone https://github.com/neutrinolabs/NeutrinoRDP.git
fi

if [ ! /usr/local/bin/xfreerdp ]; then
    echo "- Building NeutrinoRDP..."
    cd NeutrinoRDP
    sudo apt-get install cmake xmlto libssl-dev libx11-dev libxext-dev libxinerama-dev \
  libxcursor-dev libxdamage-dev libxv-dev libxkbfile-dev libasound2-dev libcups2-dev libxml2 libxml2-dev \
  libxrandr-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libxi-dev ffmpeg
    cmake -DCMAKE_BUILD_TYPE=Debug -DWITH_SSE2=ON . || exit $?
    make || exit $?
    sudo make install
    cd ..
fi

if [ ! -x /usr/bin/gmake ]; then
    echo "- Setting up gmake link"
    sudo ln -s make /usr/bin/gmake
fi
