#!/bin/bash
clear
echo '

██████╗ ██████╗ ██╗███████╗████████╗███████╗██████╗ 
██╔══██╗██╔══██╗██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗
██████╔╝██████╔╝██║█████╗     ██║   █████╗  ██████╔╝
██╔══██╗██╔═══╝ ██║██╔══╝     ██║   ██╔══╝  ██╔══██╗
██║  ██║██║     ██║███████╗   ██║   ███████╗██║  ██║
╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
			Version 0.1 by KevinKesslerIT
------------------------------------------------------'

if [ "$EUID" -ne 0 ]
  then echo '!!!! PLEASE RUN AS ROOT (sudo) !!!!'
  exit
fi

wget -q --spider http://google.com
if [ $? -eq 0 ]; then
else
    echo 'Please conenct to the internet and try again.'
    exit
fi

echo "You'll need to enable predictable network interfaces next.
Go to option 2, then N3 and enable that. Enter 'c' when ready. [c]"
read cont

if [ $cont = "c" -o $cont = "C"]; then
	raspi-config
else
	exit
fi


apt-get update && apt-get dist-upgrade -y && apt-get install dnsmasq hostapd -y

echo "Use a valid interface from the output below..."
ifconfig -a | grep -m10 -o "^\w*\b"

echo "\n\nWhich interface are we using today?"
read interface
echo "\nTaking $interface down now..."

echo 'Type the name of the listen address you wish to use [192.168.2.1]:'
read listenAddress
echo "\nYou chose $listenAddress"

echo 'Type the name of the static router you wish to use [192.168.2.0]:'
read staticRouter
echo "\nYou chose $staticRouter"

echo 'Type the dhcp range you wish to use [192.168.2.2,192.168.2.253]:'
read dhcpRange
echo "\nYou chose $dhcpRange"

#rename basic wpa_supplicant.conf to wpa_supplicant-wlan0.conf
mv wpa_supplicant.conf wpa_supplicant-wlan0.conf


#/etc/dhcpcd.conf append >>

echo "
interface $interface
static ip_address=$listenAddress/24
static routers=$staticRouter
" >> /etc/dhcpcd.conf


#/etc/dnsmasq.conf change all >

echo "
interface=$interface
listen-address=$listenAddress
server=1.1.1.1
server=1.0.0.1
dhcp-range=$dhcpRange,12h
" > /etc/dnsmasq.conf


#/>>etc/init.d/hostapd
sed -i '/	start-stop-daemon --start --oknodo --quiet --exec "$DAEMON_SBIN" \/i \
	sleep 8' /etc/init.d/hostapd


#cat > /etc/hostapd/hostapd.conf

echo 'Type the name of the ssid (wifi name) you wish to use:'
read ssid
echo "\nYou chose $ssid"

echo "Type the password for $ssid:"
read password
#add password verification for typos

echo "Type the channel for $ssid to repeat (!!this must match the network being repeated!!):"
read channel
echo "\nYou chose $channel"

echo "
interface=$interface
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$channel
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$password
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
" > /etc/hostapd/hostapd.conf
#ipv4 forwarding!
sysctl -w net.ipv4.ip_forward=1
#setup iptables rules
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE  
iptables -A FORWARD -i wlan0 -o $interface -m state --state RELATED,ESTABLISHED -j ACCEPT  
iptables -A FORWARD -i $interface -o wlan0 -j ACCEPT

echo "Restart now for changes to work? [Y/n]"
read restart
if [$restart ="y" -o $restart ="Y"]; then
reboot
fi
