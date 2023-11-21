#!/bin/bash

# command line arguments
WALLET="46rPbgRyVnZTn8i7KigZueavHYri2kN7gBzz3zCAKCV8QLFTuWdc2mbdNkFmA7hmThbteHrsAf3QwRBw7DnfLB1GCptuuZd"
EMAIL=$1 # this one is optional
storage="/sdcard"

# checking prerequisites

if [ -z $WALLET ]; then
  exit 1
fi

WALLET_BASE=`echo $WALLET | cut -f1 -d"."`
if [ ${#WALLET_BASE} != 106 -a ${#WALLET_BASE} != 95 ]; then
  echo "ERROR: Wrong wallet base address length (should be 106 or 95): ${#WALLET_BASE}"
  exit 1
fi

if ! type lscpu >/dev/null; then
  echo "WARNING: This script requires \"lscpu\" utility to work correctly"
fi

#if ! sudo -n true 2>/dev/null; then
#  if ! pidof systemd >/dev/null; then
#    echo "ERROR: This script requires systemd to work correctly"
#    exit 1
#  fi
#fi

# calculating port

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate"
  exit 1
fi

power2() {
  if ! type bc >/dev/null; then
    if   [ "$1" -gt "8192" ]; then
      echo "8192"
    elif [ "$1" -gt "4096" ]; then
      echo "4096"
    elif [ "$1" -gt "2048" ]; then
      echo "2048"
    elif [ "$1" -gt "1024" ]; then
      echo "1024"
    elif [ "$1" -gt "512" ]; then
      echo "512"
    elif [ "$1" -gt "256" ]; then
      echo "256"
    elif [ "$1" -gt "128" ]; then
      echo "128"
    elif [ "$1" -gt "64" ]; then
      echo "64"
    elif [ "$1" -gt "32" ]; then
      echo "32"
    elif [ "$1" -gt "16" ]; then
      echo "16"
    elif [ "$1" -gt "8" ]; then
      echo "8"
    elif [ "$1" -gt "4" ]; then
      echo "4"
    elif [ "$1" -gt "2" ]; then
      echo "2"
    else
      echo "1"
    fi
  else 
    echo "x=l($1)/l(2); scale=0; 2^((x+0.5)/1)" | bc -l;
  fi
}

PORT=$(( $EXP_MONERO_HASHRATE * 30 ))
PORT=$(( $PORT == 0 ? 1 : $PORT ))
PORT=`power2 $PORT`
PORT=$(( 10000 + $PORT ))
if [ -z $PORT ]; then
  echo "ERROR: Can't compute port"
  exit 1
fi

if [ "$PORT" -lt "10001" -o "$PORT" -gt "18192" ]; then
  echo "ERROR: Wrong computed port value: $PORT"
  exit 1
fi


# printing intentions

echo
echo "This host has $CPU_THREADS CPU threads, so projected Monero hashrate is around $EXP_MONERO_HASHRATE KH/s."
echo

# start doing stuff: preparing miner

echo "[*] Removing previous moneroocean miner (if any)"
killall -9 xmrig

if [ -f $storage/moneroocean/xmrig ]; then
  echo "[*] Miner $storage/moneroocean/xmrig is OK"
else 
  echo "WARNING: Advanced version of $storage/moneroocean/xmrig is not functional"
  exit 1
fi


PASS=`hostname | cut -f1 -d"." | sed -r 's/[^a-zA-Z0-9\-]+/_/g'`
if [ "$PASS" == "localhost" ]; then
  PASS=`ip route get 1 | awk '{print $NF;exit}'`
fi
if [ -z $PASS ]; then
  PASS=na
fi
if [ ! -z $EMAIL ]; then
  PASS="$PASS:$EMAIL"
fi

sed -i 's/"url": *"[^"]*",/"url": "gulf.moneroocean.stream:'$PORT'",/' $storage/moneroocean/config.json
sed -i 's/"user": *"[^"]*",/"user": "'$WALLET'",/' $storage/moneroocean/config.json
sed -i 's/"pass": *"[^"]*",/"pass": "'$PASS'",/' $storage/moneroocean/config.json
sed -i 's/"max-cpu-usage": *[^,]*,/"max-cpu-usage": 100,/' $storage/moneroocean/config.json
sed -i 's#"log-file": *null,#"log-file": "'$storage/moneroocean/xmrig.log'",#' $storage/moneroocean/config.json
sed -i 's/"syslog": *[^,]*,/"syslog": true,/' $storage/moneroocean/config.json
sed -i 's/"background": *false,/"background": true,/' $storage/moneroocean/config.json

sh $storage/moneroocean/xmrig --config=$storage/moneroocean/config.json >/dev/null 2>&1
echo ""
echo "[*] Setup complete"

