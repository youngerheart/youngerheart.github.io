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
