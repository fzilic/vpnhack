#!/bin/sh

if [ "$(whoami)" != "root" ]; then
  echo "This installation script must be run as root." >&2
  exit 1
fi

if [ "$(uname -s)" != "OpenBSD" ]; then
  echo "Only OpenBSD is supported" >&2
  exit 1
fi

if [ -z "$PKG_PATH" ]; then
  echo "Unable to install packages, PKG_PATH not configured."
  echo "Configuring default PKG_PATH to 'http://www.obsd.si/pub/OpenBSD' "
  
  cat <<EOF >> /root/.profile

PKG_PATH=http://www.obsd.si/pub/OpenBSD/`uname -r`/packages/`uname -m`/

export PKG_PATH
EOF
  
  export PKG_PATH=http://www.obsd.si/pub/OpenBSD/`uname -r`/packages/`uname -m`/
fi

if [ ! -e "/etc/installurl" ]; then
  echo "File /etc/installurl does not exist."
  echo "Creating new withj default install url"
  
  cat <<EOF > /etc/installurl
http://www.obsd.si/pub/OpenBSD/
EOF

fi

if [ "$(syspatch -c | wc -l)" -ne "0" ]; then
  echo "Patches present for your system."
  echo "Installing patches before we continue"
  
  syspatch
  
  echo "Reboot the system and then rerun this script"
  exit
fi

echo -e "Installing packages...\n"

if ! which vim > /dev/null 2>&1
then
  echo "Installing package 'vim'"
  pkg_add vim%no_x11
fi

if ! which wget > /dev/null 2>&1
then
  echo "Installing package 'wget'"
  pkg_add wget
fi

if ! which curl > /dev/null 2>&1
then
  echo "Installing package 'curl'"
  pkg_add curl
fi

if ! which links > /dev/null 2>&1
then
  echo "Installing package 'links'"
  pkg_add links
fi

if ! which ruby > /dev/null 2>&1
then
  echo "Installing package 'ruby'"
  pkg_add ruby%2.3
fi

if ! which vpnc > /dev/null 2>&1
then
  echo "Installing package 'vpnc'"
  pkg_add vpnc vpnc-scripts
fi

ln -sf /usr/local/bin/ruby23 /usr/local/bin/ruby
ln -sf /usr/local/bin/erb23 /usr/local/bin/erb
ln -sf /usr/local/bin/irb23 /usr/local/bin/irb
ln -sf /usr/local/bin/rdoc23 /usr/local/bin/rdoc
ln -sf /usr/local/bin/ri23 /usr/local/bin/ri
ln -sf /usr/local/bin/rake23 /usr/local/bin/rake
ln -sf /usr/local/bin/gem23 /usr/local/bin/gem


echo "Configuring profile"

if ! alias connect > /dev/null 2>&1 
then
  cat <<EOF >> /root/.profile
alias connect='/root/vpnhack/connect.rb -c /root/vpnhack/config.yml'
EOF
fi

if ! alias close > /dev/null 2>&1
then
  cat <<EOF >> /root/.profile
alias close='/root/vpnhack/close.rb'
EOF
fi

if ! alias disconnect > /dev/null 2>&1
then
  cat <<EOF >> /root/.profile
alias disconnect='/root/vpnhack/close.rb'
EOF
fi

if ! alias status > /dev/null 2>&1
then
  cat <<EOF >> /root/.profile
alias status='pgrep -q vpnc && echo "Running" || echo "OFFLINE"'
EOF
fi

if ! alias shutdown > /dev/null 2>&1
then
  cat <<EOF >> /root/.profile
alias shutdown='shutdown -p -h now'
EOF
fi
