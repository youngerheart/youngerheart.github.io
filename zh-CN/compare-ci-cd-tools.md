---
title: 常见CI/CD工具对比
date: 2019/07/24 18:10:21
sidebar: auto
meta:
  - name: description
    content: CI/CD简介以及对 Travis CI，Jenkins 与 gitlab CI 的对比
---

## 名词解释

持续集成（Continuous Integration，简称 CI）

持续交付(Continuous Deployment，简称CD)

持续集成和持续部署通常与敏捷开发环境齐头并进。在这类环境中，团队希望在构建完成后立即将不同的代码段部署到生产环境中。

**好处**：每次代码的小幅变更，就能看到运行结果，从而不断累积小的变更，而不是在开发周期结束时，一下子合并一大块代码。

![图解CI/CD](https://www.2cto.com/uploadfile/Collfiles/20180424/2018042409302768.jpg)

## 没有CI/CD 所引发的问题

* 上传 dist 文件到仓库导致完全无意义的冲突
* build、忘记 build、操作机器浪费的时间
* 加了特技的 [contribution](https://github.com/vuejs/vue/graphs/contributors)

![没有CI/CD 所引发的问题](http://img.99danji.com/uploadfile/2016/0419/20160419034745372.jpg)

### Git webhook机制

* Webhooks是"user-defined HTTP回调"。它们通常由一些事件触发，例如"push 代码到repo"，或者"post 一个评论到博客"。
* 当事件发生时，源站点可以发起一个HTTP请求到webhook配置的URL。配置之后，用户可以通过在一个站点触发事件，调用另一个系统的任何操作。

**github 发送报文**

```bash
// 后端发起请求
// url 是 /payload
POST /payload HTTP/1.1
Host: localhost:4567
// 唯一识别分发的GUID
X-Github-Delivery: 72d3162e-cc78-11e3-81ab-4c9367dc0958
// HMAC十六进制的响应体。如果secret配置了，这个头信息将被发送。HMAC十六进制由sha1哈希算法生成，secret作为HMAC的key。
X-Hub-Signature: sha1=7d38cdd689735b008b3c702edd92eea23791c5f6
// 神奇的UA
User-Agent: GitHub-Hookshot/044aadd
Content-Type: application/json
Content-Length: 6615
// 触发事件
X-GitHub-Event: issues
{
  "action": "opened",
  "issue": {
    "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
    "number": 1347,
    ...
  },
  "repository" : {
    "id": 1296269,
    "full_name": "octocat/Hello-World",
    "owner": {
      "login": "octocat",
      "id": 1,
      ...
    },
    ...
  }
}
```

![官网示例](https://developer.github.com/assets/images/payload_request_tab.png)

**配置方法**

* Github: 仓库界面 -> Settings -> Webhooks
* Gitlab: 仓库界面 -> Settings -> Integrations

**以发布一个静态博客站点为例介绍三种CI/CD工具**

## Travis CI

![Travis CI](http://www.ruanyifeng.com/blogimg/asset/2017/bg2017121901.png)

只支持 Github。

### 使用准备

在 (travis-ci.org)[https://travis-ci.org/] 绑定 github 账号。

Travis 会列出 Github 上面你的所有仓库，以及你所属于的组织。此时，选择你需要 Travis 帮你构建的仓库，打开仓库旁边的开关。一旦激活了一个仓库，Travis 会监听这个仓库的所有变化。

### .travis.yml 配置

在项目根目录下新建 `.travis.yml` 文件。

```yaml
language: node_js
sudo: required
node_js: stable
branch: dev
cache:
  directories:
    - node_modules
before_install:
  - export TZ='Asia/Shanghai'  # 设置时区
script:
  - ./deploy.sh
```

### token 配置

github 左上头像 -> Settings -> Developer settings -> Persional access tokens -> Generate new token

除了 delete_repo 都选上，将生成的 token 复制。

在 Travis 选择要构建的仓库 左上 More options -> Settings -> Environment Variables 新建一个 access_token，粘贴刚才的 token。

### deploy.sh 配置

```bash
#!/usr/bin/env sh

# 确保脚本抛出遇到的错误
$ set -e

# 生成静态文件
$ npm run build

# 进入生成的文件夹
$ cd .vuepress/dist

$ git init
$ git add -A
$ git commit -m 'deploy'

$ git config --local user.name "youngerheart"
$ git config --local user.email "admin@timehub.cc"

$ git push -f https://${access_token}@github.com/youngerheart/youngerheart.github.io.git master

cd -
```

## Jenkins

![Jenkins + Docker](https://cn.bing.com/th?id=OIP.RoGnyGsIDpGwq5UCdHpWpgHaFR&pid=Api&rs=1)

支持 git 与 svn。

### 安装

```bash
$ mkdir ~/Develop/jenkins

// 新版貌似不用改权限了？ 
$ sudo chown -R 1000:1000 ~/Develop/jenkins/

$ docker pull jenkins/jenkins

$ lsof -i tcp:8000 // 查看端口占用

$ sudo docker exec -u root -it xxx /bin/bash // 进入容器

$ docker run -d -p 8080:8080 -p 50000:50000 -v /Users/younger/Develop/jenkins:/var/jenkins_home jenkins/jenkins
```

### 配置

1. 进入`localhost:8080` ，在 Unlock Jenkins 中输入 `jenkins/secrets/initialAdminPassword` 的初始密码。

!['初始密码'](http://image.timehub.cc/images/2019/07/30/3734705-55dc998018a217fd.png)

2. 注册用户与安装插件，需要最新版 jenkins 否则插件可能安装不成功。

!['安装插件'](http://image.timehub.cc/images/2019/07/30/3734705-b043f2d9fa0b355b.png)

3. Manage Jenkins -> Configure System，输入 github 的 `access_token`。
4. 创建一个 `Freestyle project`，Source Code Management 中设置 git 仓库，Build Environment 中勾选 Provide Node & npm bin/ folder to PATH
5. Build 中添加一个 `Excude shell`

```
$ npm config set registry http://registry.npm.taobao.org
$ npm install
$ ./deploy.sh
```

## Gitlab runner

![Gitlab runner](https://gitlab.com/uploads/-/system/project/avatar/250833/runner_logo.png)

### 原理

*Pipelines: 官方提供的插件队列集合，用来实现和集成连续交付。*

1. Gitlab 服务器发放 url 与 token，拿去注册一个 runner，runner会通过轮训检查代码更新。
2. 每当 push 代码到制定分支，在 Pipelines 中新增 stages 状态为 `Pending`，根据 `.gitlab-ci.yml` 的配置 stages 中包含若干 jobs。
3. runner 轮训到 Pending 的仓库，开始执行 CI/CD，同时将 stages 状态变更为 `Running`
4. 执行成功 `Success` 失败 `Failed`

### 安装

首先需要有一台 Gitlab 服务器，一个有master及以上权限的项目。

```bash
// mac
$ brew update
$ brew install gitlab-ci-multi-runner

// CentOS
$ curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.rpm.sh | sudo bash
$ yum install gitlab-ci-multi-runner
```

Gitlab -> Setting -> CI/CD -> Running settings -> Setup a specific Runner manually

找到 `following URL` 与 `token`

runner 服务器中
```
$ gitlab-ci-multi-runner register // 填入上述信息，类型选择shell，tag 需要和 .gitlab-ci.yml中一致
$ gitlab-ci-multi-runner verify  #激活runner
$ gitlab-ci-multi-runner list    #查看当前runner
$ gitlab-ci-multi-runner run     #运行runner
```

### .gitlab-ci.yml

```bash
stages:
  - build

build_dev:
  stage: build
  only:
    - dev
    - test
  tags:
    - goo
  cache:
    paths:
      - node_modules/
  script:
    - cnpm i
    - cnpm run build:site
    - rsync -av ./docs/dist/ /data/wwwroot/goo/
```

