# WorkSafe PostgreSQL + C++ 串接教學（macOS）

這個版本保留真實裁罰資料的公司搜尋與明細，地圖**尚不放真實企業圖釘**：勞動部來源資料未經確認位置，不可以將登記地址直接等同違規發生地點。

## 1. 確認 pgAdmin 中存在以下物件
- 資料庫 `worksafe`
- View `public.penalties_clean`
- View `public.company_risk_scores`

## 2. 安裝工具
需要安裝 Homebrew（若先前沒有安裝，參考 https://brew.sh/ ）。在 Mac Terminal 執行：

```bash
brew install crow libpq cmake
```

## 3. 在 VS Code 中開啟本專案
解壓縮後以 VS Code「File > Open Folder」開啟 `WorkSafe_PostgreSQL_Cpp_連線版`。在 Terminal 使用 `cd` 切換到此專案根目錄（有 CMakeLists.txt 的那層）。

## 4. 編譯 C++

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH="$(brew --prefix crow);$(brew --prefix libpq)"
cmake --build build -j 2
```

如果提示 `CrowConfig.cmake` 未找到，可額外加入 `-DCrow_DIR="$(brew --prefix crow)/lib/cmake/Crow"`；實際路徑請先用 `find "$(brew --prefix crow)" -iname '*Crow*Config.cmake'` 確認。

## 5. 設定 PostgreSQL 連線

```bash
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
read -s PGPASSWORD; echo
export PGPASSWORD
```

`read -s PGPASSWORD` 執行後直接輸入 pgAdmin 使用的 PostgreSQL 密碼，畫面不會顯示字元，再按 Enter。
PGPORT 若非 5432，請改成你 PostgreSQL 的實際埠號。

## 6. 啟動伺服器
請確認 Terminal 目前位置是專案根目錄。

```bash
./build/worksafe
```

在 Chrome 打開 `http://127.0.0.1:18080/`，**不要**直接雙擊 index.html。先到 `http://127.0.0.1:18080/api/health` 應顯示 `{"status":"ok"}`，再到 `http://127.0.0.1:18080/api/companies?q=` 檢查是否有資料。

停止服務可在 Terminal 按 Ctrl+C。

## 常見問題
- `Cannot connect to worksafe`：請確認 PostgreSQL 已啟動、使用者、埠號、密碼與 db 名稱。
- `SQL query failed`：確認 `company_risk_scores`、`penalties_clean` 位於 `worksafe` 資料庫的 `public` schema。
- `403 Access blocked` 地圖底圖：這是地圖圖磚來源/網路的問題，與 SQL 無關。此版地圖透過 localhost 開啟仍須遵守 OSM 的使用政策。
- 頁面搜尋的風險指數是前一步 PostgreSQL VIEW 的結果；其計分和去重假設尚須在發表前驗證，不是官方安全認證。
- 遠端部署前必須加入認證/存取限制及正式地圖服務規劃；目前只監聽 127.0.0.1，供本機開發使用。
