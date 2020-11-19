#!/bin/bash
##########################################################################
# auto_run.sh
#
# Copyright 2018 Mycroft AI Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

# This script is executed by the .bashrc every time someone logs in to the
# system (including shelling in via SSH).

# DO NOT EDIT THIS SCRIPT!  It may be replaced later by the update process,
# but you can edit and customize the audio_setup.sh and custom_setup.sh
# script.  Use the audio_setup.sh to change audio output configuration and
# default volume; use custom_setup.sh to initialize any other IoT devices.
#

if [ "$SSH_CLIENT" = "" ] && [ "$(/usr/bin/tty)" != "/dev/tty1" ]; then
    # Quit immediately when running on a local non-primary terminal,
    # e.g. when you hit Ctrl+Alt+F2 to open the second term session
    return 0
fi

REPO_PICROFT="https://raw.githubusercontent.com/emphasize/enclosure-picroft/refactor_setup_wizard"

#since it has to be sourced and is not bound to ~/ we have to go this route
source_name=$( readlink -f ${BASH_SOURCE})
TOP=${source_name%/*}

export PATH="$PATH:$TOP/bin:"
#prevent SSH gibberish by ncurses/dialog
export NCURSES_NO_UTF8_ACS=1

function found_exe() {
    hash "$1" 2>/dev/null
}

#jq is essential for the setup process to store the flags
if ! found_exe jq ; then
    sudo apt-get -o Acquire::ForceIPv4=true update -y
    sudo apt-get install -y jq
    clear
fi

if found_exe tput ; then
    GREEN="$(tput setaf 2)"
    BLUE="$(tput setaf 4)"
    CYAN="$(tput setaf 6)"
    YELLOW="$(tput setaf 3)"
    RESET="$(tput sgr0)"
    HIGHLIGHT=${YELLOW}
fi

# This saves the option choices; USAGE: save_choices [KEY] [VALUE]; save_choices usedbranch true
function save_choices() {
    if [[ ! -f "$TOP"/.dev_opts.json ]] ; then
        touch "$TOP"/.dev_opts.json
        echo "{}" > "$TOP"/.dev_opts.json
    fi
    #no chance to bring in boolean with --arg
    #NOTE: Boolean are called without -r (whiich only outputs string)
    #eg if jq ".startup" "$TOP"/.dev_opts.json ; then
    if [ "$2" != true ] && [ "$2" != false ] ; then
        JSON=$(cat "$TOP"/.dev_opts.json | jq '.'$1' = "'$2'"')
    else
        JSON=$(cat "$TOP"/.dev_opts.json | jq '.'$1' = '$2'')
    fi
    echo "$JSON" > "$TOP"/.dev_opts.json
}

#Prime .dev_opts.json if no .dev_opts.json is present (=Picroft Image)
#especially those which are not covered in the specific
#Picroft Wizard sequence
if [[ ! -f "$TOP"/.dev_opts.json ]] ; then
    save_choices firstrun true
    save_choices initial_setup true
    save_choices dir $TOP
    save_choices dist debian
    save_choices inst_type picroft
    save_choices mimic_built true
    save_choices startup true
    save_choices autoupdate false
    save_choices restart false
else
    dist=$( jq -r ".dist" "$TOP"/.dev_opts.json )
fi

#Set timer for a new pull
time_between_updates=3600

function set_volume() {
    # Use amixer to set the volume level
    # This attempts to set both "Master" and "PCM"

    amixer set PCM $@ > /dev/null 2>&1
    amixer set Master $@ > /dev/null 2>&1
}

function save_volume() {
    # Save command to amixer to set the volume level

    echo "amixer set PCM $@ > /dev/null 2>&1" >> "$TOP"/audio_setup.sh
    echo "amixer set Master $@ > /dev/null 2>&1" >> "$TOP"/audio_setup.sh
}

function network_setup() {
    # silent check at first
    if ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 ; then
        return 0
    fi

    # Wait for an internet connection -- either the user finished Wifi Setup or
    # plugged in a network cable.
    show_prompt=1
    should_reboot=255
    verify_wifi_countdown=0

    while ! ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 ; do  # check for network connection
        if [ $show_prompt = 1 ] ; then
            echo "Network connection not found, press a key to setup via keyboard"
            echo "or plug in a network cable:"
            echo "  1) Basic wifi with SSID and password"
            echo "  2) Wifi with no password"
            echo "  3) Edit wpa_supplicant.conf directly"
            echo "  4) Force reboot"
            echo "  5) Skip network setup for now"
            echo -n "${HIGHLIGHT}Choice [1-6]:${RESET} "
            show_prompt=0
        fi

        # TODO: Options for WPA 2 Ent, etc?"
        # See:  https://github.com/MycroftAI/enclosure-picroft/blob/master/setup_eap_wifi.sh
        # See also:  https://w1.fi/cgit/hostap/plain/wpa_supplicant/wpa_supplicant.conf

        read -N1 -s -t 1 pressed  # wait for keypress or one second timeout
        case $pressed in
         1)
            echo
            echo -n "${HIGHLIGHT}Enter a network SSID:${RESET} "
            read user_ssid
            echo -n "${HIGHLIGHT}Enter the password:{RESET} "
            read -s user_pwd
            echo
            echo -n "${HIGHLIGHT}Enter the password again:{RESET} "
            read -s user_confirm
            echo

            if [[ "$user_pwd" = "$user_confirm" && "$user_ssid" != "" ]] ; then
                echo "network={" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "        ssid=\"$user_ssid\"" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "        psk=\"$user_pwd\"" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "}" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                verify_wifi_countdown=20
            else
                show_prompt=1
            fi
            ;;
         2)
            echo
            echo -n "${HIGHLIGHT}Enter a network SSID:${RESET} "
            read user_ssid

            if [[ ! "$user_ssid" = "" ]] ; then
                echo "network={" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "        ssid=\"$user_ssid\"" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "        key_mgmt=NONE" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "}" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                verify_wifi_countdown=20
            else
                show_prompt=1
            fi
            ;;
         3)
            sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
            verify_wifi_countdown=20
            ;;
         4)
            should_reboot=1
            break
            ;;
         5)
            should_reboot=0
            break;
            ;;
        esac

        if [[ $verify_wifi_countdown -gt 0 ]] ; then
            if [[ $verify_wifi_countdown -eq 20 ]] ; then
                echo -n "Reconfiguring WLAN0..."
                wpa_cli -i wlan0 reconfigure
                echo -n "Detecting network connection."
                sleep 1
            elif [[ $verify_wifi_countdown -eq 1 ]] ; then
                # Wireless network connection didn't come up within 20 seconds
                echo "Failed to connect to network, please try again."
                show_prompt=1
            else
                echo -n "."
            fi

            # decrement the counter every second
            ((verify_wifi_countdown -= 1))
        fi

    done

    if [[ $should_reboot -eq 255 ]] ; then
        # Auto-detected
        echo
        echo "Network connection detected!"
        should_reboot=0
    fi

    return $should_reboot

}

function update_software() {
    # Look for internet connection.
    if ping -q -c 1 -W 1 1.1.1.1 > /dev/null 2>&1 ; then
        echo "**** Checking for updates to Picroft environment"
        echo "This might take a few minutes, please be patient..."

        cd /tmp
        # Looking for a new enclosure-picroft version
        wget -N -q $REPO_PICROFT/home/pi/mycroft-core/version
        if [ $? -eq 0 ] ; then
            if [ ! -f "$TOP"/version ] ; then
                echo "unknown" > "$TOP"/version
            fi

            cmp /tmp/version "$TOP"/version
            if  [ $? -eq 1 ] ; then
                # Versions don't match...update needed
                echo "**** Update found, downloading new Picroft scripts!"
                if $( jq .mimic_built "$TOP"/.dev_opts.json); then
                    speak "Updating Picroft, please hold on."
                fi
                cd ~

                if [ $( jq -r ".inst_type // empty" "$TOP"/.dev_opts.json ) = custom ] ; then
                    #Regular patch process
                    mv ~/.bashrc ~/.bashrc.bak
                    wget -N -q $REPO_PICROFT/home/pi/mycroft-core/.bashrc
                    cmp ~/.bashrc ~/.bashrc.bak
                    if  [ $? -eq 1 ] ; then
                        save_choices bash_patched true
                        # delete last 4 lines of the pulled .bashrc (eg the Initialization)
                        sed -i "$(($(wc -l < .bashrc) - 3)),\$d" .bashrc
                        # Pull the lines after "custom code below"
                        awk '/CUSTOM CODE BELOW/ {p=1}; p; /source/ {p=0}' .bashrc.bak | \
                        tee -a .bashrc &> /dev/null
                        # Save custom changes so it can easily be reverted during wizard
                        awk '/CUSTOM CODE BELOW/ {p=1}; p; /END CUSTOM/ {p=0}' .bashrc.bak | \
                        tee .bashrc.patch.bak &> /dev/null
                        echo
                        echo "${HIGHLIGHT}Bashrc patched. Please check ~/.bashrc[$RESET]"
                        echo
                    fi
                else
                    wget -N -q $REPO_PICROFT/home/pi/mycroft-core/.bashrc
                fi
                cd "$TOP"
                wget -N -q $REPO_PICROFT/home/pi/mycroft-core/auto_run.sh
                cd "$TOP"/bin
                wget -N -q $REPO_PICROFT/home/pi/mycroft-core/bin/mycroft-wipe
                chmod +x mycroft-wipe
                cp /tmp/version "$TOP"/version

                # restart
                echo "Restarting..."
                if $( jq .mimic_built "$TOP"/.dev_opts.json); then
                    speak "Update complete, restarting."
                fi
                sudo reboot now
            fi
        fi

        cd "$TOP"
        time_last_pull=$(stat -c %Y .git/FETCH_HEAD)
        timedelta=$(( $time_between_updates + $time_last_pull - $EPOCHSECONDS ))
        echo -n "Checking for mycroft-core updates..."

        if [[ $timedelta -lt 0 ]] ; then
            git fetch
            if [[ $(git rev-parse HEAD) != $(git rev-parse @{u}) ]] ; then
                git pull
                if [[ $dist == 'debian' ]] ; then
                    sudo apt-get -o Acquire::ForceIPv4=true update -y
                fi
                source "$TOP"/dev_setup.sh
            fi
        else
            echo "... Skipping check for the next $(( $timedelta / 60 )) Minutes"
            echo
        fi
        cd "$TOP"
    fi
}

function speak() {
    # Generate TTS audio using Mimic 1
    "$TOP"/mimic/bin/mimic -t $@ -o /tmp/speak.wav

    # Play the audio using the configured WAV output mechanism
    wavcmd=$( jq -r ".play_wav_cmdline" /etc/mycroft/mycroft.conf )
    wavcmd="${wavcmd/\%1/\/tmp\/speak.wav}"
    $( $wavcmd >/dev/null 2>&1 )
}

######################

# this will regenerate new ssh keys on boot
# if keys don't exist. This is needed because
# ./bin/mycroft-wipe will delete old keys as
# a security measures
# Todo hook on other distros
if ! ls /etc/ssh/ssh_host_* 1> /dev/null 2>&1; then
    if [[ $( jq -r .dist "$TOP"/.dev_opts.json ) = "debian" ]]; then
        echo "Generating fresh ssh host keys"
        sudo dpkg-reconfigure openssh-server
        sudo systemctl restart ssh
        echo "New ssh host keys were created. this requires a reboot"
        sleep 2
        sudo reboot
    else
        echo "${HIGHLIGHT} NEW SSH KEYS HAVE TO BE CREATED ${RESET}"
        echo
        sleep 3
    fi
fi

echo -e "${CYAN}"
echo " ███╗   ███╗██╗   ██╗ ██████╗██████╗  ██████╗ ███████╗████████╗"
echo " ████╗ ████║╚██╗ ██╔╝██╔════╝██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝"
echo " ██╔████╔██║ ╚████╔╝ ██║     ██████╔╝██║   ██║█████╗     ██║   "
echo " ██║╚██╔╝██║  ╚██╔╝  ██║     ██╔══██╗██║   ██║██╔══╝     ██║   "
echo " ██║ ╚═╝ ██║   ██║   ╚██████╗██║  ██║╚██████╔╝██║        ██║   "
echo " ╚═╝     ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝        ╚═╝   "
echo
echo "        _____    _                          __   _   "
echo "       |  __ \  (_)                        / _| | |  "
echo "       | |__) |  _    ___   _ __    ___   | |_  | |_ "
echo "       |  ___/  | |  / __| | '__|  / _ \  |  _| | __|"
echo "       | |      | | | (__  | |    | (_) | | |   | |_ "
echo "       |_|      |_|  \___| |_|     \___/  |_|    \__|"
echo -e "${RESET}"
echo

source ${TOP}/.venv/bin/activate

# Read the current mycroft-core version
cd "$TOP"
mycroft_core_ver=$(python -c "import mycroft.version; print('mycroft-core: '+mycroft.version.CORE_VERSION_STR)" && echo "steve" | grep -o "mycroft-core:.*")
mycroft_core_branch=$(cd "$TOP" && git branch | grep -o "/* .*")

echo "***********************************************************************"
echo "** Picroft enclosure platform version:" $(<"$TOP"/version)
echo "**                       $mycroft_core_ver ( ${mycroft_core_branch/* /} )"
echo "***********************************************************************"
sleep 2  # give user a few moments to notice the version

#TODO Needed?
#alias mycroft-setup-wizard="cd ~ && touch firstrun && cd "$TOP" && rm -f .setup_choices && rm -f .setup_stage && source auto_run.sh"

if $( jq .firstrun "$TOP"/.dev_opts.json ) ; then

    $(bash "$TOP/stop-mycroft.sh" all > /dev/null)

    echo
    echo "Welcome to Picroft.  This image is designed to make getting started with"
    echo "Mycroft quick and easy.  Would you like help setting up your system?"
    echo "  Y)es, I'd like the guided setup."
    echo "  N)ope, just get me a command line and get out of my way!"

    # Something in the boot sequence is sending a CR to the screen, so wait
    # briefly for it to be sent for purely cosmetic purposes.
    sleep 1
    echo -n "${HIGHLIGHT}Choice [Y/N]:${RESET} "
    while true; do
        read -N1 -s key
        case $key in
         [Nn])
            echo $key
            echo
            echo "Alright, have fun!"
            echo "NOTE: If you decide to use the wizard later, just type 'mycroft-wizard -all'"
            echo "for the whole wizard process or 'mycroft-wizard' for a table of setup choices"
            echo
            echo "You are currently running with these defaults:"
            echo
            echo "     Branch:                      ${HIGHLIGHT}$( jq -r '.usedbranch // empty' .dev_opts.json )$RESET"
            echo "     Auto update:                 ${HIGHLIGHT}$( jq -r '.autoupdate // empty' .dev_opts.json )$RESET"
            echo "     Auto startup:                ${HIGHLIGHT}$( jq -r '.startup // empty' .dev_opts.json )$RESET"
            echo "     Input:                       ${HIGHLIGHT}$( jq -r '.audioinput' .dev_opts.json )$RESET"
            echo "     Output:                      ${HIGHLIGHT}$( jq -r '.audiooutput' .dev_opts.json )$RESET"
            save_choices firstrun false
            break
            ;;
         [Yy])
            echo $key
            echo
            #save_choices pair_text true
            # Handle internet connection
            network_setup
            if [ $? -eq 1 ] ; then
                echo "Rebooting..."
                sleep 3
                sudo reboot
            fi

            source "$TOP"/bin/mycroft-wizard -all
            update_software

            save_choices firstrun false
            break
            ;;
        esac
    done
fi

# running at the local console (e.g. plugged into the HDMI output)
if [ "$SSH_CLIENT" = "" ] && [ "$(/usr/bin/tty)" = "/dev/tty1" ]; then

    # Auto-update to latest version of mycroft-core (and Picroft if opted)
    if $( jq .autoupdate "$TOP"/.dev_opts.json ) || $( jq .initial_setup "$TOP"/.dev_opts.json ); then
        update_software
    fi


    if $( jq .startup "$TOP"/.dev_opts.json) ; then
    # Make sure the audio is being output reasonably.  This can be set
    # to match user preference in audio_setup.sh.  DON'T EDIT HERE,
    # the script will likely be overwritten during later updates.
    #
    # Default to analog audio jack at 75% volume

        if [[ -z $( jq -r '.audiooutput // empty' "$TOP"/.dev_opts.json ) ]] ; then
            amixer cset numid=3 "1" > /dev/null 2>&1
            set_volume 75%
        fi

        # Check for custom audio setup
        if [ -f "$TOP"/audio_setup.sh ]
        then
            source "$TOP"/audio_setup.sh
        fi

        # verify network settings
        network_setup
        if [[ $? -eq 1 ]]
        then
            echo "Rebooting..."
            sudo reboot
        fi

        # Check for custom Device setup
        if [ -f "$TOP"/custom_setup.sh ]
        then
            source "$TOP"/custom_setup.sh
        fi

        # Launch Mycroft Services ======================
        bash "$TOP/start-mycroft.sh" all

        # Display success/welcome message for user
        echo
        echo
        mycroft-help
        echo
        #triggering when initial_setup
        if $( jq .initial_setup "$TOP"/.dev_opts.json ) ; then
            echo "${HIGHLIGHT}Mycroft is completing startup, ensuring all of the latest versions"
            echo "of skills are installed.  Within a few minutes you will be prompted"
            echo "to pair this device with the required online services at:"
            echo "${CYAN}https://home.mycroft.ai$HIGHLIGHT"
            echo "where you can enter the pairing code.$RESET"
            echo
            sleep 5
            read -p "     ${HIGHLIGHT}Press enter to launch the Mycroft CLI client.${RESET}"

            save_choices initial_setup false
            "$TOP/start-mycroft.sh" cli
        else
            echo "Mycroft is now starting in the background."
            echo "To show the Mycroft command line interface type:  mycroft-cli-client"
        fi
    fi
else
    # running in SSH session, auto-launch the CLI
    echo
    mycroft-help
    echo
    echo "***********************************************************************"
    echo "In a few moments you will see the Mycroft CLI (command line interface)."
    echo "Hit Ctrl+C to return to the Linux command line.  You can launch the CLI"
    echo "again by entering:  mycroft-cli-client"
    echo
    sleep 2
    "$TOP/start-mycroft.sh" cli
fi
