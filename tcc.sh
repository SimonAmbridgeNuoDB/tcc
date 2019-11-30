#=========================================================================================
# Based on original tc rate control filters taken from Nitro
# The scripts connects to one or more source nodes and sets network transmission shaping
# on traffic to one or more target nodes using the parameters provided on the command line
# 25.11.2019 Simon Ambridge Version 1 - outgoing interface only using root qdisc
#========================================================================================

usage() {
   cat <<EOF

   Usage:
   $0 -s <Source IP list> -t <Target IP list> [-d <device>] -r <delay> [-b <bandwidth>]
   $0 -s <Source IP list> -c [y|n]
   where:
      -s <list> source IP(s) separated by spaces
      -t <list> target IP(s) separated by spaces
      -d <nic> active network device name on source machines
           if blank the device will default to eth0
           use < -d probe > to discover an adapter
      -r <int> transmission delay (ms) - integer
      -b <int> bandwidth limit (kbps) - integer
           if not specified bandwidth is not changed
      -c <y|n> clear rules on source IP(s)

    Values must be specified for:
       - source, target and rate
         or
       - source and clear flag

    Examples:
      Add a 100 ms transmission delay on eth0 (default) from 3.10.138.208 to 3.10.138.12:
        $ ./tcc.sh -s "3.10.138.208"  -t "3.10.138.12" -r 100

      As above, but also set a 1024kbps bandwidth limit:
        $ ./tcc.sh -s "3.10.138.208"  -t "3.10.138.12" -r 100 -b 1024

      As above, but use eth1 network device instead of the default eth0:
        $ ./tcc.sh -s "3.10.138.208"  -t "3.10.138.12" -r 100 -b 1024 -d eth1

      As above, but detect the network device:
        $ ./tcc.sh -s "3.10.138.208"  -t "3.10.138.12" -r 100 -b 1024 -d probe

      Detect adapter on the source node(s) and remove all traffic rules:
        $ ./tcc.sh -s "3.10.138.208" -c y  -d probe

EOF
exit 0
}

SOURCES=""  # list of source IP(s)
TARGETS=""  # list of target IP(s)
DEVICE=""   # network device name on source machine(s)
RATE=""     # transmission delay (ms)
BWIDTH=""   # bandwidth limit (kbps)
CLEAR=""    # reset settings on source(s)

while getopts s:t:d:r:b:c:h?* curropt
do
  case $curropt in
    s) SOURCES="$OPTARG" ;;
    t) TARGETS="$OPTARG" ;;
    d) DEVICE="$OPTARG" ;;
    r) RATE="$OPTARG" ;;
    b) BWIDTH="$OPTARG" ;;
    c) CLEAR="$OPTARG" ;;
    h) usage ;;
    ?) usage ;;
    *) usage ;;
  esac
done

#------------------
# input validation
#-------------------
echo ""
# is this a clear operation?
if [ -n "$CLEAR" ]
then
  if ! [[ "$CLEAR" =~ ^[yYnN]+$ ]]; then
    echo "[ERROR]: -c must be in [yY|nN]"
    usage
    exit 1
  fi
fi

FAIL="1"
if [[ -n "$SOURCES" && -n "$TARGETS"  && -n "$RATE" ]]
then
  FAIL="0"
elif [[ -n "$SOURCES" && -n "$CLEAR" ]]
then
  FAIL="0"
fi

if [[ $FAIL == "1" ]]
then
  echo "[ERROR]: option combinations must be either:"
  echo ""
  echo "   -s <Source IP list> -t <Target IP list> -r <delay> "
  echo "      or"
  echo "   -s <Source IP list> -c <y|n>"
  usage
  exit 1
fi

if [ -z "$CLEAR" ]
then
  if ! [[ "${RATE}" =~ ^[0-9]+$ ]]; then
    echo "[ERROR]: Rate must be an integer"
    echo ""
    usage
    exit 1
  fi
  if [ "$BWIDTH" ]
  then
    if ! [[ "${BWIDTH}" =~ ^[0-9]+$ ]]
    then
      echo "[ERROR]: Bandwidth limit must be an integer"
      echo ""
      usage
      exit 1
    fi
  fi
fi

