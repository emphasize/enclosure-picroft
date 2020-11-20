# Recipe for creating the Picroft IMG

These are the steps followed to create the base image for Picroft on Raspbian Buster.  This was performed on a Raspberry Pi 3B+ or Pi 4

NOTE: At startup Picroft will automatically update itself to the latest version of released software, scripts and Skills.


### Start with the official Raspbian Image
* Download and burn [Raspi OS Lite](https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2020-08-24/2020-08-20-raspios-buster-armhf-lite.zip).
  <br>_Last used August 20th 2020 version_
* Install into Raspberry Pi and boot
  - login: pi
  - password: raspberry
* ```sudo apt-get update && sudo apt-get upgrade```

### General configuration (Raspbian/RaspiOS)
  - (security measure) optional, but recommended: Change user and erase the standard user
      - create a new user ```sudo adduser <USERNAME>```
      - add USERNAME to sudo group ```sudo usermod -aG sudo <USERNAME>```
      - change user to USERNAME ```su <USERNAME>```
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

### Set the device to not use locale settings provided by ssh~~
* ```sudo nano /etc/ssh/sshd_config``` and comment out the line (prefix with '#')
  ```
  AcceptEnv LANG LC_*
  ```

### Wifi Setup

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
    
--------------------------

Alternatives:

[Arch Linux ARM pi4](http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-4-latest.tar.gz) | [Arch Linux ARM pi2/3](http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz)

[Basic Instructions to create Image](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4)
<details>
  <summary>Prepare ArchArm</summary>
  
  * change to root: ```su```
  * disable audit: ```sed -i 's/$/ snd-bcm2835.enable_compat_alsa=1 audit=0/' /boot/cmdline.txt```
  * Add Rpi-Audio to bootloader ```printf "dtparam=audio=on\n" | sudo tee -a /boot/config.txt```
  * if needed:
      * Add GPIO/I2C to bootloader ```printf "device_tree_param=spi=on\ndtparam=i2c_arm=on\n" | sudo tee -a /boot/config.txt```
      * Further I2C: ```printf "\ni2c-dev\ni2c-bcm2708" | sudo tee -a /etc/modules-load.d/raspberrypi.conf```
  * Update and install prerequisites: ```pacman -Syu --noconfirm sudo wget```
  * Change root password: ```passwd root```
  * Create some groups: ```echo dialout plugdev spi i2c gpio pulse pulse-access | xargs -n 1 groupadd -r```
  * (optional) Create new user (and erase the standard user later)
      * Create user and add them to groups: ```useradd --create-home -g <GROUP> -G wheel,dialout,plugdev,spi,i2c,gpio,pulse,pulse-access,adm,audio,video,input <USERNAME>``` ; "users" is a valid choice as primary group
      
      &#x1F538; Whether or not a new user is created your user should be added to this groups 
  * set password ```passwd <USERNAME>```
  * grant sudo rights to everyone in wheel group (or otherwise appropriate management): ```EDITOR=nano visudo``` -> uncomment ```# %wheel ALL=(ALL) ALL```
  * Set locale
      * ```nano /etc/locale.gen``` -> uncomment your locale
      * ```locale-gen```
      * ```nano /etc/locale.conf``` -> replace with locale just created
  * Configure keyboard
      * get standard from ```localectl list-keymaps```
      * ```localectl set-keymap --no-convert <standard>```
  * Set hostname ```hostnamectl set-hostname <HOSTNAME>```
  * Reboot and login as <USERNAME>
  * (if new user was created): ```sudo userdel -r alarm```
  
  Totally optional, but gives you more granular control 
  * Install pyenv:
      * install dependencies: ```pacman -S --needed base-devel openssl zlib bzip2 readline sqlite curl llvm ncurses xz tk libffi python-pyopenssl git pyenv```
      * edit .bashrc ```printf '\n## pyenv configs\nexport PYENV_ROOT="$HOME/.pyenv"\nexport PATH="$PYENV_ROOT/bin:$PATH"\n\nif command -v pyenv 1>/dev/null 2>&1; then\n    eval "$(pyenv init -)"\nfi' >> ~/.bashrc```
      * retrigger bash: ```exec bash```
      * Install localized Python 3.7: ```pyenv install -v 3.7.9``` (3.7 is devs choice -Raspbian baseline- yet i've seen tests with 3.9, so change this as Mycroft progresses)
      * set Py 3.7.9 globally: ```pyenv global 3.7.9``` (You might want to set this directory specific -pyenv local- later on)
      * check: ```pyenv versions```
      
      At this point you're best adviced to make an image if things go sideways 
</details>

---------------------------------------------------

## Install Picroft (/ Mycroft-core) ~~scripts~~
* Pick your USER directory you want Picroft installed to ~~cd $HOME~~

  (eg if you want to place it in ~/programs/, ```mkdir programs && cd programs```
* wget -N https://raw.githubusercontent.com/emphasize/mycroft-core/dev/dev_setup.sh ~~https://rawgit.com/MycroftAI/enclosure-picroft/buster/home/pi/update.sh~~
* bash dev_setup.sh ~~update.sh~~

**The Mycroft-wizard ~~update.sh script~~ will perform all of the following steps in this section...**
~~When asked by dev_setup, answer as follows:~~
- run on the stable 'master' or 'dev' branch
- automatically check for updates
- start up script
- check code style (developer)
- Extended setup (Sound config)
- build Mimic locally

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
