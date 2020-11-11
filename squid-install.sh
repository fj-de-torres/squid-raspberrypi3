#!/bin/bash
#Created by Francisco José de Torres
# Version for Raspberry Pi OS:
#We need to become root to access /opt and work there (recommended):
sudo su
apt update -y && apt upgrade -y #Updating the system before starting.
#Tools be need to compile Squid on the right way to support ssl:
apt install -y dpkg-dev libldap2-dev libpam0g-dev libdb-dev cdbs libsasl2-dev debhelper libcppunit-dev libkrb5-dev comerr-dev libcap2-dev libecap3-dev libexpat1-dev libxml2-dev autotools-dev libltdl-dev pkg-config libnetfilter-conntrack-dev nettle-dev libgnutls28-dev libssl-dev libcurl4-openssl-dev gdebi ruby ruby-libxml
#We need to enable source repositories:
sed -i 's/#deb-src/deb-src/g' /etc/apt/sources.list
apt update
cd /opt
#We download the source code:
apt source squid
#We need to add what is needed to compile supporting ssl bumbing:
sed -i -e '/\-\-enable\-ecap/a\ --enable-ssl \\ \n--enable-ssl-crtd \\' /opt/squid-4.*/debianrules
sed -i -e '/\-\-with\-gnutls/a\ --with-openssl \\' /opt/squid-4.*/debianrules
sed -i -e '/nettle-dev/a\ , libssl-dev' /opt/squid-4.*/debian/control
#We compile it (it can take near to an hour on a Raspberry Pi 3B+):
cd /opt/squid-4.*
dpkg-buildpackage -rfakeroot -b
cd ..
gdebi -n squid_4.*.deb squid-common_*.deb
sudo apt-mark hold squid
#sudo apt-mark showhold #to see held packages
#sudo apt-mark unhold squid #to let it upgrade (not recommended since we are installing it from compilation, not from a deb in repos).
cd /etc/squid
mkdir ssl_cert
chmod 700 ssl_cert/
cd ssl_cert
openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -extensions v3_ca -keyout susvoyacrujirvivos.pem -out susvoyacrujirvivos.pem
openssl x509 -in susvoyacrujirvivos.pem -outform DER -out susvoyacrujirvivos.der
cp susvoyacrujirvivos.der /home/pi/
cd ..
chown -R proxy:proxy ssl_cert
cp squid.conf squid.conf.original
/usr/lib/squid/security_file_certgen -c -s /var/lib/ssl_db -M 4MB
chown -R proxy:proxy /var/lib/ssl_db
echo "#####
# acl
#  http://www.squid-cache.org/Versions/v4/cfgman/acl.html
#  Every access list definition must begin with an aclname and acltype, followed by either type-specific arguments 
#  or a quoted filename that they are read from
#   acl <name> <type> <options> <argument|file>
# Cache Policy
cache_mem 256 MB
maximum_object_size_in_memory 0 KB
memory_replacement_policy heap GDSF
cache_replacement_policy heap LFUDA
 
minimum_object_size 0 KB
maximum_object_size 10 GB
cache_swap_low 98
cache_swap_high 99
 
# Cache Folder Path, using 5GB for test
cache_dir aufs /cache-1 512000 16 256

# http_acces acl
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10
acl SSL_ports port 443 
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT
# sslproxy_cert_error acl
#acl ssl_error_domains dstdomain \"/opt/conf/squid/ssl/error/domains.conf\"    
#acl ssl_error_ips     dst       \"/opt/conf/squid/ssl/error/ips.conf\"
# ssl_bump acl
acl step1 at_step SslBump1
acl step2 at_step SslBump2
acl step3 at_step SslBump3
acl ssl_skip_bump req_header X-SSL-Bump -i skip
acl ssl_force_bump req_header X-SSL-Bump -i force
  

#############
# http_access
#  http://www.squid-cache.org/Versions/v4/cfgman/http_access.html
#  Allowing or Denying access based on defined access lists
http_access deny \!Safe_ports
http_access deny CONNECT \!SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

###########
# http_port
#  http://www.squid-cache.org/Versions/v4/cfgman/http_port.html
#  The socket addresses where Squid will listen for HTTP client requests (proxy port)
#  - mode: ssl-bump
#     For each CONNECT request allowed by ssl_bump ACLs, establish secure connection with the client and with
#     the server, decrypt HTTPS messages as they pass through Squid, and treat them as unencrypted HTTP messages,
#     becoming the man-in-the-middle.
#  - SSL Bump Mode Option: generate-host-certificates, dynamic_cert_mem_cache_size
#      - Dynamically create SSL server certificates for the destination hosts of bumped CONNECT requests
#      - Approximate total RAM size spent on cached generated certificates
#  - cert: Path to file containing the X.509 certificate (PEM format) and provate key to be used in the TLS handshake ServerHello
#      Generate (cert+key):
#       $ openssl req -new -newkey rsa:4096 -sha256 -days 3650 -nodes -x509 -keyout myca.pem -out myca.pem
#      and import myca.pem into your browser (certificates -> autorities)
http_port 3128 ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=4MB cert=/etc/squid/ssl_cert/susvoyacrujirvivos.pem

