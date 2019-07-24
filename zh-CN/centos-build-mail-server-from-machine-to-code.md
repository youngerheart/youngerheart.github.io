---
title: CentOS下搭建邮件服务器-从机器到代码
date: 2017/02/21 18:10:21
sidebar: auto
meta:
  - name: description
    content: 自己配置并维护一个邮件服务器有什么好处呢？总之还是为了装x。
---

## 自己配置并维护一个邮件服务器有什么好处呢？

1. 不必再用 qq, 163 之类看上去比较 lowbi 的邮箱。
2. 不必再用 gmail 之类收个邮件还要翻墙的邮箱。
3. 精选的应用账号绑定到自己邮件服务器的邮箱，其他的绑定到 lowbi 邮箱，省的垃圾邮件太多。
4. 随意定ID，各种高大上。

说了那么多，总之还是为了装x。

这里机器配置大部分都原搬 [https://www.fancycoding.com/centos7-mail-server-with-dovecot-postfix-ssl/](https://www.fancycoding.com/centos7-mail-server-with-dovecot-postfix-ssl/) 这篇文章，向作者表示感谢。

## 准备工作

首先你需要有这些个东西

1. 自己的机器（VPS）。
2. 一级域名，然后再去解析个 `mail.domain.com` 的二级域名（A记录）。
3. 二级域名去配置下 SSL 证书， 可以用到这个工具：[Neilpang / acme.sh](https://github.com/Neilpang/acme.sh)。在最后会执行这个命令

```
acme.sh  --installcert  -d  mail.timehub.cc   \
        --keypath   /etc/nginx/keys/mail.timehub.key \ # 域名证书私钥
        --fullchainpath /etc/nginx/keys/mail.timehub.crt \  # 公钥
        --certpath /etc/nginx/keys/mail.timehub.pem \ # CA证书
        --reloadcmd  "service nginx restart"
```

记住这三个文件的路径。

## DNS 解析

（[DNS 解析的基础知识](http://www.ruanyifeng.com/blog/2016/06/dns.html)）

去你的域名提供商那的解析表单，做如下操作：

1. 为主域名添加一条 MX 记录，记录值为 `mail.domain.com`，优先级为 1 即可。
2. 为主域名添加一条 TXT 记录，该记录值为 [SPF](http://www.openspf.org/SPF_Record_Syntax) 。

```
v=spf1 a mx ~all // 指出除了解析的 A 记录 和 MX 记录之外的域发送的邮件都是伪造的
```

解析个一阵，使用 dig 命令查看是否成功：

```
$ dig MX mail.timehub.cc

; <<>> DiG 9.8.3-P1 <<>> MX mail.timehub.cc
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 45640
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 0

;; QUESTION SECTION:
;mail.timehub.cc.		IN	MX

;; AUTHORITY SECTION:
timehub.cc.		3496	IN	SOA	ns19.xincache.com. hostmaster.xinnetdns.com. 2002042718 3600 900 720000 3600
```

## 安装 Postfix（发送电子邮件服务器)

安装 <a href="https://en.wikipedia.org/wiki/Postfix_(software)">Postfix</a> 并删除原先的 sendMail：

```
yum -y install postfix
yum remove sendmail
```

然后进行基本配置：

```
$ vi /etc/postfix/main.cf

myhostname = mail.timehub.cc
mydomain = timehub.cc
myorigin = mail.timehub.cc
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128, 192.168.1.0/24
inet_interfaces = all
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = cyrus
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
smtpd_sasl_authenticated_header = yes
smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination
smtpd_tls_auth_only = no
smtp_use_tls = yes
smtpd_use_tls = yes
smtp_tls_note_starttls_offer = yes
smtpd_tls_key_file = /etc/nginx/keys/mail.timehub.key
smtpd_tls_cert_file = /etc/nginx/keys/mail.timehub.crt
smtpd_tls_CAfile = /etc/nginx/keys/mail.timehub.pem
smtpd_tls_received_header = yes
smtpd_tls_session_cache_timeout = 3600s
```

```
$ vi /etc/postfix/master.cf

submission inet n       -       -       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_wrappermode=no
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
```

## 安装 Dovecot（接收 IMAP 和 POP3 邮件服务器）

安装 <a href="https://en.wikipedia.org/wiki/Dovecot_(software)">Dovecot</a>:

```
yum -y install  dovecot
```

然后进行基本配置：

```
$ vim /etc/dovecot/dovecot.conf

protocols = imap pop3
mail_location = mbox:~/mail:INBOX=/var/mail/%u
pop3_uidl_format = %08Xu%08Xv

service auth {
    unix_listener /var/spool/postfix/private/auth {
    group = postfix
    mode = 0660
    user = postfix
}
}

ssl=required
ssl_cert = </etc/nginx/keys/mail.timehub.crt
ssl_key = </etc/nginx/keys/mail.timehub.key
ssl_ca = </etc/nginx/keys/mail.timehub.pem
```

## 启动所有服务

```
$ newaliases # 将送给使用者的信都收给 mailing list 处理程序负责分送的工作
$ service postfix restart
$ service dovecot restart
```

查看 log：

```
$ cat /var/log/maillog

Feb 21 15:12:00 fancycoding dovecot: master: Dovecot v2.2.10 starting up for imap, pop3 (core dumps disabled)
```

如果一直没有 log 生成，试着重启下系统日志服务：

```
$ service rsyslog restart
```

## 连接邮件客户端

首先创建用户：

```
useradd -s /sbin/nologin admin
passwd admin
```

打开邮件客户端，新建账户 `admin@domain.com`，收发邮件服务器填写 `mail.domain.com`，顺利的话就可以收发邮件了。

## NodeJS 下发送邮件

使用到 [nodemailer](https://github.com/nodemailer/nodemailer)，首先从 npm 安装：

```
$ npm install nodemailer --save
```

在代码中使用：

```
import nodemailer from 'nodemailer';

const mailTransport = nodemailer.createTransport({
  host: 'mail.timehub.cc',
  secureConnection: true, // use SSL
  auth: {
    user: 'lightpress',
    pass: 'pass'
  }
});

export default {
  send(options) {
    var {to = [], subject = '', text = '', html = ''} = options;
    return new Promise((reslove, reject) => {
      mailTransport.sendMail({
        from: '"Lightpress" <lightpress@timehub.cc>',
        to: to.join(','),
        subject, text, html
      }, (err, msg) => {
        if (err) reject(err);
        else reslove(msg);
      });
    });
  }
};
```

正常的话即可发出邮件。
