# 使用穩定的 Python 3.9 Slim 版本
FROM python:3.9-slim

# 設定環境變數
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 1. 安裝系統依賴
RUN apt-get update && apt-get install -y \
    git \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# [關鍵修正] 建立 /etc/machine-id
# adl 需要讀取這個檔案來產生 Device Fingerprint
# 我們產生一個隨機的 32 位元 hex 字串寫入
RUN echo "db5d12a6431784260907d72111111111" > /etc/machine-id

# 設定工作目錄
WORKDIR /app

# 2. 安裝 Python 依賴庫
RUN pip install pycryptodome requests

# 3. 安裝 adl
RUN git clone https://github.com/adrienmetais/adl.git /app/adl \
    && cd /app/adl \
    && pip install -r requirements.txt

# 4. 安裝 DeDRM 工具
RUN git clone https://github.com/noDRM/DeDRM_tools.git /app/DeDRM_tools

# 5. 修補 DeDRM 的相對路徑錯誤
RUN sed -i 's/from \.utilities/from utilities/g' /app/DeDRM_tools/DeDRM_plugin/ineptepub.py
RUN sed -i 's/from \.argv_utils/from argv_utils/g' /app/DeDRM_tools/DeDRM_plugin/ineptepub.py

# 6. 複製腳本
COPY extract_key.py /app/extract_key.py
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

# 設定資料掛載點
VOLUME /data
VOLUME /config

# 預設執行腳本
ENTRYPOINT ["/app/run.sh"]
