import sqlite3
import ast
import base64
import sys
import os

# 定義資料庫路徑
DB_PATH = '/config/adl.db'
OUTPUT_KEY = '/app/key.der'

def extract_key():
    print(f"[Info] 正在從資料庫提取金鑰...")
    
    if not os.path.exists(DB_PATH):
        print(f"[Error] 找不到資料庫 {DB_PATH}。請確認是否已完成註冊。")
        sys.exit(1)

    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        # 匿名登入後，資料通常還是在 users 表中
        # 我們先嘗試找 license_priv，如果沒有再找其他可能的欄位
        try:
            cursor.execute("SELECT license_priv FROM users LIMIT 1")
            row = cursor.fetchone()
        except sqlite3.OperationalError:
            # 萬一 schema 不同，嘗試找 device 表
            cursor.execute("SELECT key FROM device LIMIT 1")
            row = cursor.fetchone()

        if not row:
            print("[Error] 資料庫中找不到金鑰資料。")
            sys.exit(1)

        # 取得原始資料 (可能是 license_priv 或 key)
        raw_data = row[0] 
        key_bytes_b64 = None

        # 邏輯: 處理 Python bytes 字串表示法
        if isinstance(raw_data, str) and raw_data.startswith("b'"):
            try:
                key_bytes_b64 = ast.literal_eval(raw_data)
            except:
                key_bytes_b64 = raw_data[2:-1].encode('utf-8')
        else:
            key_bytes_b64 = raw_data

        # 邏輯: Base64 解碼
        try:
            final_key = base64.b64decode(key_bytes_b64)
        except Exception:
            # 如果不是 base64，就假設它是 raw bytes
            final_key = key_bytes_b64

        # 寫入檔案
        with open(OUTPUT_KEY, 'wb') as f:
            f.write(final_key)
        
        print(f"[Success] 金鑰已提取至: {OUTPUT_KEY}")
        return True

    except Exception as e:
        print(f"[Error] 提取過程發生錯誤: {e}")
        sys.exit(1)
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    extract_key()
