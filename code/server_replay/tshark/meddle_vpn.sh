echo $1
if [ $1 = "connect" ];
then
osascript <<EOF
   tell application "System Events"
      tell current location of network preferences
         set VPN to service "meddle"
         if exists VPN then connect VPN
         repeat while (current configuration of VPN is not connected)
            delay 1
         end repeat
      end tell
   end tell
EOF
elif [  $1 = "disconnect" ];
then
osascript <<EOF
   tell application "System Events"
      tell current location of network preferences
         set VPN to service "meddle"
         if exists VPN then disconnect VPN
      end tell
   end tell
EOF
fi