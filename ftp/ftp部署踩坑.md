### 背景

公司要求在 ecs 上部署 ftp,上传文件到 nas,需要创建 27 个普通账号和一个管理员账号.管理员账号可以访问根目录下的所有用户目录,有上传和下载权限.普通账号只有上传权限,无法访问其他用户目录.

### ssh 连接 ecs

创建 ecs 密钥对,下载证书到本地,放在.ssh 目录下

```
ssh -i /Users/mac/.ssh/test.pem root@test
```

### 安装 vsftpd

```
# 安装
yum install -y vsftpd
# 设置开机自己启动
systemctl enable vsftpd.service
# 启动ftp服务
systemctl start vsftpd.service
# 查看21端口是否运行ftp服务
netstat -antup | grep ftp

```

这个时候 ftp 服务已经简单的启动了,刚开始通过谷歌浏览器访问进不去,后面了解是浏览器逐渐不支持 ftp 了

后面去下载 filezilla 客户端来连接 ftp 服务

### 配置 ftp 用户以及权限

useradd ` username #创建用户`

创建完用户之后会在/home 目录下出现用户目录,用户后续上传的文件会保存在对应的用户名文件下

完整配置

```
listen=YES  #是否让 vsftpd 以独立模式运行，由 vsftpd 自己监听和处理连接请求
anonymous_enable=NO #不允许匿名登录服务器
local_enable=YES #系统用户登陆
write_enable=YES #添加写权限,支持上传文件
dirmessage_enable=YES #激活目录欢迎信息功能
use_localtime=YES #使用主机的时间
xferlog_enable=YES #记录服务器上传和下载的日志文件，默认日志文件为 /var/log/vsftpd.log
connect_from_port_20=YES #开启主动模式后是否启用默认的 20 端口监听
chroot_local_user=YES #限制用户在主目录,也就是/home
chroot_list_enable=YES #取消访问自己目录以外文件的权限
chroot_list_file=/etc/vsftpd.chroot_list #vsftpd.chroot_list文件设置可以访问其他目录的用户,管理员用户需要在这里配置
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
allow_writeable_chroot=YES #如果用户被限制在主目录,并且需要读权限需要添加这个配置
local_root=/home #系统用户登录路径
pasv_enable=YES
pasv_address=your ip #设置ip
pasv_min_port=50000
pasv_max_port=50010
userlist_enable=YES #阻止用户登陆服务器
userlist_file=/etc/vsftp.user_list #只有配置文件里面的用户可以登陆,和下面对应
userlist_deny=NO #是否阻止 vsftp.user_list 文件中的用户登录服务器
listen_port=42222 #修改默认端口
download_enable=NO #禁止所有用户下载,管理员用户权限额外配置
user_config_dir=/etc/vsftpd/userconfig #在此目录设置用户权限
local_umask=0000 #所有用户上传的文件都是最大权限

```

注意: 默认的 vsftp.user_list 以及 vsftpd.chroot_list 配置是在/etc 目录下,网络上的大部分教程是把他们放在了/etc/vsftpd/下

配置/etc/vsftp.user_list 和 /etc/vsftpd.chroot_list 文件,为空也必须要创建

在/etc/vsftpd/userconfig 目录下为所有的用户以及管理员配置对应的主目录和权限

```
管理员配置 :
local_root=/home/admin
download_enable=YES
普通用户
local_root=/home/user
```

配置完重启 ftp 服务 `systemctl restart vsftpd.service`

### ecs 配置安全组

放开 ecs 的端口限制

### 绑定 nas

清空/home 下的数据,将 nas 的/目录挂载到 ecs 的/home 目录,重新创建正式的用户信息.

useradd 用户之后创建的目录默认只有属主可以读写,需要手动去修改目录权限让管理员可以访问

创建用户权限目录的脚本

```
arr=()

for item in "${arr[@]}"
do
    filename="$item.txt"
    content="local_root=/home/$item"
    echo "$content" > "$filename"
done
```
