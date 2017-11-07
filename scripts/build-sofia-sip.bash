#!/bin/bash
#
# Build sofia sip library for all architectures and combine all the libs to a universal library. Need to be run from side the sofia-sip directory (i.e. root of sofia sip sources)
#
# Function build() is ran once for each architecture and in the end the output .a files are combined and stored in directory 'build'
#
# Example: $ ../../../scripts/build-sofia-sip.bash -d <0|1> -v <0|1>
# -d: add debug symbols to the build
# -v: show the full CC commands (like compile and link flags) for troubleshooting
#
# IMPORTANT: 
#
# If somehow 'configure' gets deleted you need to regenerate with '$ autoreconf -i'
#
# For some reason '$ autoconf' doesn't work, although it did work with original
# sofia-sip sources. Probably when we added support for BoringSSL something was
# missing in the autotools configuration files
#
#

function build()
{
	SDK=$1
	ARCH=$2
	DEBUG=$3
	VERBOSE=$4

	echo "--- Building for: $SDK, $ARCH"

	# cleanup previous runs
	echo "--- Cleaning up"
   make distclean > /dev/null

	I386_FLAGS=""
	if [[ $ARCH == "i386" ]]
	then
		I386_FLAGS="-m32"
	fi

	export DEVROOT="$(xcrun --sdk $SDK --show-sdk-platform-path)/Developer"
	export SDKROOT="$(xcrun --sdk $SDK --show-sdk-path)"
	export CC="$(xcrun --sdk $SDK --find clang)"
	export CXX="$(xcrun --sdk $SDK --find clang++)"
	export LD="$(xcrun --sdk $SDK --find ld)"
	export AR="$(xcrun --sdk $SDK --find ar)"
	export AS="$(xcrun --sdk $SDK --find as)"
	export NM="$(xcrun --sdk $SDK --find nm)"
	export RANLIB="$(xcrun --sdk $SDK --find ranlib)"

	if [[ $SDK == "iphonesimulator" ]]
	then
		# use boringssl instead of openssl
		#export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/ -lresolv -L/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/packages/webrtc -lwebrtc"
		#export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/ -lresolv -F../../binaries/frameworks -framework WebRTC.framework"
		#export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/ -lresolv -F/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/binaries/frameworks -framework WebRTC"
		#export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/ -lresolv"
		#export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/ -L/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/binaries/boringssl/lib -lresolv -lboringssl"
		export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/ -lresolv -F/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/binaries/frameworks -framework WebRTC"
	else
		# use boringssl instead of openssl
		#export LDFLAGS="-L${SDKROOT}/usr/lib/ -lresolv -L/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/packages/webrtc -lwebrtc"
		#export LDFLAGS="-L${SDKROOT}/usr/lib/ -lresolv -F../../binaries/frameworks -framework WebRTC.framework"
		#export LDFLAGS="-L${SDKROOT}/usr/lib/ -lresolv -F/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/binaries/frameworks -framework WebRTC"
		#export LDFLAGS="-L${SDKROOT}/usr/lib/ -lresolv"
		export LDFLAGS="-L${SDKROOT}/usr/lib/ -lresolv -F/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/binaries/frameworks -framework WebRTC"
	fi

	export ARCH

	# export the pkgconfig file for boringssl
	export PKG_CONFIG_PATH=/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/pkgconfig

	# for debug but use boringssl instead of openssl
	#CFLAGS=${I386_FLAGS}" -arch ${ARCH} -dynamiclib -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/ -g -O0 -I/Users/antonis/Documents/telestax/code/webrtc-ios/webrtc_checkout/src/third_party/boringssl/src/include" 
	# TODO: maybe we need to also link with boringssl? I would assume not, as this happens during build of the end executable, but I seem to recall that we had some issues using Sofia SIP with TLS without this setting

	#CFLAGS=${I386_FLAGS}" -arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/" 
	CFLAGS=${I386_FLAGS}" -arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/ -I/Users/antonis/Documents/telestax/code/restcomm-ios-sdk/dependencies/include/boringssl" 

	if [[ $SDK != "iphonesimulator" ]]
	then
		CFLAGS=${CFLAGS}" -DIOS_BUILD"
	else
		CFLAGS=${CFLAGS}" -miphoneos-version-min=8.0"
	fi

	if [ "$DEBUG" -eq 1 ]
	then
		echo "--- Adding DEBUG symbols and setting zero optimizations"
		CFLAGS=${CFLAGS}" -g -O0"
	fi

	export CFLAGS
	export CPPFLAGS="${CFLAGS}"
	export CXXFLAGS="${CFLAGS}"

	echo "--- Environment set:"
	echo "Using CC: $CC"
	echo "Using SDK: $SDK"
	echo "Using ARCH: $ARCH"
	echo "Using DEVROOT: $DEVROOT"
	echo "Using SDKROOT: $SDKROOT"
	echo "Using CFLAGS: $CFLAGS"
	echo "Using LDFLAGS: $LDFLAGS"
	echo "Using AR: $AR"
	echo "Using LD: $LD"
	echo "Using AS: $AS"
	echo "Using NM: $NM"
	echo "Using RANLIB: $RANLIB"

	echo "--- Configuring"
	if [[ $SDK != "iphonesimulator" ]]
	then 
   	#./configure --host=arm-apple-darwin --with-boringssl=pkg-config
   	./configure --host=arm-apple-darwin --with-boringssl
	else
   	#./configure --host=${ARCH}-apple-darwin --with-boringssl=pkg-config
   	./configure --host=${ARCH}-apple-darwin --with-boringssl
	fi

	echo "--- Building"
	if [ "$VERBOSE" -eq 0 ]
	then
   	make 
	else
   	make SOFIA_SILENT=""   # verbose
	fi
	
	if [ $? -eq 0 ]
	then
		cp libsofia-sip-ua/.libs/libsofia-sip-ua.a build/libsofia-sip-ua-${ARCH}.a
	else 
		echo "--- Error building Sofia SIP"
		exit 1
	fi
}

# --------------- MAIN CODE --------------- #
DEBUG=0
VERBOSE=0

while getopts ":d:v:" opt; do
  case $opt in
    d)
		if [ $OPTARG -eq 1 ]
		then
			echo "--- Making a debug build"
			let DEBUG=1
		fi
      ;;
    v)
		if [ $OPTARG -eq 1 ]
		then
			echo "--- Making a verbose build"
			let VERBOSE=1
		fi
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ ! -d "build" ] 
then
	mkdir build
fi

ARCH="i386"   
SDK="iphonesimulator"
build $SDK $ARCH $DEBUG $VERBOSE

ARCH="x86_64"
SDK="iphonesimulator"
build $SDK $ARCH $DEBUG $VERBOSE

ARCH="armv7"
SDK="iphoneos"
build $SDK $ARCH $DEBUG $VERBOSE

# this doesn't work for some reason
#ARCH="armv7s"
#SDK="iphoneos"
#build $SDK $ARCH $DEBUG $VERBOSE

ARCH="arm64"
SDK="iphoneos"
build $SDK $ARCH $DEBUG $VERBOSE

echo "--- Creating universal library at build/"
rm -f build/libsofia-sip-ua.a
lipo -create build/* -output build/libsofia-sip-ua.a
