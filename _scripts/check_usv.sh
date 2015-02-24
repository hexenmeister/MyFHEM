#!/bin/sh

BATPRESENT=`cat /sys/class/power_supply/battery/present`
BATLEVEL=`cat /sys/class/power_supply/battery/capacity`
BATONLINE=`cat /sys/class/power_supply/battery/online`
#DATE=`date`
DATE=`date +"%F_%R"`

if [ $BATPRESENT -eq 0 ]
then 
#    echo -e "$DATE: Batterie nicht vorhanden"
    exit
fi

if [ $BATONLINE -eq 0 ]
then
#    echo -e "$DATE: Batterie wird nicht entladen Ladezustand: $BATLEVEL"
    exit
fi

#if [ $BATONLINE -eq 1 ]
#then
#    echo -e "$DATE: Batterie wird entladen Ladezustand: $BATLEVEL"
#fi

#if [ $BATONLINE -eq 1 ] && [ $BATLEVEL -le 40 ]
#then
#    echo -e "$DATE: Batterieladezustand niedrig: $BATLEVEL" >>  /var/log/battery.log
#    exit
#fi

if [ $BATONLINE -eq 1 ] && [ $BATLEVEL -le 30 ]
then
    echo -e "$DATE: Batterieladezustand niedrig: $BATLEVEL" >>  /var/log/battery.log
    echo -e "$DATE: Cubietruck wird heruntergefahren" >> /var/log/battery.log
    halt
    exit
fi
