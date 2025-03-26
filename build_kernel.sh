#!/bin/bash
#set -e

## Copy this script inside the kernel directory
LINKER="lld"
DIR=$(readlink -f .)
MAIN=$(readlink -f ${DIR}/..)
KERNEL_DEFCONFIG=peridot_defconfig
export ARCH=arm64
export SUBARCH=arm64

# Prompt user to choose Clang version
echo "Choose which Clang to use:"
echo "1. ZyC Stable"
echo "2. WeebX Stable"
echo "3. WeebX Beta"
echo "4. Prelude Clang"
read -p "Enter the number of your choice: " clang_choice

# Set URL and archive name based on user choice
case "$clang_choice" in
    1)
        CLANG_URL=$(curl -s https://raw.githubusercontent.com/v3kt0r-87/Clang-Stable/main/clang-zyc.txt)
        ARCHIVE_NAME="zyc-clang.tar.gz"
        ;;
    2)
        CLANG_URL=$(curl -s https://raw.githubusercontent.com/v3kt0r-87/Clang-Stable/main/clang-weebx.txt)
        ARCHIVE_NAME="weebx-clang.tar.gz"
        ;;
    3)
        CLANG_URL=$(curl -s https://raw.githubusercontent.com/v3kt0r-87/Clang-Stable/main/clang-weebx-beta.txt)
        ARCHIVE_NAME="weebx-clang-beta.tar.gz"
        ;;
    4)
        CLANG_REPO="https://gitlab.com/jjpprrrr/prelude-clang.git"
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

if [ "$clang_choice" -eq 4 ]; then
    if ! [ -d "$MAIN/prelude-clang" ]; then
        echo "No Prelude Clang found ... Cloning from GitLab ..."
        git clone --depth=1 "$CLANG_REPO" "$MAIN/prelude-clang"
    fi
    export PATH="$MAIN/prelude-clang/bin:$PATH"
else
    if ! [ -d "$MAIN/clang" ]; then
        echo "No clang compiler found ... Downloading Clang ... Please Wait ..."
        
        if ! wget -P "$MAIN" "$CLANG_URL" -O "$MAIN/$ARCHIVE_NAME"; then
            echo "Failed to download Clang. Exiting..."
            exit 1
        fi
        
        mkdir -p "$MAIN/clang"
        if ! tar -xvf "$MAIN/$ARCHIVE_NAME" -C "$MAIN/clang" --strip-components=1; then
            echo "Failed to extract Clang. Exiting..."
            exit 1
        fi
        rm -f "$MAIN/$ARCHIVE_NAME"
    fi
    export PATH="$MAIN/clang/bin:$PATH"
fi

export KBUILD_COMPILER_STRING="$($MAIN/prelude-clang/bin/clang --version | head -n 1 | sed -e 's/ (http.*)//g' -e 's/  */ /g' -e 's/[[:space:]]*$//')"

KERNEL_DIR=$(pwd)
ZIMAGE_DIR="$KERNEL_DIR/out/arch/arm64/boot"
BUILD_START=$(date +"%s")

# Colors
blue='\033[0;34m'
nocol='\033[0m'

echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
echo -e "$blue***********************************************"
echo "          BUILDING KERNEL          "
echo -e "***********************************************$nocol"

make $KERNEL_DEFCONFIG O=out CC=clang
make -j$(nproc --all) O=out \
                      CC=clang \
                      ARCH=arm64 \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      NM=llvm-nm \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip

TIME=$(date "+%Y%m%d-%H%M%S")
mkdir -p tmp
cp -fp $ZIMAGE_DIR/Image.gz tmp
cp -rp ./anykernel/* tmp
cd tmp || exit
7za a -mx9 tmp.zip *
cd ..
rm -f *.zip
cp -fp tmp/tmp.zip RealKing-Peridot-$TIME.zip
rm -rf tmp

echo $TIME
