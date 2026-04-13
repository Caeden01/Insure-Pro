"""Investigation Engine V2 — Tree of Thought with DFS + Backtracking.
Uses recursive DFS with by deepseek_llm() for LLM calls.
Tools from insurance_tools.jac (25 insurance denial analysis tools).
State tracked via plain dicts (no graph nodes needed).
"""
import os;
import sys;
import time as _time;
import json;
import from pathlib { Path }
def _log(msg: str) {
    print(msg);
    sys.stdout.flush();
    try {
        with open("investigation_debug.log", "a") as f {
            f.write(msg + "\n");
        }
    } except Exception {
        0;
    }
}
import from byllm.lib { Model }
import from services.insurance_tools {
    ToolRegistry, TOOL_REGISTRY,
    search_google, scrape_webpage
}
# ── DeepSeek LLM setup ─────────────────────────────────────────
def _load_secret(key_name: str) -> str {
    token = os.environ.get(key_name, "");
    if token {
        return token;
    }
    env_path = Path(__file__).resolve().parent.parent / ".env";
    if env_path.exists() {
        for line in env_path.read_text().splitlines() {
            if line.startswith(key_name + "=") {
                return line.split("=", 1)[1].strip();
            }
        }
    }
    return "";
}
glob DEEPSEEK_KEY: str = _load_secret("DEEPSEEK_API_KEY");
glob deepseek_llm = Model(
    model_name="deepseek/deepseek-chat",
    api_key=DEEPSEEK_KEY
);
# ── Constants ───────────────────────────────────────────────────
glob MAX_DEPTH: int = 6;
glob MAX_CHILDREN: int = 6;
glob MAX_TOOL_CALLS: int = 30;
glob MIN_ROOT_TOOLS: int = 6;
glob MIN_ROOT_CATEGORIES: int = 3;
glob TOOL_CATEGORIES: dict = {
    "search_google": "research",
    "search_news": "news",
    "search_scholar": "medical",
    "scrape_webpage": "scrape"
};
# ── LLM return types ───────────────────────────────────────────
obj PlanResult {
    has tool_name: str = "";
    has tool_args: dict[str, str] = {};
    has child_hypothesis: str = "";
    has child_question: str = "";
    has child_notes: str = "";
    has data_visible_to_ai: bool = False;
}
obj EvalResult {
    has should_close: bool = False;
    has conclusion: str = "";
    has reasoning: str = "";
}
# ── LLM-powered decision functions (return str, we parse JSON) ──
def _plan_first_step_llm(
    investigation_goal: str,
    initial_artifacts_summary: str,
    available_tools_with_descriptions: str,
    respond_with_json_containing_tool_name_tool_args_child_hypothesis_child_question_child_notes_data_visible_to_ai: str = "Return ONLY valid JSON with keys: tool_name, tool_args, child_hypothesis, child_question, child_notes, data_visible_to_ai. PRIVACY RULE: NEVER include patient names, addresses, phone numbers, emails, dates of birth, member IDs, SSNs, or any personally identifiable information in search queries. Only search for general medical, legal, and regulatory topics."
) -> str by deepseek_llm();
def _evaluate_node_llm(
    investigation_goal: str,
    artifacts_summary: str,
    node_hypothesis: str,
    node_question: str,
    node_notes: str,
    conclusions_from_closed_children: str,
    respond_with_json_containing_should_close_conclusion_reasoning: str = "Return ONLY valid JSON with keys: should_close (bool), conclusion (string), reasoning (string). IMPORTANT: Be VERY reluctant to close. Only close if the question has been THOROUGHLY answered with evidence from multiple tool categories (research, news, medical, scrape). Prioritize finding: 1) specific state/federal regulations that apply, 2) policy fine print and contractual obligations, 3) legal precedents and case law, 4) clinical guidelines from medical authorities. If you have only used 1-2 categories, set should_close to false and suggest exploring other categories."
) -> str by deepseek_llm();
def _plan_next_step_llm(
    investigation_goal: str,
    artifacts_summary: str,
    current_hypothesis: str,
    current_question: str,
    current_notes: str,
    conclusions_from_closed_children: str,
    tools_already_used_at_this_node: str,
    available_tools_with_descriptions: str,
    respond_with_json_containing_tool_name_tool_args_child_hypothesis_child_question_child_notes_data_visible_to_ai: str = "Return ONLY valid JSON with keys: tool_name, tool_args, child_hypothesis, child_question, child_notes, data_visible_to_ai. PRIVACY RULE: NEVER include patient names, addresses, phone numbers, emails, dates of birth, member IDs, SSNs, or any personally identifiable information in search queries. Only search for general medical, legal, and regulatory topics."
) -> str by deepseek_llm();
def _summarize_llm(
    investigation_goal: str,
    original_claim_documents: str,
    all_conclusions_from_tree: str,
    tool_categories_used: str,
    evidence_ledger_with_ids: str = "",
    report_format_instructions: str = "You must produce TWO sections separated by ===SECTION_BREAK===\n\nSECTION 1 - APPEAL LETTER: Write a formal, professional insurance denial appeal letter in proper business letter format. The original_claim_documents contains PATIENT INFORMATION at the top — use the patient's real name, address, phone, email, insurance company, member ID, etc. DO NOT use placeholder brackets like [Your Name]. Fill in every field with the actual patient data provided. Requirements:\n- Start with the patient's real name, address, city/state/zip, phone, email, and today's date\n- Address it to their actual insurance company (from the patient info)\n- RE line with their real name, member ID, and claim number (from documents if available)\n- Body: Clear, professional legal arguments for why the denial should be overturned. This should be DETAILED and THOROUGH — at least 4-6 paragraphs covering policy violations, medical necessity, regulatory requirements, and legal arguments.\n- DO NOT use [A1], [A2] style citations. Refer to sources naturally in the body.\n- Include specific regulations (ERISA, ACA, state insurance codes) by name\n- Include medical necessity arguments referencing clinical guidelines by name\n- End with a firm request to reverse the denial and a deadline reminder\n- Close with Sincerely, followed by the patient's real name\n\nWORKS CITED SECTION:\nAfter the letter body, include a WORKS CITED section in APA format. Cite the most relevant and impactful sources that directly support the appeal arguments — aim for 5-10 strong citations. For each, include:\n1. Author/Organization. (Year). *Title*. URL\n2. A brief quote or paraphrase (1-2 sentences) explaining how this source supports the appeal\n\nPrioritize: federal/state regulations, clinical guidelines, legal precedents, and authoritative medical sources. Skip generic or low-value results.\n\n===SECTION_BREAK===\n\nSECTION 2 - INVESTIGATION SUMMARY: Write a detailed, friendly summary for the patient explaining what you found. Address them by their first name. NO JSON, NO technical jargon. Use plain language. Include:\n- What the denial was about and why it was likely wrong\n- ALL the strongest arguments found in their favor (explain each one in simple terms)\n- Every regulation or law found that protects them (explain what each means for their case)\n- What medical evidence and clinical guidelines support their case\n- A list of all sources found and what each one says (in plain language)\n- Recommended next steps (file appeal, contact state insurance commissioner, request external review, etc.) with specific instructions\n- How strong their case appears to be and what to expect\n- Timeline and deadlines they should be aware of\nBe encouraging but honest. Be THOROUGH — this should be at least 5-8 paragraphs."
) -> str by deepseek_llm();
def _parse_json(text: str) -> dict {
    # Extract JSON from LLM response (may be wrapped in ```json blocks)
    cleaned = text.strip();
    if "```json" in cleaned {
        start = cleaned.index("```json") + 7;
        end = cleaned.index("```", start);
        cleaned = cleaned[start:end].strip();
    } elif "```" in cleaned {
        start = cleaned.index("```") + 3;
        end = cleaned.index("```", start);
        cleaned = cleaned[start:end].strip();
    }
    try {
        return json.loads(cleaned);
    } except Exception {
        return {};
    }
}
def plan_first_step(goal: str, artifacts: str, tools: str) -> PlanResult {
    raw = _plan_first_step_llm(goal, artifacts, tools);
    _log("[JSON] plan_first_step raw: " + raw[:200]);
    d = _parse_json(raw);
    _log("[JSON] parsed: " + str(d)[:200]);
    return PlanResult(
        tool_name=d.get("tool_name", ""),
        tool_args=d.get("tool_args", {}),
        child_hypothesis=d.get("child_hypothesis", ""),
        child_question=d.get("child_question", ""),
        child_notes=d.get("child_notes", ""),
        data_visible_to_ai=d.get("data_visible_to_ai", False)
    );
}
def evaluate_node(goal: str, artifacts: str, hypothesis: str, question: str, notes: str, conclusions: str) -> EvalResult {
    raw = _evaluate_node_llm(goal, artifacts, hypothesis, question, notes, conclusions);
    _log("[JSON] evaluate raw: " + raw[:200]);
    d = _parse_json(raw);
    return EvalResult(
        should_close=d.get("should_close", False),
        conclusion=d.get("conclusion", ""),
        reasoning=d.get("reasoning", "")
    );
}
def plan_next_step(goal: str, artifacts: str, hypothesis: str, question: str, notes: str, conclusions: str, used: str, tools: str) -> PlanResult {
    raw = _plan_next_step_llm(goal, artifacts, hypothesis, question, notes, conclusions, used, tools);
    _log("[JSON] plan_next raw: " + raw[:200]);
    d = _parse_json(raw);
    return PlanResult(
        tool_name=d.get("tool_name", ""),
        tool_args=d.get("tool_args", {}),
        child_hypothesis=d.get("child_hypothesis", ""),
        child_question=d.get("child_question", ""),
        child_notes=d.get("child_notes", ""),
        data_visible_to_ai=d.get("data_visible_to_ai", False)
    );
}
def summarize_investigation(goal: str, claim_documents: str, conclusions: str, categories: str, evidence: str = "") -> str {
    return _summarize_llm(goal, claim_documents, conclusions, categories, evidence);
}
# ── Helper functions ────────────────────────────────────────────
def _format_artifacts(artifacts: list) -> str {
    if not artifacts {
        return "No evidence collected yet.";
    }
    parts: list = [];
    for a in artifacts {
        if isinstance(a, dict) {
            line = "- [" + str(a.get("tool", "?")) + "] " + str(a.get("summary", ""))[:300];
            if a.get("data_visible_to_ai") and a.get("data") {
                line = line + "\n  Data: " + str(a["data"])[:500];
            }
            parts.append(line);
        } else {
            parts.append("- " + str(a)[:200]);
        }
    }
    return "\n".join(parts);
}
def _format_tools(tools: ToolRegistry) -> str {
    tools_list = tools.list_tools();
    parts: list = [];
    for t in tools_list {
        param_strs: list = [];
        for p in t.get("params", []) {
            req = " (required)" if p.get("required") else "";
            param_strs.append(p["name"] + ": " + p.get("type", "str") + req);
        }
        parts.append("- " + t["name"] + ": " + t["description"] + "\n  Params: " + ", ".join(param_strs));
    }
    return "\n".join(parts);
}
# ── Shared investigation state ──────────────────────────────────
# ── Live progress (global, polled by frontend) ─────────────────

