#!/bin/bash
#extmail 登录网址http://IP/extmail/cgi/index.cgi  
install163yum()   #安装163yum
{
rpm -aq|grep yum|xargs rpm -e --nodeps
rpm --import /etc/pki/rpm-gpg/RPM*  
wget http://vault.centos.org/6.0/os/x86_64/Packages/python-iniparse-0.3.1-2.1.el6.noarch.rpm
wget http://vault.centos.org/6.0/os/x86_64/Packages/yum-metadata-parser-1.1.2-14.1.el6.x86_64.rpm
wget http://vault.centos.org/6.0/os/x86_64/Packages/yum-3.2.27-14.el6.centos.noarch.rpm
wget http://vault.centos.org/6.0/os/x86_64/Packages/yum-plugin-fastestmirror-1.1.26-11.el6.noarch.rpm
rpm -ivh python-iniparse-0.3.1-2.1.el6.noarch.rpm
rpm -ivh yum-metadata-parser-1.1.2-14.1.el6.x86_64.rpm
rpm -ivh yum-3.2.27-14.el6.centos.noarch.rpm yum-plugin-fastestmirror-1.1.26-11.el6.noarch.rpm
cd /etc/yum.repos.d/
wget http://mirrors.163.com/.help/CentOS6-Base-163.repo
sed -i 's/$releasever/6/g' CentOS6-Base-163.repo
rm -rf packagekit-media.repo 
yum clean all
yum makecache
yum list
}
installEMOS()      #安装EMOS
{
mkdir /mos
cd /mos
wget http://mirror.extmail.org/iso/emos/EMOS_1.6_x86_64.iso
yum install createrepo -y
mkdir /mnt/EMOS
mount -o loop /mos/EMOS_1.6_x86_64.iso /mnt/EMOS
cd /mnt/
createrepo .
touch /etc/yum.repos.d/EMOS-Base.repo
echo -e "[EMOS]\nname=EMOS" > /etc/yum.repos.d/EMOS-Base.repo
sed  -i '2a baseurl=file:///mnt/' /etc/yum.repos.d/EMOS-Base.repo
sed  -i '3a enabled=1' /etc/yum.repos.d/EMOS-Base.repo
sed  -i '4a gpgcheck=0' /etc/yum.repos.d/EMOS-Base.repo
yum clean all
yum makecache
yum list
yum -y install telnet
}
CleanAndInstallSoftwares()
{
yum install -y httpd postfix mysql mysql-server php php-mysql php-mbstring php-mcrypt courier-authlib courier-authlib-mysql courier-imap maildrop cyrus-sasl cyrus-sasl-lib cyrus-sasl-plain cyrus-sasl-devel extsuite-webmail extsuite-webman
cd /root
wget https://files.phpmyadmin.net/phpMyAdmin/4.6.4/phpMyAdmin-4.6.4-all-languages.tar.bz2 --no-check-certificate 
tar jxvf phpMyAdmin-4.6.4-all-languages.tar.bz2
mv phpMyAdmin-4.6.4-all-languages  /var/www/extsuite/phpmyadmin
cd /var/www/extsuite/phpmyadmin
cp config.sample.inc.php config.inc.php
sed -i "17c \$cfg['blowfish_secret'] = 'skssiwksksie'; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */" /var/www/extsuite/phpmyadmin/config.inc.php
}

