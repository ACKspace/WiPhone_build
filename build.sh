#!/usr/bin/env bash

# No params or --all provided?
VERBOSE=0
CORE_DEBUG=0 # 0=None, Error, Warning, Info, Debug, 5=Verbose
ARDUINO_BIN=~/bin/arduino-1.8.16
ARDUINO_PACKAGES=~/.arduino15/packages
ARDUINO_LIBRARIES=~/Arduino/libraries

if [[ $@ =~ (^| )(-a|--all)( |$) || $# -eq 0 ]]; then
    # Apply defaults
    VERSION_SUFFIX=rc01x

    UNZIP=1
    PATCH=1
    COMPILE=1
    RESTORE=1
    FILES=1
    BACKUP=1
    UPLOAD_PATH=ackspace:/var/www/ackspace.nl/WiPhone/
else
    UNZIP=0
    PATCH=0
    COMPILE=0
    RESTORE=0
    FILES=0
    BACKUP=0
fi

BUILD_PATH=`dirname $0`
WIPHONE_PATH=$BUILD_PATH/WiPhone

function usage()
{
    echo $@
    cat << HEREDOC

   Usage: $0 [arguments]
   When no arguments are provided, --all (with defaults) will be applied.
   Short argument values are separated with sapce, long with '='
   When applying a single parameter but still want to apply defaults, add --all

   optional arguments:
    -a, --all                       enable all steps
    -b, --backup                    backup current source directory
    -c, --compile                   compile
    -d, --debug       <0 to 5>      set ESP core debug level, default $CORE_DEBUG
    -e, --extract                   extract latest source zip 
    -h, --help                      show this help message and exit
    -j, --bin         <dir>         set arduino bin, default $ARDUINO_BIN
    -k, --packages    <dir>         set arduino packages, default $ARDUINO_PACKAGES
    -l, --libraries   <dir>         set arduino libraries, default $ARDUINO_LIBRARIES
    -o, --ota                       generate OTA
    -p, --patch                     apply patches from the patches folder
    -r, --restore                   restore original source code
    -s, --suffix      <suffix>      set version suffix, default $VERSION_SUFFIX
    -u, --upload      <path>        scp upload path, default $UPLOAD_PATH
    -v, --verbose                   be verbose on script output
HEREDOC
    exit 1
}

# From https://stackoverflow.com/questions/402377/using-getopts-to-process-long-and-short-command-line-options
while getopts ':abcd:ehj:k:l:oprs:u:v-' OPTION ; do
  case "$OPTION" in
    -  ) [ $OPTIND -ge 1 ] && optind=$(expr $OPTIND - 1 ) || optind=$OPTIND
         eval OPTION="\$$optind"
         OPTARG=$(echo $OPTION | cut -d'=' -f2)
         OPTION=$(echo $OPTION | cut -d'=' -f1)

         # Note: if $OPTION === $OPTARG, no arguments were provided
         case $OPTION in
            --all        ) ;;
            --backup     ) BACKUP=1 ;;
            --compile    ) COMPILE=1 ;;
            --debug      )
                            [ $OPTARG -ge 0 -a $OPTARG -le 5 ] \
                            && CORE_DEBUG=$OPTARG \
                            || usage debug needs to be between 0 and 5
                        ;;
            --extract    ) UNZIP=1 ;;
            --help       ) usage ;;
            --bin        ) ARDUINO_BIN="$OPTARG" ;;
            --packages   ) ARDUINO_PACKAGES="$OPTARG" ;;
            --libraries  ) ARDUINO_LIBRARIES="$OPTARG" ;;
            --ota        ) FILES=1 ;;
            --patch      ) PATCH=1 ;;
            --restore    ) RESTORE=1 ;;
            --suffix     ) VERSION_SUFFIX="$OPTARG" ;;
            --upload     ) UPLOAD_PATH="$OPTARG" ;;
            --verbose    ) VERBOSE=1 ;;
