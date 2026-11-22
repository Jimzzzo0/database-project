// PostgreSQL 資料經由本機 C++ Crow API 取得；不在瀏覽器儲存資料庫密碼。
const input = document.getElementById("search");
const statusBox = document.getElementById("status");
const results = document.getElementById("results");
const detail = document.getElementById("detail");
const map = L.map("map").setView([25.034,121.55], 11);
L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png",{
  maxZoom:19,attribution:'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
}).addTo(map);

function textElement(tag, text, className) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  node.textContent = text;
  return node;
}
function money(value) {
  return value === null || value === undefined ? "未公布" : "NT$ " + Number(value).toLocaleString("zh-TW");
}
function scoreLabel(value) {
  const v = Number(value);
  return v >= 70 ? "高" : v >= 40 ? "中" : "低";
}
async function loadCompanies() {
  statusBox.textContent = "正在從 PostgreSQL 查詢…";
  results.replaceChildren();
  const keyword = input.value.trim();
  try {
    const res = await fetch(`/api/companies?q=${encodeURIComponent(keyword)}`);
    if (!res.ok) throw new Error(`API 回應 ${res.status}：${await res.text()}`);
    const items = await res.json();
    statusBox.textContent = `找到 ${items.length} 筆結果（最多顯示 30 筆）`;
    for (const company of items) {
      const btn = textElement("button", "", "company");
      btn.type = "button";
      btn.append(textElement("strong", company.employer_name));
      btn.append(textElement("small", `避雷指數 ${company.risk_score}｜${scoreLabel(company.risk_score)}｜裁罰案件 ${company.violation_count}｜已列罰鍰 ${money(company.total_known_fine)}｜未列金額案件 ${company.cases_without_fine}`));
      btn.addEventListener("click", () => loadDetails(company.employer_name));
      results.append(btn);
    }
  } catch (error) {
    statusBox.textContent = `連線失敗：${error.message}`;
  }
}
async function loadDetails(name) {
  detail.replaceChildren(textElement("h2", name), textElement("p", "正在載入裁罰明細…"));
  try {
    const res = await fetch(`/api/company?name=${encodeURIComponent(name)}`);
    if (!res.ok) throw new Error(`API 回應 ${res.status}`);
    const records = await res.json();
    detail.replaceChildren(textElement("h2", name), textElement("p", `查詢到 ${records.length} 筆原始紀錄（最多顯示 100 筆）`));
    for (const r of records) {
      const box = textElement("div", "", "record");
      box.append(textElement("p", `法條：${r.law_articles || "未填"}`));
      box.append(textElement("p", `原因：${r.violation_description || "未填"}`));
      box.append(textElement("p", `罰鍰：${money(r.fine_value)}`));
      box.append(textElement("p", `處分日期：${r.penalty_date_ad || "未填"}`));
      box.append(textElement("p", `處分字號：${r.document_no || "未填"}`));
      detail.append(box);
    }
  } catch(error) {
    detail.append(textElement("p", `明細查詢失敗：${error.message}`));
  }
}
document.getElementById("searchButton").addEventListener("click", loadCompanies);
input.addEventListener("keydown", event => { if(event.key === "Enter") loadCompanies(); });
loadCompanies();
