hgrip(){ 
history | grep $1
}

#----- AWS -------

s3ls(){
aws s3 ls s3://$1
}

s3cp(){
aws s3 cp $2 s3://$1 
}

#----- misc -----
certspotter(){
curl -s https://certspotter.com/api/v0/certs\?domain\=$1 | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep $1 | tee -a $1-certspotter.txt
} #h/t Michiel Prins

crtsh(){
curl -s https://crt.sh/\?q\=%.$1\&output\=json | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | tee -a $1-domains-crt.txt 
}

certnmap(){
curl https://certspotter.com/api/v0/certs\?domain\=$1 | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep $1  | nmap -T5 -Pn -sS -i $1
} #h/t Jobert Abma

certbrute(){
cat $1 | while read line; do dirsearch $line; done
}

crtshmulti(){
input=$1
while IFS= read -r line
do
curl -s https://crt.sh/\?q\=%25.$line\&output\=json | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | tee -a all.txt
done < "$input"
}

ipinfo(){
curl http://ipinfo.io/$1
}

aj(){
cat $1 | while  read line; do arjurn $line; done
}

arjurn(){
python ~/tools/Arjun/arjun.py -u https://$1/
}

#------ Tools ------
dirsearch(){
python3 ~/tools/dirsearch/dirsearch.py -r -R 4 -t 10 -F -e "php,asp,aspx,php,php3,php4,php5,txt,shtm,shtml,phtm,phtml,jhtml,pl,jsp,cfm,cfml,py,rb,cfg,zip,pdf,gz,tar,tar.gz,tgz,doc,docx,xls,xlsx,conf,log" -w ~/tools/dirsearch/db/dicc.txt -u $1 -b -x 301,302,404,500
}

sqlmap(){
cd /tools/sqlmap*
python sqlmap.py -u $1 
}

knock(){
cd /home/tools/knock/knockpy
python knockpy.py -w list.txt $1
}

am(){
amass enum --passive -r 1.1.1.1 -d $1 -json $1.json
jq .name $1.json | sed "s/\"//g" | httprobe -c 60 | tee -a $1-domains-am.txt
}

ph(){
python3 ~/tools/Photon/photon.py -u $1 -l 6 --keys --wayback --keys
}

massph(){
cat $1 | while read line; do ph $line; done
}

jss(){
curl $1 |  js-beautify - | grep -iE "//|key|api|password|admin|usernameConsumerKey|ConsumerSecret|DB_USERNAME|HEROKU_API_KEY|HOMEBREW_GITHUB_API_TOKEN|JEKYLL_GITHUB_TOKEN|PT_TOKEN|SESSION_TOKEN|SF_USERNAME|SLACK_BOT_TOKEN|access-token|access_token|access_token_secret|accesstoken|admin|api-key|api_key|api_secret_key|api_token|auth_token|authkey|authorization|authorization_key|authorization_token|authtoken|aws_access_key_id|aws_secret_access_key|bearer|bot_access_token|bucket|client-secret|client_id|client_key|client_secret|clientsecret|consumer_key|consumer_secret|dbpasswd|email|encryption-key|encryption_key|encryptionkey|id_dsa|irc_pass|key|oauth_token|pass|private_key|private_key|privatekey|secret|secret-key|secret_key|secret_token|secretkey|secretkey|session_key|session_secret|slack_api_token|slack_secret_token|slack_token|ssh-key|ssh_key|sshkey|token|username|xoxa-2|xoxr|private-key|private_token|Authorization|Bearer"
}

mjss(){
xargs curl -O |  js-beautify - | grep -iE "//|key|api|password|admin|usernameConsumerKey|ConsumerSecret|DB_USERNAME|HEROKU_API_KEY|HOMEBREW_GITHUB_API_TOKEN|JEKYLL_GITHUB_TOKEN|PT_TOKEN|SESSION_TOKEN|SF_USERNAME|SLACK_BOT_TOKEN|access-token|access_token|access_token_secret|accesstoken|admin|api-key|api_key|api_secret_key|api_token|auth_token|authkey|authorization|authorization_key|authorization_token|authtoken|aws_access_key_id|aws_secret_access_key|bearer|bot_access_token|bucket|client-secret|client_id|client_key|client_secret|clientsecret|consumer_key|consumer_secret|dbpasswd|email|encryption-key|encryption_key|encryptionkey|id_dsa|irc_pass|key|oauth_token|pass|private_key|private_key|privatekey|secret|secret-key|secret_key|secret_token|secretkey|secretkey|session_key|session_secret|slack_api_token|slack_secret_token|slack_token|ssh-key|ssh_key|sshkey|token|username|xoxa-2|xoxr|private-key"
}

massnamp(){
input=$1
while IFS= read -r line
do
domain=$(echo $line | sed -e "s/^http:\/\///" -e "s/^https:\/\///")
nmap -A -sV $domain
done < $input
}

ms(){
masscan -p66,80,81,443,445,457,1080,1100,1241,1352,1433,1434,1521,1944,2301,3128,3306,4000,4001,4002,4100,5000,5432,5800,5801,5802,6346,6347,7001,7002,8080,8888,30821 $1
}

wfuzz(){
wfuzz -w ~/tools/SecLists/Discovery/Web-Content/raft-small-directories.txt -w ../SecLists/Discovery/Web-Content/raft-small-files.txt -u https://$1/FUZZ/FUZ2Z --hc 301,302,404,500
}

#----- misc -----

ncx(){
nc -l -n -vv -p $1 -k
}
