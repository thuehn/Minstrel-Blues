# Minstrel Blues Measurement

Lua RPC nodes for tracing wifi network.

## Installation

The measurement package have to be installed on each wifi node that should be actively participating on collecting measurement data.
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

Specify a DNS nameserver by adding an option ```nameserver = "192.168.0.4"``` to the config file to enable host name resolution for config file and command line options.

The host from option ```ctrl``` manages the measurement. It can be a different machine than the one running the measurement scripts. The fetched data from all measurement nodes are stored at the host running the measurement script.

The option ```connections``` is a map for grouping accesspoints with stations by name or IP addresses. Theses identifiers have to be used in the ```name``` field of ```nodes``` that is a list of anonymous records of fields ```name```, ```radio```, ```ctrl_if``` and ```rsa_key```. The field ```radio``` denotes the radio interface prefixed by "radio" and indexed by phy index. The field ```ctrl_if``` denotes the control interface for SSH and RPC connections. The control interface of a node record may be the same as the radio interface and may be a bridge. Devices with more than one radio can participate with more radios in experiments by adding them multiple times with individual couplings of radio and control interfaces. The RSA keys are used for controlling all measurement nodes remotely from the controller. Therefore the controllers public RSA key have to be added to the authorized key file of dropbear at all nodes.

## Execute Measurement

In a first setup connect all stations to the accesspoints manually. Check the public RSA key of the controller on all nodes by logging into manually with ```ssh -i <remote_rsa_key_file_path> <host>``` from the control node. Do the same for your local machine and the control node.

### Static Power

When running static power measurements then each experiment uses a fixed power and a fixed rate. Variable parameters are the amount of time transmitting a certain data rate or transferring a certain amount of data also by a fixed data rate. In both variants the throughput and the signal noise rate are desired measurement results. There are lua profiles for UDP, TCP and multicast experiments.

#### UDP example

The following script executes 4 UDP (2x2) experiments on one accesspoint connected with one station from config file. All fixed powers and rates are specified as lists of indices. The data rate is set to 10 Mbits/s for 10 seconds. The control node should use the interface ```eth0``` instead of the interface from the config file. The distance parameter is a text label to denote the average distance between nodes in the log and has no effect to any experiment.

```/usr/bin/traceWifi udp --enable_fixed --tx_powers 1,2 --tx_rates 1,2 -R 10M -t 10 --net_if eth0 --distance near```

The command will start the control node and the control node itself starts the measurement nodes with ```ssh```. Remote procedure connections between the controller and the other nodes are established. Each experiment is executed seperately in randomized order and the processes on all nodes are managed with RPC functions by the controller. The collected data traces are fetched after each experiment and are stored in a time stamp directory in ```/tmp``` because no empty output directory was specified.

The data can be fetched online during each experiment running with command line option ```--online``` when different interfaces for controling and experimenting are present. Without enabling option ```--online``` or providing local USB storage with option ```--dump_to_dir``` it is not possible to perform long experiments or high data rates since the traces have to be collected in the limited device memory during an experiment.

Please refer to the output of option ```--help``` for a complete list of available options.

# Analyse Measurement

Statistical analysis and reporting is done in language ```R```. The traces of the measurement have to be processed by a lua script to extract data points for inspection.

## Dependencies

Extracting data point using ```tshark``` requires an installation of wireshark with enabled tshark compilation option.

The ```R``` scripts requires the following dependencies.

* ```R> install.packages("tidyverse")```
* ```R> install.packages("plotly")```
* ```R> install.packages("Hmisc")```
* ```R> install.packages("quantreg")```
* ```R> install.packages("ggplot2")``` - already a dependency of tidyverse
* ```R> install.packages("readr")```
* ```R> install.packages("webshot")```

For three dimensional processing additional dependecies are needed.
* chrome browser
* ```R> install.packages("RSelenium")```

## Example: Preprocessing SNR from pcap files with ```tshark``` from static power measurement.

This example can process data from static power measurements, i.e. ```/usr/bin/traceWifi udp --enable_fixed```. The fixed power and the fixed rate were coded in the pcap file names.
The following command extracts the signal noise rate (SNR) from dumped pcap files, saves a comma separated list in file ```~/data/snr-histogram-per_rate-power.csv``` and passes that file to the ```R``` script ```R/rate-power-validation.R```. The ```R``` script will plot several diagrams into files in the data directory and after than it will open an three dimenstional interactive plot of the whole SNR diagram with a chrome browser.

```/usr/bin/analyseSNR -t ~/data```

# Future

The next steps may be:

* mesh networks
* dynamic power experiments

# Troubleshooting

## minstrel-measurement package doesn't appear in menuconfig of OpenWRT/LEDE

When no entry for the measurement package appears under "Languages/Lua" then the feed may not be present or some dependencies are not resolved correctly.

First check whether the packages of a feed are available and installed and then check the dependencies.

All dependencies are listed in the search result section of ```menuconfig```. Enter ```/``` and then type into the search dialog the phrase ```minstrel-measurement``` and all matching packages and options are lists together with their location and the dependencies. When there exists more than one choises for certain package, i.e. one act as a drop-in replacement for the other then the dependencies are not resolved. In section Network the packages ```iw``` and ```iw-full``` are such drop-in replacements the measurement package depends on. Here the package ```iw-full``` should be selected.

## ssid cannot be determined by a node

Maybe the wrong package of iw is installed. Please check the dependencies. At OpenWRT / LEDE are two variant of iw available. As a test try to run, i.e. ```iw wlan0 info```.
