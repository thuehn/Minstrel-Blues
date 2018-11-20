# Minstrel Measurement

Lua rpc nodes for tracing wifi network.

## Installation

The measurement package have to be installed on each wifi node that should be activly participating on collecting mesurement data.
First patch the kernel with minstrel blues algorithm sources according to https://github.com/thuehn/Minstrel-Blues/blob/master/README.md.

### Install measurement package

You can choose between using packages or installing from source.

#### OpenWRT / LEDE

OpenWRT / LEDE packages can be added to feeds from https://github.com/thuehn/Minstrel-Blues/tree/master/lede-packages, i.e. by adding a line pointing to a copy into the file ```feeds.conf```:

```
src-link minstrelm /home/user/Minstrel-Blues/lede-packages
```

After updating your feeds with ```~/openwrt $ ./scripts/feeds update``` the package ```minstrel-measurement``` can be selected with ```~/openwrt $ make menuconf``` under the Menu ```Languages/Lua```.

#### Gentoo

Gentoo packages are available at ```https://github.com/thuehn/Minstrel-Blues/tree/master/portage```. Add a recursive copy of all files and directories from ```portage``` directory to the local portage tree, i. e. denoted in file ```/etc/portage/repos.conf/localrepo.conf```:

```
[localrepo]
location = /usr/local/portage
```

After synchronizing with ```emerge sync``` the package can be installed with ```èmerge -av minstrel-measurement```. The keywords are not set to stable and have to be overwritten, i.e. by autounmask.

#### Install from source

Install all dependencies and run gnu make and ```make install``` to install into the system. The dependencies are:

* lua 5.1
* lua filesystem
* <= luaposix 33.2.1
* lua bit op
* pcap lua
* lpc
* lua argparse
* lua pprint
* lua rpc
* lua system
* lua cjson
* procps
* dig
* iw
* tcpdump
* iperf 2
* ssh

## Configuration

A configuration file ```~/.minstrelmrc``` is needed.

```
ctrl = "192.168.0.1"

connections["192.168.0.3"] = { "192.168.0.2" }

nodes = { { name = "192.168.0.1", radio = "radio0", ctrl_if = "enp0s31f6", rsa_key = "/home/user/.ssh/id_rsa.pub" }
        , { name = "192.168.0.2", radio = "radio0", ctrl_if = "br-lan", rsa_key = "/etc/dropbear/id_rsa" }
        , { name = "192.168.0.3", radio = "radio0", ctrl_if = "br-lan", rsa_key = "/etc/dropbear/id_rsa" }
        }
```

Specify a DNS nameserver by adding ```nameserver = "192.168.0.4"``` to the config file for using host names in the config file and at the command line.

The host ```ctrl``` manages the measurement. It can be a different machine than the one running the measurement scripts. The fetched data from all measurement nodes are stored at the host running the measurement script.

```Connections``` is a map for grouping accesspoints with stations and ```nodes``` is a list of anonymous records of fields ```name```, ```radio```, ```ctrl_if``` and ```rsa_key```. The name may contain the IP address and the control interface may be a bridge. The rsa keys are used for controlling all measurement nodes remotely from the controller. Therefore the controllers public rsa key have to be added to the authorized key file of dropbear at all nodes.

## Execute Measurement

First connect all stations to the accesspoints manually. Check the public rsa key of the controller on all nodes by logging into with ssh manually from the control node.

### Static Power

When running static power measurement then each experiments uses a fixed power and a fixed rate. Variable parameters are the transmitted amount of data with a fixed amount of time or how long a transmittion with a fixed data rate should last. There are profiles for udp, tcp and multicast experiments.

#### UDP example

The following script executes 4 udp experiments on one accesspoint connected with one station from config file. All fixed powers and rates are specified as lists of indizes. The data rate is set to 10 Mbits/s for 10 seconds. The control node should use the interface ```eth0``` instead of the interface from the config file. The distance parameter is a text label to denote the average distance between nodes in the log and has no effect to any experiment.

```/usr/bin/netRun udp --enable_fixed --tx_powers 1,2 --tx_rates 1,2 -R 10M -t 10 --net_if eth0 --distance near```

The command will start the control node and the control node itself starts the measurement nodes with ssh. Remote procedure connections between the controller and the other nodes are established. Each experiment is executed seperately in randomized order and the processes on all nodes are managed with rpc functions by the controller. The collected data traces are fetched after each experiment and are stored in a time stamp directory in ```/tmp``` because no empty output directory was specified. The data can be fetched online during each experiment running with option ```--online``` when different interfaces for controlling and experimenting are present.

Please refer to the output of option ```--help``` for a complete list of available options.

# Future

The next steps may be:

* support for usb local storage
* mesh networks
* dynamic power experiments
