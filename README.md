先build image
```bash
docker build -t epub-worker .
```
把Google 圖書的 epub.acsm下載下來(比方說是 NO_GAME_NO_LIFE_遊戲人生_12-epub.acsm )，放在data資料夾裡
```bash
docker run --rm -v $(pwd)/data:/data -v $(pwd)/config:/config epub-worker process NO_GAME_NO_LIFE_遊戲人生_12-epub.acsm
```