#####################
# sslproxy_cert_error
#  Bypass server certificate validation errors for destination (ips, domains and submnets)
#  http://www.squid-cache.org/Versions/v4/cfgman/sslproxy_cert_error.html
#sslproxy_cert_error allow ssl_error_domains
#sslproxy_cert_error allow ssl_error_ips

##########
# ssl_bump
#  http://www.squid-cache.org/Versions/v4/cfgman/ssl_bump.html
#  Consulted when a CONNECT request is received on an http_port
#  The subsequent data on the connection is either treated as HTTPS and decrypted OR tunneled at TCP level without decryption,
#  depending on the first matching bumping \"action\":
#  - splice: become a TCP tunnel without decrypting proxied traffic
#  - peek: receive client or server certificate while preserving the possibility of splicing the connection
#  - bump: establishes a secure connection with the client and server

# just tunnel (no decryption) on SSL request header match
ssl_bump splice localhost
ssl_bump splice ssl_skip_bump
# peek on SslBump1 step
ssl_bump peek step1 all
# force bump (decryption) on SSL request header match
ssl_bump bump ssl_force_bump
# To disable decryption (bump) uncomment line \"ssl_bump splice all\" and comment \"sspl_bump bump all\"
#ssl_bump splice all
ssl_bump bump all

#################
# sslcrtd_program
#  http://www.squid-cache.org/Versions/v4/cfgman/sslcrtd_program.html
#  certificate generator executable
sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/lib/ssl_db -M 4MB

##########
# send_hit
#  http://www.squid-cache.org/Versions/v4/cfgman/send_hit.html
#  Responses denied by this directive will not be served from the cache (but may still be cached, see store_miss)
#send_hit deny cache_exclude_contenttype

############
# store_miss
#  http://www.squid-cache.org/Versions/v4/cfgman/store_miss.html
#  Responses denied by this directive will not be cached (but may still be served from the cache, see send_hit)
#store_miss deny cache_exclude_contenttype

#################
# refresh_pattern
#  http://www.squid-cache.org/Versions/v4/cfgman/refresh_pattern.html
#  Regexp based expiration rules
refresh_pattern ^ftp:       1440    20% 10080
refresh_pattern ^gopher:    1440    0%  1440
refresh_pattern -i (/cgi-bin/|\?) 0 0%  0
refresh_pattern .       0   20% 4320

###################
# shutdown_lifetime
#  http://www.squid-cache.org/Versions/v4/cfgman/shutdown_lifetime.html
#  Any active clients after this many seconds will receive a 'timeout' message.
shutdown_lifetime 5 seconds

###########
# logformat
#  http://www.squid-cache.org/Versions/v4/cfgman/logformat.html
logformat squid-cs %{%Y-%m-%d %H:%M:%S}tl %3tr %>a %Ss/%03>Hs %<st %rm %>ru %un %Sh/%<a %mt \"%{User-Agent}>h\" \"SQUID-CS\" %>st %note
access_log /var/log/squid/access.log squid-cs

##################
# various config options
#  http://www.squid-cache.org/Versions/v4/cfgman/visible_hostname.html
#  http://www.squid-cache.org/Versions/v4/cfgman/dns_v4_first.html
#  http://www.squid-cache.org/Versions/v4/cfgman/forwarded_for.html
visible_hostname proxy.cyber.saiyan
dns_v4_first on
forwarded_for on


#url_rewrite_program /usr/bin/squidGuard
url_rewrite_program /usr/local/bin/simplerewrite

acl rewritedoms dstdomain .dailymotion.com .video-http.media-imdb.com .dl.sourceforge.net .prod.video.msn.com .fbcdn.net .akamaihd.net vl.mccont.com .mais.uol.com.br .streaming.r7.com
acl yt url_regex -i googlevideo.*videoplayback
acl gmaps url_regex -i ^https?:\/\/(khms|mt)[0-9]+\.google\.[a-z\.]+\/.*
acl ttv url_regex -i terratv
acl globo url_regex -i ^http:\/\/voddownload[0-9]+\.globo\.com.*
acl dm url_regex -i dailymotion\-flv2
acl getmethod method GET

range_offset_limit none
quick_abort_min -1 KB

store_id_program /usr/local/bin/hsc-dynamic-cache -file /usr/local/etc/hsc-dynamic-cache-db.txt
store_id_extras \"%>a/%>A %un %>rm myip=%la myport=%lp referer=%{Referer}>h\"
store_id_children 40 startup=10 idle=5 concurrency=0
store_id_access deny \!getmethod
store_id_access allow rewritedoms
store_id_access allow yt
store_id_access allow gmaps
store_id_access allow ttv
store_id_access allow globo
store_id_access allow dm
store_id_access deny all

refresh_pattern -i squid\.internal	10080	80%	79900 override-lastmod override-expire ignore-reload ignore-no-store ignore-must-revalidate ignore-private ignore-auth" > /etc/squid/squid.conf
echo "[NetDev]
Name=br0
Kind=bridge" > /etc/systemd/network/bridge-br0.netdev
echo "[Match]
Name=eth0

[Network]
Bridge=br0" > /etc/systemd/network/br0-member-eth0.network
systemctl enable systemd-networkd
echo "denyinterfaces wlan0 eth0" >> /etc/dhcpcd.conf
echo "interface br0" >> /etc/dhcpcd.conf
systemctl reboot
