
build
=====

*Either* edit the defaults at the top of `build.sh`: to make sure the used directories are correct (and set a version suffix: x for xopr ;)
```
# Defaults
VERSION_SUFFIX=<suffix>
ARDUINO_BIN=<dir>
ARDUINO_PACKAGES=<dir>
ARDUINO_LIBRARIES=<dir>
UPLOAD_PATH=<scp path>
```

*or* use the following parameters:
```
     -s, --suffix <suffix>    add version suffix
     -b, --bin <dir>          arduino bin directory
     -p, --packages <dir>     arduino packages directory
     -l, --libraries <dir>    arduino packages directory
     -u, --upload <path>      upload to remote path
```

Place the WiPhone-*.zip file in the root of this directory and run `./build.sh` (optionally with parameters listed above)

other parameters
----------------

The following parameters are also available (to steps or be more verbose):
```
   other options:
     -h, --help               show this help message and exit
     -v, --verbose            increase the verbosity of the bash script

   negating options:
     -a, --noarchive          don't create a backup of the current folder
     -z, --nounzip            don't unzip source (implicit backup copy)
     -o, --nopatch            don't apply any patches
     -x, --nosuffix           don't add auto version suffix (default: $VERSION_SUFFIX)
     -c, --nocompile          don't compile
     -r, --norestore          don't revert applies patches in repo
     -f, --nofiles            don't generate OTA files
     -n, --noupload           don't upload to server
```
The lower set of options is to disable a step in the build (and upload) process.
By default, the build script runs the following (tag included, disable with `-no` or use the sorthand param):
* backup: (archive, ~a: move if unzip, ~z, else copy)
* unzip latest version (unzip, ~z)
* stashing local work (restore, ~r)
* applying patches(patch, ~o)
* set version suffix (suffix, ~x)
* compile project.. (compile, ~c)
* copy partition information (compile, ~c)
* copy default partitions (compile, ~c)
* compile ctags (compile, ~c)
* build ctags (compile, ~c)
* compile project (compile, ~c)
* create elf (compile, ~c)
* extract bin (compile, ~c)
* partition bin (compile, ~c)
* restore current work (restore, ~r)
* create OTA file (files, ~f)
* upload (upload, ~n)

generate patch
==============

To start a clean branch where one can write patches:
* `./build.sh -x -o -c -r -f -n -v`
    * no suffix, patch, compile, restore, OTA or upload
* Navigate inside the `Wiphone/` directory
    * Do some coding
    * Generate patches: `git diff HEAD -- [file] > ../patches/my_work.patch`
    * optionally reset the project with `git reset --hard` for the next topic

reapply single patch
--------------------
To reapply your current patch, use the following:
* Navigate inside the `Wiphone/` directory
  * `patch --forward -r - -p1 < ../patches/my_work.patch`

list of patches
===============

The following patches are currently created (on file)
* version (done automatically in the build script): `config.h`
* configs (timezone, lock, LoRa): `data/configs.ini`
* OTA URL: `data/ota.ini`
* EU LoRa frequency: `Hardware.h` (See https://github.com/ESP32-WiPhone/wiphone-firmware/issues/24)
* lock screen ignore keys: `GUI.cpp`(See https://github.com/ESP32-WiPhone/wiphone-firmware/issues/28)
* Loud speaker: `GUI.cpp` (See https://github.com/ESP32-WiPhone/wiphone-firmware/issues/3)
* Caret in dial app (See https://github.com/ESP32-WiPhone/wiphone-firmware/issues/30)
* TODO (look into possibilities):
    * Full LoRa menu: https://github.com/ESP32-WiPhone/wiphone-firmware/issues/24
    * Dial "*" for phonenumbers: https://github.com/ESP32-WiPhone/wiphone-firmware/issues/20
    * Press and hold keys: https://github.com/ESP32-WiPhone/wiphone-firmware/issues/25
    * ESP RTC: https://github.com/ESP32-WiPhone/wiphone-firmware/issues/26
    * Custom NTP: https://github.com/ESP32-WiPhone/wiphone-firmware/issues/27
    * Right arrow for submenu: https://github.com/ESP32-WiPhone/wiphone-firmware/issues/29

considerations
==============
You might consider to create a patch for adding a sip account in `data/sip_accounts.ini`:
```
[]
m=1
d=<nick>
s=sip:<nick>@ackspace.nl
p=<pass>
```
as well as a phonebook list:
```
[]
n=<friend>
s=sip:<friend>@ackspace.nl
l=<lora friend mac>
[]
n=broadcast
l=000000
```

useless commands
================

To do absolutely nothing, run:
`./compile.sh -a -z -o -x -c -r -f -n -v`