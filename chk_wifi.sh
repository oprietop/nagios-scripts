#!/bin/sh
IWC=$(/usr/sbin/iwconfig wl0)
AP=$(echo "$IWC" | sed -n 's/.*Access Point: \([^ ]\+\).*/\1/p')
LQ=$(echo "$IWC" | sed -n 's/.*Link Quality=\([^ ]\+\) .*/\1/p')
ESSID=$(echo "$IWC" | sed -n 's/.*ESSID:"\([^"]\+\)".*/\1/p')
IP=$(ifconfig wl0 | sed -n 's/.*inet addr:\([^ ]\+\) .*/\1/p')
MAC=$(ifconfig wl0 | sed -n 's/.*HWaddr \([^ ]\+\) .*/\1/p')
echo "$(uname -n) $IP($MAC) associated to $ESSID($AP) with a link quality of $LQ."
