#!/usr/bin/env bash
# Enable port forwarding when using Private Internet Access
client_id=`head -n 100 /dev/urandom | sha256sum | tr -d " -"`
json=`curl "http://209.222.18.222:2000/?client_id=$client_id" 2>/dev/null`
if [ "$json" == "" ]; then
        echo "Error updating the port forward rule for tunnel-server's VPN"
else
        port=$( echo "$json" | cut -c9-13 )
        echo "$port" > /etc/openvpn/port
        sed -i -r "s|\"peer-port\": [0-9][0-9]*,|\"peer-port\": $port,|g" /etc/transmission-daemon/settings.json.edits
fi
exit 0
