```
                                   __                 
 )\/) o  _   _ _)_  _   _   )  __  )_)  )       _   _ 
(  (  ( ) ) (  (_  )   )_) (      /__) (  (_(  )_) (  
            _)        (_                      (_   _) 
```

This repository contains the development of my joint rate &amp; power controller Minstrel-Blues 
for the Linux mac80211 subsystem. The mac80211 rate control algorithms Minstrel and Minstrel_HT are 
extended by my transmit power control algorithm Blues. The current development is based on my dissertation 
about practical ressource allocation in WiFi networks at the Technical University of Berlin.

# main contributions
- joint rate and power control in WiFi networks to increase spacial reuse and hence sum-network throughput
- cross-layer algorithm Minstrel-Blues for 802.11b/g/a WiFi hardware
- new joint utility function to specify user preferences by setting a weighting factor
- Linux kernel implementation, validation, performance evaluation with legacy Minstrel

# current Goals
1. integration of Blues into Minstrel-HT to supprt IEEE 802.11n/ac hardware
2. get a well structured set of patches to enable Linux ubstream acceptance & final intregration
3. validate and analyse Minstrel-Blues performance in different environments

## How to use Minstrel-Blues ?
(my development environment is Linux OpenWrt on embedded routers driving Atheros ath9k WiFi hardware)
- get the current trunk verision of OpenWrt (git clone git://git.openwrt.org/openwrt.git)
- checkout Minstrel-Blues current version
- copy all patches from the src folder into /openwwrt/packages/kernel/mac80211/
- rebuild mac80211 subsystem by: make package/mac80211/{clean,compile} or re-build complite OpenWrt
- install new mac80211 package or flash full image to your router

## Usage instructions to control Minstrel-Blues
- TBD !

## Do you want to contribute ?
Everybody can participate, and any help is highly appreciated.
Feel free to send pull requests or open a new issue via GitHub.
- testing Minstrel-Blues performance
- reviewing kernel patches




### How to reference to  Minstrel-Blues ?
Just use the following bibtex :
```
@PhdThesis{Huehn2013,
 author      = {Thomas H{\"u}hn},
 title       = {A Measurement-Based Joint Power and Rate Controller for IEEE 802.11 Networks},
 school      = {Technische Universit{\"a}t Berlin, FG INET Prof. Anja Feldmann},
 year        = 2013,
 month       = July,
 urn         = {urn:nbn:de:kobv:83-opus4-39397},
 url         = {http://opus4.kobv.de/opus4-tuberlin/frontdoor/index/index/docId/3939}
}
```
