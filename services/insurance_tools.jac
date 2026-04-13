"""Insurance Investigation Tools — real web search and scraping via Serper.dev API.

Tools:
  - search_google: Google web search
  - search_news: Google News search
  - search_scholar: Google Scholar search (medical/legal papers)
  - scrape_webpage: Fetch and extract text from a URL
"""

import os;
import requests;
import json;
import re;
import from pathlib { Path }

# ── Load Serper API key ───────────────────────────────────────────
def _load_serper_key() -> str {
    key = os.environ.get("SERPER_API_KEY", "");
    if key { return key; }
    env_path = Path(__file__).resolve().parent.parent / ".env";
    if env_path.exists() {
        for line in env_path.read_text().splitlines() {
            if line.startswith("SERPER_API_KEY=") {
                return line.split("=", 1)[1].strip();
            }
        }
    }
    return "";
}

glob SERPER_KEY: str = _load_serper_key();

# ── Privacy: strip personal info from search queries ──────────────
def _scrub_pii(query: str) -> str {
    import re as _re;
    scrubbed = query;
    # Remove email addresses
    scrubbed = _re.sub(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '', scrubbed);
    # Remove phone numbers
    scrubbed = _re.sub(r'[\(]?\d{3}[\)]?[-.\s]?\d{3}[-.\s]?\d{4}', '', scrubbed);
    # Remove SSN patterns
    scrubbed = _re.sub(r'\d{3}-\d{2}-\d{4}', '', scrubbed);
    # Remove dates of birth in common formats
    scrubbed = _re.sub(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', '', scrubbed);
    # Remove zip codes (5 or 9 digit)
    scrubbed = _re.sub(r'\b\d{5}(-\d{4})?\b', '', scrubbed);
    # Remove member ID patterns (alphanumeric 6+ chars)
    scrubbed = _re.sub(r'(?i)(member\s*id|member\s*#|id\s*#|policy\s*#|group\s*#|claim\s*#)\s*:?\s*[A-Z0-9-]{4,}', '', scrubbed);
    # Remove street addresses (number + street name)
    scrubbed = _re.sub(r'\d+\s+[A-Za-z]+\s+(Street|St|Avenue|Ave|Drive|Dr|Road|Rd|Boulevard|Blvd|Lane|Ln|Court|Ct|Way|Circle|Cir)\b', '', scrubbed, flags=_re.IGNORECASE);
    # Clean up extra whitespace
    scrubbed = _re.sub(r'\s+', ' ', scrubbed).strip();
    return scrubbed;
}

# ── Tool Registry ─────────────────────────────────────────────────
obj ToolRegistry {
    has tools: dict = {};
    has descriptions: dict = {};

    def list_tools() -> list {
        result: list = [];
        import inspect;
        for name in self.tools {
            func = self.tools[name];
            params: list = [];
            try {
                sig = inspect.signature(func);
                for pname in sig.parameters {
                    p = sig.parameters[pname];
                    params.append({
                        "name": pname,
                        "type": "str",
                        "required": p.default == inspect.Parameter.empty
                    });
                }
            } except Exception {
                0;
            }
            result.append({
                "name": name,
                "description": self.descriptions.get(name, ""),
                "params": params
            });
        }
        return result;
    }

    def keys() -> list {
        return list(self.tools.keys());
    }

    def call(name: str, args: dict) -> dict {
        if name not in self.tools {
            return {"error": "Unknown tool: " + name};
        }
        try {
            func = self.tools[name];
            return func(**args);
        } except Exception as e {
            return {"error": str(e)};
        }
    }

    def __contains__(name: str) -> bool {
        return name in self.tools;
    }

    def __getitem__(name: str) -> dict {
        return {
            "name": name,
            "description": self.descriptions.get(name, ""),
            "params": self.list_tools()[0]["params"] if self.tools else []
        };
    }
}

# ══════════════════════════════════════════════════════════════════
# Tool 1: search_google — Google web search via Serper.dev
# ══════════════════════════════════════════════════════════════════
def search_google(query: str, num_results: str = "10") -> dict {
    query = _scrub_pii(query);
    n = 10;
    try { n = int(num_results); }
    except Exception { n = 10; }
    if n > 20 { n = 20; }
    try {
        resp = requests.post(
            "https://google.serper.dev/search",
            headers={"X-API-KEY": SERPER_KEY, "Content-Type": "application/json"},
            json={"q": query, "num": n},
            timeout=15
        );
        if resp.status_code != 200 {
            return {"error": "Serper API returned status " + str(resp.status_code), "summary": "Google search failed."};
        }
        data = resp.json();
    } except Exception as e {
        return {"error": str(e), "summary": "Google search request failed: " + str(e)};
    }
    organic = data.get("organic", []);
    results: list = [];
    for i in range(min(len(organic), n)) {
        r = organic[i];
        results.append({
            "title": r.get("title", ""),
            "url": r.get("link", ""),
            "snippet": r.get("snippet", ""),
            "position": i + 1
        });
    }
    answer_box = data.get("answerBox", {});
    answer_text = "";
    if answer_box {
        answer_text = answer_box.get("answer", answer_box.get("snippet", ""));
    }
    kg = data.get("knowledgeGraph", {});
    kg_text = "";
    if kg {
        kg_text = kg.get("title", "") + ": " + kg.get("description", "");
    }
    lines: list = [];
    if answer_text { lines.append("ANSWER: " + answer_text); }
    if kg_text { lines.append("INFO: " + kg_text); }
    for r in results {
        if r["snippet"] { lines.append(r["title"] + " — " + r["snippet"]); }
    }
    summary = "Google search for '" + query[:60] + "': " + str(len(results)) + " results.\n" + "\n".join(lines[:8]);
    return {
        "data": {"query": query, "results": results, "answer_box": answer_text, "knowledge_graph": kg_text, "references": results},
        "summary": summary
    };
}

# ══════════════════════════════════════════════════════════════════
# Tool 2: search_news — Google News search via Serper.dev
# ══════════════════════════════════════════════════════════════════
def search_news(query: str, num_results: str = "10") -> dict {
    query = _scrub_pii(query);
    n = 10;
    try { n = int(num_results); }
    except Exception { n = 10; }
    if n > 20 { n = 20; }
    try {
        resp = requests.post(
            "https://google.serper.dev/news",
            headers={"X-API-KEY": SERPER_KEY, "Content-Type": "application/json"},
            json={"q": query, "num": n},
            timeout=15
        );
        if resp.status_code != 200 {
            return {"error": "Serper News API returned status " + str(resp.status_code), "summary": "News search failed."};
        }
        data = resp.json();
    } except Exception as e {
        return {"error": str(e), "summary": "News search request failed: " + str(e)};
    }
    news = data.get("news", []);
    results: list = [];
    for i in range(min(len(news), n)) {
        r = news[i];
        results.append({
            "title": r.get("title", ""),
            "url": r.get("link", ""),
            "snippet": r.get("snippet", ""),
            "source": r.get("source", ""),
            "date": r.get("date", ""),
            "position": i + 1
        });
    }
    lines: list = [];
    for r in results {
        src = r["source"];
        line = r["title"];
        if src { line = "[" + src + "] " + line; }
        if r["snippet"] { line = line + " — " + r["snippet"]; }
        lines.append(line);
    }
    summary = "News search for '" + query[:60] + "': " + str(len(results)) + " articles.\n" + "\n".join(lines[:8]);
    return {
        "data": {"query": query, "results": results, "references": results},
        "summary": summary
    };
}

# ══════════════════════════════════════════════════════════════════
# Tool 3: search_scholar — Google Scholar via Serper.dev
# ══════════════════════════════════════════════════════════════════
def search_scholar(query: str, num_results: str = "10") -> dict {
    query = _scrub_pii(query);
    n = 10;
    try { n = int(num_results); }
    except Exception { n = 10; }
    if n > 20 { n = 20; }
    try {
        resp = requests.post(
            "https://google.serper.dev/scholar",
            headers={"X-API-KEY": SERPER_KEY, "Content-Type": "application/json"},
            json={"q": query, "num": n},
            timeout=15
        );
        if resp.status_code != 200 {
            return {"error": "Serper Scholar API returned status " + str(resp.status_code), "summary": "Scholar search failed."};
        }
        data = resp.json();
    } except Exception as e {
        return {"error": str(e), "summary": "Scholar search request failed: " + str(e)};
    }
    organic = data.get("organic", []);
    results: list = [];
    for i in range(min(len(organic), n)) {
        r = organic[i];
        results.append({
            "title": r.get("title", ""),
            "url": r.get("link", ""),
            "snippet": r.get("snippet", ""),
            "year": r.get("year", ""),
            "cited_by": r.get("citedBy", {}).get("total", 0) if isinstance(r.get("citedBy"), dict) else r.get("citedBy", 0),
            "position": i + 1
        });
    }
    lines: list = [];
    for r in results {
        line = r["title"];
        if r["year"] { line = "(" + str(r["year"]) + ") " + line; }
        if r["snippet"] { line = line + " — " + r["snippet"]; }
        lines.append(line);
    }
    summary = "Scholar search for '" + query[:60] + "': " + str(len(results)) + " papers.\n" + "\n".join(lines[:8]);
    return {
        "data": {"query": query, "results": results, "references": results},
        "summary": summary
    };
}

# ══════════════════════════════════════════════════════════════════
# Tool 4: scrape_webpage — Fetch and extract text from a URL
# ══════════════════════════════════════════════════════════════════
def scrape_webpage(url: str) -> dict {
    try {
        resp = requests.get(
            url,
            headers={"User-Agent": "Mozilla/5.0 (compatible; InsurePro/1.0)"},
            timeout=15,
            allow_redirects=True
        );
        if resp.status_code != 200 {
            return {"error": "HTTP " + str(resp.status_code) + " fetching " + url, "summary": "Failed to fetch webpage."};
        }
    } except Exception as e {
        return {"error": str(e), "summary": "Webpage fetch failed: " + str(e)};
    }
    content_type = resp.headers.get("Content-Type", "").lower();
    # Handle PDF files — extract text with pypdf
    if "application/pdf" in content_type or url.lower().endswith(".pdf") {
        try {
            import io;
            import pypdf;
            reader = pypdf.PdfReader(io.BytesIO(resp.content));
            pages: list = [];
            for page in reader.pages {
                t = page.extract_text();
                if t { pages.append(t); }
            }
            text = "\n\n".join(pages);
            if len(text) > 8000 {
                text = text[:8000] + "... [truncated]";
            }
            summary = "Extracted text from PDF at " + url[:60] + ": " + str(len(text)) + " chars, " + str(len(reader.pages)) + " pages.\n" + text[:500];
            return {
                "data": {"url": url, "text": text, "char_count": len(text), "pages": len(reader.pages)},
                "summary": summary
            };
        } except Exception as e {
            return {"error": "PDF extraction failed: " + str(e), "summary": "Could not extract text from PDF at " + url[:60]};
        }
    }
    # Handle HTML — strip tags to get text
    html = resp.text;
    text = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL);
    text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL);
    text = re.sub(r'<[^>]+>', ' ', text);
    text = re.sub(r'\s+', ' ', text).strip();
    if len(text) > 8000 {
        text = text[:8000] + "... [truncated]";
    }
    summary = "Scraped " + url[:80] + ": " + str(len(text)) + " chars extracted.\n" + text[:500];
    return {
        "data": {"url": url, "text": text, "char_count": len(text)},
        "summary": summary
    };
}

# ── Build and populate registry ───────────────────────────────────
def _build_registry() -> ToolRegistry {
    r = ToolRegistry();
    r.tools["search_google"] = search_google;
    r.descriptions["search_google"] = "Search Google for any query. Use for policy info, regulations, appeal strategies, medical guidelines, billing codes, legal precedents. Params: query (str), num_results (str, default '10')";
    r.tools["search_news"] = search_news;
    r.descriptions["search_news"] = "Search Google News for recent articles. Use for recent regulatory changes, insurance industry news, similar denial cases in the news. Params: query (str), num_results (str, default '10')";
    r.tools["search_scholar"] = search_scholar;
    r.descriptions["search_scholar"] = "Search Google Scholar for academic/medical papers. Use for clinical guidelines, medical necessity evidence, peer-reviewed studies. Params: query (str), num_results (str, default '10')";
    r.tools["scrape_webpage"] = scrape_webpage;
    r.descriptions["scrape_webpage"] = "Fetch and extract text content from a URL. Use to read full articles, regulations, guidelines found via search. Params: url (str)";
    return r;
}

glob TOOL_REGISTRY: ToolRegistry = _build_registry();
