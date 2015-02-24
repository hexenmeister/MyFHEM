#!/bin/sh

druckerip=192.168.0.49
dosepoch=`date +%s -d "1980-01-01 00:00:00"`
unixseconds=`date +%s`
mydate=`echo "$unixseconds - $dosepoch" | bc`
#echo $dosepoch
#echo $unixseconds
#echo $mydate
curl -d "DateTime=$mydate" http://$druckerip/fax/general_setup.html?kind=item -u admin:7ac7kdy7
