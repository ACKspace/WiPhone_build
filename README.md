
build
=====

You can use the following optional parameters.
When no arguments are provided, `--all` (with all its defaults) is assumed
```
    -a, --all                       enable all steps: backup, compile, debug, extract, ota, patch, restore, suffix, upload
    -b, --backup                    backup current source directory
    -c, --compile                   compile
    -d, --debug       <0 to 5>      set ESP core debug level, default 0, part of compile
    -e, --extract                   extract latest source zip 
    -h, --help                      show this help message and exit
    -j, --bin         <dir>         set arduino bin, default ~/bin/arduino-1.8.16
    -k, --packages    <dir>         set arduino packages, default ~/.arduino15/packages
    -l, --libraries   <dir>         set arduino libraries, default ~/Arduino/libraries
    -o, --ota                       generate OTA
    -p, --patch                     apply patches from the patches folder
    -r, --restore                   restore original source code
    -s, --suffix      <suffix>      set version suffix, default rc01x
    -u, --upload      <path>        scp upload path, default ackspace:/var/www/ackspace.nl/WiPhone/
    -v, --verbose                   be verbose on script output
```
Short parameter values are separated by space, i.e. `-s rc02a`; long parameters with `=`, i.e. `--suffix=rc02a`.

Place the WiPhone-*.zip file in the root of this directory and run `./build.sh` (optionally with parameters listed above)

For the version suffix, please keep the following format in mind: `rc<digits><trailing character>`
Where `<digits>` typically will be between 00 and 99, and `<character>` is something typically to identify the (contact) person delivering the build: `x` for xopr.

generate patch
==============

To start a clean branch where one can write patches:
* `./build.sh -be`
    * backup and extract zip.
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

To do absolutely nothing (display variables), run:
`./compile.sh -v`
