# tcc
The following script can be used to simulate latency and bandwidth limitations for a remote node.
```
$ ./tcc.sh -h


   Usage:
   ./tcc.sh -s <Source IP list> -t <Target IP list> [-d <device>] -r <delay> [-b <bandwidth>]
   ./tcc.sh -s <Source IP list> -c [y|n]
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
```

For example:
```
$ ./tcc.sh -s "3.10.138.208"  -t "3.10.138.12" -r 100 -b 1024 -d probe

tcc will shape network traffic:
    from Source      [3.10.138.208]
      to Destination [3.10.138.12]
    using:
         Device      [probe]
         Speed       [100] ms
         Bandwidth   [1024] kbps

Connecting to 3.10.138.208...
Connected.
...Host name: ip-172-31-36-8.eu-west-2.compute.internal
...Probing for active network interface...
.....device eth0 selected
...Checking eth0 existing egress rules
.....Netem found
.....Deleting existing qdisc rules
...Create new egress qdisc rules on eth0
.....Set transmission delay to 100ms on eth0
.....Set bandwidth to 1024kbps on eth0
.....Create tc filters for eth0 traffic to all hosts in [3.10.138.12]
.......Setting eth0 filter for traffic to 3.10.138.12...
...Ping test to 3.10.138.12:
.....64 bytes from 3.10.138.12: icmp_seq=1 ttl=254 time=100 ms
...Ping check to Google:
.....64 bytes from lhr48s08-in-f4.1e100.net (172.217.169.36): icmp_seq=1 ttl=43 time=1.71 ms
------------------------------------------------------------
egress rules created on 3.10.138.208
------------------------------------------------------------
qdisc noqueue 0: dev lo root refcnt 2
qdisc prio 1: dev eth0 root refcnt 9 bands 10 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
qdisc netem 10: dev eth0 parent 1:1 limit 1000 delay 100.0ms
qdisc tbf 20: dev eth0 parent 1:2 rate 1024Kbit burst 1599b lat 10.9ms
------------------------------------------------------------
```
To clear rules set on a single machine, default to eth0:
```
$ ./tcc.sh -s 3.10.138.208 -c y


tcc will shape network traffic:
    from Source      [3.10.138.208]
      to Destination []
    using:
         Device      [eth0 - default]
         Option      [clear=y]

Connecting to 3.10.138.208...
Connected.
...Host name: ip-172-31-36-8.eu-west-2.compute.internal
...Checking eth0 exists
...[SUCCESS]: eth0 found
...Checking eth0 existing egress rules
.....No egress rules to delete
Rules cleared on eth0, exiting
------------------------------------------------------------
egress rules 3.10.138.208
------------------------------------------------------------
qdisc noqueue 0: dev lo root refcnt 2
qdisc mq 0: dev eth0 root
qdisc pfifo_fast 0: dev eth0 parent :8 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
qdisc pfifo_fast 0: dev eth0 parent :7 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
qdisc pfifo_fast 0: dev eth0 parent :6 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
qdisc pfifo_fast 0: dev eth0 parent :5 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
qdisc pfifo_fast 0: dev eth0 parent :4 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
qdisc pfifo_fast 0: dev eth0 parent :3 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
qdisc pfifo_fast 0: dev eth0 parent :2 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
qdisc pfifo_fast 0: dev eth0 parent :1 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1
------------------------------------------------------------
```