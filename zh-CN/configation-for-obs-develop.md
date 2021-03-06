---
title: 桌面版OBS开发配置
date: 2019/07/25 18:10:21
sidebar: auto
meta:
  - name: description
    content: 比坑更坑
---

目前的友商的直播客户端也大多基于OBS开发而来。在此总结下OBS开发环境的搭建与打包发布的流程。

## macOS(版本Mojave10.14.6)

*开发后期系统升级到了10.15, 不过并无大碍。*

### 开发环境配置

开发IDE用的是Clion，先下载着。之后会是30天试用，没钱的话网上随便可以破解。
OBS是基于Qt开发的界面，需要安装以下依赖

```
brew install FFmpeg x264 qt cmake mbedtls
```

**注意安装qt最新版**，坑有 Mojave10.14.6 最低也需要 qt 10.12.0 不然样式会有问题；从 5.13.0 到 5.13.1 解决了一个轻触不能触发点击事件且样式错误的bug。

在qt安装完成后，应该可以看到引用路径，如 /usr/local/Cellar/qt/5.13.1/

在途中也需要clone下官方repo：
```
$ git clone --recursive https://github.com/obsproject/obs-studio.git
```
注意！一定要使用 --recursive 以克隆子模块，不然无法成功运行。

打开 clion，进行以下配置：

1. 系统栏 Clion->Preferences->Build, Execution, Deployment->CMake
2. 在Debug->CMake options 中输入

```
-DCMAKE_PREFIX_PATH=/usr/local/Cellar/qt/5.13.1/ -DCMAKE_INSTALL_PREFIX="/Users/yourname/Develop/obs-test/build-debug"
```

3. 执行一遍cmake(界面左下方，CMake标签页左边的run按钮)如果可以正常执行则界面左上会出现 "CMake Application" 的列表，如果该列表中没有ALL_BUILD选项，则需要在 "Edit configration" 中手工创建一个。
4. 点击创建的ALL_BUILD，点击左边的锤子按钮执行一遍build。
5. "Edit configration" 中选中obs，在build列表下方新建一项 "Run External tool", 添加一项，Name 与 Pragram 填 make，Arguments填install, Working directory 填 /Users/yourname/Develop/obs-test/cmake-build-debug, 点击 ok 后添加。
6. "CMake Application" 中选择 obs 点击列表框右边的 run，执行过一遍 make 之后会提示没有找到执行文件，这时再点开 obs 的 Edit configration, 在 Executable 中选择 build-debug/bin/obs
7. 再次运行，之后便可以打开 obs 界面，进行开发了。

### 打包发布步骤

在开发初期时按照官方尝试过直接在 cmake-build-debug 目录 `make package`, 会生成一个 .dmg 文件，自带安装包。但是接近开发完成再去运行这个命令就报错无法执行了。

根据官方的 `.travis.yml` 文件可以构建出一个直接运行的 .app 文件。其中的命令可以简化为：

```
./CI/install-dependencies-osx.sh && ./CI/before-script-osx.sh && cd ./build && make -j4 && cd - && ./CI/before-deploy-osx.sh
```

但是官方的 Qt 版本之类可能和本地都不同，需要自己对脚本进行一些修改。

我的 Mac 比较神奇，命令行运行时无法获取到 Qt 的 include 目录，可能是安装时运行的不完全吧。需要在自己命令行的 bash_rc 文件中导入如下变量：

```
export C_INCLUDE_PATH="/usr/local/include:/usr/local/Cellar/qt/5.13.1/include"
export CPLUS_INCLUDE_PATH="/usr/local/include:/usr/local/Cellar/qt/5.13.1/include"
export LIBRARY_PATH="/usr/local/include:/usr/local/Cellar/qt/5.13.1/include"
```

执行了上述的 Shell 命令后会两次要求输入密码，之后即可编译成功，在 build 目录下出现 .app 文件。
