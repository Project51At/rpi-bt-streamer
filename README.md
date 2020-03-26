# Raspberry Pi Bluetooth-Audio Streamer
A simple Bluetooth-Audio receiver that forward its content via iceCast2 

## Requirements
 - Raspberry Pi with Bluetooth support (tested with Raspberry Pi 2 and USB dongle)
 - Raspbian Buster Lite (tested with 2020-02-13)
 
## Installation
The installation script asks what to do

    wget -q https://github.com/Project51At/rpi-bt-streamer/archive/master.zip
    unzip rpi-bt-streamer-master.zip
    rm rpi-bt-streamer-master.zip

    cd rpi-bt-streamer-master
    ./install.sh
    
## Disclaimer


## References
- [Raspberry Pi Audio Receiver](https://github.com/nicokaiser/rpi-audio-receiver)
- [BlueALSA: Bluetooth Audio ALSA Backend](https://github.com/Arkq/bluez-alsa)
- [ffmpeg](https://www.ffmpeg.org/)
- [icecast](https://icecast.org/)
