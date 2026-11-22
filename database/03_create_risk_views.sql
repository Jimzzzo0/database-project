-- ============================================================
-- WorkSafe: 建立裁罰案件評分與企業避雷指數
-- 執行順序：03
-- 前置條件：public.penalties_clean 已建立
--
-- 初版模型：
-- R = MIN(100, SUM(S * T) + 5 * N)
-- S：違規嚴重程度分數
-- T：裁罰時間權重
-- N：近五年去重後裁罰案件數
--
-- 這是專題自訂參考模型，不是政府官方評等。
-- 未被下列法條規則辨識的法條，暫以 10 分計算。
-- ============================================================


-- 每筆（去重後）裁罰案件的評分
CREATE OR REPLACE VIEW public.risk_case_scores AS
WITH scored_rows AS (
    SELECT
        p.employer_name,
        p.region,
        p.document_no,
        p.penalty_date_ad,
        p.law_articles,
        p.violation_description,
        p.fine_value,

        -- 優先以處分文號識別案件；
        -- 若文號空白，退回使用原始資料編號，避免空白文號全部合併。
        CASE
            WHEN NULLIF(BTRIM(p.document_no), '') IS NOT NULL
                THEN 'doc:' || BTRIM(p.document_no)
            WHEN NULLIF(BTRIM(p.record_no), '') IS NOT NULL
                THEN 'record:' || BTRIM(p.record_no)
            ELSE
                'fallback:' || MD5(
                    CONCAT_WS(
                        '|',
                        p.employer_name,
                        p.region,
                        p.penalty_date_ad::TEXT,
                        p.law_articles,
                        p.violation_description
                    )
                )
        END AS case_key,

        COALESCE(
            (
                SELECT MAX(
                    CASE
                        -- 違法延長工作時間：勞基法第 32 條第 2 項
                        WHEN BTRIM(a.article)
                             LIKE '勞動基準法第32條第2項%'
                            THEN 20

                        -- 工資、加班費及工資給付相關
                        WHEN BTRIM(a.article)
                             LIKE '勞動基準法第22條%'
                          OR BTRIM(a.article)
                             LIKE '勞動基準法第24條%'
                          OR BTRIM(a.article)
                             LIKE '勞動基準法第39條%'
                            THEN 15

                        -- 例假、休息日、休假及特別休假相關
                        WHEN BTRIM(a.article)
                             LIKE '勞動基準法第36條%'
                          OR BTRIM(a.article)
                             LIKE '勞動基準法第37條%'
                          OR BTRIM(a.article)
                             LIKE '勞動基準法第38條%'
                            THEN 10

                        -- 出勤紀錄及工資清冊相關
                        WHEN BTRIM(a.article)
                             LIKE '勞動基準法第23條第2項%'
                          OR BTRIM(a.article)
                             LIKE '勞動基準法第30條第5項%'
                          OR BTRIM(a.article)
                             LIKE '勞動基準法第30條第6項%'
                            THEN 5

                        ELSE NULL
                    END
                )
                FROM REGEXP_SPLIT_TO_TABLE(
                    COALESCE(p.law_articles, ''),
                    '[;；、]'
                ) AS a(article)
            ),
            10
        ) AS severity_score

    FROM public.penalties_clean AS p
),

unique_cases AS (
    SELECT
        employer_name,
        region,
        case_key,
        MAX(document_no) AS document_no,
        MAX(penalty_date_ad) AS penalty_date,
        MAX(severity_score) AS severity_score,
        MAX(fine_value) AS fine_value
    FROM scored_rows
    GROUP BY
        employer_name,
        region,
        case_key
)

SELECT
    employer_name,
    region,
    document_no,
    penalty_date,
    severity_score,
    fine_value,

    CASE
        WHEN penalty_date >= CURRENT_DATE - INTERVAL '1 year'
            THEN 1.0
        WHEN penalty_date >= CURRENT_DATE - INTERVAL '3 years'
            THEN 0.7
        WHEN penalty_date >= CURRENT_DATE - INTERVAL '5 years'
            THEN 0.4
        ELSE 0.0
    END AS time_weight

FROM unique_cases;


-- 依企業名稱彙整近五年避雷指數
CREATE OR REPLACE VIEW public.company_risk_scores AS
SELECT
    employer_name,
    COUNT(*) AS violation_count,
    COALESCE(SUM(fine_value), 0) AS total_known_fine,
    COUNT(fine_value) AS cases_with_fine,
    COUNT(*) - COUNT(fine_value) AS cases_without_fine,
    MAX(penalty_date) AS latest_penalty_date,

    ROUND(
        LEAST(
            100::NUMERIC,
            SUM(severity_score * time_weight)
                + 5 * COUNT(*)
        ),
        1
    ) AS risk_score

FROM public.risk_case_scores
WHERE penalty_date >= CURRENT_DATE - INTERVAL '5 years'
  AND penalty_date <= CURRENT_DATE
GROUP BY employer_name;


-- 檢查避雷指數最高的前 20 筆企業名稱
SELECT
    employer_name,
    violation_count,
    total_known_fine,
    cases_with_fine,
    cases_without_fine,
    latest_penalty_date,
    risk_score,
    CASE
        WHEN risk_score >= 70 THEN '高'
        WHEN risk_score >= 40 THEN '中'
        ELSE '低'
    END AS risk_level
FROM public.company_risk_scores
ORDER BY risk_score DESC, violation_count DESC
LIMIT 20;