#           *            ) echo this triggers if parameters are not ordered on length 
         esac
       OPTIND=1
       shift
      ;;
    a  ) ;;
    b  ) BACKUP=1 ;;
    c  ) COMPILE=1 ;;
    d  )
        [ $OPTARG -ge 0 -a $OPTARG -le 5 ] \
            && CORE_DEBUG=$OPTARG \
            || usage debug needs to be between 0 and 5
        ;;
    e  ) UNZIP=1 ;;
    h  ) usage ;;
    j  ) ARDUINO_BIN="$OPTARG" ;;
    k  ) ARDUINO_PACKAGES="$OPTARG" ;;
    l  ) ARDUINO_LIBRARIES="$OPTARG" ;;
    o  ) FILES=1 ;;
    p  ) PATCH=1 ;;
    r  ) RESTORE=1 ;;
    s  ) VERSION_SUFFIX="$OPTARG" ;;
    u  ) UPLOAD_PATH="$OPTARG" ;;
    v  ) VERBOSE=1 ;;
    ?  ) usage unknown parameter ;;
  esac
done

if [ $VERBOSE -eq 1 ]; then
echo "Verbose mode:"
echo "  backup: $BACKUP"
echo "  compile: $COMPILE"
echo "  debug: $CORE_DEBUG"
echo "  extract: $UNZIP"
echo "  bin: $ARDUINO_BIN"
echo "  packages: $ARDUINO_PACKAGES"
echo "  libraries: $ARDUINO_LIBRARIES"
echo "  ota: $FILES"
echo "  patch: $PATCH"
echo "  restore: $RESTORE"
echo "  suffix: $VERSION_SUFFIX"
echo "  upload: $UPLOAD_PATH"
fi

# Backup
if [[ -d $WIPHONE_PATH && $BACKUP -eq 1 ]]; then
    echo -n "* backup: "

    # TODO: nounzip -> cp -R
    if [ $UNZIP -eq 1 ]; then
        echo "move"
        mv $WIPHONE_PATH "${WIPHONE_PATH}_`date -Iminutes`"
    else
        echo "copy";
        if [ $VERBOSE -eq 1 ]; then
            cp $WIPHONE_PATH "${WIPHONE_PATH}_`date -Iminutes`" -R -v
        else
            cp $WIPHONE_PATH "${WIPHONE_PATH}_`date -Iminutes`" -R
        fi
    fi
fi

# Unzip latest version
if [ $UNZIP -eq 1 ]; then
    echo "* unzip latest version to $WIPHONE_PATH"
    ZIP=`ls *.zip -1|sort -n|tail -n1`

    if [ $VERBOSE -eq 1 ]; then
        unzip $ZIP && rm -fr WiPhone && mv `basename $ZIP .zip` $WIPHONE_PATH
    else
        unzip -qq $ZIP && rm -fr WiPhone && mv `basename $ZIP .zip` $WIPHONE_PATH
    fi
    VERSION=`basename $ZIP .zip|awk -F '[-]' '{print $2}'`
else
    # Fetch version from existing config
    VERSION=`cat $WIPHONE_PATH/config.h |grep FIRMWARE_VERSION|awk -F '[ "]' '{print $4}'`
fi

# Stash current changes
if [ $RESTORE -eq 1 ]; then
    pushd $WIPHONE_PATH > /dev/null
    echo "* stashing local work"
    if [ $VERBOSE -eq 1 ]; then
        git stash push -m "backup `date -I`"
    else
        git stash push --quiet -m "backup `date -I`" > /dev/null
    fi
    popd > /dev/null
fi

if [ $PATCH -eq 1 ]; then
    # Apply patches
    pushd $WIPHONE_PATH > /dev/null

    echo "* applying patches"
    for PATCH in ../patches/*.patch; do
        if [ $VERBOSE -eq 1 ]; then
            patch --forward -r - -p1 < $PATCH
            echo
        else
            patch --quiet --forward -r - -p1 < $PATCH
        fi
    done
    popd > /dev/null
fi

# Add version suffix
if [ ! -z $VERSION_SUFFIX ]; then
    VERSION=$VERSION$VERSION_SUFFIX
    echo "* set version $VERSION"
    sed -i "s/#define FIRMWARE_VERSION .*/#define FIRMWARE_VERSION \"$VERSION\"/g" $WIPHONE_PATH/config.h
fi

# Determine version after patch/suffix
VERSION=`cat $WIPHONE_PATH/config.h |grep FIRMWARE_VERSION|awk -F '[ "]' '{print $4}'`

