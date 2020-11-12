# Recipe for creating the Picroft IMG

These are the steps followed to create the base image for Picroft on Raspbian Buster.  This was performed on a Raspberry Pi 3B+ or Pi 4

NOTE: At startup Picroft will automatically update itself to the latest version of released software, scripts and Skills.


### Start with the official Raspbian Image
* Download and burn [Raspbian Buster Lite](https://downloads.raspberrypi.org/raspbian_lite_latest).
  <br>_Last used 2019-09-26 version_
* Install into Raspberry Pi and boot
  - login: pi
  - password: raspberry
* ```sudo apt-get update && sudo apt-get upgrade```
### General configuration
  - (security measure) optional, but recommended: Change user and erase the standard user
      - create a new user ```sudo adduser USERNAME```
      - add USERNAME to sudo group ```sudo usermod -aG sudo USERNAME```
      - change user to USERNAME ```su USERNAME && cd ~```
      - Populate groups ```sudo usermod -aG `cat /etc/group | grep :pi | awk -F: '{print $1}' | tr '\n' ',' | sed 's:,$::g'` `whoami` ```
      - Reboot and login as USERNAME
      - Delete User pi ```sudo deluser -remove-home pi && sudo rm /etc/sudoers.d/010_pi-nopasswd```
  - ```sudo raspi-config```
  - 1 Change User Password (skip if new user was created)
      - Enter and verify new password ~~```mycroft```~~
  - 2 Network Options
      - N1 Hostname
        - Enter new hostname ~~```picroft```~~
      - N3 Network interface names
        - pick *Yes*
  - 3 Boot Options
      - B1 Desktop / CLI
        - B1~~2~~ Console ~~Autologin~~ #autologin is a part of mycroft-wizard
      - B2 Wait for network
        - pick *No*
  - 4 Localization Options
      - I3 Change Keyboard Layout (given your country/device standards)
          - Pick *Generic 104-key PC*
          - Pick *Other*
          - Pick *English (US)*
          - Pick *English (US)*
          - Pick *The default for the keyboard layout*
          - Pick *No compose key*
      - I4 Change Wi-fi Country
          - Pick *United States*
  - 5 Interfacing Options
      - P2 SSH
          - Pick *Yes*
  - Finish and reboot

#don't see the necessity of this step
### Set the device to not use locale settings provided by ssh~~
* ```sudo nano /etc/ssh/sshd_config``` and comment out the line (prefix with '#')
  ~```
  AcceptEnv LANG LC_*
  ```

### Connect to the network
* Either plug in Ethernet or

  __or__
* Guided wifi setup
  * ```sudo raspi-config```
    - 2 Network Options
      - N2 Wi-fi

  __or__
* Manually setup wifi
  * ```sudo nano /etc/wpa_supplicant/wpa_supplicant.conf```
  * Enter network creds:
    ```
    network={
            ssid="NETWORK"
            psk="WIFI_PASSWORD"  # for network with password
            key_mgmt=NONE        # for open network
    }
    ```

## Install Picroft (/ Mycroft-core) ~~scripts~~
* Pick your USER directory (eg ~/../* ) you want Picroft installed to ~~cd ~ ~~
* wget -N https://raw.githubusercontent.com/emphasize/mycroft-core/refactor_setup_wizard/dev_setup.sh ~~https://rawgit.com/MycroftAI/enclosure-picroft/buster/home/pi/update.sh~~
* bash dev_setup.sh ~~update.sh~~

**The Mycroft-wizard ~~update.sh script~~ will perform all of the following steps in this section...**
When asked by dev_setup, answer as follows:
- ?) run on the stable 'master' or 'dev' branch
- ?) automatically check for updates
- Y) start up script
- ?) check code style (developer)
- ?) Extended setup (Sound config)
- Y) build Mimic locally

~~##### Enable Autologin as the 'pi' user~~
<details>
  <summary>Cut</summary>
* ```sudo nano /etc/systemd/system/getty@tty1.service.d/autologin.conf``` and enter:
   ```
   [Service]
   ExecStart=
   ExecStart=-/sbin/agetty --autologin pi --noclear %I     38400 linux
   ```
   
* ```sudo systemctl enable getty@tty1.service```
</details>

~~##### Create RAM disk and point to it~~
<details>
  <summary>Cut</summary>
  - ```sudo nano /etc/fstab``` and add the line:
    ```
    tmpfs /ramdisk tmpfs rw,nodev,nosuid,size=20M 0 0
    ```
</details>

~~##### Environment setup (part of update.sh)~~

<details>
  <summary>Cut</summary>
* ```sudo mkdir /etc/mycroft```
* ```sudo nano /etc/mycroft/mycroft.conf```
* mkdir ~/bin
</details>

~~##### Customize .bashrc for startup~~
<details>
  <summary>Cut</summary>
* ```nano ~/.bashrc```
   uncomment *#alias ll='ls -l'* near the bottom of the file
   at the bottom add:
   ```
   #####################################
   # This initializes Mycroft
   #####################################
   source ~/auto_run.sh
   ```
</details>

~~##### Install git and mycroft-core~~

<details>
  <summary>Cut</summary>
* ```sudo apt-get install git```
* ```git clone https://github.com/MycroftAI/mycroft-core.git```
* ```cd mycroft-core```
* ```git checkout master```
* ```bash dev_setup.sh```
 </details>

(The approx. time is announced in the setup process; all in all half an hour on a Pi4)

## Final steps
* optional: optimize the system to your needs before running mycroft-wipe
* Run ```. mycroft-wipe --keep-skills```
* Remove the SD card
* Create an IMG file named "raspbian-buster_Picroft_YYYY-MM-DD.img" (optionally include an "_release-suffix.img")

<details>
  <summary>Dev</summary>
* Compress the IMG using pishrink.sh
* Upload and adjust redirect link from https://mycroft.ai/to/picroft-image or https://mycroft.ai/to/picroft-unstable
</details>
