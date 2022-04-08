---
layout: post
title: 👨‍💻 Local API Retro Engineering
date: 2022-03-16 22:30 +0100
---


## Exposing the problem
_We want to control programatically a smart speaker but there is no public API._
_The speaker application communicates locally, so a proprietary local API should exists and we want to use it as well._
- Have a pair of smart/connected speakers.
- Can be controlled by an app locally
- Must have a local API of some kind
- Need to capture packets send by the application and analyse network activity

## Capturing network trafic
_In order to understand how the API works, we will spy on the communication between the app and the speakers._
What we want to do
| app | --> network --> | smart speakers | 
              |
        packet interception

### Problem
_We need to come with a setup that allows us to spy on the app-speaker trafic._
- not possible to easily intercept packet sent by and android phone
- A possible solution is to host application in VM and intercept VM trafic before it reached the physical level
- Android for ARM, our computer is on x86_64 architecture. ->**** will use Android x86 release
- need to setup a VM running android x86 and wireshark
- 
## setup
_We will setup a VM running a distribution of Android compatible with our processor, and then intercept and filter all the VM trafic with WireShark._

### VM
- Install virtmanager and qemu.
- download Android x86 iso
- Configure VM
- Install android x86
- Install speakers app on the VM

### Wireshark
- install wireshark
- caution with sudo !
- configure wireshark

## Let the hacking begin
_Now that everything is setup, we can start analyzing the trafic._
### Grab a few paquets
- generate trafic in the app
- identify pertinent trafic
- filter trafic

### Analyze the packets & Draft and API
- paquet structure
- draft and API

## Start building and API
- Python requests

## Profit !






