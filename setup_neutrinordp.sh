#!/bin/sh
# Sets up a Debian based machine for xrdp development

cd ~

if [ ! -d NeutrinoRDP ]; then
    echo "- Fetching NeutrinoRDP..."
    git clone https://github.com/neutrinolabs/NeutrinoRDP.git || exit $?
fi

if [ ! -x /usr/local/bin/xfreerdp ]; then
    echo "- Building NeutrinoRDP..."
    cd NeutrinoRDP || exit $?
    sudo apt-get install cmake xmlto libssl-dev libx11-dev libxext-dev libxinerama-dev \
  libxcursor-dev libxdamage-dev libxv-dev libxkbfile-dev libasound2-dev libcups2-dev libxml2 libxml2-dev \
  libxrandr-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libxi-dev ffmpeg
    cmake -DCMAKE_BUILD_TYPE=Debug -DWITH_SSE2=ON . || exit $?
    make || exit $?
    sudo make install
    cd ..
fi
