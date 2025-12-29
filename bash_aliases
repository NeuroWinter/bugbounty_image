# GENERAL
alias ll='ls -la'
hgrip(){ history | grep $1; }

# AWS
s3ls(){ aws s3 ls s3://$1; }
s3cp(){ aws s3 cp $2 s3://$1; }

# CERTIFICATE & SUBDOMAIN DISCOVERY
certspotter(){
    curl -s https://certspotter.com/api/v0/certs\?domain\=$1 | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep $1 | tee -a $1-certspotter.txt
}

crtsh(){
    curl -s https://crt.sh/\?q\=%.$1\&output\=json | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | tee -a $1-domains-crt.txt
}

crtshmulti(){
    input=$1
    while IFS= read -r line; do
        curl -s https://crt.sh/\?q\=%25.$line\&output\=json | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | tee -a all.txt
    done < "$input"
}

certnmap(){
    curl https://certspotter.com/api/v0/certs\?domain\=$1 | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep $1 | nmap -T5 -Pn -sS -i $1
}

# RECON SHORTCUTS
alias subs='subfinder -silent'
alias probe='httpx -silent'
alias live='httpx -silent -mc 200,301,302,403'
alias crawl='katana -silent'
alias urls='waybackurls'
alias params='paramspider'
alias getparams='unfurl keys'

ipinfo(){ curl http://ipinfo.io/$1; }

am(){
    amass enum --ip --active -r 1.1.1.1 -d $1 -json $1.json
    jq .name $1.json | sed "s/\"//g" | httpx -silent | tee -a $1-domains-am.txt
}

# TOOL SHORTCUTS
alias nuc='nuclei'
alias dal='dalfox'
alias ff='ffuf'
alias fb='feroxbuster'

ph(){
    python3 ~/tools/Photon/photon.py -u $1 -l 6 --keys --wayback
}

massph(){
    cat $1 | while read line; do ph $line; done
}

aj(){
    cat $1 | while read line; do arjun -u https://$line/; done
}

dirsearchx(){
    python3 ~/tools/dirsearch/dirsearch.py -r -R 4 -t 10 -F \
        -e "php,asp,aspx,php3,php4,php5,txt,shtm,shtml,phtm,phtml,jhtml,pl,jsp,cfm,cfml,py,rb,cfg,zip,pdf,gz,tar,tar.gz,tgz,doc,docx,xls,xlsx,conf,log" \
        -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt \
        -u $1 -b -x 301,302,404,500 --recursion-status 200-399,401 \
        -o ~/reports/$(echo $1 | sed 's/[^a-zA-Z0-9]/_/g')_dir.json --format json
}

certbrute(){
    cat $1 | while read line; do dirsearchx $line; done
}

wpsa(){
    wpscan --random-user-agent -e ap,at,tt,cb,dbe,u,m --url $1 \
        -o ~/reports/wps_$(echo $1 | sed -e 's#^https://##' -e 's#^http://##' -e 's#/$##' -e 's/[^a-zA-Z0-9]/_/g').txt
}

# JS ANALYSIS
alias js-urls='grep -iE "\.js$"'

jss(){
    curl -s $1 | js-beautify - | grep -iE "key|api|password|admin|ConsumerKey|ConsumerSecret|DB_USERNAME|HEROKU_API_KEY|HOMEBREW_GITHUB_API_TOKEN|JEKYLL_GITHUB_TOKEN|PT_TOKEN|SESSION_TOKEN|SF_USERNAME|SLACK_BOT_TOKEN|access-token|access_token|access_token_secret|accesstoken|api-key|api_key|api_secret_key|api_token|auth_token|authkey|authorization|authorization_key|authorization_token|authtoken|aws_access_key_id|aws_secret_access_key|bearer|bot_access_token|bucket|client-secret|client_id|client_key|client_secret|clientsecret|consumer_key|consumer_secret|dbpasswd|email|encryption-key|encryption_key|encryptionkey|id_dsa|irc_pass|oauth_token|pass|private_key|privatekey|secret|secret-key|secret_key|secret_token|secretkey|session_key|session_secret|slack_api_token|slack_secret_token|slack_token|ssh-key|ssh_key|sshkey|token|username|xoxa-2|xoxr|private-key|private_token|Authorization|Bearer"
}

mjss(){
    cat $1 | while read url; do
        echo "[*] $url"
        jss $url
    done
}

# SCANNING
alias scan-xss='gf xss | uro | dalfox pipe'
alias scan-sqli='gf sqli | uro | ghauri --batch'

ms(){
    masscan -p66,80,81,443,445,457,1080,1100,1241,1352,1433,1434,1521,1944,2301,3128,3306,4000,4001,4002,4100,5000,5432,5800,5801,5802,6346,6347,7001,7002,8080,8888,30821 $1
}

massnmap(){
    input=$1
    while IFS= read -r line; do
        domain=$(echo $line | sed -e "s/^http:\/\///" -e "s/^https:\/\///")
        nmap -A -sV $domain
    done < $input
}

wfuzzx(){
    wfuzz -w /usr/share/seclists/Discovery/Web-Content/raft-small-directories.txt \
          -w /usr/share/seclists/Discovery/Web-Content/raft-small-files.txt \
          -u https://$1/FUZZ/FUZ2Z --hc 301,302,404,500
}

# MISC
ncx(){ nc -l -n -vv -p $1 -k; }

# Full recon one-liner
fullrecon(){
    domain=$1
    echo " Starting full recon on $domain"
    mkdir -p ~/recon/$domain && cd ~/recon/$domain

    # Subdomains
    echo " Subdomain enumeration..."
    subfinder -d $domain -silent | anew subs.txt
    # Amass - only output subdomains, not the verbose relationship data
    amass enum -passive -d $domain 2>/dev/null | grep -E "^[a-zA-Z0-9.-]+\.$domain$" | anew subs.txt
    crtsh $domain 2>/dev/null | grep -v "^$" | anew subs.txt

    # Probe
    echo " Probing..."
    cat subs.txt | sort -u | httpx -silent | anew live.txt

    # URLs
    echo " URL discovery..."
    cat live.txt | katana -d 3 -silent | anew urls.txt
    cat live.txt | waybackurls 2>/dev/null | anew urls.txt
    cat live.txt | gau --blacklist png,jpg,gif,css,woff 2>/dev/null | anew urls.txt

    # JS
    echo " JS extraction..."
    cat urls.txt | grep -iE '\.js(\?|$)' | anew js.txt

    # Params
    echo " Parameter discovery..."
    cat urls.txt | grep "=" | unfurl keys 2>/dev/null | sort -u | anew params.txt

    # Nuclei
    echo " Nuclei scan..."
    nuclei -l live.txt -severity critical,high,medium -o nuclei.txt 2>/dev/null

    echo " Done! Results in ~/recon/$domain/"
    echo " Summary:"
    echo "    Subdomains: $(wc -l < subs.txt 2>/dev/null || echo 0)"
    echo "    Live hosts: $(wc -l < live.txt 2>/dev/null || echo 0)"
    echo "    URLs found: $(wc -l < urls.txt 2>/dev/null || echo 0)"
    echo "    JS files:   $(wc -l < js.txt 2>/dev/null || echo 0)"
}