ConfigPostfix()
{
cd /etc/postfix
cp main.cf main.cf.bak
postconf -n > main1.cf
cp main1.cf main.cf
sed  -i '18a #hostname' /etc/postfix/main.cf
sed  -i '19a mynetworks = 127.0.0.1' /etc/postfix/main.cf
sed -i "20a myhostname = $HOSTNAME" /etc/postfix/main.cf
echo "mydestination = \$mynetworks \$myhostname" >> /etc/postfix/main.cf
echo -e "# banner\nmail_name = Postfix – by extmail.org" >> /etc/postfix/main.cf
echo -e "smtpd_banner = \$myhostname ESMTP \$mail_name\n# response immediately\nsmtpd_error_sleep_time = 0s\n# Message and return code control\nmessage_size_limit = 5242880\nmailbox_size_limit = 5242880\nshow_user_unknown_table_name = no\n# Queue lifetime control\nbounce_queue_lifetime = 1d\nmaximal_queue_lifetime = 1d" >> /etc/postfix/main.cf
}
ConfigCourierAuthlib()
{
echo -e "MYSQL_SERVER localhost\nMYSQL_USERNAME extmail\nMYSQL_PASSWORD extmail\nMYSQL_SOCKET /var/lib/mysql/mysql.sock\nMYSQL_PORT 3306\nMYSQL_OPT 0\nMYSQL_DATABASE extmail\nMYSQL_USER_TABLE mailbox\nMYSQL_CRYPT_PWFIELD password\nMYSQL_UID_FIELD uidnumber\nMYSQL_GID_FIELD gidnumber\nMYSQL_LOGIN_FIELD username\nMYSQL_HOME_FIELD homedir\nMYSQL_NAME_FIELD name\nMYSQL_MAILDIR_FIELD maildir\nMYSQL_QUOTA_FIELD quota" > /etc/authlib/authmysqlrc
echo "MYSQL_SELECT_CLAUSE     SELECT username,password,\"\",uidnumber,gidnumber,\\" >> /etc/authlib/authmysqlrc
echo "                        CONCAT('/home/domains/',homedir),               \\" >> /etc/authlib/authmysqlrc
echo "                        CONCAT('/home/domains/',maildir),               \\" >> /etc/authlib/authmysqlrc
echo "                        quota,                                          \\" >> /etc/authlib/authmysqlrc
echo "                        name                                            \\" >> /etc/authlib/authmysqlrc
echo "                        FROM mailbox                                    \\" >> /etc/authlib/authmysqlrc
echo "                        WHERE username = '\$(local_part)@\$(domain)'" >> /etc/authlib/authmysqlrc
sed -i '27c authmodulelist="authmysql"' /etc/authlib/authdaemonrc
sed -i '34c authmodulelistorig="authmysql"' /etc/authlib/authdaemonrc
chmod 755 /var/spool/authdaemon/
service courier-authlib start
}

ConfigMaildrop()
{
echo  "maildrop   unix        -       n        n        -        -        pipe" >> /etc/postfix/master.cf
echo "  flags=DRhu user=vuser argv=maildrop -w 90 -d \${user}@\${nexthop} \${recipient} \${user} \${extension} {nexthop}" >> /etc/postfix/master.cf
echo "maildrop_destination_recipient_limit = 1" >> /etc/postfix/main.cf
maildrop -v   #测试maildrop
}
ConfigApache()
{
echo -e "NameVirtualHost *:80\n# VirtualHost for ExtMail Solution\n<VirtualHost *:80> \nServerName mail.extmail.org\nDocumentRoot /var/www/extsuite/extmail/html/\nScriptAlias /extmail/cgi/ /var/www/extsuite/extmail/cgi/\nAlias /extmail /var/www/extsuite/extmail/html/\nScriptAlias /extman/cgi/ /var/www/extsuite/extman/cgi/\nAlias /extman /var/www/extsuite/extman/html/\nAlias /phpmyadmin /var/www/extsuite/phpmyadmin/\n# Suexec config\nSuexecUserGroup vuser vgroup\n</VirtualHost>" >> /etc/httpd/conf/httpd.conf
sed -i '276s/#ServerName www.example.com:80/ServerName www.example.com:80/g' /etc/httpd/conf/httpd.conf
service httpd start
}
ConfigExtmail()
{
cd /var/www/extsuite/extmail
cp webmail.cf.default webmail.cf
sed -i 's/SYS_MYSQL_USER = db_user/SYS_MYSQL_USER = extmail/g' /var/www/extsuite/extmail/webmail.cf
sed -i 's/SYS_MYSQL_PASS = db_pass/SYS_MYSQL_PASS = extmail/g' /var/www/extsuite/extmail/webmail.cf
sed -i 's/SYS_MYSQL_DB = extmail/SYS_MYSQL_DB = extmail/g' /var/www/extsuite/extmail/webmail.cf
chown -R vuser:vgroup /var/www/extsuite/extmail/cgi/
}
ConfigExtman()
{
chown -R vuser:vgroup /var/www/extsuite/extman/cgi/
mkdir /tmp/extman
chown -R vuser:vgroup /tmp/extman
service mysqld start 
mysql -u root -p < /var/www/extsuite/extman/docs/extmail.sql
mysql -u root -p < /var/www/extsuite/extman/docs/init.sql
#设置虚拟域和虚拟用户的配置文件
cd /var/www/extsuite/extman/docs
cp mysql_virtual_alias_maps.cf /etc/postfix/ 
cp mysql_virtual_domains_maps.cf /etc/postfix/
cp mysql_virtual_mailbox_maps.cf /etc/postfix/
cp mysql_virtual_sender_maps.cf /etc/postfix/
echo -e "# extmail config here\nvirtual_alias_maps = mysql:/etc/postfix/mysql_virtual_alias_maps.cf\nvirtual_mailbox_domains = mysql:/etc/postfix/mysql_virtual_domains_maps.cf\nvirtual_mailbox_maps = mysql:/etc/postfix/mysql_virtual_mailbox_maps.cf\nvirtual_transport = maildrop:" >> /etc/postfix/main.cf
/usr/sbin/authtest -s login postmaster@extmail.org extmail  #测试authlib
/usr/local/mailgraph_ext/mailgraph-init start #启动mailgraph_ext（后台管理的图像日志信息）
/var/www/extsuite/extman/daemon/cmdserver --daemon  #启动cmdserver(在后台显示系统信息)
echo "/usr/local/mailgraph_ext/mailgraph-init start" >> /etc/rc.d/rc.local
echo "/var/www/extsuite/extman/daemon/cmdserver -v -d" >> /etc/rc.d/rc.local
#加入开机启动
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
#关闭SELINUX
}
ConfigCourierImap()
{
sed -i 's/IMAPDSTART=YES/IMAPDSTART=NO/g' /usr/lib/courier-imap/etc/imapd
sed -i 's/IMAPDSSLSTART=YES/IMAPDSSLSTART=NO/g' /usr/lib/courier-imap/etc/imapd-ssl
service courier-imap start
}
TestPop3()
{
echo "telnet localhost 110"   #如果想测试
#首先去extmail下建立test@extmail.org用户，密码test
echo "user test@extmail.org"
echo "pass test"
echo "list"
echo "quit" 
}
ConfigCyrusSasl()

