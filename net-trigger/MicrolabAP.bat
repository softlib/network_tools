netsh wlan stop hostednetwork
rem net stop SharedAccess
rem net stop Wlansvc
rem net start Wlansvc
rem net start SharedAccess
netsh wlan set hostednetwork mode=allow ssid="MicrolabAP" key="7a8b9c4d5e"
netsh wlan start hostednetwork