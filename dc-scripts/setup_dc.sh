#!/bin/bash

# Sets up a standalone SAMBA-based Domain Controller for Kerberos, etc testing
#
# This really needs more testing. Use at your own risk!

# -----------------------------------------------------------------------------
# G L O B A L S
# -----------------------------------------------------------------------------
# Packages needed early on in this script
# Odd values are executables provided by the even value packages
readonly G_INITIAL_PACKAGES="\
    /usr/bin/chronyc chronyc \
    /usr/bin/ipcalc ipcalc \
    "

# Networking values
declare G_HOSTNAME=
declare G_FQDN=
declare G_IP_ADDR=
declare G_NETMASK_BITS=
declare G_DEFAULT_ROUTE=
declare G_DOMAIN=
declare G_REALM=

# Values in dc.params
declare G_DNS_RESOLVER=
declare G_NTP_SERVERS=
declare G_DHCP_LOW_ADDR=
declare G_DHCP_HIGH_ADDR=

# -----------------------------------------------------------------------------
# I N S T A L L   I N I T I A L   P A C K A G E S
# -----------------------------------------------------------------------------
InstallInitialPackages()
{
    local -a plist=()

    set -- $G_INITIAL_PACKAGES
    while [[ $# -gt 2 ]]; do
        if [[ ! -x $1 ]]; then
            plist+=( $2 )
        fi
        shift 2
    done

    if [[ ${#plist[@]} -gt 0 ]]; then
        echo "- Installing packages ${plist[@]}"
        apt-get install -y ${plist[@]} || exit $?
    fi
}

# -----------------------------------------------------------------------------
# S E T U P   B A S I C   S E R V I C E S
# -----------------------------------------------------------------------------
SetupBasicServices()
{
    # Disable systemd resolver
    echo "- Configuring initial DNS"
    systemctl disable --now systemd-resolved >/dev/null 2>&1
    if [[ -h /etc/resolv.conf ]]; then
        rm /etc/resolv.conf
    fi
    echo "nameserver $G_DNS_RESOLVER" >/etc/resolv.conf

    echo "- Configuring time server"
    systemctl enable --now chrony
    for s in $G_NTP_SERVERS; do
        echo "server $s iburst"
    done >/etc/chrony/sources.d/dcnet.sources
    chronyc reload sources
}


# -----------------------------------------------------------------------------
# S E T   N E T W O R K I N G   G L O B A L S
# -----------------------------------------------------------------------------
SetNetworkingGlobals()
{
    G_HOSTNAME=$(hostname -s)

    set -- $(getent hosts $G_HOSTNAME)
    G_IP_ADDR=$1

    if [[ -z $G_IP_ADDR || $G_IP_ADDR == 127.0.0.1 || $G_IP_ADDR == *:* ]]; then
        echo "** name $G_HOSTNAME does not resolve to a valid IPv4 address" >&2
        exit 1
    fi
    if [[ $# != 3 ]]; then
        echo "** Expected IP address $G_IP_ADDR to resolve to two hostnames" 2>&1
        exit 1
    fi

    shift ; # Lose IP address

    if [[ $1 == *.* ]]; then
        G_FQDN=$1
    elif [[ $2 == *.* ]]; then
        G_FQDN=$2
    else
        echo "** Neither $1 nor $2 appears to be fully qualified" >&2
        exit 1
    fi

    if [[ ${G_FQDN%%.*} != $G_HOSTNAME ]]; then
        echo "First part of FQDN ${G_FQDN%%.*} must match hostname" >&2
        exit 1
    fi
    set -- $(ip addr | grep $G_IP_ADDR/)
    if [[ $# -lt 2 || $1 != inet || $2 != */* ]]; then
        echo "** Unable to find the netmask for $G_IP_ADDR" 2>&1
        exit 1
    fi
    G_NETMASK_BITS=${2#*/}
    G_DOMAIN=${G_FQDN#*.}
    G_REALM=${G_DOMAIN^^}

    set -- $(ip route show default)
    if [[ $# -ge 3 && $1.$2 == default.via ]]; then
        G_DEFAULT_ROUTE=$3
    else
        echo "** Unable to find the default route for this machine" >&2
        exit 1
    fi
}


# -----------------------------------------------------------------------------
# I N S T A L L   D O M A I N   C O N T R O L L E R   P A C K A G E S
#
# See
# - https://wiki.samba.org/index.php/Distribution-specific_Package_Installation
# - https://wiki.samba.org/index.php/Setting_up_a_BIND_DNS_Server#Installing_.26_Configuring_BIND_on_Debian_based_distros
# -----------------------------------------------------------------------------
InstallDomainControllerPackages()
{
    echo "- Installing domain controller packages"
    apt-get -y install acl attr samba samba-dsdb-modules \
        samba-vfs-modules winbind libpam-winbind libnss-winbind \
        krb5-config krb5-user dnsutils \
        bind9 bind9utils \
        isc-dhcp-server || exit $?
}


# -----------------------------------------------------------------------------
# C O N F I G U R E   S A M B A
# -----------------------------------------------------------------------------
ConfigureSamba()
{
    rm -f /etc/samba/smb.conf
    samba-tool domain provision \
        --server-role=dc \
        --use-rfc2307 \
        --dns-backend=BIND9_DLZ \
        --domain="${G_REALM%%.*}" \
        --realm="$G_REALM" \
        --adminpass="$G_ADMIN_PASS" || exit $?
}


# -----------------------------------------------------------------------------
# C O N F I G U R E   B I N D
#
# See:-
# - https://wiki.samba.org/index.php/Setting_up_a_BIND_DNS_Server#Installing_.26_Configuring_BIND_on_Debian_based_distros
# -----------------------------------------------------------------------------
ConfigureBind()
{
    echo "- Configuring BIND"
    local file=/etc/bind/named.conf.options
    local this_subnet=$(ipcalc -nb $G_IP_ADDR/$G_NETMASK_BITS | \
        sed -ne 's/^Network: *//p')

    if [[ -f $file && ! -f $file.orig ]]; then
        mv $file $file.orig
    fi

    cat >$file <<EOF
// Managing acls
acl internals { 127.0.0.0/8; $this_subnet; };

options {
      directory "/var/cache/bind";
      version "Go Away 0.0.7";
      notify no;
      empty-zones-enable no;
      auth-nxdomain yes;
      forwarders { $G_DNS_RESOLVER; };
      allow-transfer { none; };

      dnssec-validation no;
      // These two no longer supported
      //dnssec-enable no;
      //dnssec-lookaside no;

      // Added Per Debian buster Bind9.
      // Due to : resolver: info: resolver priming query complete messages in the logs.
      // See: https://gitlab.isc.org/isc-projects/bind9/commit/4a827494618e776a78b413d863bc23badd14ea42
      minimal-responses yes;

      //  Add any subnets or hosts you want to allow to use this DNS server
      allow-query { "internals";  };
      allow-query-cache { "internals"; };

      //  Add any subnets or hosts you want to allow to use recursive queries
      recursion yes;
      allow-recursion {  "internals"; };

      // https://wiki.samba.org/index.php/Dns-backend_bind
      // DNS dynamic updates via Kerberos (optional, but recommended)
      tkey-gssapi-keytab "/var/lib/samba/bind-dns/dns.keytab";

  };
EOF
    file=/etc/bind/named.conf.local
    if ! grep -q /var/lib/samba/bind-dns/named.conf $file; then
        if [[ -f $file && ! -f $file.orig ]]; then
            cp -p $file $file.orig
        fi

        {
            echo '// Added for Domain controller setup'
            echo 'include "/var/lib/samba/bind-dns/named.conf";'
        } >>$file
    fi

    systemctl stop named.service
    systemctl enable --now named.service

    # Make the DNS server usable on this machine
    {
        echo search $G_DOMAIN
        echo nameserver $G_IP_ADDR
    } >/etc/resolv.conf
}


# -----------------------------------------------------------------------------
# C O N F I G U R E   D H C P D
# -----------------------------------------------------------------------------
ConfigureDhcpd()
{
    echo "- Configuring DHCP server"
    local file=/etc/dhcp/dhcpd.conf
    local ipinfo=$(mktemp)
    # sed strips off trailing ' ' characters
    ipcalc -nb $G_IP_ADDR/$G_NETMASK_BITS | sed -e 's/ *$//' >$ipinfo
    local subnet=$(sed -n -e 's#/.*##' -e 's#^Network: *##p' < $ipinfo)
    local netmask=$(sed -n -e 's# *=.*##' -e 's#^Netmask: *##p' < $ipinfo)
    local broadcast=$(sed -n -e 's#^Broadcast: *##p' < $ipinfo)
    rm $ipinfo

    if [[ -f $file && ! -f $file.orig ]]; then
        mv $file $file.orig
    fi

    cat >$file <<EOF
ddns-update-style none;
authoritative;

subnet $subnet netmask $netmask {
  range $G_DHCP_LOW_ADDR $G_DHCP_HIGH_ADDR;
  option domain-name "$G_DOMAIN";
  option domain-name-servers $G_FQDN;
  option subnet-mask $netmask;
  option routers $G_DEFAULT_ROUTE;
  option broadcast-address $broadcast;
  option ntp-servers $G_NTP_SERVERS;
  default-lease-time 600;
  max-lease-time 7200;
EOF
    systemctl stop isc-dhcp-server.service
    systemctl enable --now isc-dhcp-server.service || exit $?
}


# -----------------------------------------------------------------------------
# M A I N
# -----------------------------------------------------------------------------
if [[ $(id -u) != 0 ]]; then
    echo "** Must be root to run this script" >&2
    exit 1
fi

DISTRIBUTION=$(lsb_release -si)
RELEASE=$(lsb_release -sr)

case "$DISTRIBUTION-$RELEASE" in
    Ubuntu-22.04)
        ;;
    *)  echo "** This script is not tested on $DISTRIBUTION $RELEASE" 2>&2
        ;;
esac

cd $(dirname $0) || exit $?
if [[ $1 != "--net-ok" || ! -f ./dc.params ]]; then
    echo
    echo "    Make sure the machine :-"
    echo "    - Has a static IP address"
    echo "    - Has the FQDN resolving to the static IP in /etc/hosts"
    echo "    - Has the short name resolving to the static IP in /etc/hosts"
    echo "    - Has a default route which will be used for all machines"
    echo "    - on a VLAN with no DHCP server."
    echo "    - Has the file $(pwd)/dc.params filled in from the template"
    echo
    echo "    When you are sure this is the case, re-run the script"
    echo "    with the switch --net-ok"
    echo
    exit 1
fi >&2

. ./dc.params
dc_params_ok=1

for p in G_DNS_RESOLVER G_NTP_SERVERS G_ADMIN_PASS \
         G_DHCP_LOW_ADDR G_DHCP_HIGH_ADDR; do
    eval v=\$${p}
    if [[ -z $v ]]; then
        if [[ -n $dc_params_ok ]]; then
            echo "** Need these parameters in $(pwd)/dc.params :-" >&2
            dc_params_ok=
        fi
        echo "- $p" >&2
    fi
done
if [ -z $dc_params_ok ]; then
    exit 1
fi

InstallInitialPackages
SetupBasicServices

SetNetworkingGlobals

echo "Hostname      : $G_HOSTNAME"
echo "FQDN          : $G_FQDN"
echo "IP4 address   : $G_IP_ADDR/$G_NETMASK_BITS"
echo "Default route : $G_DEFAULT_ROUTE"
echo "Domain        : $G_DOMAIN"
echo "Realm         : $G_REALM"

read -p "Return to continue, CTRL-C to exit :"

InstallDomainControllerPackages
ConfigureSamba
ConfigureBind
# This may be necessary to get DNS working.
#
# See https://wiki.samba.org/index.php/BIND9_DLZ_DNS_Back_End#Troubleshooting
#samba_upgradedns --dns-backend=BIND9_DLZ

ConfigureDhcpd

echo "- Configuring Kerberos"
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

echo "- Starting the Domain Controller"
systemctl unmask samba-ad-dc.service
systemctl enable samba-ad-dc.service
systemctl restart samba-ad-dc.service || exit $?
