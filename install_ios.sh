#!/data/data/com.termux/files/usr/bin/bash

LOG_FILE="$HOME/qemu-ios-install.log"
WORKSPACE="$HOME/ios-workspace"
REPO_DIR="$HOME/qemu-ios"

CPU_CORES=4
FAST_MODE=0
STEP=0

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

bar() {
    local progress=$1
    local total=20
    local filled=$((progress * total / 100))
    local empty=$((total - filled))
    printf "${GREEN}$(printf '#%.0s' $(seq 1 $filled))${GRAY}$(printf '-%.0s' $(seq 1 $empty))${NC}"
}

step_ui() {
    STEP=$((STEP+1))
    if [ "$FAST_MODE" -eq 1 ]; then
        echo "[STEP $STEP] $1"
    else
        echo -e "\n${WHITE}---------------------------------------${NC}"
        echo -ne "${CYAN}STEP $STEP: $1 ${NC}"
    fi
}

progress_ui() {
    if [ "$FAST_MODE" -eq 0 ]; then
        printf " "
        for i in {1..100..5}; do
            printf "\r${CYAN}STEP $STEP: $1 ${NC}$(bar $i) $i%%"
            sleep 0.02
        done
        echo
        echo -e "${WHITE}---------------------------------------${NC}"
    fi
}

run() {
    if [ "$FAST_MODE" -eq 1 ]; then
        eval "$1" >> "$LOG_FILE" 2>&1
    else
        eval "$1" >> "$LOG_FILE" 2>&1 &
        pid=$!
        while kill -0 $pid 2>/dev/null; do sleep 0.2; done
        wait $pid || { echo -e "${RED}Error${NC}"; exit 1; }
    fi
}

ask_cores() {
    MAX=$(nproc 2>/dev/null || echo 4)
    while true; do
        echo -ne "Cores [1-$MAX] (default $MAX): "
        read INPUT < /dev/tty
        if [ -z "$INPUT" ]; then CPU_CORES=$MAX; break; fi
        [[ "$INPUT" =~ ^[0-9]+$ ]] && [ "$INPUT" -ge 1 ] && [ "$INPUT" -le "$MAX" ] && { CPU_CORES=$INPUT; break; }
    done
}

ask_fast() {
    while true; do
        echo -ne "Do u want to use fast mode? (Y/N): "
        read INPUT < /dev/tty
        case "$INPUT" in
            Y|y) FAST_MODE=1; break ;;
            N|n) FAST_MODE=0; break ;;
        esac
    done
}

step_ui "Setup"
ask_cores
ask_fast

step_ui "Updating system"
run "yes | pkg update -y && yes | pkg upgrade -y"
progress_ui "Updating"

step_ui "Installing dependencies"
deps=(x11-repo termux-x11-nightly openbox xterm wget unzip git clang make ninja pkg-config python glib libpixman libtasn1 libusb libgcrypt zlib sdl2 libx11 xorgproto openssl libglvnd libepoxy liblzo bzip2)
for p in "${deps[@]}"; do run "yes | pkg install $p -y"; done
run "pip install distlib"
progress_ui "Dependencies"

step_ui "Cloning"
[ ! -d "$REPO_DIR" ] && run "git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git $REPO_DIR"
progress_ui "Clone"

cd "$REPO_DIR"

step_ui "Patching"
sed -i 's/syscall(SYS_gettid)/gettid()/g' util/oslib-posix.c
sed -i 's/pr_manager_execute/termux_pr_mgr_stub/g' block/file-posix.c

cat << 'EOF' > fix_header.h
#include <errno.h>
#include <stddef.h>
#include <sys/syscall.h>
static inline int copy_file_range(int a, void* b, int c, void* d, size_t e, unsigned int f) { errno = ENOSYS; return -1; }
static inline int termux_pr_mgr_stub(void* a, ...) { return -1; }
EOF

sed -i '1i #include "fix_header.h"' block/file-posix.c
progress_ui "Patch"

step_ui "Configure (optimized)"
mkdir -p build && cd build

run "../configure \
--target-list=arm-softmmu \
--disable-werror \
--disable-capstone \
--disable-slirp \
--disable-vhost-user \
--disable-linux-aio \
--disable-debug-info \
--enable-pie \
--extra-cflags='-O2 -pipe -fomit-frame-pointer' \
--extra-ldflags='-Wl,--as-needed'"
progress_ui "Configure"

step_ui "Building (cores=$CPU_CORES)"
run "make -j$CPU_CORES"
progress_ui "Build"

step_ui "Downloading files"
mkdir -p "$WORKSPACE/roms"
cd "$WORKSPACE"

run "wget -q https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4 -O roms/bootrom_240_4"
run "wget -q https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin -O roms/nor_n72ap.bin"

if [ ! -d "$WORKSPACE/nand" ]; then
    run "wget -q https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip -O nand.zip"
    run "unzip -o nand.zip && rm nand.zip"
fi
progress_ui "Files"

step_ui "Launcher"

cat > "$HOME/start-ios.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
export DISPLAY=:0
termux-x11 :0 -ac &
sleep 2
openbox-session &
sleep 1
$qemu_cmd ~/qemu-ios/build/arm-softmmu/qemu-system-arm \
-M iPod-Touch \
-cpu max \
-smp $CPU_CORES \
-m 512M \
-boot c \
EOF

chmod +x "$HOME/start-ios.sh"
progress_ui "Done"

echo -e "\n${GREEN}READY → bash ~/start-ios.sh${NC}"
