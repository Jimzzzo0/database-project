#include "crow.h"
#include <libpq-fe.h>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

static std::string read_file(const std::string& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return "";
    std::ostringstream s;
    s << f.rdbuf();
    return s.str();
}

static crow::response web_file(const std::string& path, const std::string& mime) {
    std::string content = read_file(path);
    if (content.empty()) return crow::response(404, "File not found. Start server from project root.");
    crow::response res(200, content);
    res.set_header("Content-Type", mime);
    return res;
}

static crow::response database_json(const std::string& sql, const std::string& input) {
    // libpq reads PGHOST, PGPORT, PGUSER and PGPASSWORD from environment.
    PGconn* db = PQconnectdb("dbname=worksafe connect_timeout=5");
    if (!db || PQstatus(db) != CONNECTION_OK) {
        std::cerr << "PostgreSQL connect error: " << (db ? PQerrorMessage(db) : "unknown") << '\n';
        if (db) PQfinish(db);
        crow::response r(503, "{\"error\":\"Cannot connect to worksafe database; check PGHOST, PGPORT, PGUSER, PGPASSWORD.\"}");
        r.set_header("Content-Type", "application/json; charset=utf-8");
        return r;
    }

    const char* params[] = {input.c_str()};
    PGresult* result = PQexecParams(db, sql.c_str(), 1, nullptr, params, nullptr, nullptr, 0);
    if (!result || PQresultStatus(result) != PGRES_TUPLES_OK) {
        std::cerr << "SQL error: " << PQerrorMessage(db) << '\n';
        if (result) PQclear(result);
        PQfinish(db);
        crow::response r(500, "{\"error\":\"SQL query failed; confirm company_risk_scores and penalties_clean exist.\"}");
        r.set_header("Content-Type", "application/json; charset=utf-8");
        return r;
    }
    const std::string json = PQntuples(result) > 0 && !PQgetisnull(result, 0, 0)
                                 ? PQgetvalue(result, 0, 0) : "[]";
    PQclear(result);
    PQfinish(db);
    crow::response r(200, json);
    r.set_header("Content-Type", "application/json; charset=utf-8");
    r.set_header("Cache-Control", "no-store");
    return r;
}

int main() {
    crow::SimpleApp app;

    CROW_ROUTE(app, "/")([] {
        return web_file("frontend/index.html", "text/html; charset=utf-8");
    });
    CROW_ROUTE(app, "/style.css")([] {
        return web_file("frontend/style.css", "text/css; charset=utf-8");
    });
    CROW_ROUTE(app, "/app.js")([] {
        return web_file("frontend/app.js", "text/javascript; charset=utf-8");
    });
    CROW_ROUTE(app, "/api/health")([] {
        crow::response r(200, "{\"status\":\"ok\"}");
        r.set_header("Content-Type", "application/json; charset=utf-8");
        return r;
    });

    CROW_ROUTE(app, "/api/companies")([](const crow::request& req) {
        const char* q = req.url_params.get("q");
        std::string search = q ? q : "";
        if (search.size() > 100) return crow::response(400, "Search is too long");
        const std::string sql = R"SQL(
          SELECT COALESCE(json_agg(row_to_json(x)), '[]'::json)::text
          FROM (
            SELECT employer_name, violation_count, risk_score,
                   total_known_fine, cases_without_fine, latest_penalty_date
            FROM public.company_risk_scores
            WHERE employer_name ILIKE '%' || $1 || '%'
            ORDER BY risk_score DESC, employer_name
            LIMIT 30
          ) x
        )SQL";
        return database_json(sql, search);
    });

    CROW_ROUTE(app, "/api/company")([](const crow::request& req) {
        const char* p = req.url_params.get("name");
        std::string name = p ? p : "";
        if (name.empty() || name.size() > 200) return crow::response(400, "Missing or overly long company name");
        const std::string sql = R"SQL(
          SELECT COALESCE(json_agg(row_to_json(x)), '[]'::json)::text
          FROM (
            SELECT law_articles, violation_description, fine_value,
                   penalty_date_ad, document_no
            FROM public.penalties_clean
            WHERE employer_name = $1
            ORDER BY penalty_date_ad DESC NULLS LAST
            LIMIT 100
          ) x
        )SQL";
        return database_json(sql, name);
    });

    std::cout << "WorkSafe: http://127.0.0.1:18080\n";
    app.bindaddr("127.0.0.1").port(18080).multithreaded().run();
}
