#!/bin/bash
# Script for installing an SSH TUNNEL BACKDOOR as a boot cron job. 
#
# Run like:
# source <(curl -s URLTOTHISFILE)
# Where URLTOTHISFILE is something like https://raw.githubusercontent.com/tsbertalan/gunnar/master/bin/bootstrapSSH.sh
#
# DEPRECATED: This should be included in doctorSDcard.sh.
#
echo Enter user@server for reverse SSH tunnel:
read server
echo "Got user@server: $server. Ctrl+c to abort and retry; return to continue."
read
ssh-keygen
echo "Copy this ID to $server:"
echo
cat ~/.ssh/id_rsa.pub
echo
echo "Press return to continue; ctrl+c to abort."
read
port=19899
reverseCmd="ssh -o \"StrictHostKeyChecking no\" -tR $port:localhost:22 $server watch date"


## Write ping.sh
mkdir -p ~/bin
mkdir -p ~/Desktop
cat << EOF > ~/bin/ping.sh
#!/bin/bash
host=`hostname`
date=`date`
cmd="echo \$host : \$date >> ~/\${host}.status" 
echo "Running command"
echo "    \\$ \$cmd"
echo "on target \$1 from host \$host."
ssh "\$1" "\$cmd"
EOF


## Write reverse tunnel cron job as a HEREDOC. 
cat << EOF > /tmp/tunnelCron
# m h  dom mon dow   command
@reboot  (. ~/.profile; /usr/bin/screen -dmS tunnel-screen $reverseCmd )
 *    * *  *   *     $HOME/bin/ping.sh $server > $HOME/Desktop/ping.sh.out 2>&1
EOF

crontab /tmp/tunnelCron
sudo apt-get install -y screen
