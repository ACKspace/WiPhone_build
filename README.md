Edit `compile.sh` to make sure the used directories are correct (and set a version suffix: x for xopr ;)
```
ARDUINO_BIN=~/bin/arduino-1.8.16
ARDUINO_PACKAGES=~/.arduino15/packages
ARDUINO_LIBRARIES=~/Arduino/libraries
VERSION_SUFFIX=x01
```

Place the WiPhone-*.zip file in the root of this directory and run `./compile.sh`

To generate patches from a working branch, run `./create_patch.sh`
