# mediabox
Set up Transmission through a PIA VPN.

This drew a lot of inspiration from a PIA forum post (https://www.privateinternetaccess.com/forum/discussion/24597/full-guide-set-up-pia-on-headless-ubuntu-with-transmission-and-port-forwarding-with-auto-reconnect
), but I had slightly different needs.


## Installation
I'm using Ubuntu 18 for this, so YMMV.

    # get this repo
    git clone &lt;this&gt;
    
    # install transmission
    apt install transmission-daemon

    # copy the files into place
    sudo cp *.bash /usr/local/bin/
    sudo cp *.service *.path /lib/systemd/system/
    sudo cp /etc/transmission/settings.json /etc/transmission/settings.json.edits

    # build symbolic links for the systemd elements
    sudo ln -s /lib/systemd/system/transmission* /etc/systemd/system/multi-user.target.wants/
    sudo ln -s /lib/systemd/system/pia@.service /etc/systemd/system/multi-user.target.wants/
    
    # set the script as executable
    sudo chmod +x /usr/local/bin/pia-forward.bash

    # load, enable, and start the transmission elements
    sudo systemctl daemon-reload
    sudo systemctl enable transmission-watcher.service
    sudo systemctl enable transmission-watcher.path
    sudo systemctl enable transmission-daemon.service
    sudo systemctl start transmission-watcher.service
    sudo systemctl start transmission-watcher.path
    sudo systemctl start transmission-daemon.service


## Transmission Settings
Transmission does a funny thing:  When you make a change to the configuration through the web interface, it makes no changes to its config file.  When you shut it down, it overwrites settings.json with its in-memory config, which means any changes you've made get blown away. To combat this, we're going to just overwrite settings.json with settings.json.edits _every time we start up_. That means that no changes made in the web interface will persist beyond service restarts.  Nota Bene. 

To facilitate this, we have a line in the transmission-daemon.service that does the copy upon startup and we have a watcher that monitors settings.json.edits for changes.  When we see that its changed, we bounce the service, which overwrites settings.json with its in-memory config, then stops, then we overwrite settings.json _again_ with settings.json.edits, then it start up Transmission.  So only edit /etc/transmission/settings.json.edits and don't worry about reloading as it should be done for you.

## Files

### SystemD units and paths
Copy to /lib/systemd/system/ and symbolically link (ln -s) to /etc/systemd/system/multi-user.target.wants

pia@.service - control an openvpn client connection to a PIA endpoint; run pia-forward.bash after connecting; required for transmission-daemon

transmission-daemon.service - control transmission

transmission-watcher.path - monitor a transmission configuration file (/etc/transmission-daemon/settings.json.edits)

transmission-watcher.service - when transmission-watcher.path sees a change to the transmission config file, it triggers this service to restart transmission

### Scripts

pia-forward.bash - check the PIA API to find out what port is being forwarded; update the transmission configuration with the port; this should trigger a transmission restart with the new configuration

## Dynamic DNS
If you, like me, want to be able to SSH into this box, you'll need to do some flexing.  I'm using a Dreamhost dynamic dns script (https://github.com/jgabello/dreamhost-dynamic-dns) that figures out your external IP and updates a DNS record at Dreamhost using their API.  Since we're using a VPN, it'll find the external IP of your VPN connection, which isn't likely to allow SSH traffic back into your server. My workaround for this was to:
    
    1. check the IP of  resolver1.opendns.com
    2. set a static route to my router for that IP so that the next step won't use my VPN
    3. check my external IP (dig myip.opendns.com @resolver.opendns.com)
    4. unset that static route
    5. update Dreamhost via the API

This ensures that it'll find the external IP of my router rather than the VPN.  My router has port 22 forwarded to my server (with fail2ban enabled, natch).

Here's the specific change I made to jgabello's script (around line 225).

    router="192.168.0.1"
	opendns=$(eval "dig +short resolver1.opendns.com")
	ip route add $opendns via $router
	IP=$(eval "dig +short myip.opendns.com @resolver1.opendns.com")
	ip route del $opendns via $router

I did have to add a route for my router's external IP back through 192.168.0.1 because my incoming ssh seems to originate from the external IP, which is weird, but I haven't figured it out yet.  Without this route, return traffic to SSH goes out via the VPN and gets dropped by the ssh client because of the asymmetric route.

    ip add route $IP via $router


