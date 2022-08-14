pushd WiPhone > /dev/null
echo version
git diff HEAD -- config.h > ../patches/version.patch

echo LoRa EU frequency
git diff HEAD -- Hardware.h > ../patches/lora_eu.patch

echo Lockscreen fixes
git diff HEAD -- GUI.cpp > ../patches/lockscreen.patch

echo "configs (timezone, lock, LoRa)"
git diff HEAD -- data/configs.ini > ../patches/configs.patch

echo "OTA URL"
git diff HEAD -- data/ota.ini > ../patches/ota.patch

#echo "Phonebook, verify!"
##git diff HEAD -- data/phonebook.ini > ../patches/phonebook.patch
#echo SIP accounts
#[]
#d=axopr
#s=sip:xopr@ackspace.nl
#p=
