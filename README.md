# WorkSafe — 企業職安風險查詢系統

## 一、專題介紹
WorkSafe 結合政府公開資料、PostgreSQL 資料庫、地圖及 AI 分析，提供企業職安違規紀錄查詢與風險評估功能。

## 二、需要下載的軟體

1. **VS Code**：編輯程式碼  
   https://code.visualstudio.com/
2. **PostgreSQL**：儲存企業資料  
   https://www.postgresql.org/download/windows/
3. **pgAdmin 4**：管理 PostgreSQL 資料庫（通常隨 PostgreSQL 安裝）
4. **GitHub Desktop**：下載及同步專題  
   https://desktop.github.com/
5. **CMake**：編譯 C++ 專案  
   https://cmake.org/download/
6. **C++ 編譯器、vcpkg**：編譯後端及安裝相依套件

## 三、安裝與執行流程

### Step 1：下載專題
1. 開啟 GitHub Desktop。
2. 選擇 File → Clone Repository → URL。
3. 輸入：
   `https://github.com/Jimzzzo0/database-project.git`
4. Clone 完成後，使用 VS Code 開啟專題。

### Step 2：建立資料庫
1. 開啟 pgAdmin 4。
2. 連接 PostgreSQL 伺服器。
3. 建立資料庫 `worksafe`。
4. 開啟 Query Tool。

### Step 3：建立資料表及匯入資料
依序執行：

1. `01_create_tables.sql`（建立資料表）
2. 匯入企業職安資料 CSV
3. `02_create_clean_views.sql`（清理資料）
4. `03_create_risk_views.sql`（建立風險評分）

確認資料筆數：

```sql
SELECT COUNT(*) FROM public.penalties_raw;
```

### Step 4：啟動系統
1. 在 VS Code 開啟專題。
2. 設定 CMake、vcpkg 與 PostgreSQL 連線。
3. 編譯並啟動 C++ 後端。
4. 在瀏覽器開啟：

`http://127.0.0.1:18080/`

注意：Windows 與 macOS 的編譯指令不同，請依照各自環境設定。

## 四、專題分工

| 組員 | 負責內容 |
|---|---|
| A | 資料庫建置、資料匯入、SQL 分析 |
| B | C++ 後端、API、系統整合與部署 |
| C | 前端介面、地圖功能、手機介面 |
| D | AI 風險分析、改善建議、功能測試 |

## 五、後續開發目標

- [ ] 完成 20 萬筆以上資料匯入
- [ ] 完成企業查詢與風險評分
- [ ] 加入企業地圖功能
- [ ] 加入 AI 風險分析及改善建議
- [ ] 完成手機／平板 App
- [ ] 完成網路部署及系統測試

## 六、注意事項

- 不可將資料庫密碼或 API Key 上傳至 GitHub。
- 地圖上的企業登記位置不代表違規發生地點。
- AI 分析及風險評分僅供參考。
- 正式版本須符合老師要求的網路連線及手機／平板 App 規格。
