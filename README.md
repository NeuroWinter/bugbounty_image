# bugbounty_image
A docker image that contains all the tools I use while bug hunting

## Tools
There are a range of tools in this container:
* [Photon](https://github.com/s0md3v/Photon)
* [Amass](https://github.com/OWASP/Amass)
* [httprobe](https://github.com/tomnomnom/httprobe)
* [MassScan](https://github.com/robertdavidgraham/masscan)
* [SecLists](https://github.com/danielmiessler/SecLists)
* [wfuzz](https://wfuzz.readthedocs.io/en/latest/)
* [sqlmap](https://github.com/sqlmapproject/sqlmap)
* [dirserach](https://github.com/maurosoria/dirsearch)
* [Ajurn](https://github.com/s0md3v/Arjun)
* [Fuff](https://github.com/ffuf/ffuf)
* [Cloud-enum](https://github.com/initstring/cloud_enum)
* [RustScan](https://github.com/RustScan/RustScan)
* [httpx](https://github.com/projectdiscovery/httpx)

## Aliases
I have also included a few of the aliases that I regularly use check out .bash_aliases to find
out more

## Usage
First you need to build the container!
```
docker build -t bbc .
```
I use this container as a way to have all my tools installed and ready to use.
Normally I will load up this container and start a terminal, from there I will
run all the tools I need and save the results locally. I have a folder on my
local machine called targets, so I mount into the container so I can save all
the outputs there, using the following command:
```
docker run -v /home/neuro/bugbounty/targets:/root/targets -it bbc bash
```
For tips on how to use the tools check the links for each of the tools above.

### VPN
WireGuard is also installed, I use this to connect to different mullvad VPN
servers. VPNs allow me to access different countries to test if different
endpoints, or domains are accessible from within certain countries. I have a 
folder with all my wireguard configs in it, so when starting the container I 
add `-v /path/to/wireguard/configs:/root/wireguard/ ` We also need to include 
some other access rights to the container so add the following to your start up
command: 
` --cap-add NET_ADMIN --cap-add SYS_MODULE --sysctl net.ipv4.conf.all.src_valid_mark=1 --sysctl net.ipv6.conf.all.disable_ipv6=0 `. Then to use the vpn I run `wg-quick up /root/wireguard/config_file`.
So my final command to run the container is as follows:
```
docker run -v /home/neuro/targets:/root/targets \
           -v /path/to/wireguard/configs:/root/wireguard/ \
            --cap-add NET_ADMIN \
            --cap-add SYS_MODULE \
            --sysctl net.ipv4.conf.all.src_valid_mark=1
            --sysctl net.ipv6.conf.all.disable_ipv6=0
            -it bbc bash
```
