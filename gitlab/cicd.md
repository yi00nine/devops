### 配置.gitlab-ci.yml 文件

一个.gitlab-ci.yml 文件一般有下面几个模块

- image:指定作业的运行时候使用的容器
- variables:定义作业运行的环境变量
- stage:定义作业的执行阶段

### stage

```yml
stages:
  - deploy
```

### image

```yml
image:
```

### .common

定义通用方法

```yml
.common:
  before_script: &before-script
    - echo "build start"
    - docker login --username=test@test --password=test registry.cn-hangzhou.aliyuncs.com
  after_script: &after-script
    - docker logout
    - echo "build end"

  script: &exec-script
    - REGISTRY_WITH_TAG="registry.cn-hangzhou.aliyuncs.com/test:${DOCKER_TAG}"
    - docker build -t "${REGISTRY_WITH_TAG}" -f deploy/Dockerfile .
    - docker push "${REGISTRY_WITH_TAG}"
    #    - docker rmi "${REGISTRY_WITH_TAG}"
    - sed -i "s/<IMAGE_TAG>/$DOCKER_TAG/g" ./deploy/docker-compose-head.yaml
    - sed -i "s/<IMAGE_TAG>/$DOCKER_TAG/g" ./deploy/docker-compose-side.yaml

.deploy:
  script: &deploy-script
    - TIMESTAMP=$(date +%Y%m%d%H%M%S)
    - DOCKER_TAG="${TIMESTAMP}"_"${CI_COMMIT_SHORT_SHA}"
    - *exec-script
    - ssh -o "StrictHostKeyChecking=no" ${HEAD_HOST} "[ -d /tmp/cicd/barn/head ] && echo ok || mkdir -p /tmp/cicd/barn/head"
    - rsync -icrvh --delete deploy/ ${HEAD_HOST}:/tmp/cicd/barn/head/deploy
    - ssh -o "StrictHostKeyChecking=no" ${HEAD_HOST} "cd /tmp/cicd/barn/head/deploy && $HEAD_DOCKER_COMPOSE";
    - ssh -o "StrictHostKeyChecking=no" ${SIDE_HOST} "[ -d /tmp/cicd/barn/side ] && echo ok || mkdir -p /tmp/cicd/barn/side"
    - rsync -icrvh --delete deploy/ ${SIDE_HOST}:/tmp/cicd/barn/side/deploy
    - ssh -o "StrictHostKeyChecking=no" ${SIDE_HOST} "cd /tmp/cicd/barn/side/deploy && $SIDE_DOCKER_COMPOSE";
```

定义了 before-script、after-script、exec-script 和 deploy-script 方法

### 具体的作业定义

```yml
deploy_to_dev:
  before_script:
    - *before-script
  after_script:
    - *after-script
  stage: deploy
  when: manual
  variables:
    HEAD_HOST: root@192.168.3.118
    HELM: helm upgrade --install barn-release barn-cluster -n barn --create-namespace
    HEAD_DOCKER_COMPOSE: docker compose  -f docker-compose-head.yaml up -d
    SIDE_HOST: xyz10@192.168.3.118
    SIDE_DOCKER_COMPOSE: docker compose  -f docker-compose-side.yaml up -d
  script:
    - *deploy-script
```

### 整体流程

- before-script 命令登陆 docker 仓库
- 生成唯一的 tag,用 deploy 目录下的 dockerfile 来打包镜像
- 替换 deploy 目录下的 docker-compose 的 tag
- ssh 到指定的服务器(需要提前配置好密钥)
- 使用 rsync 将部署的脚本以及文件传输到服务器的指定位置
- 进入到指定的目录下运行 docker-compose