glob PROGRESS_FILE: str = "investigation_progress.json";

def _write_progress(data: dict) {
    try {
        tmp = PROGRESS_FILE + ".tmp";
        with open(tmp, "w") as f {
            json.dump(data, f);
        }
        os.replace(tmp, PROGRESS_FILE);
    } except Exception {
        0;
    }
}

def _read_progress() -> dict {
    try {
        with open(PROGRESS_FILE, "r") as f {
            return json.load(f);
        }
    } except Exception {
        return {"running": False, "tree": [], "total_tool_calls": 0, "total_llm_calls": 0, "categories": [], "status": "idle"};
    }
}

glob _live_progress: dict = {
    "running": False,
    "tree": [],
    "total_tool_calls": 0,
    "total_llm_calls": 0,
    "categories": [],
    "status": "idle"
};

glob STOP_FILE: str = "investigation_stop.flag";

def:priv get_investigation_progress() -> dict {
    return _read_progress();
}

def:priv stop_investigation() -> dict {
    try {
        with open(STOP_FILE, "w") as f {
            f.write("stop");
        }
    } except Exception {
        0;
    }
    return {"stopped": True};
}

def _should_stop() -> bool {
    try {
        with open(STOP_FILE, "r") as f {
            return True;
        }
    } except Exception {
        return False;
    }
}


