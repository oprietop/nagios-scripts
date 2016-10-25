#!/bin/sh
# Check on a directoryfor files created on the last 24h
RES=$(ssh -T -o ConnectTimeout=20 -o StrictHostKeyChecking=no root@voipmonitor -C 'find /var/spool/voipmonitor/ -ctime -1 -type d | wc -l' 2>/dev/null )
test "$?" -ne 0 && { echo "Problems connecting to host."; exit 1; }
test "$RES" -ne 0 && { echo "OK! $RES files"; exit 0; } || { echo "NOK!! No files created on 24h."; exit 1; }

