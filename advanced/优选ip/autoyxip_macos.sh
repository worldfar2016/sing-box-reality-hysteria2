#!/bin/bash

#这些需要修改为自己的
API_KEY="xxxxxxx"
API_EMAIL="xxxx@gmail.com"
ZONE_ID="xxxxxxxx"
DOMAINS=("yx.example.com" "yx1.example.com" "yx2.example.com")
pdir="/Users/mareep" # 替换为你的路径，如果此路径中存在CF/CloudflareST文件，则默认CloudflareST已经下载，如果没有则会自动下载解压
urltest="https://urltest.example.com" #替换为自己的测速地址，托管在cf上的测速网站,自建的测速网站
isIPv4=true #如果要测v6就改为false

# 根据isIPv4的值执行不同的命令
if [ "$isIPv4" = true ]; then
    ipfile="ip.txt"
    atype="A"
else
    ipfile="ipv6.txt"
    atype="AAAA"
fi

arch=$(uname -m)
case ${arch} in
    x86_64)
        cf_arch="amd64"
        ;;
    arm64)
        cf_arch="arm64"
        ;;
    *)
        echo "不支持的架构: ${arch}"
        exit 1
        ;;
esac


if [ ! -f "$pdir/CF/CloudflareST" ]; then
    echo "CloudflareST 不存在，开始下载，如果下载不动，手动下载解压到$pdir/CF/文件夹下."
    cf_url="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download/CloudflareST_darwin_${cf_arch}.zip"
    curl -sL "$cf_url" -o "$pdir/cloudflaredST.zip"
    mkdir -p "$pdir/CF"
    unzip -q "$pdir/cloudflaredST.zip" -d "$pdir/CF"
    chmod +x "$pdir/CF/CloudflareST"
else
    # 如果文件存在，则跳过这段代码
    echo "CloudflareST 已经存在，开始测速."
fi


domain_count=${#DOMAINS[@]}

cd "$pdir/CF"
"$pdir/CF/CloudflareST" -p $domain_count -n 1000 -f "$pdir/CF/$ipfile" -url $urltest
bestips=($(awk -F ',' 'NR>1 {print $1}' "$pdir/CF/result.csv" | head -n ${#DOMAINS[@]}))

for ((i=0; i<${#DOMAINS[@]}; i++)); do
    domain="${DOMAINS[$i]}"
    bestip="${bestips[$i]}"
    record_info=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$Atype&name=$domain" \
        -H "X-Auth-Email: $API_EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json")
    #echo "$record_info"
    record_id=$(echo "$record_info" | awk -F '"id":"' '{print $2}' | awk -F '","' '{print $1}')
    
    if [ -z "$record_id" ]; then
        echo "无法提取记录ID for 域名 $domain"
    else
        echo "域名 $domain 的RECORD NAME为 $record_id"
        update_result=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "X-Auth-Email: $API_EMAIL" \
            -H "X-Auth-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            --data '{"type":"'"$atype"'","name":"'"$domain"'","content":"'"$bestip"'","ttl":1,"proxied":false}')
        echo "域名 $domain 的DNS记录已更新为IP地址 $bestip"

    fi
done
