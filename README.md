# 如何使用

## 前置條件
* Docker 環境

## 使用步驟
1. git clone 並進入專案目錄
```bash
git clone https://github.com/liaozensiang/download_epbg_and_dedrm.git
cd download_epbg_and_dedrm
```
2. build image
```bash
sudo docker build -t epub-worker .
```
3. 把Google 圖書的 epub.acsm下載下來(比方說是 NO_GAME_NO_LIFE_遊戲人生_12-epub.acsm )，放在data資料夾裡
然後執行程序
```bash
sudo docker run --rm -v $(pwd)/data:/data -v $(pwd)/config:/config epub-worker process NO_GAME_NO_LIFE_遊戲人生_12-epub.acsm
```
***注意！ acsm有使用期限，太久沒去下載可能失效***
# **注意！ Google Play圖書只允許6部裝置下載**
# **使用此方法下載一次會被記作一部裝置**
## 特別感謝
dedrm 使用了 https://github.com/noDRM/DeDRM_tools 這個專案
