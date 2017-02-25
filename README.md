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

# Contributions
- joint rate and power control in WiFi networks to increase spacial reuse by lowering interference to the necessary level and hence increase sum-network throughput in todays WiFi networks
- cross-layer algorithm Minstrel-Blues for off-the-shelf 802.11b/g/a WiFi hardware
- new joint utility function to specify user preferences for lowering transmit power with respect to throughput reduction
- Linux kernel implementation, validation, performance evaluation with legacy Minstrel & Minstrel_HT

# Current Goals
1. integration of Blues into Minstrel-HT to supprt IEEE 802.11b/g/a/n/ac hardware
2. get a well structured set of patches to enable Linux ubstream acceptance & final kernel intregration
3. validate and analyse Minstrel-Blues performance in different WiFi environments

## How to use Minstrel-Blues ?
(my development environment is Linux LEDE on embedded routers driving Atheros ath9k WiFi hardware)
- get the current trunk verision of LEDE (git clone git clone http://git.lede-project.org/source.git)
- checkout Minstrel-Blues current version
- copy all patches from the src folder into /lede/packages/kernel/mac80211/patches
- rebuild mac80211 subsystem by: make package/mac80211/{clean,compile} or re-build complite LEDE
- install new mac80211 package or flash full image to your router

## Usage instructions to control Minstrel-Blues
- TBD !

## Do you want to contribute ?
Everybody can participate, and any help is highly appreciated.
Feel free to send pull requests or open a new issue via GitHub.
- testing Minstrel-Blues and its performance in your environment
- reviewing kernel patches (get your hands on QUILT to work with patch series)

### Supporters and Developers
- Stefan Venz from TU-Berlin
- Felix Fietkau (aka nbd) from OpenWrt


### former contributors
- Alina Friedrichsen
- Bastian Bittorf from Freifunk Weimar

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
