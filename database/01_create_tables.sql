-- ============================================================
-- WorkSafe: 建立原始裁罰資料表
-- 執行順序：01
-- 資料庫：worksafe
--
-- 建立資料表後，請使用 pgAdmin Import/Export Data 將整理好的
-- CSV 匯入 public.penalties_raw。
-- 本檔不會刪除既有資料。
-- ============================================================

CREATE TABLE IF NOT EXISTS public.penalties_raw (
    record_no TEXT,
    region TEXT,
    announcement_date TEXT,
    employer_name TEXT,
    penalty_date TEXT,
    document_no TEXT,
    law_articles TEXT,
    violation_description TEXT,
    fine_amount TEXT,
    notes TEXT
);

-- 常用查詢欄位索引
CREATE INDEX IF NOT EXISTS idx_penalties_raw_employer_name
    ON public.penalties_raw (employer_name);

CREATE INDEX IF NOT EXISTS idx_penalties_raw_document_no
    ON public.penalties_raw (document_no);

-- 確認資料表欄位
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'penalties_raw'
ORDER BY ordinal_position;