obj InvestigationContext {
    has goal: str = "";
    has market_id: str = "";
    has event_timestamp: str = "";
    has tools: ToolRegistry = ToolRegistry();
    has total_tool_calls: int = 0;
    has total_llm_calls: int = 0;
    has categories_used: list = [];
    has all_conclusions: list = [];
    has tree_nodes: list = [];
    has all_artifacts: list = [];
}
# ── Recursive DFS investigation ────────────────────────────────
def _investigate_node(
    ctx: InvestigationContext,
    depth: int,
    is_root: bool,
    hypothesis: str,
    question: str,
    notes: str,
    artifacts: list,
    conclusions: list,
    parent_id: str = "",
    incoming_tool: str = "",
    incoming_result: str = "",
    incoming_category: str = ""
) -> list {
    # Returns updated conclusions list
    pad = "  " * depth;
    node_id = "root" if is_root else "d" + str(depth) + "_" + str(ctx.total_tool_calls);
    # Track this node in the tree
    tree_node = {
        "id": node_id,
        "parent": parent_id,
        "depth": depth,
        "hypothesis": hypothesis[:150] if hypothesis else "",
        "question": question[:150] if question else "",
        "tool": incoming_tool,
        "result": incoming_result,
        "status": "active",
        "category": incoming_category,
        "children": []
    };
    ctx.tree_nodes.append(tree_node);
    _log(pad + "[ENTER " + node_id + " depth=" + str(depth) + "]");
    edges_used: list = [];
    child_count = 0;
    is_open = True;
    iterations = 0;
    max_iterations = 15;
    while is_open {
        iterations += 1;
        if iterations > max_iterations {
            conclusions.append("Max iterations per node reached.");
            
_log(pad + "  [MAX ITER]");
            break;
        }
        # Stop check
        if _should_stop() {
            conclusions.append("Investigation stopped by user.");
            _log(pad + "  [STOPPED BY USER]");
            break;
        }
        # Budget check
        if ctx.total_tool_calls >= MAX_TOOL_CALLS {
            conclusions.append("Budget exhausted (" + str(MAX_TOOL_CALLS) + " tool calls).");
            _log(pad + "  [BUDGET]");
            break;
        }
        # STEP 2: Root first iteration — plan first step
        if is_root and child_count == 0 {
            ctx.total_llm_calls += 1;
            tools_desc = _format_tools(ctx.tools);
            artifacts_str = _format_artifacts(artifacts);
            
_log(pad + "  [LLM] plan_first_step...");
            plan = plan_first_step(ctx.goal, artifacts_str, tools_desc);
            
_log(pad + "  [PLAN] tool=" + plan.tool_name);
        } else {
            # STEP 4: Evaluate node
            ctx.total_llm_calls += 1;
            artifacts_str = _format_artifacts(artifacts);
            conclusions_str = "\n".join(conclusions) if conclusions else "No conclusions yet.";
            
_log(pad + "  [LLM] evaluate_node...");
            eval_result = evaluate_node(
                ctx.goal, artifacts_str, hypothesis,
                question, notes, conclusions_str
            );
            # STEP 6: Close and backtrack
            if eval_result.should_close {
                # Block premature root closure
                if is_root and (ctx.total_tool_calls < MIN_ROOT_TOOLS or len(ctx.categories_used) < MIN_ROOT_CATEGORIES) {
                    missing_cats = [c for c in ["research", "news", "medical", "scrape"] if c not in ctx.categories_used];
                    
_log(pad + "  [ROOT CLOSE BLOCKED] " + str(ctx.total_tool_calls) + " tools, " + str(len(ctx.categories_used)) + " cats. Need: " + str(MIN_ROOT_TOOLS) + " tools, " + str(MIN_ROOT_CATEGORIES) + " cats. Missing: " + ", ".join(missing_cats));
                    notes = notes + "\nYou must investigate more before closing. Categories not yet explored: " + ", ".join(missing_cats) + ". Use tools from those categories.";
                } else {
                    if eval_result.conclusion {
                        conclusions.append(eval_result.conclusion);
                    }
                    
_log(pad + "  [CLOSED] " + eval_result.reasoning[:80]);
                    break;
                }
            }
            # Max depth
            if depth >= MAX_DEPTH {
                conclusions.append("Max depth reached.");
                
_log(pad + "  [MAX DEPTH]");
                break;
            }
            # Max children
            if child_count >= MAX_CHILDREN {
                conclusions.append("Max children reached.");
                
_log(pad + "  [MAX CHILDREN]");
                break;
            }
            # STEP 5/8: Plan next step
            ctx.total_llm_calls += 1;
            used_str = ", ".join(edges_used) if edges_used else "None";
            tools_desc = _format_tools(ctx.tools);
            # Inject priority guidance for unexplored categories
            missing_cats = [c for c in ["research", "news", "medical", "scrape"] if c not in ctx.categories_used];
            priority_notes = notes;
            if missing_cats {
                priority_notes = priority_notes + "\nPRIORITY: You have not yet explored these categories: " + ", ".join(missing_cats) + ". Choose a tool from an unexplored category to broaden the investigation.";
            }
            
_log(pad + "  [LLM] plan_next_step...");
            plan = plan_next_step(
                ctx.goal, artifacts_str, hypothesis,
                question, priority_notes, conclusions_str,
                used_str, tools_desc
            );
            
_log(pad + "  [PLAN] tool=" + plan.tool_name);
        }
        # ── Execute tool ──
        tool_name = plan.tool_name;
        tool_args = plan.tool_args if plan.tool_args else {};
        # Error: invalid tool
        if tool_name not in TOOL_REGISTRY {
            
_log(pad + "  [ERROR] Invalid tool: " + tool_name);
            notes = notes + "\nError: tool '" + tool_name + "' does not exist. Valid: " + ", ".join(list(TOOL_REGISTRY.keys()));
            continue;
        }
        # Error: duplicate
        call_key = tool_name + "(" + json.dumps(tool_args, sort_keys=True) + ")";
        if call_key in edges_used {
            
_log(pad + "  [DUPLICATE] " + call_key[:60]);
            notes = notes + "\nError: already called " + tool_name + " with these args.";
            continue;
        }
        # Filter args to only valid params and inject context
        import inspect as _inspect;
        _func = TOOL_REGISTRY.tools.get(tool_name);
        if _func {
            try {
                _sig = _inspect.signature(_func);
                _valid_params = list(_sig.parameters.keys());
                _filtered = {};
                for _k in tool_args {
                    if _k in _valid_params {
                        _filtered[_k] = tool_args[_k];
                    }
                }
                tool_args = _filtered;
            } except Exception {
                0;
            }
        }
        # Execute via the populated global registry

_log(pad + "  [TOOL] " + tool_name + " args=" + str(list(tool_args.keys())));
        result = TOOL_REGISTRY.call(tool_name, tool_args);
        ctx.total_tool_calls += 1;
        edges_used.append(call_key);
        # Track category
        cat = TOOL_CATEGORIES.get(tool_name, "other");
        if cat not in ctx.categories_used {
            ctx.categories_used.append(cat);
        }
        # Update live progress
        _live_progress["total_tool_calls"] = ctx.total_tool_calls;
        _live_progress["total_llm_calls"] = ctx.total_llm_calls;
        _live_progress["categories"] = list(ctx.categories_used);
        _live_progress["tree"] = list(ctx.tree_nodes);
        _live_progress["status"] = "tool: " + tool_name;
        # Artifact summaries for live viewer (no raw data — too large for JSON file)
        _live_progress["artifacts"] = [{"id": a["id"], "tool": a["tool"], "category": a["category"], "summary": a["summary"], "data": a["data"]} for a in ctx.all_artifacts];
        _write_progress(_live_progress);
        # Error: tool failed
        if "error" in result {
            
_log(pad + "  [TOOL ERROR] " + str(result["error"])[:80]);
            notes = notes + "\nTool " + tool_name + " failed: " + str(result["error"])[:200];
            continue;
        }
        summary = result.get("summary", "");
        
_log(pad + "  [RESULT] " + summary[:80]);
        # Build artifact
        artifact = {
            "tool": tool_name,
            "summary": summary,
            "data": result.get("data") if plan.data_visible_to_ai else None,
            "data_visible_to_ai": plan.data_visible_to_ai
        };
        # Collect artifact with full data for viewer
        ctx.all_artifacts.append({
            "id": "A" + str(len(ctx.all_artifacts) + 1),
            "tool": tool_name,
            "category": cat,
            "summary": summary,
            "data": result.get("data"),
            "node_id": node_id,
            "depth": depth
        });
        # STEP 3: Create child — recurse (DFS)
        # Tool info goes on the CHILD node (incoming edge)
        child_conclusions: list = [];
        child_conclusions = _investigate_node(
            ctx=ctx,
            depth=depth + 1,
            is_root=False,
            hypothesis=plan.child_hypothesis if plan.child_hypothesis else "",
            question=plan.child_question if plan.child_question else "",
            notes=plan.child_notes if plan.child_notes else "",
            artifacts=artifacts + [artifact],
            conclusions=child_conclusions,
            parent_id=node_id,
            incoming_tool=tool_name,
            incoming_result=summary[:150],
            incoming_category=cat
        );
        child_count += 1;
        # Record child in tree
        tree_node["children"].append("d" + str(depth + 1) + "_" + str(ctx.total_tool_calls - 1));
        # STEP 7: Backtrack — add child conclusions to this node
        for c in child_conclusions {
            conclusions.append("[child] " + c);
            ctx.all_conclusions.append(c);
        }
        
_log(pad + "  [BACKTRACK] " + str(len(child_conclusions)) + " conclusions from child");
    }
    tree_node["status"] = "closed";
    return conclusions;
}
# ── Background runner ───────────────────────────────────────────

