## 初始操作

- 关闭防火墙

  `systemctl stop firewalld`

  `systemctl disable firewalld`
- 关闭selinux

  `set -i 's/forcing/disabled' '/etc/selinux/config'  `永久关闭

  `sudo setenforce 0` 临时关闭
- 关闭swap

  `sed -ri 's/.swap./#&/' /etc/fstab `永久关闭

  `swapoff -a `临时关闭
- 设置主机名

  ```
  cat >> /etc/hosts << EOF
  192.168.3.1 k8s-master
  192.168.3.2 k8s-node1
  192.168.3.3 k8s-node2
  EOF
  ```
- 启用桥接网络

  ```
  cat > /etc/sysctl.d/k8s.conf << EOF
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
  EOF
  ```
- 重启

  ```
  sysctl --system
  ```
- 时间同步

  `yum install ntpdate -y`

  `ntpdate time.windows.com`

## 安装基础软件

- 安装docker

  ```
  wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo

  yum list docker-ce --showduplicates

  yum install --setopt=obsoletes=0 docker-ce-18.06.3.ce-3.el7 -y

  mkdir /etc/docker

  #Docker 在默认情况下使用Vgroup Driver为cgroupfs，而Kubernetes推荐使用systemd来替代cgroupfs
  cat <<EOF> /etc/docker/daemon.json
  {
    "exec-opts": ["native.cgroupdriver=systemd"],
    "registry-mirrors": ["https://kn0t2bca.mirror.aliyuncs.com"]
  }
  EOF

  systemctl restart docker

  systemctl enable docker
  ```
- 添加阿里云yum源
  编辑/etc/yum.repos.d/kubernetes.repo,添加下面的配置

  ```
  [kubernetes]
  name=Kubernetes
  baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
  enabled=1
  gpgchech=0
  repo_gpgcheck=0
  gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
    		http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
  ```
- 安装kubeadm、kubelet、kubectl

  ```
  yum install --setopt=obsoletes=0 kubeadm-1.17.4-0 kubelet-1.17.4-0 kubectl-1.17.4-0 -y
  ```
  ```
  # 编辑/etc/sysconfig/kubelet, 添加下面的配置
  KUBELET_CGROUP_ARGS="--cgroup-driver=systemd"
  KUBE_PROXY_MODE="ipvs"
  ```
  ` systemctl enable kubelet`

## 初始化master节点

  ```
  # master节点执行
  kubeadm init \
    --apiserver-advertise-address=192.168.90.100 \
    --image-repository registry.aliyuncs.com/google_containers \
    --kubernetes-version=v1.17.4 \
    --service-cidr=10.96.0.0/12 \
    --pod-network-cidr=10.244.0.0/16
  ```
  `mkdir -p $HOME/.kube`
  `sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config`
  `sudo chown $(id -u):$(id -g) $HOME/.kube/config`

## 加入node节点
```
kubeadm join 192.168.0.100:6443 --token <初始化master时候产生的token> \
    --discovery-token-ca-cert-hash <master控制台的hash>
```
` kubeadm token list`  获取token

获取hash:需要拼接sha256: 
``` 
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt| openssl rsa -pubin -outform der 2>/dev/null|\
openssl dgst -sha256 -hex|sed 's/^.*//'
```  

## master节点安装网络插件
`wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml`

重置集群
```
#在master节点之外的节点进行操作
kubeadm reset
systemctl stop kubelet
systemctl stop docker
rm -rf /var/lib/cni/
rm -rf /var/lib/kubelet/*
rm -rf /etc/cni/
ifconfig cni0 down
ifconfig flannel.1 down
ifconfig docker0 down
ip link delete cni0
ip link delete flannel.1
##重启kubelet
systemctl restart kubelet
##重启docker
systemctl restart docker
```
`kubectl apply -f kube-flannel.yml`

这个时候三个node的状态都是ready

## 测试
`kubectl create deployment nginx  --image=nginx:1.14-alpine`

`kubectl expose deploy nginx  --port=80 --target-port=80  --type=NodePort`