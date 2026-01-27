#!/bin/bash

# 定義路徑
ADL_DIR="/app/adl"
ADL_CONFIG_LOCAL="/root/.adl"
USER_CONFIG_DIR="/config"
DATA_DIR="/data"
LOG_FILE="/tmp/adl_run.log"

# 初始化設定檔連結
mkdir -p "$ADL_CONFIG_LOCAL"

# 函數：同步設定檔 (從 Config 到 Local)
sync_config_in() {
    if [ -f "$USER_CONFIG_DIR/adl.db" ]; then
        cp "$USER_CONFIG_DIR/adl.db" "$ADL_CONFIG_LOCAL/adl.db"
    fi
}

# 函數：同步設定檔 (從 Local 到 Config)
sync_config_out() {
    if [ -f "$ADL_CONFIG_LOCAL/adl.db" ]; then
        cp "$ADL_CONFIG_LOCAL/adl.db" "$USER_CONFIG_DIR/adl.db"
    fi
}

# 函數：執行自動註冊
auto_register() {
    echo ">>> 偵測到尚未註冊，正在執行匿名登入..."
    echo "" | python3 "$ADL_DIR/adl.py" login > "$LOG_FILE" 2>&1
    RET=$?
    cat "$LOG_FILE"

    if [ $RET -ne 0 ]; then
        echo ">>> [Fatal Error] 登入程序發生崩潰。"
        exit 1
    fi
    
    if [ -f "$ADL_CONFIG_LOCAL/adl.db" ]; then
        echo ">>> 匿名註冊成功！"
        sync_config_out
    else
        echo ">>> [Error] 註冊失敗：程式跑完了但找不到 adl.db。"
        exit 1
    fi
}

COMMAND=$1
ARG=$2

if [ "$COMMAND" == "process" ]; then
    if [ -z "$ARG" ]; then
        echo "使用法: docker run ... process <filename.acsm>"
        exit 1
    fi

    ACSM_FILE="/data/$ARG"
    if [ ! -f "$ACSM_FILE" ]; then
        echo "錯誤: 找不到檔案 $ACSM_FILE"
        exit 1
    fi

    sync_config_in
    
    if [ ! -f "$ADL_CONFIG_LOCAL/adl.db" ]; then
        auto_register
    else
        echo ">>> 偵測到現有設定檔，跳過登入步驟。"
    fi

    echo ">>> 步驟 1: 下載電子書..."
    
    # [關鍵修正] 切換到 data 目錄，確保檔案下載到掛載區
    cd "$DATA_DIR" || exit 1
    
    # 執行下載 (注意路徑變數)
    python3 "$ADL_DIR/adl.py" get -f "$ACSM_FILE" 2>&1 | tee "$LOG_FILE"
    RET=${PIPESTATUS[0]}
    
    # 切換回 app 目錄以免後續腳本路徑錯亂
    cd /app
    
    if [ $RET -ne 0 ]; then
        echo ""
        echo ">>> [Error] 下載失敗，正在分析原因..."
        if grep -q "E_GOOGLE_DEVICE_LIMIT_REACHED" "$LOG_FILE"; then
            echo "🔴 錯誤原因：裝置數量限制 (Device Limit Reached)"
            echo "💡 解決建議：請重新下載一個新的 ACSM 檔案。"
        elif grep -q "E_ADEPT_REQUEST_EXPIRED" "$LOG_FILE"; then
            echo "🔴 錯誤原因：ACSM 檔案已過期 (Expired)"
            echo "💡 解決建議：請重新下載新的檔案。"
        else
            echo "🔴 未知錯誤，請檢查 Log。"
        fi
        exit 1
    fi

    # 搜尋最新的 epub 檔案 (排除 decrypted 的以免抓錯)
    # 使用 grep -v 排除已經解密過的檔案
    EPUB_FILE=$(ls -t "$DATA_DIR"/*.epub 2>/dev/null | grep -v "_decrypted" | head -n1)
    
    if [ -z "$EPUB_FILE" ]; then
        echo ">>> [Error] 下載指令成功，但在 $DATA_DIR 找不到 epub 檔案。"
        echo "    請檢查是否下載到了錯誤的路徑。"
        exit 1
    fi
    echo ">>> 下載完成: $(basename "$EPUB_FILE")"

    echo ">>> 步驟 2: 提取金鑰..."
    python3 /app/extract_key.py > /dev/null
    if [ $? -ne 0 ]; then
        echo ">>> [Error] 金鑰提取失敗。"
        exit 1
    fi

    echo ">>> 步驟 3: 解除 DRM..."
    BASENAME=$(basename "$EPUB_FILE" .epub)
    OUTPUT_FILE="$DATA_DIR/${BASENAME}_decrypted.epub"
    
    python3 /app/DeDRM_tools/DeDRM_plugin/ineptepub.py "/app/key.der" "$EPUB_FILE" "$OUTPUT_FILE"
    
    if [ $? -eq 0 ]; then
        echo "========================================"
        echo "SUCCESS! 任務完成"
        echo "輸出: $OUTPUT_FILE"
        echo "========================================"
    else
        echo ">>> [Error] 解密失敗"
        exit 1
    fi

elif [ "$COMMAND" == "login" ]; then
    echo ">>> 手動登入模式..."
    python3 "$ADL_DIR/adl.py" login
    sync_config_out
    echo ">>> 設定已儲存至 config"

else
    echo "未知的指令。請使用 'process <acsm_file>' 或 'login'"
fi
