"""Investigation tree visualization — shows the AI's DFS thought process."""

def:pub InvestigationTree(tree: list) -> JsxElement {

    def get_cat_class(tool_name: str) -> str {
        if not tool_name { return "tree-cat-default"; }
        t = tool_name.toLowerCase() if tool_name else "";
        if "search_google" in t { return "tree-cat-research"; }
        if "search_news" in t { return "tree-cat-news"; }
        if "search_scholar" in t { return "tree-cat-medical"; }
        if "scrape" in t { return "tree-cat-scrape"; }
        return "tree-cat-research";
    }

    nodes = Array.from(tree);
    if not nodes or nodes.length == 0 {
        return <p className="text-muted-foreground text-sm">{"No tree data available."}</p>;
    }

    def render_single(n: any) -> JsxElement {
        cat = get_cat_class(n["tool"] or "");
        d = n["depth"] or 0;
        return (
            <div className="tree-viz-node" key={n["id"] or "?"} style={{"marginLeft": str(d * 28) + "px"}}>
                <div className={"tree-viz-bar " + cat}>
                    <span className="tree-viz-id">{n["id"] or "?"}</span>
                    {n["tool"] and (
                        <span className="tree-viz-tool">{n["tool"]}</span>
                    )}
                    <span className="tree-viz-depth">{"D" + str(d)}</span>
                </div>
                {n["hypothesis"] and (
                    <div className="tree-viz-hyp">{n["hypothesis"]}</div>
                )}
                {n["result"] and (
                    <div className="tree-viz-result">{n["result"]}</div>
                )}
            </div>
        );
    }

    return (
        <div className="tree-viz-container">
            <div className="tree-legend">
                <span className="tree-legend-dot tree-cat-research" />
                <span className="tree-legend-label">Google Search</span>
                <span className="tree-legend-dot tree-cat-news" />
                <span className="tree-legend-label">News</span>
                <span className="tree-legend-dot tree-cat-medical" />
                <span className="tree-legend-label">Scholar</span>
                <span className="tree-legend-dot tree-cat-scrape" />
                <span className="tree-legend-label">Web Scrape</span>
            </div>
            <div className="tree-viz-scroll">
                {nodes.map(render_single)}
            </div>
        </div>
    );
}