if [ $COMPILE -eq 1 ]; then
    # Compile
    CACHE=`mktemp -d arduino_cache-XXX`
    BUILD=`mktemp -d arduino_build-XXX`

    if [ $VERBOSE -eq 1 ]; then
        echo "* dump prefs:"
        $ARDUINO_BIN/arduino-builder -dump-prefs -hardware $ARDUINO_BIN/hardware -hardware $ARDUINO_PACKAGES -tools $ARDUINO_BIN/tools-builder -tools $ARDUINO_BIN/hardware/tools/avr -tools $ARDUINO_PACKAGES -built-in-libraries $ARDUINO_BIN/libraries -libraries $ARDUINO_LIBRARIES -fqbn=WiPhone:esp32:wiphone:PSRAM=enabled,PartitionScheme=default,UploadSpeed=921600,DebugLevel=none -ide-version=10816 -build-path $BUILD -warnings=none -build-cache $CACHE -prefs=build.warn_data_percentage=75 -prefs=runtime.tools.mkspiffs.path=$ARDUINO_PACKAGES/WiPhone/tools/mkspiffs/0.2.3 -prefs=runtime.tools.mkspiffs-0.2.3.path=$ARDUINO_PACKAGES/WiPhone/tools/mkspiffs/0.2.3 -prefs=runtime.tools.esptool_py.path=$ARDUINO_PACKAGES/WiPhone/tools/esptool_py/2.6.1 -prefs=runtime.tools.esptool_py-2.6.1.path=$ARDUINO_PACKAGES/WiPhone/tools/esptool_py/2.6.1 -prefs=runtime.tools.xtensa-esp32-elf-gcc.path=$ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0 -prefs=runtime.tools.xtensa-esp32-elf-gcc-1.22.0-80-g6c4433a-5.2.0.path=$ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0 -verbose $WIPHONE_PATH/WiPhone.ino
        echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    fi

    echo "* compile project.."
    if [ $VERBOSE -eq 1 ]; then
        $ARDUINO_BIN/arduino-builder -compile -hardware $ARDUINO_BIN/hardware -hardware $ARDUINO_PACKAGES -tools $ARDUINO_BIN/tools-builder -tools $ARDUINO_BIN/hardware/tools/avr -tools $ARDUINO_PACKAGES -built-in-libraries $ARDUINO_BIN/libraries -libraries $ARDUINO_LIBRARIES -fqbn=WiPhone:esp32:wiphone:PSRAM=enabled,PartitionScheme=default,UploadSpeed=921600,DebugLevel=none -ide-version=10816 -build-path $BUILD -warnings=none -build-cache $CACHE -prefs=build.warn_data_percentage=75 -prefs=runtime.tools.mkspiffs.path=$ARDUINO_PACKAGES/WiPhone/tools/mkspiffs/0.2.3 -prefs=runtime.tools.mkspiffs-0.2.3.path=$ARDUINO_PACKAGES/WiPhone/tools/mkspiffs/0.2.3 -prefs=runtime.tools.esptool_py.path=$ARDUINO_PACKAGES/WiPhone/tools/esptool_py/2.6.1 -prefs=runtime.tools.esptool_py-2.6.1.path=$ARDUINO_PACKAGES/WiPhone/tools/esptool_py/2.6.1 -prefs=runtime.tools.xtensa-esp32-elf-gcc.path=$ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0 -prefs=runtime.tools.xtensa-esp32-elf-gcc-1.22.0-80-g6c4433a-5.2.0.path=$ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0 -verbose $WIPHONE_PATH/WiPhone.ino
        echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    else
        $ARDUINO_BIN/arduino-builder -compile -quiet -hardware $ARDUINO_BIN/hardware -hardware $ARDUINO_PACKAGES -tools $ARDUINO_BIN/tools-builder -tools $ARDUINO_BIN/hardware/tools/avr -tools $ARDUINO_PACKAGES -built-in-libraries $ARDUINO_BIN/libraries -libraries $ARDUINO_LIBRARIES -fqbn=WiPhone:esp32:wiphone:PSRAM=enabled,PartitionScheme=default,UploadSpeed=921600,DebugLevel=none -ide-version=10816 -build-path $BUILD -warnings=none -build-cache $CACHE -prefs=build.warn_data_percentage=75 -prefs=runtime.tools.mkspiffs.path=$ARDUINO_PACKAGES/WiPhone/tools/mkspiffs/0.2.3 -prefs=runtime.tools.mkspiffs-0.2.3.path=$ARDUINO_PACKAGES/WiPhone/tools/mkspiffs/0.2.3 -prefs=runtime.tools.esptool_py.path=$ARDUINO_PACKAGES/WiPhone/tools/esptool_py/2.6.1 -prefs=runtime.tools.esptool_py-2.6.1.path=$ARDUINO_PACKAGES/WiPhone/tools/esptool_py/2.6.1 -prefs=runtime.tools.xtensa-esp32-elf-gcc.path=$ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0 -prefs=runtime.tools.xtensa-esp32-elf-gcc-1.22.0-80-g6c4433a-5.2.0.path=$ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0 -verbose $WIPHONE_PATH/WiPhone.ino
    fi

    echo "* copy partition information"
    bash -c "[ ! -f $WIPHONE_PATH/partitions.csv ] || cp -f $WIPHONE_PATH/partitions.csv $BUILD/partitions.csv"

    echo "* copy default partitions"
    bash -c "[ -f $BUILD/partitions.csv ] || cp $ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/partitions/default_16MB.csv $BUILD/partitions.csv"

    echo "* compile ctags"
    $ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0/bin/xtensa-esp32-elf-g++ -DESP_PLATFORM "-DMBEDTLS_CONFIG_FILE=\"mbedtls/esp_config.h\"" -DHAVE_CONFIG_H -DGCC_NOT_5_2_0=0 -DWITH_POSIX -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/config -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/app_trace -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/app_update -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/asio -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/bootloader_support -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/bt -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/coap -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/console -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/driver -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/efuse -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp-tls -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp32 -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_adc_cal -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_event -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_http_client -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_http_server -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_https_ota -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_https_server -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_ringbuf -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_websocket_client -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/espcoredump -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/ethernet -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/expat -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/fatfs -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/freemodbus -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/freertos -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/heap -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/idf_test -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/jsmn -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/json -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/libsodium -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/log -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/lwip -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/mbedtls -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/mdns -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/micro-ecc -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/mqtt -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/newlib -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/nghttp -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/nimble -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/nvs_flash -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/openssl -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/protobuf-c -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/protocomm -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/pthread -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/sdmmc -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/smartconfig_ack -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/soc -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/spi_flash -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/spiffs -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/tcp_transport -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/tcpip_adapter -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/ulp -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/unity -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/vfs -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/wear_levelling -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/wifi_provisioning -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/wpa_supplicant -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/xtensa-debug-module -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp-face -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp32-camera -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp-face -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/fb_gfx -std=gnu++11 -Os -g3 -Wpointer-arith -fexceptions -fstack-protector -ffunction-sections -fdata-sections -fstrict-volatile-bitfields -mlongcalls -nostdlib -w -Wno-error=maybe-uninitialized -Wno-error=unused-function -Wno-error=unused-but-set-variable -Wno-error=unused-variable -Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-unused-but-set-parameter -Wno-missing-field-initializers -Wno-sign-compare -fno-rtti -c -w -x c++ -E -CC -DF_CPU=240000000L -DARDUINO=10816 -DARDUINO_WiPhone -DARDUINO_ARCH_ESP32 "-DARDUINO_BOARD=\"WiPhone\"" "-DARDUINO_VARIANT=\"wiphone\"" -DESP32 -DCORE_DEBUG_LEVEL=$CORE_DEBUG -DBOARD_HAS_PSRAM -mfix-esp32-psram-cache-issue -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/cores/esp32 -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/variants/wiphone -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/ESP32/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/HTTPClient/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/WiFi/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/WiFiClientSecure/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/HTTPUpdate/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/Update/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/SPI/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/FS/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/SPIFFS/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/Preferences/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/SD/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/ESPmDNS/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/Wire/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/RadioHead $BUILD/sketch/WiPhone.ino.cpp -o $BUILD/preproc/ctags_target_for_gcc_minus_e.cpp
    #echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    echo "* build ctags"
    if [ $VERBOSE -eq 1 ]; then
        $ARDUINO_BIN/tools-builder/ctags/5.8-arduino11/ctags -u --language-force=c++ -f - --c++-kinds=svpf --fields=KSTtzns --line-directives $BUILD/preproc/ctags_target_for_gcc_minus_e.cpp
        echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    else
        $ARDUINO_BIN/tools-builder/ctags/5.8-arduino11/ctags -u --language-force=c++ -f - --c++-kinds=svpf --fields=KSTtzns --line-directives $BUILD/preproc/ctags_target_for_gcc_minus_e.cpp > /dev/null
    fi

    echo "* compile project"
    $ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0/bin/xtensa-esp32-elf-g++ -DESP_PLATFORM "-DMBEDTLS_CONFIG_FILE=\"mbedtls/esp_config.h\"" -DHAVE_CONFIG_H -DGCC_NOT_5_2_0=0 -DWITH_POSIX -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/config -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/app_trace -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/app_update -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/asio -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/bootloader_support -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/bt -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/coap -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/console -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/driver -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/efuse -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp-tls -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp32 -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_adc_cal -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_event -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_http_client -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_http_server -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_https_ota -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_https_server -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_ringbuf -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp_websocket_client -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/espcoredump -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/ethernet -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/expat -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/fatfs -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/freemodbus -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/freertos -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/heap -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/idf_test -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/jsmn -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/json -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/libsodium -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/log -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/lwip -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/mbedtls -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/mdns -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/micro-ecc -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/mqtt -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/newlib -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/nghttp -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/nimble -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/nvs_flash -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/openssl -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/protobuf-c -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/protocomm -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/pthread -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/sdmmc -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/smartconfig_ack -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/soc -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/spi_flash -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/spiffs -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/tcp_transport -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/tcpip_adapter -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/ulp -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/unity -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/vfs -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/wear_levelling -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/wifi_provisioning -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/wpa_supplicant -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/xtensa-debug-module -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp-face -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp32-camera -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/esp-face -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/include/fb_gfx -std=gnu++11 -Os -g3 -Wpointer-arith -fexceptions -fstack-protector -ffunction-sections -fdata-sections -fstrict-volatile-bitfields -mlongcalls -nostdlib -w -Wno-error=maybe-uninitialized -Wno-error=unused-function -Wno-error=unused-but-set-variable -Wno-error=unused-variable -Wno-error=deprecated-declarations -Wno-unused-parameter -Wno-unused-but-set-parameter -Wno-missing-field-initializers -Wno-sign-compare -fno-rtti -MMD -c -DF_CPU=240000000L -DARDUINO=10816 -DARDUINO_WiPhone -DARDUINO_ARCH_ESP32 "-DARDUINO_BOARD=\"WiPhone\"" "-DARDUINO_VARIANT=\"wiphone\"" -DESP32 -DCORE_DEBUG_LEVEL=$CORE_DEBUG -DBOARD_HAS_PSRAM -mfix-esp32-psram-cache-issue -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/cores/esp32 -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/variants/wiphone -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/ESP32/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/HTTPClient/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/WiFi/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/WiFiClientSecure/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/HTTPUpdate/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/Update/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/SPI/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/FS/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/SPIFFS/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/Preferences/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/SD/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/ESPmDNS/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/Wire/src -I$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/libraries/RadioHead $BUILD/sketch/WiPhone.ino.cpp -o $BUILD/sketch/WiPhone.ino.cpp.o
    #echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    echo "* create elf"
    $ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0/bin/xtensa-esp32-elf-gcc -nostdlib -L$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/lib -L$ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/sdk/ld -T esp32_out.ld -T esp32.project.ld -T esp32.rom.ld -T esp32.peripherals.ld -T esp32.rom.libgcc.ld -T esp32.rom.spiram_incompatible_fns.ld -u esp_app_desc -u ld_include_panic_highint_hdl -u call_user_start_cpu0 -Wl,--gc-sections -Wl,-static -Wl,--undefined=uxTopUsedPriority -u __cxa_guard_dummy -u __cxx_fatal_exception -Wl,--start-group $BUILD/sketch/Audio.cpp.o $BUILD/sketch/GUI.cpp.o $BUILD/sketch/Hardware.cpp.o $BUILD/sketch/NanoINI.cpp.o $BUILD/sketch/Networks.cpp.o $BUILD/sketch/Storage.cpp.o $BUILD/sketch/Test.cpp.o $BUILD/sketch/WiPhone.ino.cpp.o $BUILD/sketch/clock.cpp.o $BUILD/sketch/helpers.cpp.o $BUILD/sketch/lora.cpp.o $BUILD/sketch/ota.cpp.o $BUILD/sketch/tinySIP.cpp.o $BUILD/sketch/src/TFT_eSPI/Fonts/Font16.c.o $BUILD/sketch/src/TFT_eSPI/Fonts/Font32rle.c.o $BUILD/sketch/src/TFT_eSPI/Fonts/Font64rle.c.o $BUILD/sketch/src/TFT_eSPI/Fonts/Font72rle.c.o $BUILD/sketch/src/TFT_eSPI/Fonts/Font7srle.c.o $BUILD/sketch/src/TFT_eSPI/Fonts/glcdfont.c.o $BUILD/sketch/src/audio/g711.c.o $BUILD/sketch/src/audio/g722_decoder.c.o $BUILD/sketch/src/audio/g722_encoder.c.o $BUILD/sketch/src/digcalc.c.o $BUILD/sketch/src/MurmurHash3_32.cpp.o $BUILD/sketch/src/NanoINI/test.cpp.o $BUILD/sketch/src/TFT_eSPI/TFT_eSPI.cpp.o $BUILD/sketch/src/drivers/APA102/APA102.cpp.o $BUILD/sketch/src/drivers/DRV8833/DRV8833.cpp.o $BUILD/sketch/src/drivers/SX1509/SparkFunSX1509.cpp.o $BUILD/sketch/src/ping/ping.cpp.o $BUILD/libraries/HTTPClient/HTTPClient.cpp.o $BUILD/libraries/WiFi/ETH.cpp.o $BUILD/libraries/WiFi/WiFi.cpp.o $BUILD/libraries/WiFi/WiFiAP.cpp.o $BUILD/libraries/WiFi/WiFiClient.cpp.o $BUILD/libraries/WiFi/WiFiGeneric.cpp.o $BUILD/libraries/WiFi/WiFiMulti.cpp.o $BUILD/libraries/WiFi/WiFiSTA.cpp.o $BUILD/libraries/WiFi/WiFiScan.cpp.o $BUILD/libraries/WiFi/WiFiServer.cpp.o $BUILD/libraries/WiFi/WiFiUdp.cpp.o $BUILD/libraries/WiFiClientSecure/WiFiClientSecure.cpp.o $BUILD/libraries/WiFiClientSecure/ssl_client.cpp.o $BUILD/libraries/HTTPUpdate/HTTPUpdate.cpp.o $BUILD/libraries/Update/HttpsOTAUpdate.cpp.o $BUILD/libraries/Update/Updater.cpp.o $BUILD/libraries/SPI/SPI.cpp.o $BUILD/libraries/FS/FS.cpp.o $BUILD/libraries/FS/vfs_api.cpp.o $BUILD/libraries/SPIFFS/SPIFFS.cpp.o $BUILD/libraries/Preferences/Preferences.cpp.o $BUILD/libraries/SD/sd_diskio_crc.c.o $BUILD/libraries/SD/SD.cpp.o $BUILD/libraries/SD/sd_diskio.cpp.o $BUILD/libraries/ESPmDNS/ESPmDNS.cpp.o $BUILD/libraries/Wire/Wire.cpp.o $BUILD/libraries/RadioHead/RHCRC.cpp.o $BUILD/libraries/RadioHead/RHDatagram.cpp.o $BUILD/libraries/RadioHead/RHEncryptedDriver.cpp.o $BUILD/libraries/RadioHead/RHGenericDriver.cpp.o $BUILD/libraries/RadioHead/RHGenericSPI.cpp.o $BUILD/libraries/RadioHead/RHHardwareSP12.cpp.o $BUILD/libraries/RadioHead/RHHardwareSP1I.cpp.o $BUILD/libraries/RadioHead/RHHardwareSPI.cpp.o $BUILD/libraries/RadioHead/RHMesh.cpp.o $BUILD/libraries/RadioHead/RHNRFSPIDriver.cpp.o $BUILD/libraries/RadioHead/RHReliableDatagram.cpp.o $BUILD/libraries/RadioHead/RHRouter.cpp.o $BUILD/libraries/RadioHead/RHSPIDriver.cpp.o $BUILD/libraries/RadioHead/RHSoftwareSPI.cpp.o $BUILD/libraries/RadioHead/RH_ABZ.cpp.o $BUILD/libraries/RadioHead/RH_ASK.cpp.o $BUILD/libraries/RadioHead/RH_CC110.cpp.o $BUILD/libraries/RadioHead/RH_E32.cpp.o $BUILD/libraries/RadioHead/RH_MRF89.cpp.o $BUILD/libraries/RadioHead/RH_NRF24.cpp.o $BUILD/libraries/RadioHead/RH_NRF51.cpp.o $BUILD/libraries/RadioHead/RH_NRF905.cpp.o $BUILD/libraries/RadioHead/RH_RF22.cpp.o $BUILD/libraries/RadioHead/RH_RF24.cpp.o $BUILD/libraries/RadioHead/RH_RF69.cpp.o $BUILD/libraries/RadioHead/RH_RF95.cpp.o $BUILD/libraries/RadioHead/RH_Serial.cpp.o $BUILD/libraries/RadioHead/RH_TCP.cpp.o $CACHE/core/core_24206846086c9e8982335839cab4769b.a -lgcc -lopenssl -lbtdm_app -lfatfs -lwps -lcoexist -lwear_levelling -lesp_http_client -lprotobuf-c -lhal -lnewlib -ldriver -lbootloader_support -lpp -lfreemodbus -lmesh -lsmartconfig -ljsmn -lwpa -lethernet -lphy -lapp_trace -lconsole -lulp -lwpa_supplicant -lfreertos -lbt -lmicro-ecc -lesp32-camera -lcxx -lxtensa-debug-module -ltcp_transport -lod -lmdns -ldetection -lvfs -lpe -lesp_websocket_client -lespcoredump -lesp_ringbuf -lsoc -lcore -lfb_gfx -lsdmmc -llibsodium -lcoap -ltcpip_adapter -lprotocomm -lesp_event -limage_util -lc_nano -lesp-tls -lasio -lrtc -lspi_flash -lwpa2 -lwifi_provisioning -lesp32 -lface_recognition -lapp_update -lnghttp -ldl -lspiffs -lface_detection -lefuse -lunity -lesp_https_server -lespnow -lnvs_flash -lesp_adc_cal -llog -ldetection_cat_face -lsmartconfig_ack -lexpat -lm -lfr -lmqtt -lc -lheap -lmbedtls -llwip -lnet80211 -lesp_http_server -lpthread -ljson -lesp_https_ota -lfd -lstdc++ -lc-psram-workaround -lm-psram-workaround -Wl,--end-group -Wl,-EL -o $BUILD/WiPhone.ino.elf
    #echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    echo "* extract bin"
    python $ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/esptool/esptool.py --chip esp32 elf2image --flash_mode dio --flash_freq 80m --flash_size 16MB -o WiPhone_$VERSION.bin $BUILD/WiPhone.ino.elf > /dev/null
    #echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    echo "* partition bin"
    python $ARDUINO_PACKAGES/WiPhone/hardware/esp32/0.1.2/tools/gen_esp32part.py -q $BUILD/partitions.csv partitions.bin
    #echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

fi

if [ $RESTORE -eq 1 ]; then
    # Restore current work
    echo "* restore current work"
    pushd $WIPHONE_PATH > /dev/null
    git reset --hard --quiet
    git stash pop --quiet 2>/dev/null
    popd > /dev/null
fi

#echo size info
#$ARDUINO_PACKAGES/WiPhone/tools/xtensa-esp32-elf-gcc/1.22.0-80-g6c4433a-5.2.0/bin/xtensa-esp32-elf-size -A $BUILD/WiPhone.ino.elf

# Cleanup
if [ $COMPILE -eq 1 ]; then
    rm -rf $CACHE
    rm -rf $BUILD
fi

if [ $FILES -eq 1 ]; then
    echo "* create OTA file"
    echo version=$VERSION > WiPhone.ini
    echo url=https://ackspace.nl/WiPhone/WiPhone_$VERSION.bin >> WiPhone.ini
fi

if [ ! -z $UPLOAD_PATH ]; then
    # Upload OTA+binary
    echo "* upload (have your yubikey ready and press enter)"
    read
    scp WiPhone*.{bin,ini} $UPLOAD_PATH
fi
