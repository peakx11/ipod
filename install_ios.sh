#!/data/data/com.termux/files/usr/bin/bash

TOTAL_STEPS=10
CURRENT_STEP=0
CPU_CORES=4
FAST_MODE=0

LOG_FILE="$HOME/qemu-ios-install.log"
WORKSPACE="$HOME/ios-workspace"
REPO_DIR="$HOME/qemu-ios"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

exec </dev/tty >/dev/tty 2>&1

cleanup() {
    echo -e "\n${RED}Build Failed${NC}"
    echo -e "${YELLOW}Last errors:${NC}"
    [ -f "$LOG_FILE" ] && tail -n 80 "$LOG_FILE"
    pkill -P $$ 2>/dev/null
    exit 1
}
trap cleanup SIGINT SIGTERM ERR

initialize_log() {
    echo "=== LOG ===" > "$LOG_FILE"
}

overall_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [ "$FAST_MODE" -eq 1 ]; then
        echo "[${CURRENT_STEP}/${TOTAL_STEPS}] $1"
        return
    fi

    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    local bar="${GREEN}"

    for ((i=0;i<filled;i++)); do bar+="█"; done
    bar+="${GRAY}"
    for ((i=0;i<empty;i++)); do bar+="░"; done
    bar+="${NC}"

    echo ""
    echo -e "${CYAN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} $1"
    echo -e "$bar ${percent}%"
    echo ""
}

spinner() {
    local pid=$1
    local msg=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    if [ "$FAST_MODE" -eq 1 ]; then
        wait "$pid"
        return $?
    fi

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1)%10 ))
        printf "\r${YELLOW}%s${NC} %s " "${spin:$i:1}" "$msg"
        sleep 0.1
    done

    wait "$pid"
    local code=$?

    if [ $code -ne 0 ]; then
        printf "\r${RED}✗${NC} %s\n" "$msg"
        tail -n 40 "$LOG_FILE"
        exit $code
    else
        printf "\r${GREEN}✓${NC} %s\n" "$msg"
    fi
}

run_cmd() {
    (bash -lc "$1" >> "$LOG_FILE" 2>&1) &
    spinner $! "$2"
}

install_pkg() {
    run_cmd "yes | pkg install $1 -y" "Installing $1"
}

ask_fast_mode() {
    while true; do
        echo -ne "Fast mode? (Y/N): "
        read -r a
        a=$(echo "$a" | tr -d '[:space:]')
        case "$a" in
            y|Y) FAST_MODE=1; break;;
            n|N) FAST_MODE=0; break;;
        esac
    done
}

ask_cores() {
    MAX=$(nproc 2>/dev/null || echo 4)
    [ "$FAST_MODE" -eq 1 ] && CPU_CORES=$MAX && return

    echo "Cores available: $MAX"
    read -r c
    if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -le "$MAX" ]; then
        CPU_CORES=$c
    else
        CPU_CORES=$MAX
    fi
}

step_update() {
    overall_progress "Updating"
    run_cmd "pkg update -y && pkg upgrade -y" "Updating packages"
}

step_x11() {
    overall_progress "X11"
    install_pkg x11-repo
    install_pkg termux-x11-nightly
    install_pkg openbox
    install_pkg xterm
}

step_deps() {
    overall_progress "Dependencies"
    install_pkg git
    install_pkg clang
    install_pkg make
    install_pkg ninja
    install_pkg pkg-config
    install_pkg python
    install_pkg wget
    install_pkg unzip
    install_pkg glib
    install_pkg libpixman
    install_pkg sdl2
    install_pkg libx11
}

step_clone() {
    overall_progress "Source"
    cd "$HOME"

    if [ -d "$REPO_DIR/.git" ]; then
        if [ "$FAST_MODE" -eq 1 ]; then
            echo "Using existing repo"
            return
        fi

        echo "1) Use existing"
        echo "2) Reclone"
        read -r c
        [ "$c" = "2" ] && rm -rf "$REPO_DIR"
    fi

    [ ! -d "$REPO_DIR" ] && run_cmd "git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git $REPO_DIR" "Cloning"
}

step_clean() {
    overall_progress "Cleaning"
    cd "$REPO_DIR"
    rm -rf build
}

apply_patches() {
    cd "$REPO_DIR"

    sed -i 's/syscall(SYS_gettid)/gettid()/g' util/oslib-posix.c 2>/dev/null
    sed -i 's/pr_manager_execute/termux_pr_mgr_stub/g' block/file-posix.c 2>/dev/null

    cat <<EOF > fix_header.h
#include <errno.h>
static inline int termux_pr_mgr_stub(void* a, ...) { errno = ENOSYS; return -1; }
EOF

    sed -i '1i #include "fix_header.h"' block/file-posix.c
}

step_configure() {
    overall_progress "Configure"
    cd "$REPO_DIR"
    mkdir build && cd build

    run_cmd "../configure \
    --target-list=arm-softmmu \
    --disable-werror \
    --disable-capstone \
    --disable-slirp \
    --disable-linux-aio \
    --enable-sdl \
    --extra-cflags='-O2 -pipe -fomit-frame-pointer -Wno-implicit-function-declaration -Wno-macro-redefined -DSG_ERR_DRIVER_TIMEOUT=0 -DSG_ERR_DRIVER_SENSE=0' \
    --extra-ldflags='-lX11'" "Configuring"
}

step_build() {
    overall_progress "Building"
    cd "$REPO_DIR/build"

    export NINJA_STATUS="[%f/%t] "

    make -j"$CPU_CORES" 2>&1 | tee -a "$LOG_FILE"
    local code=${PIPESTATUS[0]}

    if [ $code -ne 0 ]; then
        echo -e "${RED}Build failed${NC}"
        tail -n 60 "$LOG_FILE"
        exit $code
    fi
}

step_files() {
    overall_progress "Files"
    mkdir -p "$WORKSPACE/roms"
    cd "$WORKSPACE"

    [ ! -f roms/bootrom_240_4 ] && run_cmd "wget -q https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4 -O roms/bootrom_240_4" "Bootrom"
    [ ! -f roms/nor_n72ap.bin ] && run_cmd "wget -q https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin -O roms/nor_n72ap.bin" "NOR"
    [ ! -d nand ] && run_cmd "wget -q https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip && unzip -o nand_n72ap.zip && rm nand_n72ap.zip" "NAND"
}

step_launcher() {
    overall_progress "Launcher"

cat > "$HOME/start-ios.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0
openbox-session &
sleep 1

/data/data/com.termux/files/home/qemu-ios/build/arm-softmmu/qemu-system-arm \\
-M iPod-Touch,bootrom=/data/data/com.termux/files/home/ios-workspace/roms/bootrom_240_4,nand=/data/data/com.termux/files/home/ios-workspace/nand,nor=/data/data/com.termux/files/home/ios-workspace/roms/nor_n72ap.bin \\
-cpu max -smp $CPU_CORES -m 512M -serial mon:stdio
EOF

chmod +x "$HOME/start-ios.sh"
}

finish() {
    echo ""
    echo "DONE"
    echo "Run: bash ~/start-ios.sh"
}

main() {
    initialize_log
    ask_fast_mode
    ask_cores

    step_update
    step_x11
    step_deps
    step_clone
    step_clean
    apply_patches
    step_configure
    step_build
    step_files
    step_launcher
    finish
}

main
