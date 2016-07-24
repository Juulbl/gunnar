#!/bin/bash
# Make modifications to a mounted Raspbian SD image s.t. it will have desired
# software, and, most importantly, a backdoor from Sigurd.
#
# This is called by mountAndAlterSD.sh
#
if [ $# -ne 2 ]
then
	echo "USAGE: $0 BASEPATH SBCUSER"
	echo 
	echo 'Where BASEPATH is the path where the SD image is mounted (like /mnt/sdcard"),'
	echo 'and   SBCUSER is the user on the single-board-computer (probaby "pi").'
	echo
	echo "It's probably better to invoke mountAndAlterSD.sh instead."
	exit
fi
set -e
startDir=`pwd`
export nargs=$#
function retAbrt {
    if [[ "$nargs" -ge 3 ]]
    then
        echo Non-interactive mode. Continuing.
    else
        echo "Return to continue; Ctrl+C to abort."; read
    fi
}


bp=$1
user=$2
server=sigurd.tomsb.net
serverUser=tsbertalan
port=19898

echo Continuing with these parameters:
    echo Base dir: $bp
    echo SBC user: $user
    echo SSH target: $serverUser@$server:$port
echo Proceed?
retAbrt


## Generate SSH key files for the new image and install them both there
# and in the home directory of the user calling this script. 
ssh-keygen -t rsa -N "" -f /tmp/id_rsa
cat /tmp/id_rsa.pub
echo "Installing public key for the SD image in $HOME/.authorized_keys."
retAbrt
mkdir -p $HOME/.ssh
cat /tmp/id_rsa.pub >> $HOME/.ssh/authorized_keys
# Install the private and public keys into the SD image.
mkdir -p $bp/home/$user/.ssh
mv /tmp/id_rsa $bp/home/$user/.ssh/
mv /tmp/id_rsa.pub $bp/home/$user/.ssh/
# If the running user has an RSA identity, copy their public key into the SD image.
[ -e ~/.ssh/id_rsa.pub ] && cat ~/.ssh/id_rsa.pub >> $bp/home/$user/.ssh/authorized_keys



## Make hourly ping script to keep connection alive (I hope).
echo "Make ping script."
mkdir -p $bp
cat << EOF > $bp/etc/cron.hourly/pingServer.sh
#!/bin/bash
host=\`hostname\`
date=\`date\`
cmd="echo \$host : \$date >> ~/\${host}.status" 
echo "Running command"
echo "    \\$ \$cmd"
echo "on target \$1 from host \$host."
ssh "$serverUser@$server" "\$cmd"
EOF
chmod +x $bp/etc/cron.hourly/pingServer.sh



## Make boot install script, to be run exactly once.
desc="Install some things on first boot."
echo "Make script for: $desc"
cat << EOF >> $bp/etc/init.d/bootInstall
#!/bin/bash
### BEGIN INIT INFO
# Provides:          bootInstall
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:
# Short-Description: $desc
# Description: $desc
### END INIT INFO
set -e
if [ -f /etc/bootInstall_semaphore ]
then
    echo "bootInstall has run before. Not running on this boot."
else
    # Wait for network connection...try to ping $server for about a minute.
    for i in {1..60}
    do
        ping -c1 $server &> /dev/null && echo "Can see $server on network. Continuing...." && break
        echo "Can't see $server on network. Waiting..."
        sleep 1
    done
    apt-get clean
    apt-get update
    apt-get clean
    # Install programs needed for SSH tunnel.
    apt-get install -y --force-yes screen  htop
    # Set permissions of SSH keys.
    chmod 700 /home/$user/.ssh
    chown -R $user:$user /home/$user/.ssh
    chmod 700 /home/$user/.ssh/
    chmod 600 /home/$user/.ssh/id_rsa*
    # Set permissions of crontab.
    touch /var/spool/cron/crontabs/$user
    chown $user:$user /var/spool/cron/crontabs/$user
    chmod 600 /var/spool/cron/crontabs/$user
    chown $user:crontab /var/spool/cron/crontabs/$user
    # Ensure console boot (optional).
    [ -e /etc/init.d/lightdm ] && update-rc.d lightdm disable && echo "/bin/true" > /etc/X11/default-display-manager
    # If the script has gotten to this point, we've succeeded. Touch a semaphore.
    touch /etc/bootInstall_semaphore
    echo "bootInstall appears to have succeeded. Rebooting..."
    reboot
fi
EOF
chmod +x $bp/etc/init.d/bootInstall
# Run at boot. 
cd $bp/etc/rc2.d && \
    ln -s ../init.d/bootInstall ./S99bootInstall



## Make script to start screen tunnel at boot.
# This supersedes the bootstrapSSH.sh script.
# The script makes an SSH reverse tunnel and runs the `date` command there
# once per second (?) to keep the connection alive.
desc="Start screen tunnel at boot."
echo "Make script for: $desc"
reverseCmd="ssh -o \"StrictHostKeyChecking no\" -tR $port:localhost:22 $serverUser@$server watch date"
cat << EOF >> $bp/etc/init.d/screenTunnel
#!/bin/bash
### BEGIN INIT INFO
# Provides:          screenTunnel
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:
# Short-Description: $desc
# Description: $desc
### END INIT INFO
# Wait for network connection...try to ping $server for about a minute.
for i in {1..60}
do
    ping -c1 $server &> /dev/null && echo "Can see $server on network. Continuing...." && break
    echo "Can't see $server on network. Waiting..."
    sleep 1
done
su $user --command='/usr/bin/screen -dmS tunnel-screen $reverseCmd'
EOF
chmod +x $bp/etc/init.d/screenTunnel
# Run at boot.
cd $bp/etc/rc2.d && \
    ln -s ../init.d/screenTunnel ./S99screenTunnel



## Make WIFI defaults configuration file.
echo "Make WIFI defaults file."
wpadir=$bp/etc/wpa_supplicant/
mkdir -p $wpadir
cat << EOF >> $wpadir/wpa_supplicant.conf
network={
    ssid="puvisitor"
    priority=5
    key_mgmt=NONE
}
EOF
echo "" >> $wpaddr/wpa_supplicant.conf
# Add any extra networks defined in extraNetworks.conf. 
cat $startDir/extraNetworks.conf >> $wpaddr/wpa_supplicant.conf 2>/dev/null


## Set Keyboard layout and locale to US
echo "Set keyboard layout to US."
mkdir -p $bp/etc/default/
cat << EOF > $bp/etc/default/keyboard
XKBMODEL="pc104"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"
EOF
cat << EOF > $bp/etc/default/locale
LANG=en_US.UTF-8
EOF



## Clone repo into card.
mkdir -p $bp/home/$user/sketchbook/
cd `dirname $0` && \
git clone ../.. $bp/home/$user/sketchbook/gunnar



## Modify .bashrc
export bashrc=$bp/home/$user/.bashrc
echo "export LC_ALL=\"C\"" >> $bashrc
echo "source \$HOME/catkin_ws/devel/setup.bash" >> $bashrc
 


echo "Done with script $0."