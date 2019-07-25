---
title: 常见CI/CD工具对比
date: 2019/07/24 18:10:21
sidebar: auto
meta:
  - name: description
    content: CI/CD简介以及对 Travis CI，Jenkins 与 gitlab CI 的对比
---

## 名词解释

持续集成服务（Continuous Integration，简称 CI）

持续交付(Continuous Deployment，简称CD)

持续集成和持续部署通常与敏捷开发环境齐头并进。在这类环境中，团队希望在构建完成后立即将不同的代码段部署到生产环境中。

**好处**：每次代码的小幅变更，就能看到运行结果，从而不断累积小的变更，而不是在开发周期结束时，一下子合并一大块代码。

**以发布一个静态博客站点为例介绍三种CI/CD工具**

## Travis CI

只支持 Github。

### 使用准备

在 (travis-ci.org)[https://travis-ci.org/] 绑定 github 账号。

Travis 会列出 Github 上面你的所有仓库，以及你所属于的组织。此时，选择你需要 Travis 帮你构建的仓库，打开仓库旁边的开关。一旦激活了一个仓库，Travis 会监听这个仓库的所有变化。

### .travis.yml 配置

在项目根目录下新建 `.travis.yml` 文件。

```
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

```
#!/usr/bin/env sh

# 确保脚本抛出遇到的错误
set -e

# 生成静态文件
npm run build

# 进入生成的文件夹
cd .vuepress/dist

git init
git add -A
git commit -m 'deploy'

git config --local user.name "youngerheart"
git config --local user.email "admin@timehub.cc"

git push -f https://${access_token}@github.com/youngerheart/youngerheart.github.io.git master

cd -
```

## Jenkis

支持 git 与 svn。

### 安装

```
mkdir ~/Develop/jenkins

sudo chown -R 1000:1000 ~/Develop/jenkins/

docker pull jenkins/jenkins

lsof -i tcp:8000 // 查看端口占用

sudo docker exec -u root -it xxx /bin/bash // 进入容器

docker run -d -p 8080:8080 -p 50000:50000 -v /Users/younger/Develop/jenkins:/var/jenkins_home jenkins/jenkins
```
