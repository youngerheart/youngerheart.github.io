开发配置：

1、克隆项目（完成）
git clone git@talkcheap.xiaoeknow.com:XiaoeFE/xiaoe-obs.git

2、安装依赖（完成）
brew install qt
brew install x264
brew install ffmpeg

3、安装cmake(安装命令行)（完成）

4、安装xcode（等啊等完成）

5、命令行进入xiaoe-obs工程目录（完成）

mkdir -p builds/mk 
cd builds/mk
CMAKE_PREFIX_PATH=/usr/local/opt/qt5/ cmake ../../

mkdir -p builds/xcode
cd builds/xcode
CMAKE_PREFIX_PATH=/usr/local/opt/qt5/ cmake ../../ -G Xcode

6、xcode打开生成的工程文件（xcode文件夹下）

1、file -> new -> target -> corss-platform -> external build，确定新建一个target
2、左上角选文件夹图标，右侧列表选中刚才的新建的target ->Info -> Directory 选择第一步的mk，然后箭头
打包运行一下

3、edit scheme -> info -> executable选obs，options-> working directory->obs-studio/builds/mk/rundir/RelWithDebInfo/bin
