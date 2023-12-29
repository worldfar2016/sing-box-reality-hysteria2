## 先随意安装reality
例如二合一：
```bash
bash <(curl -fsSL https://github.com/vveg26/sing-box-reality-hysteria2/raw/main/install.sh)
```
## 申请证书
```shell
bash <(curl -Ls https://raw.githubusercontent.com/vveg26/myself/main/BashScript/SSLAutoInstall/SSLAutoInstall.sh)
```
## 安装ngx
```shell
bash <(curl -Ls https://raw.githubusercontent.com/vveg26/myself/main/BashScript/nginx-onekey/ngx.sh) --install
```
## 修改ngx内容
如果需要更加多功能，请参考：https://github.com/vveg26/myself/tree/main/Conf/sing-box
<p>
nano /etc/nginx/nginx.conf

```nginx
user nginx;
worker_processes auto;

error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}
#监听443端口的流量里的sni域名
stream {
    # sni分流，如果sni匹配到以下域名则跳转对应端口
    map $ssl_preread_server_name $backend_name {

        wow.mareep.net          reality2; # 正常的一个网站，用来被偷证书，自己的一个需要被偷取的网站

    }
    

    #偷自己的证书，当443端口sni匹配到reality.example.com，则直接转发到8013端口执行后续操作，此处转发到sing-box监听的8013端口之后由reality回落到自己的8003端口去偷reality.example.com的证书
    upstream reality2 {
        server 127.0.0.1:8013;  # IPv4 地址
        server [::1]:8013;      # IPv6 地址
    }

    # 监听 443 并开启 ssl_preread,监听对应域名并转发
    server {
        listen 443 reuseport;
        listen [::]:443 reuseport; #ipv6
        proxy_pass  $backend_name;
        ssl_preread on;
    }
}

http {
    log_format main '[$time_local] $remote_addr "$http_referer" "$http_user_agent"';
    access_log /var/log/nginx/access.log main;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    map $remote_addr $proxy_forwarded_elem {
        ~^[0-9.]+$        "for=$remote_addr";
        ~^[0-9A-Fa-f:.]+$ "for=\"[$remote_addr]\"";
        default           "for=unknown";
    }

    map $http_forwarded $proxy_add_forwarded {
        "~^(,[ \\t]*)*([!#$%&'*+.^_`|~0-9A-Za-z-]+=([!#$%&'*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'*+.^_`|~0-9A-Za-z-]+=([!#$%&'*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*([ \\t]*,([ \\t]*([!#$%&'*+.^_`|~0-9A-Za-z-]+=([!#$%&'*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'*+.^_`|~0-9A-Za-z-]+=([!#$%&'*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*)?)*$" "$http_forwarded, $proxy_forwarded_elem";
        default "$proxy_forwarded_elem";
    }

    server {
        listen 80;
        listen [::]:80;
        return 301 https://$host$request_uri;
    }

    
    #偷取自己证书，和上文的reality2对应，这里监听8003端口，对应sing-box那边监听reality2那边的8013，然后回落到nginx这边的8003端口偷取这里reality.example.com的证书
    server {
        listen 8003 ssl http2;
        listen [::]:8003 ssl http2;  # 同时监听 IPv6 地址

        ssl_certificate       /root/cert/mareep.net.cer;  # 证书位置，可以用泛域名证书一劳永逸
        ssl_certificate_key   /root/cert/mareep.net.key;  # 私钥
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256:TLS13-AES-128-CCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305:AES256-GCM-SHA384:CHACHA20-POLY1305;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass https://www.bing.com; #伪装网址或者你改成自己的动态网站
            proxy_ssl_server_name on;
            proxy_redirect off;
            sub_filter_once off;
            sub_filter "www.bing.com" $server_name;
            proxy_set_header Host "www.bing.com";
            proxy_set_header Referer $http_referer;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header User-Agent $http_user_agent;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header Accept-Encoding "";
            proxy_set_header Accept-Language "zh-CN";
        }
    }

}
```
## 修改sing-box配置文件
配置文件路径：/root/sbox/sbconfig_server.json
只给出入站部分
```json
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": 8013, //nginx的reality入站端口
      "users": [
        {
          "uuid": "50000006-58ef-4ac6-0000-41f9600003",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "wow.mareep.net",//客户端对应sni，对应ngx的域名
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "::", //因为偷自己，所以本地回环127.0.0.1也可以换成::
            "server_port": 8003 //对应ngx的server监听端口
          },
          "private_key": "abcacbbcbcbcbacbabcbsbc",
          "short_id": ["acbcbabcabab"]
        }
      }
    },
    {
        "type": "hysteria2",
        "tag": "hy2-in",
        "listen": "::",
        "listen_port": 8443,
        "users": [
            {
                "password": "d700000008"
            }
        ],
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "/root/cert/fullchain.cer", //可以换成你自己的域名证书路径了
            "key_path": "/root/cert/mareep.net.key" //可以换成你自己的域名证书路径了
        }
    }
  ]
```

## 客户端
客户端只需要修改域名即可
```yaml
  - name: Reality
    type: vless
    server: 101.207.201.133
    port: 443 #ngx监听443sni至sing-box的8013
    uuid: 50000006-58ef-4ac6-0000-41f9600003
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: wow.mareep.net #你的域名
    client-fingerprint: chrome
    reality-opts:
      public-key: abcacbbcbcbcbacbabcbsbc
      short-id: acbcbabcabab
```
