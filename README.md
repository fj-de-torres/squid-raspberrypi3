# squid-raspberry3
*Work in progress. I'm still uploading all the files*

This is an installation of Squid 4.x on a Raspberry Pi 3B+ as a proxy cache for https. This will intercept the encrypted traffic, cache, and deliver it to the client's web browser. For that purpose, a personal certificate will be created; and its installation on the different web browsers we have, will be needed.

The initial purpose of this project is that you use your mobile phone tethered connection to give internet access to both the RP and your laptop.

Ways of sharing your phone internet connection to both the Rasbperry Pi and your computer so it can be configured to connect to the internet through the Raspberry Pi working as a proxy:

Tether your mobile connection to your PC with the usb cable through the Raspberry Pi:

* Connect your phone to the RP with the usb wire. Go to settings on your phone and share the internet connection through USB. Then, connect your PC/Laptop to the RP through an ethernet wire. The Raspberry Pi work as a bridge that will allow the PC to directly request an IP to your phone. This is done by the script. It will set a bridge between usb0 and eth0 cards. Please check if your usb connection on the Raspberry Pi has actually been identified as usb0. If it hasn't, try to figure out the name it has been given, and change it inside the script.

* The installation script I am giving will also create a bridge between usb0 and eth0 cards in the RP so your phone will also give your PC an IP and will all them (phone, RP and PC) be on the same network. It will be like if the RP and the PC were both connected to the phone directly so they both would be requesting an IP to the it.

* You can also configure your phone to share its internet connection by creating a wifi access point and connect both your laptop and RP to that share point.

In both scenarios, you will need to manually configure your OS in your PC/Laptop to connect through the Rasbperry Pi, so you'll need to figure out its IP first.
The port Squid will be using will be 3128.

#Installation:

Fist of all, update your system:

*sudo apt update ; sudo apt upgrade*

Then, install git:

*sudo apt install git*

Then, clone de git repository. We suppose that your are working on your home directory (/home/pi):

*git clone https://github.com/fj-de-torres/squid-raspberry3.git*

Then go to the squid-raspberry3 squid-raspberry3 folder, give executing permissions to the installation script, and and run it:

*cd squid-raspberry3*

*chmod +x squid-install-RP3.sh*

*./squid-install-RP3.sh*

You will be asked for your password to run most of the commands as root. Just do it and continue.

The script will, firstly, enable the source repositories at /etc/apt/sources.list and will download squid source code into /opt/.
Then, It will compile the sourece code and this will take such a while. I haven't tested it on a Raspberry Pi 4 but it should initially work. And, obviously, compiling times will be significantly lower.
Once the .deb packages are created, they will be installed. Thereafter, the creation of a personal certificate will start, so you will have to give some information there.
At the end, a bridge between usb0 and eth0 will be created (called br0). I assume that, if you prefer to connect to your Raspberry Pi through the wireless card, that you have previously configured it.
You will need to figure out which IP your Pi has, wether is wlan0 or br0, through which you are connecting.
Once the script has finished, you should reboot your RP in order to apply changes to the network system and activate the bridge
