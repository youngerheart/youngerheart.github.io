---
title: 黑苹果简明教程-手稿
date: 2017/09/18 17:13:37
sidebar: auto
meta:
  - name: description
    content: 黑苹果是一个巨坑，请抱着黑苹果以折腾而生的心态，遇到个别问题需要认真百度，科学上网才能知道答案，本人第一次折腾，用了整整三天达到自己满意的程度。
---

视频链接： [https://www.bilibili.com/video/av14573035](https://www.bilibili.com/video/av14573035)

## 引子

hello 大家好。

9月13号，在我研究黑苹果的时候苹果公司发布了新一代 iPhone X，售价999美元，中国加上增值税售价8388软妹币，对此你怎么看呢。
网上有人评论 iPhone 的销量自 iPhone 6 登顶后有所下滑。iPhone 7 也没能超过早先 iPhone 6 的水平。提升单机售价可以让为苹果带来更多利润。现在觉得自己用了三年真是对得起自己的价格了。
换个话题。今天带来的是关于黑苹果的视频，分以下几部分，可以选择性观看。
1.为什么选择黑苹果？这就问的好了，不光是手机，苹果电脑这几年也成功地在性能挤牙膏的同时大幅提高了售价，最低配 macbook pro 成功破万，顶配版更是接近三万，性能有一定提升，但是去除了很多有价值的接口，需要购置更多昂贵的转换器（这很pro）。
本人在三年前以 6000 余元买了一台 2013 款 13寸 macbook pro，无奈性能实在捉急，基本没法玩游戏就不说了，上b站基本没法开弹幕，一开就卡。对于新款 mbp 的售价望而却步，只得选择黑苹果。
2.选择机型。第一种就是与 mbp 相似的超极本，关注度较高的有 Dell XPS15 系列，LG Gram 系列等，在硬件水平相似的情况下售价相对较低。第二种就是烂大街的游戏本们，性价比高，但便携性比较差。请在其中自己权衡考虑。下面正式进入装机教程。

## 前期准备

### 心理准备
黑苹果是一个巨坑，请抱着黑苹果以折腾而生的心态，遇到个别问题需要认真百度，科学上网才能知道答案，本人第一次折腾，用了整整三天达到自己满意的程度。

### 硬件准备
本教程选择使用流行的 EFI 引导 Clover 方法基于 Win10 安装 macOS Sierra10.12.6 系统。首先为机器准备一块安装 macOS 的系统盘，首先整块硬盘需要以 UEFI 形式进行格式化（GUID模式），新的 WIN10 机器在装机时一般都会采取这种新式。如果没有此类硬盘则需要格式化出一块。另外再准备一块8G及以上的u盘，一块2g及以上u盘。

### 软件准备
下载你中意的系统版本，关键词：macOS with Clover，最好是“懒人包”其中包含的驱动较为齐全。其次在win10系统中安装如下软件。

### 制作 macOS 启动盘
插入8G及以上u盘，将 TransMac 设置为使用管理员权限并打开，对u盘右键选择第二项将该u盘格式化为 HFS 格式的 UEFI 形式，再右键选择第三项，选择之前下载好的镜像文件，写入为 macOS 启动盘。之后在我的电脑中打开u盘的EFI 分区，根据自己硬件配置的需要配置驱动及config.plist文件。具体请百度，本人提供的百度网盘资源可供参考。请特别注意，如果系统分区为nvme协议的固态硬盘，则必须有 IONVMeFamily.kext 驱动并在config.plist中进行配置，否则苹果系统无法识别该硬盘。将本人提供的 .IAProductInfo 文件放入该分区根目录。如果没有该文件直接进入该分区将出现这种情况，此为被称为“二次安装”的坑。

### 制作WINDOWS装机盘
装机过程中极可能出现硬盘误操作导致无法进入原  Windows 系统，此时可以进入装机系统进行操作。具体请百度 Wndows 装机盘，请下载UEFI版本并进行在2G及以上U盘制作。

### 准备MacOS系统分区
打开 DiskGenius ，在之前准备好的硬盘中分出20GB以上的空间，全部分好区的硬盘也可以对剩余容量20GB以上的分区调整大小，分出20GB空间。检查该硬盘的ESP分区如果小于300MB则需要进行扩容，事先备份好原 ESP 分区的数据，新分出300MB空间并格式化为 EFI 格式，还原数据到该分区，最后删除原EFI分区并妥善利用原空间。

1. 添加 macOS 系统盘引导序列。在UEFI形式的系统中打开BOOTICEx64（系统分区不是该形式则启动之前制作的 Windows 装机盘），点击UEFI，修改启动序列，添加，选择u盘EFI分区中的 CLOVERX64.efi 文件，修改名称后点击确定，并将该项移动到第一位

2. 百度好自己机型的进入 BIOS 快捷键与选择 UEFI 启动项快捷键。至此前期准备基本完成。

## 正式开始安装

### 重启机器
开机时按住进入 BIOS 快捷键，将启动模式设置为 UEFI，启动第一项设置为USB HARD DISK，安全启动模式设置为关闭，SATA模式设置为AHCI，保存后重启。

### 重启时立马按住选择 UEFI 启动项快捷键
选择之前设置过的 macOS 启动盘，回车进入clover引导界面。选择 BOOT OS X install from macOS 选项，加载文件后进入MACOS装机界面。

### “五国”的坑
如果此时出现五国文字提示的错误信息，则为你遇到了简称“五国”的坑，请结合自己的硬件信息进行百度解决。正常情况下进入的可能为选择语言界面，选择适合自己的语言，也有可能是直接没有该界面。

### 选择磁盘工具
选择之前分配的硬盘中的空闲的20GB以上空间，点击抹掉之后格式化为选项中的第一项。

### 点击安装 macOS 进行硬盘写入操作
之后机器将自动重启，此时立马按住选择 UEFI 启动项快捷键进入原 Windows 系统，在我的电脑中可以看到新的 macOS 系统分区。

###DiskGenius
利用 DiskGenius 将 macOS 启动盘中的 Clove r文件夹放入硬盘中的EFI分区对应位置，并在 BOOTICEx64 中添加该启动项，至此 macOS 系统盘已经可以脱离MAC启动盘独立运行。

### 重新启动
按住选择UEFI启动项快捷键选择 macOS 系统盘，进入 Clover 引导界面，选择 boot macOS from macOS,因为是硬盘启动，短暂加载后如果能看到选择语言界面，则说明系统安装基本成功，接下来就是一些系统初始化操作了。终于看到熟悉的山脉，你会不会有些许感动呢。

## 驱动调教

### 检查 macOS 下软硬件功能
通常可能出现：无法显示电量，无法识别移动硬盘，无法识别无线网卡，无法正常关机，关机后自动重启，无法识别英伟达独立显卡，无法识别读卡器等情况。
下载如下软件。当前没有网络，可以从 Windows 系统下下载。
1. 无法显示电量，无法识别移动硬盘时，打开 Kext Wizard，利用本人提供的资源打入如下补丁并重启。
2. 无法识别无线网卡：除非你是博通的无线网卡，否则在 macOS 下基本找不到驱动，可以在地摊买一个20元左右的 USB 无线网卡，插入后能被软件自动识别，输入wifi信息后即可使用。
3. 无法正常关机，关机后自动重启的情况，请打开 Clover Configurator，点击 mount efi 打开硬盘ESP分区中的 config.plist 文件，结合自己硬件配置进行调教。
4. 无法识别英伟达独立显卡，可以在 config.plist 文件中配置后在英伟达官网下载 webdriver 驱动。之后进行配置即可识别。
5. 无法识别读卡器的情况我还没有解决，可能还会有一些小的问题没有解决，调教是一个漫长的过程。

通过 config.plist 配置可以在开机后直接进入 macOS 系统，最后来欣赏一下 macOS 的启动过程吧。

ok，这个教程讲解基本就告一段落了，本视频由younger浪君制作，英语口语问题敬请谅解大学四级水平我也是才发现那个词念clover的，如果你有任何问题请在留言中提出，如果对你有帮助请投个硬币点个关注，我们有生之年再见。