import threading;

def _run_investigation_bg(market_id: str, event_timestamp: str, goal: str) {
    try {
        _log("\n" + "=" * 60);
        _log("  InsurePro Investigation Engine V2");
        _log("  Claim: " + market_id);
        _log("  Timestamp: " + event_timestamp);
        _log("=" * 60);
        # Bootstrap — do a GENERIC search (NO personal info in queries)
        init_result = search_google("insurance claim denial appeal process rights regulations");
        _log("[INIT] Search: " + init_result.get("summary", "N/A")[:80]);
        _live_progress["status"] = "investigating";
        _write_progress(_live_progress);
        bootstrap = [
            {"tool": "claim_documents", "summary": "Original claim documents and patient info (kept private, not sent to search engines): " + market_id[:300], "data": {"claim_text": market_id}, "data_visible_to_ai": True},
            {"tool": "search_google", "summary": init_result.get("summary", ""), "data": init_result.get("data"), "data_visible_to_ai": True},
        ];
        # Create context — use the populated global TOOL_REGISTRY
        ctx = InvestigationContext(
            goal=goal, market_id=market_id, event_timestamp=event_timestamp,
            tools=TOOL_REGISTRY
        );
        # Add bootstrap artifacts (including original docs) to the evidence ledger
        for b in bootstrap {
            ctx.all_artifacts.append({
                "id": "A" + str(len(ctx.all_artifacts) + 1),
                "tool": b.get("tool", "bootstrap"),
                "category": "research",
                "summary": b.get("summary", "")[:500],
                "data": b.get("data"),
                "node_id": "bootstrap",
                "depth": 0
            });
        }
        start = _time.monotonic();
        # Run recursive DFS
        root_conclusions: list = [];
        root_conclusions = _investigate_node(
            ctx=ctx, depth=0, is_root=True,
            hypothesis="", question="", notes="",
            artifacts=bootstrap, conclusions=root_conclusions
        );
        elapsed = _time.monotonic() - start;
        # Generate final summary
        _log("\n[REPORT] Generating final summary...");
        _live_progress["status"] = "generating report";
        _write_progress(_live_progress);
        all_conclusions_str = "\n".join(ctx.all_conclusions) if ctx.all_conclusions else "No conclusions reached.";
        categories_str = ", ".join(sorted(ctx.categories_used));
        # Build evidence ledger for LLM citations
        evidence_lines: list = [];
        for a in ctx.all_artifacts {
            evidence_lines.append("[" + a["id"] + "] " + a["tool"] + " (" + a["category"] + "): " + a["summary"][:500]);
        }
        evidence_ledger_str = "\n".join(evidence_lines) if evidence_lines else "No evidence collected.";
        raw_output = summarize_investigation(goal, market_id, all_conclusions_str, categories_str, evidence_ledger_str);
        # Split into appeal letter and user summary
        if "===SECTION_BREAK===" in raw_output {
            parts = raw_output.split("===SECTION_BREAK===", 1);
            appeal_letter = parts[0].strip();
            user_summary = parts[1].strip();
        } else {
            appeal_letter = raw_output;
            user_summary = "Investigation complete. See the appeal letter for full details.";
        }
        final_text = appeal_letter;
        # Write log
        try {
            log_lines = [
                "=" * 60, "INVESTIGATION LOG",
                "Market: " + market_id, "Timestamp: " + event_timestamp,
                "Goal: " + goal, "Elapsed: " + str(round(elapsed, 1)) + "s",
                "Tool Calls: " + str(ctx.total_tool_calls),
                "LLM Calls: " + str(ctx.total_llm_calls),
                "Categories: " + categories_str, "=" * 60, "",
                "CONCLUSIONS:",
            ];
            for c in ctx.all_conclusions {
                log_lines.append("  - " + c);
            }
            log_lines.append("");
            log_lines.append("FINAL REPORT:");
            log_lines.append(final_text);
            with open("investigation.log", "w") as f {
                f.write("\n".join(log_lines));
            }
        } except Exception as e {
            _log("[LOG] Failed: " + str(e));
        }
        _log("INVESTIGATION COMPLETE — " + str(round(elapsed, 1)) + "s, " + str(ctx.total_tool_calls) + " tools");
        # Collect legal/medical references from artifacts
        references: list = [];
        seen_ref_titles: set = set();
        for a in ctx.all_artifacts {
            cat = a.get("category", "");
            if cat in ["legal", "precedent"] and a.get("data") {
                adata = a["data"];
                if isinstance(adata, dict) {
                    for key in ["references", "cases", "guidance_documents", "studies_found"] {
                        refs = adata.get(key, []);
                        if isinstance(refs, list) {
                            for ref in refs {
                                if isinstance(ref, dict) {
                                    title = ref.get("title", ref.get("name", ""));
                                    if title and title.lower() not in seen_ref_titles {
                                        seen_ref_titles.add(title.lower());
                                        references.append({
                                            "title": title,
                                            "source": ref.get("source", ref.get("jurisdiction", "")),
                                            "date": ref.get("date", ref.get("year", "")),
                                            "url": ref.get("url", ref.get("link", "")),
                                            "description": ref.get("description", ref.get("summary", ""))
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        # Store final result in progress
        _live_progress["result"] = {
            "summary": final_text,
            "user_summary": user_summary,
            "market_id": market_id,
            "claim_title": market_id[:100],
            "event_timestamp": event_timestamp,
            "total_tool_calls": ctx.total_tool_calls,
            "total_llm_calls": ctx.total_llm_calls,
            "evidence_count": len(ctx.all_conclusions),
            "confidence": "HIGH" if len(ctx.categories_used) >= 4 else ("MEDIUM" if len(ctx.categories_used) >= 3 else "LOW"),
            "categories": sorted(ctx.categories_used),
            "elapsed": round(elapsed, 1),
            "tree": list(ctx.tree_nodes),
            "artifacts": list(ctx.all_artifacts)
        };
        _live_progress["running"] = False;
        _live_progress["status"] = "complete";
        _live_progress["tree"] = list(ctx.tree_nodes);
        _live_progress["artifacts"] = [{"id": a["id"], "tool": a["tool"], "category": a["category"], "summary": a["summary"][:200], "data": a["data"]} for a in ctx.all_artifacts];
        _write_progress(_live_progress);
        # Save completed investigation to history
        _save_investigation(_live_progress["result"]);
    } except Exception as e {
        _log("[ERROR] Investigation failed: " + str(e));
        _live_progress["running"] = False;
        _live_progress["status"] = "error: " + str(e)[:100];
        _write_progress(_live_progress);
    }
}


# ���─ Investigation History ──────────────────────────────────────
glob HISTORY_DIR: str = "investigation_history";

def _ensure_history_dir() {
    try {
        os.makedirs(HISTORY_DIR, exist_ok=True);
    } except Exception {
        0;
    }
}

def _save_investigation(result: dict) {
    _ensure_history_dir();
    try {
        market_id = result.get("market_id", "unknown");
        ts = str(int(_time.time()));
        filename = market_id.replace("/", "_").replace(" ", "_")[:50] + "_" + ts + ".json";
        filepath = os.path.join(HISTORY_DIR, filename);
        with open(filepath, "w") as f {
            json.dump(result, f);
        }
        _log("[HISTORY] Saved: " + filepath);
    } except Exception as e {
        _log("[HISTORY] Save failed: " + str(e));
    }
}

# ── Service functions ───────────────────────────────────────────

def:priv start_investigation(market_id: str, event_timestamp: str, goal: str = "") -> dict {
    if not goal {
        goal = "Investigate this insurance claim denial thoroughly. Focus heavily on: 1) Finding specific state and federal regulations (ERISA, ACA, state insurance codes) that the insurer may be violating, 2) Searching for legal precedents and case law where similar denials were overturned, 3) Finding the fine print in policy terms and contractual obligations the insurer must follow, 4) Researching clinical guidelines from medical authorities (AMA, specialty societies) supporting medical necessity, 5) Identifying any procedural violations in how the denial was handled. Use search_google and scrape_webpage to read full legal articles and regulatory texts. Use search_scholar for peer-reviewed medical evidence.";
    }
    # Reset progress
    _live_progress["running"] = True;
    _live_progress["tree"] = [];
    _live_progress["total_tool_calls"] = 0;
    _live_progress["total_llm_calls"] = 0;
    _live_progress["categories"] = [];
    _live_progress["status"] = "bootstrapping";
    _live_progress["result"] = None;
    _write_progress(_live_progress);
    # Clear stop flag
    try {
        import os as _os2;
        _os2.remove(STOP_FILE);
    } except Exception {
        0;
    }
    # Launch in background thread
    t = threading.Thread(target=_run_investigation_bg, args=(market_id, event_timestamp, goal));
    t.daemon = True;
    t.start();
    return {"started": True, "market_id": market_id};
}
