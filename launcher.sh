step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Launchers...${NC}"
    echo ""
    cat > ~/start-ios.sh << 'LAUNCHEREOF'
#!/data/data/com.termux/files/usr/bin/bash

pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "openbox" 2>/dev/null

am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
termux-x11 :0 -ac &
sleep 2

export DISPLAY=:0
openbox-session &
sleep 1

cd ~/ios-workspace

xterm -geometry 80x24 -title "QEMU-iOS" -e bash -c '
(
while true; do
    read -rsn1 key
    if [[ $key == $'\''\e'\'' ]]; then
        echo "sendkey home"
    fi
done
) &

"~/qemu-ios/build/arm-softmmu/qemu-system-arm \
-M iPod-Touch,bootrom=roms/bootrom_240_4,nand=nand,nor=roms/nor_n72ap.bin \
-serial mon:stdio \
-cpu max \
-m 2G \
-device usb-mouse \
-device usb-kbd \
-display sdl \
-d unimp; echo 'Process finished. Press Enter to close.'; read" &

LAUNCHEREOF
    chmod +x ~/start-ios.sh
    echo -e "  ${GREEN}✓${NC} Created ~/start-ios.sh"
}
