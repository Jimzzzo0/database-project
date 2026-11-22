-- ============================================================
-- WorkSafe: 清理原始資料並建立企業統計檢視表
-- 執行順序：02
-- 前置條件：public.penalties_raw 已建立且已匯入 CSV
--
-- 注意：
-- 1. 罰鍰無法辨識或空白時保留 NULL，不視為 0 元。
-- 2. 日期欄位預期為民國日期，例如 115/10/30。
-- 3. 本檢視表不修改原始資料。
-- 4. SELECT 欄位順序維持既有 penalties_clean 檢視表相容。
-- ============================================================

CREATE OR REPLACE VIEW public.penalties_clean AS
WITH normalized AS (
    SELECT
        record_no,
        region,
        NULLIF(BTRIM(announcement_date), '') AS announcement_date_text,
        NULLIF(BTRIM(employer_name), '') AS employer_name,
        NULLIF(BTRIM(penalty_date), '') AS penalty_date_text,
        NULLIF(BTRIM(document_no), '') AS document_no,
        law_articles,
        violation_description,
        NULLIF(BTRIM(fine_amount), '') AS fine_amount_text,
        notes
    FROM public.penalties_raw
)
SELECT
    -- 欄位順序需與先前建立的 penalties_clean 相同
    record_no,
    region,
    employer_name,
    document_no,
    law_articles,
    violation_description,
    notes,

    CASE
        WHEN fine_amount_text ~ '^[0-9,]+$'
        THEN REPLACE(fine_amount_text, ',', '')::NUMERIC
        ELSE NULL
    END AS fine_value,

    CASE
        WHEN penalty_date_text ~ '^[0-9]{2,3}/[0-9]{1,2}/[0-9]{1,2}$'
        THEN MAKE_DATE(
            SPLIT_PART(penalty_date_text, '/', 1)::INTEGER + 1911,
            SPLIT_PART(penalty_date_text, '/', 2)::INTEGER,
            SPLIT_PART(penalty_date_text, '/', 3)::INTEGER
        )
        ELSE NULL
    END AS penalty_date_ad,

    CASE
        WHEN announcement_date_text ~ '^[0-9]{2,3}/[0-9]{1,2}/[0-9]{1,2}$'
        THEN MAKE_DATE(
            SPLIT_PART(announcement_date_text, '/', 1)::INTEGER + 1911,
            SPLIT_PART(announcement_date_text, '/', 2)::INTEGER,
            SPLIT_PART(announcement_date_text, '/', 3)::INTEGER
        )
        ELSE NULL
    END AS announcement_date_ad

FROM normalized;


-- 依原始企業名稱統計裁罰資料
-- violation_count 是資料列筆數，不保證等於去重後的案件數。
CREATE OR REPLACE VIEW public.company_statistics AS
SELECT
    employer_name,
    COUNT(*) AS violation_count,
    COUNT(fine_value) AS fine_record_count,
    SUM(fine_value) AS total_fine,
    MAX(penalty_date_ad) AS latest_penalty_date
FROM public.penalties_clean
GROUP BY employer_name;


-- 檢查清理結果
SELECT
    COUNT(*) AS total_records,
    COUNT(fine_value) AS records_with_fine,
    COUNT(*) - COUNT(fine_value) AS records_without_fine
FROM public.penalties_clean;
