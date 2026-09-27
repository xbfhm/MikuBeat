# MikuBeat  

![](https://count.littlebell.top/@MikuBeat)

## 软件信息  

| | |
|-----|-----|  
| 软件名 | [MikuBeat](https://github.com/Pafonshaw/MikuBeat) |  
| 版本名 | [0.3Release](https://github.com/Pafonshaw/MikuBeat/releases/tag/0.3Release) |  
| 开发者 | [Pafonshaw](https://github.com/Pafonshaw) |  
| 语言 | AndroLua |  
| 编辑器 | [OpenLuaX+](https://github.com/znzsofficial/OpenLuaX_Open-Source) |  

## 软件介绍  

+  `MikuBeat` 是一款安卓 **术力口** 播放器软件，基于 `AndroLua` - [`OpenLuaX+`](https://github.com/znzsofficial/OpenLuaX_Open-Source) 开发，完全 `免费开源` 。  
+ MikuBeat依赖于网易云音乐、哔站，通过开放接口与网页爬虫获取音频与歌曲信息，项目仅用于交流学习，无意对相关图片与歌曲造成任何侵权。  
+ MikuBeat坚持使用 `Material Design 3` 主题开发，界面优雅美观。  

## 新增功能（本分支）  

+ **网易云歌单**：音乐页新增「歌单」标签页，点击右下角 `+` 按钮，粘贴网易云歌单链接或歌单ID即可自动抓取整张歌单，支持播放全部、刷新歌单、删除歌单。  
+ **免费播放兜底**：通过 [`GDStudio`](https://music-api.gdstudio.xyz/) 聚合接口（`source=netease`），在网易云官方接口拿不到直链（VIP/下架歌曲）时自动改用免费接口播放，复用网易云歌曲ID，无需手动搜索。  
+ 涉及文件：`lua/gdstudio.lua`（免费接口）、`lua/playlistManager.lua`（歌单管理）、`layout/playlistCard.lua`（歌单卡片），并对 `main.lua`、`layout/music.lua`、`lua/music163.lua`、`lua/music163Parsing.lua` 做了改动。  

## 开源声明  

+ 本APP基于 `AndroLua` - [`OpenLuaX+`](https://github.com/znzsofficial/OpenLuaX_Open-Source) 开发，完全免费开源。  
+ 本项目下所有文件均受 `Apache-2.0` 协议保护  

### 开源项目使用声明:  

 >    部分代码取自 梅花易排盘 By [Xiayu372](https://github.com/xiayu372/)  
 >    网易解析接口取自 [Netease_url](https://github.com/Suxiaoqinx/Netease_url) [演示网站](https://api.toubiec.cn/wyapi.html)


## 其他  

### 注意事项

> 请在 `MikuBeat/lua/userAddManager.lua` 第307行填入正确的 deepseek 密钥  
> 源码内含有用到本人水仙后台的代码，自行修改


### 致谢:  

 >    非常感谢 [Xiayu372](https://github.com/xiayu372/) 在开发过程中提供的大量指导性帮助。  

### 免责声明:  

 >    本项目仅用于交流学习，无意对相关图片与歌曲造成任何侵权。  
 >    本项目不对使用本项目产生的任何后果负责。  
 >    请在下载并使用本项目前自行评估风险。  

### 联系方式:  

 >    QQ: 271607916  
 >    官方Q群: 912150197  
 >    TG: @Pafonshaw  