{
echo -e "# smtpd related config\nsmtpd_recipient_restrictions =\n        permit_mynetworks,\n        permit_sasl_authenticated,\n        reject_non_fqdn_hostname,\n        reject_non_fqdn_sender,\n        reject_non_fqdn_recipient,\n        reject_unauth_destination,\n        reject_unauth_pipelining,\n        reject_invalid_hostname,\n# SMTP sender login matching config\nsmtpd_sender_restrictions =\n        permit_mynetworks,\n        reject_sender_login_mismatch,\n        reject_authenticated_sender_login_mismatch,\n        reject_unauthenticated_sender_login_mismatch\nsmtpd_sender_login_maps =\n        mysql:/etc/postfix/mysql_virtual_sender_maps.cf,\n        mysql:/etc/postfix/mysql_virtual_alias_maps.cf\n# SMTP AUTH config here\nbroken_sasl_auth_clients = yes\nsmtpd_sasl_auth_enable = yes\nsmtpd_sasl_local_domain = \$myhostname\nsmtpd_sasl_security_options = noanonymous" >> /etc/postfix/main.cf
echo -e "pwcheck_method: authdaemond\nlog_level: 3 \nmech_list: PLAIN LOGIN \nauthdaemond_path:/var/spool/authdaemon/socket" > /usr/lib64/sasl2/smtpd.conf
service postfix restart
perl -e 'use MIME::Base64; print encode_base64("postmaster\@extmail.org")' #测试SMTP认证
#cG9zdG1hc3RlckBleHRtYWlsLm9yZw==
perl -e 'use MIME::Base64; print encode_base64("extmail")'
#ZXh0bWFpbA==
}
SetBoot()
{
chkconfig httpd on
chkconfig mysqld on
chkconfig postfix on
chkconfig courier-imap on
chkconfig courier-authlib on
}


install163yum
installEMOS
CleanAndInstallSoftwares
ConfigPostfix     #配置Postfix（MTA邮件传输代理）
ConfigCourierAuthlib     #配置courier-authlib（imap和maildrop的认证）
ConfigMaildrop    #配置maildrop（MDA邮件投递代理）
ConfigApache      #为邮件系统提供网页服务
ConfigExtmail  　 #提供网页收发邮件服务
ConfigExtman
ConfigCourierImap  #配置Courier-imap(imap和pop3接收邮件代理)
#TestPop3
ConfigCyrusSasl
SetBoot
