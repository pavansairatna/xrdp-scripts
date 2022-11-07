#!/bin/sh

echo "- Setting up library links"
cd /usr/local/lib/xrdp || exit $?
for file in *.so*; do
    if [ -h $file ]; then
        :
    elif [ -f $file ]; then
	dest=$(find ~/xrdp -type f -name $file)
	set -- $dest
	if [ $# -eq 0 ]; then
            echo "** Can't find file for $file" >&2
            exit 1
        elif [ $# -gt 1 ]; then
            echo "** Found multiple matches for $file" >&2
            exit 1
        else
            set -- $(file -b $dest)
            if [ $1 != ELF ]; then
                echo "Link $dest is not an ELF file" >&2
                exit 1
            else
                sudo ln -sf $dest $file
            fi
        fi
    fi
done
echo "- Setting up binary links"
set -- \
    SETDIR          /usr/local/bin \
    xrdp-genkeymap  genkeymap/ \
    xrdp-keygen     keygen/.libs/ \
    xrdp-mkfv1      fontutils/.libs/ \
    xrdp-dumpfv1    fontutils/.libs/ \
    xrdp-dis        sesman/tools/.libs/ \
    xrdp-sesadmin   sesman/tools/.libs/ \
    xrdp-sesrun     sesman/tools/.libs/ \
    SETDIR          /usr/local/sbin \
    xrdp            xrdp/.libs/ \
    xrdp-sesman     sesman/.libs/ \
    xrdp-chansrv     sesman/chansrv/.libs/ \

while [ $# -ge 2 ]; do
    if [ $1 = SETDIR ]; then
        cd $2 || exit $?
    else
        dest=$HOME/xrdp/$2/$1
        if [ ! -x $dest ]; then
            echo "** Warning: Can't find target $dest" >&2
        fi
        sudo ln -sf $dest ./$1
    fi
    shift 2
done

echo "- Setting up /usr/local/share/xrdp links"
cd /usr/local/share/xrdp || exit $?
for file in sans-10.fv1 sans-18.fv1; do
    sudo ln -sf $HOME/xrdp/xrdp/$file .
done

