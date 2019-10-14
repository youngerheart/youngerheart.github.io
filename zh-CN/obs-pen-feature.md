---
title: OBS画笔功能的开发
date: 2019/09/13 18:10:21
sidebar: auto
meta:
  - name: description
    content: 一个看似平常的功能，却耗费了数倍于前端开发的精力
---

## 序

近两个月基本都在开发自家的定制OBS。这次的版本主要是精简了原有操作逻辑，并自动引入推流信息等。要说稍有些新意的功能可能就是画笔了。关于OBS开发环境搭建可以查看这篇文章。

之前做过一个区域截屏框功能（这版还不能上），其实就是借鉴之前只能手动输入截取区域的区域截屏插件，用qt画一个dialog，设置属性使其透明，在其被调整大小与移动时更新插件的截取区域。

这次的画笔功能则要求在推流过程中通过鼠标事件实时更新画面，这就不管是新建插件那么简单，还要了解到插件究竟如何影响到推流了。

其实踩坑不要紧，关键是OBS相关的文档实在是少之又少，网上也非常难搜到信息（开发者太少）。相比较而言前端开发真是一件过于幸福的事。

## 相关文件

* `plugin/mac-pen` 画笔推流插件
* `UI/forms/PenLabel` 画笔功能条界面布局
* `UI/pen/board` 画板控件
* `UI/pen/main` 画笔功能条逻辑
* `libobs/global-data` 设置储存像素信息的全局变量

## 代码顺序逻辑

* 用户点击画笔功能条中的开关后，`UI/pen/main` 中的逻辑触发 `UI/window-basic-main` 的 enablePenBoard 函数以初始化画笔推流插件。之后在`window-basic-main`中将该插件图层置顶。
* 由于普通的插件初始化后会被加入到素材(source-tree)列表，为了阻止这个默认行为，在`UI/obs-scene.c`的obs_scene_enum_items函数中做了过滤处理。
* 插件初始化后的回调会创建透明的画板控件。由于Windows端非浮动窗口无法保持画板透明，在这里做了非常多的兼容处理。
* 用户点击画板后触发一系列鼠标事件，图形被绘制在一个 QPixmap 上，并通过遍历像素点赋值在global-data的全局变量。
* 画笔推流插件每帧遍历一次全局变量的像素点信息并进行推流(目前的帧率为15fps)。

## 技术细节

### 插件如何实现推流？

首先需要制造推流的单帧数据，大致如下

```
struct obs_source_frame frame = {
  .data = {[0] = (uint8_t *) pixels},
  .linesize = {[0] = ast->width * 4},
  .width = ast->width,
  .height = ast->height,
  .format = VIDEO_FORMAT_BGRA,
};


// 遍历像素点
uint64_t start_time = os_gettime_ns(), cur_time;
cur_time = os_gettime_ns();
uint32_t x, y, index;
for (x = 0; x < ast->width; x++) {
  for (y = 0; y < ast->height; y++) {
    index = x * ast->height + y;
    //pixels[y * ast->width + x] = penData[x * ast->height + y];
    pixels[y * ast->width + x] = getPixData(index);

  }
}
frame.timestamp = cur_time - start_time;
obs_source_output_video(ast->source, &frame);
```
关于这个结构体是没有在obs的文档里查到的，查源代码与实践后得知各字段功能：

* data: 像素点数组的数组（？？），在第一项放入uint8_t的像素点数组。
* linesize: 用途未知的数组，如果设置不当会各种花屏。实践证明将其第一项设置为图片宽的一边的像素 * 4 可以正常推流内容。
* format: 颜色模式，如果不包含alpha通道可以将最后一项设置为X，如果设置为好像很熟悉的RGBA则会显示为诡异的颜色。

接下来需要按照一定的帧率实现推流，很容易想到的是在 `video_tick` 回调调用上面的代码，然而实践证明发生了内存泄漏(macOS下30秒内内存占用突破1G，正常应该不超过100M)，而在使用创建线程函数 pthread_create 的回调中制造 while 循环则不会。相关代码如下：

```
if (os_event_init(&ast->stop_signal, OS_EVENT_TYPE_MANUAL) != 0) {
  ast_destroy(ast);
  return NULL;
}
if (pthread_create(&ast->thread, NULL, video_thread, ast) != 0) {
  ast_destroy(ast);
  return NULL;
}

static void *video_thread(void *data) {
  struct mac_pen_info *ast = data;
  while (os_event_try(ast->stop_signal) == EAGAIN) {
    ...
    obs_source_output_video(ast->source, &frame);
      start_time = cur_time;
#ifdef __APPLE__
  usleep(66666);
#endif
#ifdef _WIN32
  Sleep(66);
#endif
}
```
上面按照双平台做了usleep与Sleep，使得while循环可以保持在约15fps。

### 用到的一些绘图函数与技巧

* 直线: painter->drawLine(startX, startY, newX, newY)
* 曲线: painter->drawLine(lastX, lastY, newX, newY)
* 椭圆: painter->drawEllipse(startX, startY, newX - startX, newY - startY)
* 矩形: painter->drawRect(startX, startY, newX - startX, newY - startY)
* 箭头: 

```
double arrowX1, arrowY1, arrowX2, arrowY2;
double arrowLength = 10, arrowDegrees = 0.5;
double angle = atan2(newY - startY, newX - startX) + 3.1415927;
// 求得箭头点1坐标
arrowX1 = newX + arrowLength * cos(angle - arrowDegrees);
arrowY1 = newY + arrowLength * sin(angle - arrowDegrees);
// 求得箭头点2坐标
arrowX2 = newX + arrowLength * cos(angle + arrowDegrees);
arrowY2 = newY + arrowLength * sin(angle + arrowDegrees);

painter->drawLine(startX, startY, newX, newY);   // 绘制线段
painter->drawLine(newX, newY, arrowX1, arrowY1); // 绘制箭头一半
painter->drawLine(newX, newY, arrowX2, arrowY2); // 绘制箭头另一半
```
* 橡皮擦: painter->setCompositionMode(QPainter::CompositionMode_Clear)
* QPixmap 转透明 QImage: pixmap.toImage().convertToFormat(QImage::Format_ARGB32);
* C++ 版 indexOf:

```
vector<string> penBtnNames {"cursorButton", "painterButton", "lineButton", "circleButton", "rectButton", "arrowButton", "eraserButton"};
int mode = std::distance(penBtnNames.begin(), std::find(penBtnNames.begin(), penBtnNames.end(), btn->objectName().toLatin1().data()));
```
