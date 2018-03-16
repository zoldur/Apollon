#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='Apollon.conf'
CONFIGFOLDER='/root/.Apollon'
COIN_DAEMON='/usr/local/bin/Apollond'
COIN_CLI='/usr/local/bin/Apollond'
COIN_REPO='https://github.com/apollondeveloper/ApollonCoin'
COIN_NAME='Apollon'
COIN_PORT=12116
RPC_PORT=12117
HOST=$(hostname)


NODEIP=$(curl -s4 icanhazip.com)


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function compile_node() {
  echo -e "Preparing to compile ${GREEN}$COIN_NAME${NC}."
  git clone  $COIN_REPO $TMP_FOLDER
  cd $TMP_FOLDER/src
  make -f makefile.unix | pv
  compile_error
  strip Apollond
  cp Apollond /usr/local/bin
  cd -
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target

[Service]
User=root
Group=root

Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid

ExecStart=$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}.  Try running the following commands as the root user:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$RPC_PORT
listen=1
server=1
daemon=1
port=$COIN_PORT
EOF
}

function create_key() {
  echo -e "Press enter to generate your ${RED}Masternode Private Key${NC}:"
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then
  $COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  COINKEY=$($COIN_CLI masternode genkey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet did not fully load. Let us wait and try again to generate the Private Key${NC}"
    sleep 30
    COINKEY=$($COIN_CLI masternode genkey)
  fi
  $COIN_CLI stop
fi
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logintimestamps=1
maxconnections=256
masternode=1
bind=$NODEIP
masternodeaddr=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
addnode=144.202.88.54:12116
addnode=95.29.191.30:12117  
addnode=52.41.181.185:12116  
addnode=52.32.174.206:12116  
addnode=45.76.95.105:12117  
addnode=45.76.81.0:12117  
addnode=45.76.43.78:12116  
addnode=45.76.138.93:12116  
addnode=45.63.96.252:12117  
addnode=45.32.234.222:12116  
addnode=35.162.219.114:12116  
addnode=34.208.82.44:12116  
addnode=23.95.130.119:12120  
addnode=209.250.245.104:12116  
addnode=209.250.244.203:12116  
addnode=207.246.124.169:12116  
addnode=199.247.26.72:12117  
addnode=192.3.41.197:12129  
addnode=18.221.176.77:12116  
addnode=18.220.132.106:12116  
addnode=18.218.93.233:12116  
addnode=172.245.205.159:12124  
addnode=167.99.0.97:12118  
addnode=160.16.189.145:12116  
addnode=159.89.55.62:12118  
addnode=108.61.189.98:12116  
addnode=107.175.17.193:12117
EOF
}


function enable_firewall() {
  echo -e "Installing and setting up firewall to allow connections on port ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null
  ufw allow $RPC_PORT/tcp comment "$COIN_NAME RPC port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}



function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP has been detected. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please contact support at https://discord.gg/p8xHmVQ.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation has been cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 Installation must be run as the root user.${NC}"
   exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMOM" ] ; then
  echo -e "${RED}$COIN_NAME is already installed.${NC}"
  exit 1
fi
}

function prepare_system() {
echo -e "Preparing the system to install an ${GREEN}$COIN_NAME${NC} masternode."
echo -e "Several background tasks are currently running."
echo -e "This entire process will take 15 to 20 minutes to complete."
echo -e "Leave this terminal session open until you are prompted to"
echo -e "generate your private key."
DEBIAN_FRONTEND=noninteractive apt-get install pv > /dev/null 2>&1
apt-get update >/dev/null 2>&1 | pv
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1 | pv
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1 | pv
echo -e "${GREEN}Adding the Bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1 | pv
echo -e "Continuing to install the required software packages.${NC}"
echo -e "In a few moments you will begin to see a number of responses, please allow these to complete.${NC}"
apt-get update >/dev/null 2>&1 | pv
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ unzip >/dev/null 2>&1 | pv
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pkg-config libevent-dev unzip"
 exit 1
fi

clear
}

function create_swap() {
 echo -e "Checking to see if a memory swap file is required."
 PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
 SWAP=$(free -g|awk '/^Swap:/{print $2}')
 if [ "$PHYMEM" -lt "2" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Your server has less than 2GB of ram, a swap file is required. Creating 2GB swap file.${NC}"
    SWAPFILE=$(mktemp)
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon -a $SWAPFILE
    echo -e "${GREEN}Swap file created successfully.${NC}"
 else
  echo -e "${GREEN}Your server has 2GB of ram, a swap file is not required. Continuing installation.${NC}"
 fi
 clear
}


function important_information() {
 echo
 echo -e "=========================================================================================="
 echo -e "${GREEN}CONGRATULATIONS!!!${NC} Your ${GREEN}$COIN_NAME${NC} masternode is up and running!" 
 echo -e "=========================================================================================="
 echo -e " "
 echo -e "MASTERNODE SERVICE DETAILS"
 echo -e " "
 echo -e "The masternode alias is (${GREEN}Alias*${NC}): ${RED}$HOST${NC}"
 echo -e "Your server IP Address and Port are (${GREEN}Address*${NC}): ${RED}$NODEIP:$COIN_PORT${NC}"
 echo -e "Your MASTERNODE PRIVATEKEY is (${GREEN}PrivKey*${NC}): ${RED}$COINKEY${NC}"
 echo -e " "
 echo -e "The server configuration file is located at: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e " "
 echo -e "=========================================================================================="
 echo -e " "
 echo -e "Please copy and paste the above data into your ${GREEN}$COIN_NAME${NC} Masternode Reference Document under"
 echo -e "the header MASTERNODE SERVICE DETAILS.  You will need this information to complete your installation."
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  configure_systemd
}


##### Main #####


clear

checks
prepare_system
create_swap
compile_node
setup_node

