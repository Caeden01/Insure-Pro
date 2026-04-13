"""Investigation page — start and view insurance denial investigations."""

import from "@jac/runtime" { jacLogout, useNavigate, __doFuncFetch }

def:pub page() -> JsxElement {
    has phase: str = "input";
    has claim_desc: str = "";
    has goal: str = "";
    has loading: bool = False;
    has error: str = "";
    has elapsed: int = 0;
    has timer_id: any = None;
    has poll_id: any = None;
    has result: any = None;
    has auto_started: bool = False;
    has live_tree: list = [];
    has live_status: str = "";
    has live_tool_calls: int = 0;
    has live_llm_calls: int = 0;
    has live_categories: list = [];
    has live_artifacts: list = [];
    has selected_artifact: any = None;
    has auto_scroll: bool = True;
    has tree_view_mode: str = "list";
    has active_tab: str = "overview";
    has is_running: bool = False;
    has stop_requested: bool = False;
    has uploaded_files: list = [];
    has drag_over: bool = False;

    navigate = useNavigate();

    # Expose citation click handler on window
    window.__insurepro_open_cite = lambda aid: handle_citation_click(aid);

    # Global click listener for citation links
    def _setup_cite_listener() -> None {
        document.addEventListener("click", lambda e: None);
        document.addEventListener("click", lambda e: (
            e.target.classList.contains("citation-link") and
            e.target.getAttribute("data-aid") and
            handle_citation_click(e.target.getAttribute("data-aid"))
        ));
    }
    _setup_cite_listener();

    # Auto-start if extracted text was passed from dashboard
    if not auto_started and phase == "input" and not loading {
        auto_started = True;
        stored_text = window.sessionStorage.getItem("insure_pro_text");
        if stored_text {
            window.sessionStorage.removeItem("insure_pro_text");
            if stored_text.length > 10 {
                claim_desc = stored_text;
                run_investigation(stored_text);
            }
        }
    }

    def handle_logout() -> None {
        jacLogout();
        navigate("/login");
    }

    def on_claim_change(e: any) -> None { claim_desc = e.target.value; }
    def on_goal_change(e: any) -> None { goal = e.target.value; }
    def set_drag(val: bool) -> None { drag_over = val; }

    async def read_file_base64(file: any) -> str {
        reader = Reflect.construct(FileReader, []);
        return await Reflect.construct(Promise, [lambda resolve, reject: (
            reader.addEventListener("load", lambda: resolve(reader.result)),
            reader.addEventListener("error", lambda: reject("read error")),
            reader.readAsDataURL(file)
        )]);
    }

    def handle_file_select(e: any) -> None {
        files = e.target.files;
        new_files: list = [];
        for i in range(files.length) {
            new_files.append({"name": String(files[i].name), "file": files[i]});
        }
        uploaded_files = uploaded_files.concat(new_files);
    }

    def handle_file_drop(e: any) -> None {
        e.preventDefault();
        e.stopPropagation();
        drag_over = False;
        files = e.dataTransfer.files;
        new_files: list = [];
        for i in range(files.length) {
            new_files.append({"name": String(files[i].name), "file": files[i]});
        }
        uploaded_files = uploaded_files.concat(new_files);
    }

    def tick() -> None {
        st = window.__insurepro_start_time;
        if st and st > 0 {
            elapsed = Math.floor((Date.now() - st) / 1000);
        }
    }

    def open_artifact(art: any) -> None { selected_artifact = art; }
    def close_artifact() -> None { selected_artifact = None; }
    def toggle_auto_scroll() -> None { auto_scroll = not auto_scroll; }
    def set_tree_view(mode: str) -> None { tree_view_mode = mode; }
    def switch_tab(tab: str) -> None { active_tab = tab; }

    async def end_investigation() -> None {
        stop_requested = True;
        try { await __doFuncFetch("stop_investigation", {}); }
        except Exception as e { console.log("[STOP] Error:", e); }
    }

    def download_appeal_doc() -> None {
        if not result or not result["summary"] { return; }
        text = result["summary"];
        # Build Word-compatible HTML document (.doc)
        html_content = "<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'><head><meta charset='utf-8'/><title>Appeal Letter</title><style>body{font-family:'Times New Roman',serif;font-size:12pt;line-height:1.6;color:#000;margin:1in}h1{font-size:14pt;font-weight:bold;margin-bottom:0.5em}h2{font-size:13pt;font-weight:bold;margin-top:1.5em;margin-bottom:0.5em;border-bottom:1px solid #ccc;padding-bottom:4px}h3{font-size:12pt;font-weight:bold;margin-top:1em}p{margin:0.4em 0}blockquote{margin:0.5em 0 0.5em 1.5em;padding-left:0.5em;border-left:2px solid #999;font-style:italic}</style></head><body>";
        lines = text.split("\n");
        for line in lines {
            trimmed = line.trim();
            if trimmed.length == 0 { html_content = html_content + "<br/>"; }
            elif trimmed.startsWith("# ") { html_content = html_content + "<h1>" + trimmed.substring(2).trim() + "</h1>"; }
            elif trimmed.startsWith("## ") { html_content = html_content + "<h2>" + trimmed.substring(3).trim() + "</h2>"; }
            elif trimmed.startsWith("### ") { html_content = html_content + "<h3>" + trimmed.substring(4).trim() + "</h3>"; }
            elif trimmed.startsWith("**") and trimmed.endsWith("**") { html_content = html_content + "<h3>" + trimmed.split("**").join("") + "</h3>"; }
            elif trimmed.startsWith("> ") { html_content = html_content + "<blockquote>" + trimmed.substring(2) + "</blockquote>"; }
            else { html_content = html_content + "<p>" + trimmed + "</p>"; }
        }
        html_content = html_content + "</body></html>";
        # Use Reflect.construct to create Blob (Jac doesn't support 'new' keyword)
        blob = Reflect.construct(Blob, [[html_content], {"type": "application/msword"}]);
        data_uri = URL.createObjectURL(blob);
        a = document.createElement("a");
        a.href = data_uri;
        a.download = "Appeal_Letter.doc";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    def handle_citation_click(aid: str) -> None {
        arts = window.__insurepro_artifacts or [];
        for i in range(len(arts)) {
            if arts[i]["id"] == aid {
                open_artifact(arts[i]);
                return;
            }
        }
    }

    def render_formatted_text(text: str) -> str {
        html = text;
        html = html.split("&").join("&amp;");
        html = html.split("<").join("&lt;");
        html = html.split(">").join("&gt;");
        # Render markdown bold **text**
        while html.indexOf("**") >= 0 {
            first = html.indexOf("**");
            second = html.indexOf("**", first + 2);
            if second < 0 { break; }
            before = html.substring(0, first);
            bold_text = html.substring(first + 2, second);
            after = html.substring(second + 2);
            html = before + "<strong>" + bold_text + "</strong>" + after;
        }
        # Render markdown headers
        lines = html.split("\n");
        rendered: list = [];
        for line in lines {
            trimmed = line.trim();
            if trimmed.startsWith("### ") { rendered.append("<h4 style='margin:0.8em 0 0.3em;font-size:1em'>" + trimmed.substring(4) + "</h4>"); }
            elif trimmed.startsWith("## ") { rendered.append("<h3 style='margin:1em 0 0.4em;font-size:1.05em;border-bottom:1px solid #333;padding-bottom:4px'>" + trimmed.substring(3) + "</h3>"); }
            elif trimmed.startsWith("# ") { rendered.append("<h2 style='margin:1em 0 0.4em;font-size:1.1em'>" + trimmed.substring(2) + "</h2>"); }
            elif trimmed.length == 0 { rendered.append("<br/>"); }
            else { rendered.append(trimmed + "<br/>"); }
        }
        return rendered.join("");
    }

    def find_active_node_idx(tree: list) -> int {
        last_active = -1;
        for i in range(len(tree)) {
            if tree[i]["status"] == "active" { last_active = i; }
        }
        return last_active;
    }

    def format_timestamp(ts: any) -> str {
        if not ts { return "N/A"; }
        try {
            s = String(ts);
            if s.indexOf("T") >= 0 { return s.substring(0, 10); }
            if s.length > 16 and isNaN(Number(s)) { return s.substring(0, 16); }
        } except Exception { 0; }
        return String(ts);
    }

    def get_tool_description(status: str) -> str {
        if not status { return "Analyzing insurance documents..."; }
        tool = String(status).toLowerCase();
        if tool.startsWith("tool: ") { tool = tool.substring(6).trim(); }
        descs = {
            "search_google": "Searching Google...",
            "search_news": "Searching news articles...",
            "search_scholar": "Searching medical literature...",
            "scrape_webpage": "Reading webpage content..."
        };
        if descs[tool] { return descs[tool]; }
        if tool == "generating report" { return "Writing the appeal letter..."; }
        if tool == "bootstrapping" { return "Setting up the investigation..."; }
        if tool == "investigating" { return "Investigating the denial..."; }
        if tool == "starting..." { return "Starting up..."; }
        return "Researching...";
    }

    def get_funny_phrase(status: str) -> str {
        if not status { return "Putting on the reading glasses..."; }
        tool = String(status).toLowerCase();
        if tool.startsWith("tool: ") { tool = tool.substring(6).trim(); }
        phrases = {
            "search_google": ["Googling the fine print...", "What does the internet say?", "Following the evidence trail...", "Searching for answers..."],
            "search_news": ["Checking the headlines...", "What's in the news?", "Finding recent coverage...", "Reading the latest..."],
            "search_scholar": ["Consulting the experts...", "What does the research say?", "Digging into the literature...", "Science is on your side..."],
            "scrape_webpage": ["Reading the full article...", "Extracting the details...", "Getting the whole story...", "Diving deeper..."]
        };
        if phrases[tool] {
            arr = phrases[tool];
            idx = Math.floor(Math.random() * len(arr));
            return arr[idx];
        }
        if tool == "generating report" { return "Drafting your appeal letter..."; }
        if tool == "bootstrapping" { return "Preparing the case file..."; }
        if tool == "investigating" { return "Building your case..."; }
        if tool == "starting..." { return "Putting on the reading glasses..."; }
        return "Working on your appeal...";
    }

    def get_tool_name_from_status(status: str) -> str {
        if not status { return ""; }
        tool = String(status);
        if tool.toLowerCase().startsWith("tool: ") { return tool.substring(6).trim(); }
        return tool;
    }

    def get_stable_funny_phrase(status: str) -> str {
        now = Date.now();
        tool_key = get_tool_name_from_status(status);
        prev_tool = window.__ip_phrase_tool or "";
        prev_time = window.__ip_phrase_time or 0;
        prev_phrase = window.__ip_phrase or "";
        if tool_key != prev_tool {
            phrase = get_funny_phrase(status);
            window.__ip_phrase = phrase;
            window.__ip_phrase_tool = tool_key;
            window.__ip_phrase_time = now;
            return phrase;
        }
        if prev_phrase and (now - prev_time) < 3000 {
            return prev_phrase;
        }
        phrase = get_funny_phrase(status);
        window.__ip_phrase = phrase;
        window.__ip_phrase_time = now;
        return phrase;
    }

    def extract_live_references(artifacts: list) -> list {
        refs: list = [];
        seen_titles: list = [];
        for i in range(len(artifacts)) {
            art = artifacts[i];
            cat = String(art["category"] or "");
            tool = String(art["tool"] or "");
            if cat == "legal" or cat == "precedent" or tool.toLowerCase().indexOf("regulation") >= 0 or tool.toLowerCase().indexOf("precedent") >= 0 or tool.toLowerCase().indexOf("appeal") >= 0 {
                data = art["data"];
                if not data { continue; }
                sources: list = [];
                if data["references"] and Array.isArray(data["references"]) { sources = data["references"]; }
                if data["cases"] and Array.isArray(data["cases"]) { sources = sources.concat(data["cases"]); }
                for j in range(len(sources)) {
                    a = sources[j];
                    title = String(a["title"] or a["name"] or "");
                    if title and title.length > 0 and seen_titles.indexOf(title) < 0 {
                        seen_titles.append(title);
                        refs.append({
                            "title": title,
                            "url": String(a["url"] or a["link"] or ""),
                            "source": String(a["source"] or a["jurisdiction"] or ""),
                            "date": String(a["date"] or a["year"] or ""),
                            "description": String(a["description"] or a["summary"] or "")
                        });
                    }
                }
            }
        }
        return refs;
    }


    async def poll_progress() -> None {
        try {
            prog = await __doFuncFetch("get_investigation_progress", {});
            if prog {
                if prog["tree"] { live_tree = prog["tree"]; }
                live_status = prog["status"] or "";
                live_tool_calls = prog["total_tool_calls"] or 0;
                live_llm_calls = prog["total_llm_calls"] or 0;
                if prog["categories"] { live_categories = prog["categories"]; }
                if prog["artifacts"] {
                    live_artifacts = prog["artifacts"];
                    window.__insurepro_artifacts = prog["artifacts"];
                }
                if auto_scroll and active_tab == "tree" {
                    scroll_el = document.getElementById("tree-scroll-container");
                    if scroll_el { scroll_el.scrollTop = scroll_el.scrollHeight; }
                }
                if prog["status"] == "complete" and prog["result"] {
                    if timer_id { clearInterval(timer_id); }
                    if poll_id { clearInterval(poll_id); }
                    result = prog["result"];
                    window.__insurepro_artifacts = prog["result"]["artifacts"] or [];
                    loading = False;
                    is_running = False;
                }
                if prog["status"] and prog["status"].startsWith("error") {
                    if timer_id { clearInterval(timer_id); }
                    if poll_id { clearInterval(poll_id); }
                    error = prog["status"];
                    loading = False;
                    is_running = False;
                    phase = "input";
                }
            }
        } except Exception as e { console.log("[POLL ERROR]", e); }
    }

    async def run_investigation(override_desc: str = "") -> None {
        actual_desc = override_desc if override_desc else claim_desc;
        phase = "active";
        active_tab = "overview";
        loading = True;
        is_running = True;
        error = "";
        elapsed = 0;
        result = None;
        window.__insurepro_start_time = Date.now();
        live_tree = [];
        live_status = "starting...";
        live_tool_calls = 0;
        live_llm_calls = 0;
        live_categories = [];
        live_artifacts = [];

        timer_id = setInterval(tick, 500);
        poll_id = setInterval(poll_progress, 2000);

        try {
            inv_goal = goal;
            if not inv_goal {
                inv_goal = "Investigate this insurance claim denial. Analyze the denial reasons, review policy terms, check medical necessity, research applicable regulations, find appeal precedents, and draft a comprehensive appeal strategy.";
            }
            # Load user profile from localStorage and prepend to claim text
            profile_json = window.localStorage.getItem("insure_pro_profile");
            if profile_json {
                try {
                    p = JSON.parse(profile_json);
                    profile_text = "PATIENT INFORMATION:\n";
                    profile_text = profile_text + "Full Name: " + (p["full_name"] or "") + "\n";
                    profile_text = profile_text + "Date of Birth: " + (p["dob"] or "") + "\n";
                    profile_text = profile_text + "Address: " + (p["address"] or "") + ", " + (p["city"] or "") + ", " + (p["state"] or "") + " " + (p["zip_code"] or "") + "\n";
                    profile_text = profile_text + "Phone: " + (p["phone"] or "") + "\n";
                    profile_text = profile_text + "Email: " + (p["email"] or "") + "\n";
                    profile_text = profile_text + "Insurance Company: " + (p["insurance_company"] or "") + "\n";
                    profile_text = profile_text + "Member ID: " + (p["member_id"] or "") + "\n";
                    profile_text = profile_text + "Plan Type: " + (p["plan_type"] or "") + "\n";
                    profile_text = profile_text + "Group Number: " + (p["group_number"] or "") + "\n\n";
                    actual_desc = profile_text + actual_desc;
                } except Exception { 0; }
            }
            now_ts = str(Math.floor(Date.now() / 1000));
            await __doFuncFetch("start_investigation", {
                "market_id": actual_desc,
                "event_timestamp": now_ts,
                "goal": inv_goal
            });
        } except Exception as ex {
            msg = str(ex);
            if "UNAUTHORIZED" in msg { jacLogout(); navigate("/login"); }
            else { console.log("[INFO] start_investigation returned:", msg); }
        }
        loading = False;
    }

    async def handle_start(e: any) -> None {
        e.preventDefault();
        loading = True;
        error = "";
        all_text: list = [];
        # Extract text from all uploaded files via backend
        if uploaded_files and len(uploaded_files) > 0 {
            for i in range(len(uploaded_files)) {
                uf = uploaded_files[i];
                try {
                    base64_data = await read_file_base64(uf["file"]);
                    res = await __doFuncFetch("analyze_document", {
                        "document_data": base64_data,
                        "filename": uf["name"]
                    });
                    if res and res["text"] and res["text"].length > 10 {
                        all_text.append("=== " + uf["name"] + " ===\n" + res["text"]);
                    }
                } except Exception as ex {
                    console.log("File read error:", uf["name"], ex);
                }
            }
        }
        # Combine file text with any manual description
        file_content = "\n\n".join(all_text);
        if file_content and file_content.length > 0 {
            if claim_desc and claim_desc.length > 0 { claim_desc = file_content + "\n\n" + claim_desc; }
            else { claim_desc = file_content; }
        }
        if not claim_desc or claim_desc.length < 5 {
            error = "Please upload documents or describe the insurance denial.";
            loading = False;
            return;
        }
        run_investigation(claim_desc);
    }

    def handle_new() -> None {
        phase = "input";
        result = None;
        error = "";
        uploaded_files = [];
        stop_requested = False;
        claim_desc = "";
        goal = "";
        elapsed = 0;
        is_running = False;
        auto_started = False;
        navigate("/dashboard");
    }

    can with exit {
        if timer_id { clearInterval(timer_id); }
    }

    # ── Helper: render graph-based investigation tree ──
    def render_graph_tree(tree: list) -> JsxElement {
        if not tree or len(tree) == 0 {
            return <p className="text-muted-foreground text-sm">{"No tree data available."}</p>;
        }
        n = len(tree);
        node_h = 56;
        node_w = 320;
        gap_y = 20;
        indent_x = 32;
        base_x = 40;
        svg_w = 700;
        svg_h = n * (node_h + gap_y) + 40;
        elements: list = [];
        for i in range(n) {
            nd = tree[i];
            depth = nd["depth"] or 0;
            cat = nd["category"] or "default";
            x_offset = base_x + depth * indent_x;
            y_pos = 20 + i * (node_h + gap_y);
            if i > 0 {
                prev_depth = tree[i - 1]["depth"] or 0;
                prev_x = base_x + prev_depth * indent_x;
                prev_y_bottom = 20 + (i - 1) * (node_h + gap_y) + node_h;
                conn_x1 = prev_x;
                conn_y1 = prev_y_bottom;
                conn_x2 = x_offset;
                conn_y2 = y_pos + node_h / 2;
                elements.append(
                    <path key={"conn" + str(i)}
                          d={"M" + str(conn_x1) + "," + str(conn_y1) + " L" + str(conn_x1) + "," + str(conn_y2) + " L" + str(conn_x2) + "," + str(conn_y2)}
                          fill="none" stroke="#3a3a3a" strokeWidth="2" />
                );
            }
            colors = {"research": "#3b82f6", "news": "#f59e0b", "medical": "#22c55e", "scrape": "#a855f7", "default": "#6b6b6b"};
            c = colors[cat] if cat in colors else "#6b6b6b";
            is_active = nd["status"] == "active";
            elements.append(
                <g key={"node" + str(i)}>
                    <rect x={str(x_offset)} y={str(y_pos)} width={str(node_w)} height={str(node_h)}
                          rx="8" fill="#141414" stroke={c} strokeWidth={is_active and "2.5" or "1.5"} opacity="0.95" />
                    <circle cx={str(x_offset + 16)} cy={str(y_pos + node_h / 2)} r="5" fill={c} />
                    <text x={str(x_offset + 28)} y={str(y_pos + 20)} fill="#f5f0e8" fontSize="11" fontWeight="600">
                        {str(nd["hypothesis"] or nd["tool"] or "Node " + str(i))[:40]}
                    </text>
                    <text x={str(x_offset + 28)} y={str(y_pos + 38)} fill="#6b6b6b" fontSize="9" fontFamily="monospace">
                        {str(nd["tool"] or "") + "  D" + str(depth)}
                    </text>
                    <text x={str(x_offset + node_w - 10)} y={str(y_pos + 20)} fill={c} fontSize="9" textAnchor="end" fontWeight="700">
                        {str(nd["status"] or "")}
                    </text>
                </g>
            );
        }
        return (
            <div className="graph-tree-container">
                <svg viewBox={"0 0 " + str(svg_w) + " " + str(svg_h)} className="graph-tree-svg" style={{"width": "100%", "height": str(svg_h) + "px"}}>
                    {elements}
                </svg>
            </div>
        );
    }

    # Derive display data: use result when available, live data during run
    disp_tree = result["tree"] if result and result["tree"] else live_tree;
    disp_artifacts = result["artifacts"] if result and result["artifacts"] else live_artifacts;
    disp_tool_calls = result["total_tool_calls"] if result else live_tool_calls;
    disp_llm_calls = result["total_llm_calls"] if result else live_llm_calls;
    disp_categories = result["categories"] if result and result["categories"] else live_categories;

    # ---- INPUT PHASE ----
    if phase == "input" {
        return (
            <div className="page">
                <div className="page-container">
                    <div className="page-header">
                        <div>
                            <h1>InsurePro Investigation</h1>
                            <p className="text-sm text-muted-foreground">
                                {"Analyze insurance claim denials with AI-powered Tree of Thought reasoning"}
                            </p>
                        </div>
                        <button className="btn btn-ghost" onClick={handle_logout}>{"Sign out"}</button>
                    </div>
                    <div className="card investigation-form-card">
                        <h2>Start Denial Investigation</h2>
                        <p className="text-sm text-muted-foreground mb-2">
                            {"Upload your denial documents or paste the denial letter text to begin."}
                        </p>
                        <div className={"upload-zone" + (drag_over and " upload-zone-active" or "")} style={{"marginBottom": "1rem", "padding": "1.5rem"}}
                             onDragOver={lambda e: (e.preventDefault(), e.stopPropagation(), set_drag(True))}
                             onDragLeave={lambda e: (e.preventDefault(), e.stopPropagation(), set_drag(False))}
                             onDrop={handle_file_drop}>
                            <div className="upload-zone-content">
                                <div className="upload-icon" style={{"width": "40px", "height": "40px", "fontSize": "1.5rem"}}>{"+"}</div>
                                <h3 className="upload-title" style={{"fontSize": "0.9rem"}}>Upload Denial Letter, EOB, or Plan Documents</h3>
                                <p className="upload-formats">{"PDF, text, and image files supported"}</p>
                                <label className="btn btn-primary" style={{"fontSize": "0.8rem", "padding": "0.4rem 1rem", "marginTop": "0.5rem"}}>
                                    {"Browse Files"}
                                    <input type="file" multiple={True} accept=".pdf,.png,.jpg,.jpeg,.doc,.docx,.txt"
                                           onChange={handle_file_select} style={{"display": "none"}} />
                                </label>
                            </div>
                        </div>
                        {uploaded_files and len(uploaded_files) > 0 and (
                            <div style={{"marginBottom": "1rem"}}>
                                {[
                                    <div key={str(fidx)} className="doc-item" style={{"marginBottom": "4px"}}>
                                        <div className="doc-item-left">
                                            <span className="doc-icon doc-icon-pdf">{"PDF" if String(uploaded_files[fidx]["name"]).toLowerCase().endsWith(".pdf") else "DOC"}</span>
                                            <span className="doc-name">{str(uploaded_files[fidx]["name"])}</span>
                                        </div>
                                    </div>
                                    for fidx in range(len(uploaded_files))
                                ]}
                            </div>
                        )}
                        <form onSubmit={handle_start} className="investigation-form">
                            <div>
                                <label className="label">Additional Details (optional)</label>
                                <textarea className="investigation-textarea" value={claim_desc} onChange={on_claim_change}
                                          placeholder="Add any extra context about your denial (optional — the AI will extract everything it needs from your uploaded documents)"
                                          disabled={loading} style={{"minHeight": "4rem"}} />
                            </div>
                            <button className="btn btn-primary w-full h-12 mt-1" type="submit" disabled={loading or (not claim_desc and (not uploaded_files or len(uploaded_files) == 0))}>
                                {loading and "Extracting documents..." or "Start Investigation"}
                            </button>
                        </form>
                        {error and (<div className="error-box mt-3">{error}</div>)}
                    </div>
                </div>
            </div>
        );
    }

    # ---- ACTIVE PHASE (running + results, with persistent tabs) ----
    return (
        <div className="page">
            <div className="page-container investigation-results-container">
                <div className="inv-header">
                    <div className="inv-header-left">
                        <h1 className="inv-title">{"Insurance Denial Investigation"}</h1>
                        <div className="inv-header-stats">
                            {is_running and (
                                <span className="inv-status-badge inv-status-running">
                                    <span className="inv-status-dot" />
                                    {str(elapsed) + "s | " + get_tool_description(live_status)}
                                </span>
                            )}
                            {not is_running and result and (
                                <span className="inv-status-badge inv-status-complete">{"Complete"}</span>
                            )}
                            <span className="inv-stat-pill">{str(disp_tool_calls) + " tools"}</span>
                            <span className="inv-stat-pill">{str(disp_llm_calls) + " LLM"}</span>
                            {result and result["confidence"] and (
                                <span className={"inv-confidence-badge inv-confidence-" + str(result["confidence"] or "").toLowerCase()}>
                                    {str(result["confidence"] or "")}
                                </span>
                            )}
                        </div>
                    </div>
                    <div className="inv-header-right">
                        {is_running and not stop_requested and (
                            <button className="btn inv-stop-btn" onClick={end_investigation}>{"Stop Investigation"}</button>
                        )}
                        {is_running and stop_requested and (
                            <button className="btn inv-stop-btn" disabled={True} style={{"opacity": "0.6", "cursor": "not-allowed"}}>{"Stopping..."}</button>
                        )}
                        <button className="btn btn-ghost" onClick={handle_new}>{"Back"}</button>
                    </div>
                </div>

                <div className="inv-tab-bar">
                    <button className={"inv-tab" + (" inv-tab-active" if active_tab == "overview" else "")} onClick={lambda: switch_tab("overview")}>{"Overview"}</button>
                    <button className={"inv-tab" + (" inv-tab-active" if active_tab == "summary" else "")} onClick={lambda: switch_tab("summary")}>{"Summary"}</button>
                    <button className={"inv-tab" + (" inv-tab-active" if active_tab == "report" else "")} onClick={lambda: switch_tab("report")}>{"Appeal Letter"}</button>
                    <button className={"inv-tab" + (" inv-tab-active" if active_tab == "evidence" else "")} onClick={lambda: switch_tab("evidence")}>
                        {"Evidence" + (" (" + str(len(disp_artifacts)) + ")" if len(disp_artifacts) > 0 else "")}
                    </button>
                    <button className={"inv-tab" + (" inv-tab-active" if active_tab == "tree" else "")} onClick={lambda: switch_tab("tree")}>
                        {"Tree" + (" (" + str(len(disp_tree)) + ")" if len(disp_tree) > 0 else "")}
                    </button>
                </div>

                {active_tab == "overview" and (
                    <div className="inv-tab-panel">
                        <div className="overview-stats-row">
                            <div className="results-stat-card">
                                <div className="results-stat-label">Tool Calls</div>
                                <div className="results-stat-value">{str(disp_tool_calls)}</div>
                            </div>
                            <div className="results-stat-card">
                                <div className="results-stat-label">LLM Calls</div>
                                <div className="results-stat-value">{str(disp_llm_calls)}</div>
                            </div>
                            <div className="results-stat-card">
                                <div className="results-stat-label">Evidence</div>
                                <div className="results-stat-value">{str(len(disp_artifacts))}</div>
                            </div>
                            <div className="results-stat-card">
                                <div className="results-stat-label">Categories</div>
                                <div className="results-stat-value">{str(len(disp_categories))}</div>
                            </div>
                            <div className="results-stat-card">
                                <div className="results-stat-label">Nodes</div>
                                <div className="results-stat-value">{str(len(disp_tree))}</div>
                            </div>
                            <div className="results-stat-card">
                                <div className="results-stat-label">Duration</div>
                                <div className="results-stat-value">{str(result["elapsed"] or 0) + "s" if result else str(elapsed) + "s"}</div>
                            </div>
                        </div>

                        {is_running and (
                            <div className="card p-4 mb-4" style={{"textAlign": "center"}}>
                                <div className="loading-spinner" style={{"margin": "0 auto 0.5rem"}} />
                                <p className="text-sm" style={{"color": "var(--color-primary)"}}>{get_stable_funny_phrase(live_status)}</p>
                                <p className="text-xs text-muted-foreground" style={{"marginTop": "0.25rem", "fontFamily": "monospace"}}>
                                    {get_tool_name_from_status(live_status)}
                                </p>
                            </div>
                        )}

                        <div className="overview-two-col">
                            <div className="card overview-section-card">
                                <h3 className="overview-section-title">Appeal Strength</h3>
                                <div className="overview-confidence-display">
                                    <span className={"overview-confidence-level overview-confidence-" + str(result["confidence"] or "").toLowerCase() if result else "overview-confidence-level"}>
                                        {str(result["confidence"] or "Analyzing...") if result else "Analyzing..."}
                                    </span>
                                </div>
                                <div className="overview-confidence-details">
                                    <div className="overview-detail-row">
                                        <span className="overview-detail-label">Evidence Collected</span>
                                        <span className="overview-detail-value">{str(len(disp_artifacts))}</span>
                                    </div>
                                    <div className="overview-detail-row">
                                        <span className="overview-detail-label">Categories Covered</span>
                                        <span className="overview-detail-value">{str(len(disp_categories))}</span>
                                    </div>
                                    <div className="overview-detail-row">
                                        <span className="overview-detail-label">Analysis Depth</span>
                                        <span className="overview-detail-value">{str(disp_tree[len(disp_tree) - 1]["depth"] or 0) if len(disp_tree) > 0 else "0"}</span>
                                    </div>
                                    {disp_categories and len(disp_categories) > 0 and (
                                        <div className="overview-detail-row">
                                            <span className="overview-detail-label">Categories</span>
                                            <span className="overview-detail-value text-xs">{", ".join(disp_categories)}</span>
                                        </div>
                                    )}
                                </div>
                            </div>
                            <div className="card overview-section-card">
                                <h3 className="overview-section-title">Investigation Steps</h3>
                                {len(disp_tree) > 0 and (
                                    <div className="overview-steps-list">
                                        {[
                                            <div key={str(sidx)} className="overview-step-item">
                                                <span className={"overview-step-dot overview-step-" + str(disp_tree[sidx]["status"] or "closed")} />
                                                <div className="overview-step-content">
                                                    <span className="overview-step-text">{str(disp_tree[sidx]["hypothesis"] or disp_tree[sidx]["tool"] or "Step " + str(sidx + 1))}</span>
                                                    {disp_tree[sidx]["tool"] and (
                                                        <span className="overview-step-tool">{str(disp_tree[sidx]["tool"])}</span>
                                                    )}
                                                </div>
                                            </div>
                                            for sidx in range(len(disp_tree))
                                        ]}
                                    </div>
                                )}
                                {len(disp_tree) == 0 and (
                                    <p className="text-sm text-muted-foreground">{"Steps will appear as the investigation runs..."}</p>
                                )}
                            </div>
                        </div>
                    </div>
                )}

                {active_tab == "summary" and (
                    <div className="inv-tab-panel">
                        {result and result["user_summary"] and (
                            <div className="card investigation-summary-card">
                                <h2>{"What We Found"}</h2>
                                <div className="report-text text-sm text-foreground" style={{"lineHeight": "1.8"}} dangerouslySetInnerHTML={{"__html": render_formatted_text(str(result["user_summary"] or ""))}} />
                            </div>
                        )}
                        {(not result or not result["user_summary"]) and (
                            <div className="card p-6 mb-4" style={{"textAlign": "center"}}>
                                {is_running and (<div className="loading-spinner" style={{"margin": "0 auto 0.75rem"}} />)}
                                <p className="text-muted-foreground text-sm">{is_running and "Summary will appear when the investigation completes..." or "No summary available yet."}</p>
                            </div>
                        )}
                    </div>
                )}

                {active_tab == "report" and (
                    <div className="inv-tab-panel">
                        {result and result["summary"] and (
                            <div className="card investigation-summary-card">
                                <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "1rem"}}>
                                    <h2 style={{"margin": "0"}}>{"Appeal Letter"}</h2>
                                    <button className="btn btn-primary" onClick={download_appeal_doc} style={{"fontSize": "0.8rem", "padding": "0.4rem 1rem"}}>
                                        {"Download as .doc"}
                                    </button>
                                </div>
                                <div className="report-text text-sm text-foreground" dangerouslySetInnerHTML={{"__html": render_formatted_text(str(result["summary"] or ""))}} />
                            </div>
                        )}
                        {(not result or not result["summary"]) and (
                            <div className="card p-6 mb-4" style={{"textAlign": "center"}}>
                                {is_running and (<div className="loading-spinner" style={{"margin": "0 auto 0.75rem"}} />)}
                                <p className="text-muted-foreground text-sm">{is_running and "Appeal letter will appear when the investigation completes..." or "No appeal letter available yet."}</p>
                            </div>
                        )}
                    </div>
                )}

                {active_tab == "evidence" and (
                    <div className="inv-tab-panel">
                        {len(disp_artifacts) > 0 and (
                            <div className="card p-6 mb-4">
                                <h2 className="text-base font-semibold text-primary mb-3">{"Evidence Collected (" + str(len(disp_artifacts)) + " artifacts)"}</h2>
                                <div className="artifact-list">
                                    {[
                                        <div key={str(aidx)} className={"artifact-item artifact-cat-" + (disp_artifacts[aidx]["category"] or "default")} onClick={lambda: open_artifact(disp_artifacts[aidx])}>
                                            <span className="artifact-id">{str(disp_artifacts[aidx]["id"] or "")}</span>
                                            <span className="artifact-tool">{str(disp_artifacts[aidx]["tool"] or "")}</span>
                                            <span className="artifact-summary">{str(disp_artifacts[aidx]["summary"] or "")[:120]}</span>
                                        </div>
                                        for aidx in range(len(disp_artifacts))
                                    ]}
                                </div>
                            </div>
                        )}
                        {len(disp_artifacts) == 0 and (
                            <div className="card p-6 mb-4" style={{"textAlign": "center"}}>
                                {is_running and (<div className="loading-spinner" style={{"margin": "0 auto 0.75rem"}} />)}
                                <p className="text-muted-foreground text-sm">{is_running and "Evidence is being collected..." or "No evidence available."}</p>
                            </div>
                        )}
                    </div>
                )}

                {active_tab == "tree" and (
                    <div className="inv-tab-panel">
                        {len(disp_tree) > 0 and (
                            <div className="card p-6 mb-4">
                                <div className="tree-header-row">
                                    <h2 className="text-base font-semibold text-primary">{"Investigation Tree \u2014 " + str(len(disp_tree)) + " nodes"}</h2>
                                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.75rem"}}>
                                        {is_running and (
                                            <label className="tree-autoscroll-toggle">
                                                <input type="checkbox" checked={auto_scroll} onChange={toggle_auto_scroll} />
                                                <span className="text-xs text-muted-foreground">{"Auto-scroll"}</span>
                                            </label>
                                        )}
                                        <div className="tree-view-toggle">
                                            <button className={"tree-toggle-btn" + (" tree-toggle-active" if tree_view_mode == "list" else "")} onClick={lambda: set_tree_view("list")}>{"List"}</button>
                                            <button className={"tree-toggle-btn" + (" tree-toggle-active" if tree_view_mode == "graph" else "")} onClick={lambda: set_tree_view("graph")}>{"Graph"}</button>
                                        </div>
                                    </div>
                                </div>
                                <div className="tree-legend" style={{"marginTop": "0.75rem"}}>
                                    <span className="tree-legend-dot tree-badge-research" /><span className="tree-legend-label">Google Search</span>
                                    <span className="tree-legend-dot tree-badge-news" /><span className="tree-legend-label">News</span>
                                    <span className="tree-legend-dot tree-badge-medical" /><span className="tree-legend-label">Scholar</span>
                                    <span className="tree-legend-dot tree-badge-scrape" /><span className="tree-legend-label">Web Scrape</span>
                                </div>
                                {tree_view_mode == "list" and (
                                    <div className="tree-viz-list" id="tree-scroll-container">
                                        {[
                                            <div key={str(idx)}
                                                 className={"tree-node-card" + (" tree-active" if disp_tree[idx]["status"] == "active" and idx == find_active_node_idx(disp_tree) else " tree-closed") + " tree-border-" + (disp_tree[idx]["category"] or "default")}
                                                 style={{"marginLeft": str((disp_tree[idx]["depth"] or 0) * 24) + "px"}}>
                                                <div className="tree-node-title">
                                                    {disp_tree[idx]["status"] == "active" and idx == find_active_node_idx(disp_tree) and (
                                                        <span className="tree-active-dot" />
                                                    )}
                                                    {disp_tree[idx]["hypothesis"] or ("Root: " + str(disp_tree[idx]["tool"] or "Initializing...")) if disp_tree[idx]["depth"] == 0 else (disp_tree[idx]["hypothesis"] or str(disp_tree[idx]["tool"] or "..."))}
                                                </div>
                                                <div className="tree-node-meta">
                                                    {disp_tree[idx]["tool"] and (
                                                        <span className={"tree-tool-badge tree-badge-" + (disp_tree[idx]["category"] or "default")}>{str(disp_tree[idx]["tool"] or "")}</span>
                                                    )}
                                                    <span className="tree-depth-badge">{"D" + str(disp_tree[idx]["depth"] or 0)}</span>
                                                    {disp_tree[idx]["status"] == "active" and idx == find_active_node_idx(disp_tree) and (
                                                        <span className="tree-tool-badge" style={{"background": "rgba(239,68,68,0.3)", "color": "#f87171"}}>ACTIVE</span>
                                                    )}
                                                </div>
                                                {disp_tree[idx]["question"] and (
                                                    <div className="tree-section">
                                                        <div className="tree-section-label">{is_running and disp_tree[idx]["status"] == "active" and "Unanswered Question" or "Question Investigated"}</div>
                                                        <div className="tree-section-text">{str(disp_tree[idx]["question"] or "")}</div>
                                                    </div>
                                                )}
                                                {disp_tree[idx]["result"] and (
                                                    <div className="tree-node-result">{str(disp_tree[idx]["result"] or "")}</div>
                                                )}
                                            </div>
                                            for idx in range(len(disp_tree))
                                        ]}
                                    </div>
                                )}
                                {tree_view_mode == "graph" and (
                                    render_graph_tree(disp_tree)
                                )}
                            </div>
                        )}
                        {len(disp_tree) == 0 and (
                            <div className="card p-6 mb-4" style={{"textAlign": "center"}}>
                                {is_running and (<div className="loading-spinner" style={{"margin": "0 auto 0.75rem"}} />)}
                                <p className="text-muted-foreground text-sm">{is_running and "Building investigation tree..." or "No tree data available."}</p>
                            </div>
                        )}
                    </div>
                )}

                {selected_artifact and (
                    <div className="artifact-modal-overlay" onClick={close_artifact}>
                        <div className="artifact-modal" onClick={lambda e: e.stopPropagation()}>
                            <div className="artifact-modal-header">
                                <h3>{str(selected_artifact["tool"] or "Artifact")}</h3>
                                <button className="btn btn-ghost" onClick={close_artifact}>{"X"}</button>
                            </div>
                            <div className="artifact-modal-summary">
                                <div className="tree-section-label">Summary</div>
                                {str(selected_artifact["summary"] or "")}
                            </div>
                            <div className="artifact-modal-data">
                                <div className="tree-section-label">Full Data</div>
                                <pre className="whitespace-pre-wrap text-xs">{JSON.stringify(selected_artifact["data"], null, 2) if selected_artifact["data"] else "Data not available."}</pre>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
