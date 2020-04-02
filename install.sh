#!/bin/bash

###############################################################################
    if [[ $(id -u) -ne 0 ]] ; then echo "rpi-bt-streamer -> Please run as root" ; exit 1 ; fi

###############################################################################
    echo "rpi-bt-streamer -> Updating packages"
    apt update
    apt upgrade -y

###############################################################################
    echo "rpi-bt-streamer -> Change host names"

    read -e -p "rpi-bt-streamer -> Hostname : " -i "$(hostname)" HOSTNAME
    raspi-config nonint do_hostname ${HOSTNAME:-$(hostname)}

    CURRENT_PRETTY_HOSTNAME=$(hostnamectl status --pretty)
    read -e -p "rpi-bt-streamer -> Pretty hostname : " -i "${CURRENT_PRETTY_HOSTNAME:-Raspberry Pi}" PRETTY_HOSTNAME
    hostnamectl set-hostname --pretty "${PRETTY_HOSTNAME:-${CURRENT_PRETTY_HOSTNAME:-Raspberry Pi}}"

###############################################################################
    echo "rpi-bt-streamer -> Install Bluetooth (rpi-audio-receiver)"

    wget -q https://github.com/nicokaiser/rpi-audio-receiver/archive/master.zip
    unzip master.zip
    rm master.zip
    cd rpi-audio-receiver-master

    ./install-bluetooth.sh

    cd ..

###############################################################################
    echo "rpi-bt-streamer -> Install Packages"

    apt-get install ffmpeg -y
    apt-get install icecast2 -y

    systemctl enable icecast2

###############################################################################
    echo "rpi-bt-streamer -> Load modules at startup"

    echo "snd-bcm2835"  >> /etc/modules
    echo "snd-aloop"    >> /etc/modules

###############################################################################
    echo "rpi-bt-streamer -> Create config:  asound.conf"

    cat << EOF > /etc/asound.conf
# default device
pcm.!default {
    type plug
    slave {
        pcm "masterout"
    }
}

# output device
pcm.loopout {
    type dmix
    ipc_key 328211
    slave {
        pcm "hw:Loopback,0,0"
    }
}

# input device
pcm.loopin {
    type dsnoop
    ipc_key 686592
    slave {
        pcm "hw:Loopback,1,0"
    }
}

# duplex plug device
pcm.loop {
    type plug
    slave {
        pcm {
            type asym
            playback.pcm "loopout"
            capture.pcm "loopin"
        }
    }
}

# split and duplicate audio stream
pcm.masterout {
    type plug
    slave.pcm mixer
    route_policy "duplicate"
}

# mixing device
pcm.mixer {
    type multi
    slaves {
        a {
            pcm "hw:Loopback,0,0"
            channels 2
        }
        b {
            pcm "hw:0,0"
            channels 2
        }
    }

    bindings {
       0 {
            slave a
            channel 0
        }

        1 {
            slave a
            channel 1
        }

        2 {
            slave b
            channel 0
        }

        3 {
            slave b
            channel 1
        }
    }
}
EOF

###############################################################################
    echo "rpi-bt-streamer -> Create scripts: ffmpeg-icecast2.sh"
    cat << EOF > /usr/local/bin/ffmpeg-icecast2.sh
#!/bin/bash
    ffmpeg  -f alsa \\
            -i loop \\
            -ac 2 \\
            -content_type audio/mpeg \\
            -acodec libmp3lame \\
            -af volume=5.0 \\
            -f mp3 \\
            -ice_genre "${IceCastGenre}" \\
            -ice_name "${IceCastName}" \\
            -ice_description "${IceCastDesc}" \\
            icecast://source:${IceCastSourcePassword}@127.0.0.1:8000/stream
EOF

    chmod 774 /usr/local/bin/ffmpeg-icecast2.sh



###############################################################################
    echo "rpi-bt-streamer -> Create script: ffmpeg-icecast2"
    read -e -p "rpi-bt-streamer -> IceCast admin password  : " -i "hackme" IceCastAdminPassword
    read -e -p "rpi-bt-streamer -> IceCast source password : " -i "hackme" IceCastSourcePassword
    read -e -p "rpi-bt-streamer -> IceCast relay password  : " -i "hackme" IceCastRelayPassword
    read -e -p "rpi-bt-streamer -> IceCast genre           : " -i "unknown" IceCastGenre
    read -e -p "rpi-bt-streamer -> IceCast name            : " -i "bt-streamer" IceCastName
    read -e -p "rpi-bt-streamer -> IceCast description     : " -i "Bluetooth- Audio- Streamer" IceCastDesc

    cat << EOF > /usr/local/bin/ffmpeg-icecast2.sh
#!/bin/bash
    ffmpeg  -f alsa \\
            -i loop \\
            -ac 2 \\
            -content_type audio/mpeg \\
            -acodec libmp3lame \\
            -f mp3 \\
            -ice_genre "${IceCastGenre}" \\
            -ice_name "${IceCastName}" \\
            -ice_description "${IceCastDesc}" \\
            icecast://source:${IceCastSourcePassword}@127.0.0.1:8000/stream
EOF

    chmod 774 /usr/local/bin/ffmpeg-icecast2.sh

###############################################################################
    echo "rpi-bt-streamer -> Create service: ffmpeg-icecast2"

    cat <<'EOF' > /etc/systemd/system/ffmpeg-icecast2.service
[Unit]
Description=stream audio to iceCast 1
After=bluealsa-aplay.service

[Service]
User=root
ExecStart=/usr/local/bin/ffmpeg-icecast2.sh
RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

###############################################################################
    echo "rpi-bt-streamer -> Create silent stream.mp3"

    ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -b:a 128k -t 1 /usr/share/icecast2/web/stream.mp3

###############################################################################
    echo "rpi-bt-streamer -> Change IceCast2 Config"

    sed -i 's/<icecast>/<icecast><mount><mount-name>\/stream.mp3<\/mount-name><\/mount>/g' /etc/icecast2/icecast.xml

    sed -i "s/<source-password>hackme</<source-password>$IceCastSourcePassword</g" /etc/icecast2/icecast.xml
    sed -i "s/<admin-password>hackme</<admin-password>$IceCastAdminPassword</g" /etc/icecast2/icecast.xml
    sed -i "s/<relay-password>hackme</<relay-password>$IceCastRelayPassword</g" /etc/icecast2/icecast.xml
    
    sed -i "s/<burst-size>65535</<burst-size>128</g" /etc/icecast2/icecast.xml

###############################################################################
    echo "rpi-bt-streamer -> bluetooth-udev: Change script"

    cat <<'EOF' > /usr/local/bin/bluetooth-udev
#!/bin/bash
if [[ ! $NAME =~ ^\"([0-9A-F]{2}[:-]){5}([0-9A-F]{2})\"$ ]]; then exit 0; fi

action=$(expr "$ACTION" : "\([a-zA-Z]\+\).*")

if [ "$action" = "add" ]; then
    bluetoothctl discoverable off

    systemctl start ffmpeg-icecast2
    amixer sset PCM,0 90

    # disconnect wifi to prevent dropouts
    #ifconfig wlan0 down &
fi

if [ "$action" = "remove" ]; then
    # reenable wifi
    #ifconfig wlan0 up &
    bluetoothctl discoverable on

    systemctl stop ffmpeg-icecast2
fi
EOF


###############################################################################
    echo"rpi-bt-streamer -> http://$(HOSTNAME):8000/stream"

###############################################################################
    echo"rpi-bt-streamer -> Do you want to reboot? [y/N] "

    read REPLY
    if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then exit 0; fi

    reboot