if [ ! "${DEVICE}" ]
then
  DEVICE="eth0" # set the default network interface if not specified on the command line
  DEVICE_NAME=$DEVICE" - default"
else
  DEVICE_NAME=$DEVICE
fi

echo
echo "tcc will shape network traffic:"
echo "    from Source      ["$SOURCES"]"
echo "      to Destination ["$TARGETS"]"
echo "    using:"
echo "         Device      ["$DEVICE_NAME"]"
if [ "${CLEAR}" ]
then
  echo "         Option       clear="$CLEAR
else
  echo "         Speed       ["$RATE"] ms"
  if [ "$BWIDTH" ]
  then
    echo "         Bandwidth   ["$BWIDTH"] kbps"
  else
    echo "         Bandwidth   [Not set]"
  fi
fi
echo ""

#exit 0

#----------------------------------------
# loop through source and target machines
#----------------------------------------

for SOURCEHOST in $SOURCES; do
  echo "Connecting to "$SOURCEHOST"..."
  ssh -i ~/.ssh/emea-lon.pem -o StrictHostKeyChecking=false -tt $SOURCEHOST "
  echo "Connected."
  echo "...Host name: "\$HOSTNAME
  NIC=$DEVICE

  if [ "\$NIC" == "probe" ]
  then
    echo "...Probing for active network interface..."
    NIC=`/usr/bin/netstat -nr | tail -1 | awk '{print $8}'`
    echo ".....device "\$NIC" selected"
  else
    echo "...Checking "\$NIC" exists"
    device_exists=\$(/usr/sbin/ifconfig | grep \$NIC | awk -F: '{print \$1}')
    if [[ -z "\$device_exists" ]]; then
      echo "...[ERROR]: device "\$NIC" not found on "$SOURCEHOST", exiting"
      echo "Aborted."
      echo ""
      exit 0
    else
      echo "...[SUCCESS]: "\$NIC" found"
    fi
  fi

  echo "...Checking "\$NIC" existing egress rules"
  netem_exists=\$(sudo tc qdisc show dev \$NIC | grep netem | awk '{print \$2}')
  if [[ \$netem_exists == "netem" ]]
  then
    echo ".....Netem found"
    echo ".....Deleting existing qdisc rules"
    sudo tc qdisc del dev \$NIC root
  else
    echo ".....No egress rules to delete"
  fi

  if [ "$CLEAR" ]
  then
    echo "Rules cleared on "\$NIC", exiting"
  else
    echo "...Create new egress qdisc rules on "\$NIC
    #sudo tc qdisc add dev \$NIC root netem delay 500ms
    sudo tc qdisc add dev \$NIC root handle 1: prio bands 10
    echo ".....Set transmission delay to "$RATE"ms on "\$NIC
    sudo tc qdisc add dev \$NIC parent 1:1 handle 10: netem delay ${RATE}ms

    if [ "$BWIDTH" ]
    then
      echo ".....Set bandwidth to "$BWIDTH"kbps on "\$NIC
      sudo tc qdisc add dev \$NIC parent 1:2 handle 20: tbf rate ${BWIDTH}kbit buffer 1600 limit 3000
    else
      echo ".....Bandwidth not set on "\$NIC
    fi

    echo ".....Create tc filters for "\$NIC" traffic to all hosts in ["$TARGETS"]"

    for TARGETHOST in $TARGETS; do
      echo ".......Setting "\$NIC" filter for traffic to "\$TARGETHOST"..."
      sudo tc filter add dev \$NIC protocol ip parent 1:0 prio 1 u32 match ip src 0.0.0.0/0 match ip dst \$TARGETHOST flowid 10:1
      echo ".....Ping test to "\$TARGETHOST":"
      ping_result=\$(ping -c 1 \$TARGETHOST | grep time=)
      echo "......."\$ping_result
    done

    echo "...Ping check to Google:"
    ping_result=\$(ping -c 1 www.google.com | grep time=)
    echo "....."\$ping_result
  fi

  echo "------------------------------------------------------------"
  echo "egress rules "${SOURCEHOST}
  echo "------------------------------------------------------------"
  sudo tc -s qdisc | grep qdisc
  echo "------------------------------------------------------------"
  echo ""
"
done

