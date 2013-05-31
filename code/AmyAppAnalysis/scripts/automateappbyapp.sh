#!/bin/bash
#This script takes a directory name, reads all the apks in it.
# It installs each apk onto the phone. Then it runs a 10,000 monkey random actions.
# It then uninstalls and reflashes (with an image optionally).
echo " " > apktimestamps.txt
directory=$1
image=$2
#Meddle must be turned on and connected at this point
#Unlock phone
adb shell input keyevent 26;adb shell input text meddlepw ;adb shell input keyevent 66

#sets up screen rotations (for disconnecting and connecting meddle)
adb shell content insert --uri content://settings/system --bind name:s:accelerometer_rotation --bind value:i:0

for file in $directory/*.apk;
do
packagename=$(aapt dump badging "$file" | grep package | awk -F ' ' '{print $2}' | awk -F "'" '{print $2}')
echo "$packagename : $(date)" >> apktimestamps.txt
#Goes to home
adb shell input keyevent 3

#restart meddle and rotate it (to get it to disconnect and reconnect)
#adb shell am start  org.strongswan.android/.ui.MainActivity
#adb shell content insert --uri content://settings/system --bind name:s:user_rotation --bind value:i:1
#adb shell content insert --uri content://settings/system --bind name:s:user_rotation --bind value:i:0
#adb shell input keyevent 66

echo "FILENAME: "  "$file"
echo "PACKAGE: " + $packagename
adb install "$file"
#do this ten times. we do short bursts in case it accidentally closes out of application
 for i in $(seq 1 5); 
  do
    adb shell monkey -p $packagename -v 200 --pct-syskeys 0 --pct-appswitch 0 --kill-process-after-error --throttle 100000
  done
adb uninstall $packagename


adb reboot

#wait for boot animation to stop
while [ -z "$(adb shell getprop init.svc.bootanim | grep stopped)"  ]
 do sleep 2
done

#input password; default meddlepw
adb shell input text meddlepw ;adb shell input keyevent 66

#wait for meddle to start
while [ -z "$(adb shell ps | grep 'org.strongswan.android')" ]
  do sleep 2
done
#check checkbox, press ok button
adb shell input keyevent 66; adb shell input keyevent 61; adb shell input keyevent 61; adb shell input keyevent 66

done 
