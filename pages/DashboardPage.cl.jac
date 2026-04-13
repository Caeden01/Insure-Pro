import from "@jac/runtime" { jacLogout, useNavigate, __doFuncFetch }

def:pub page() -> JsxElement {
    has documents: list = [];
    has loading: bool = False;
    has error: str = "";
    has drag_active: bool = False;

    navigate = useNavigate();

    def handle_logout() -> None {
        jacLogout();
        navigate("/login");
    }

    def handle_drag_over(e: any) -> None {
        e.preventDefault();
        e.stopPropagation();
        drag_active = True;
    }

    def handle_drag_leave(e: any) -> None {
        e.preventDefault();
        e.stopPropagation();
        drag_active = False;
    }

    def handle_drop(e: any) -> None {
        e.preventDefault();
        e.stopPropagation();
        drag_active = False;
        files = e.dataTransfer.files;
        process_files(files);
    }

    def handle_file_input(e: any) -> None {
        files = e.target.files;
        process_files(files);
    }

    def classify_file(fname: str, ftype: str) -> str {
        lower_name = fname.toLowerCase();
        if ftype == "application/pdf" or lower_name.endsWith(".pdf") {
            return "pdf";
        }
        if ftype.startsWith("image/") or lower_name.endsWith(".png") or lower_name.endsWith(".jpg") or lower_name.endsWith(".jpeg") {
            return "image";
        }
        return "document";
    }

    def process_files(files: any) -> None {
        new_docs: list = [];
        for i in range(files.length) {
            f = files[i];
            fname = String(f.name);
            ftype = String(f.type);
            doc_type = classify_file(fname, ftype);
            new_docs.append({
                "name": fname,
                "size": f.size,
                "file": f,
                "type": doc_type,
                "status": "ready"
            });
        }
        documents = documents.concat(new_docs);
    }

    def remove_document(idx: int) -> None {
        new_list: list = [];
        for i in range(len(documents)) {
            if i != idx { new_list.append(documents[i]); }
        }
        documents = new_list;
    }

    def format_size(bytes: int) -> str {
        if bytes >= 1048576 { return str(Math.round(bytes / 1048576 * 10) / 10) + " MB"; }
        if bytes >= 1024 { return str(Math.round(bytes / 1024)) + " KB"; }
        return str(bytes) + " B";
    }

    def get_doc_icon(doc_type: str) -> str {
        if doc_type == "pdf" { return "PDF"; }
        if doc_type == "image" { return "IMG"; }
        return "DOC";
    }

    async def read_file_base64(file: any) -> str {
        reader = Reflect.construct(FileReader, []);
        return await Reflect.construct(Promise, [lambda resolve, reject: (
            reader.addEventListener("load", lambda: resolve(reader.result)),
            reader.addEventListener("error", lambda: reject("read error")),
            reader.readAsDataURL(file)
        )]);
    }

    async def start_analysis() -> None {
        if len(documents) == 0 { error = "Please upload at least one document."; return; }
        loading = True;
        error = "";
        try {
            all_text: list = [];
            for i in range(len(documents)) {
                doc = documents[i];
                try {
                    base64_data = await read_file_base64(doc["file"]);
                    res = await __doFuncFetch("analyze_document", {
                        "document_data": base64_data,
                        "filename": doc["name"]
                    });
                    if res and res["text"] and res["text"].length > 10 {
                        all_text.append("=== " + doc["name"] + " ===\n" + res["text"]);
                    }
                } except Exception as ex {
                    console.log("File read error:", doc["name"], ex);
                }
            }
            extracted = "\n\n".join(all_text);
            if not extracted or extracted.length < 10 {
                error = "Could not extract text from the uploaded documents.";
                loading = False;
                return;
            }
            window.sessionStorage.setItem("insure_pro_text", extracted);
            navigate("/investigation");
        } except Exception as ex {
            error = "Error processing documents: " + str(ex);
            loading = False;
        }
    }

    return (
        <div className="page">
            <div className="page-container">
                <div className="page-header">
                    <div>
                        <h1>InsurePro</h1>
                        <p className="text-sm text-muted-foreground">Upload insurance documents to investigate claim denials</p>
                    </div>
                    <button className="btn btn-ghost" onClick={handle_logout}>
                        Sign out
                    </button>
                </div>

                <div className={"card upload-zone" + (drag_active and " upload-zone-active" or "")}
                     onDragOver={handle_drag_over}
                     onDragLeave={handle_drag_leave}
                     onDrop={handle_drop}>
                    <div className="upload-zone-content">
                        <div className="upload-icon">{"+"}</div>
                        <h3 className="upload-title">Upload Insurance Documents</h3>
                        <p className="upload-desc">
                            {"Drag & drop your denial letter, explanation of benefits (EOB), insurance plan documents, or medical records"}
                        </p>
                        <p className="upload-formats">{"Supports PDF, images, and text documents"}</p>
                        <label className="btn btn-primary upload-browse-btn">
                            {"Browse Files"}
                            <input type="file" multiple={True} accept=".pdf,.png,.jpg,.jpeg,.doc,.docx,.txt"
                                   onChange={handle_file_input} style={{"display": "none"}} />
                        </label>
                    </div>
                </div>

                {len(documents) > 0 and (
                    <div className="card p-6 mb-4">
                        <h2 className="text-base font-semibold text-primary mb-3">
                            {"Uploaded Documents (" + str(len(documents)) + ")"}
                        </h2>
                        <div className="doc-list">
                            {[
                                <div key={str(didx)} className="doc-item">
                                    <div className="doc-item-left">
                                        <span className={"doc-icon doc-icon-" + documents[didx]["type"]}>{get_doc_icon(documents[didx]["type"])}</span>
                                        <div className="doc-info">
                                            <span className="doc-name">{str(documents[didx]["name"])}</span>
                                            <span className="doc-size">{format_size(documents[didx]["size"])}</span>
                                        </div>
                                    </div>
                                    <button className="btn btn-ghost doc-remove-btn" onClick={lambda: remove_document(didx)}>{"x"}</button>
                                </div>
                                for didx in range(len(documents))
                            ]}
                        </div>
                        <button className="btn btn-primary w-full h-12 mt-4" onClick={start_analysis} disabled={loading}>
                            {loading and "Processing..." or "Investigate Denial"}
                        </button>
                        {error and (<div className="error-box mt-3">{error}</div>)}
                    </div>
                )}

                <div className="info-grid">
                    <div className="info-card">
                        <div className="info-icon">{"1"}</div>
                        <h3>Upload Documents</h3>
                        <p>Upload your denial letter, EOB, insurance plan, and any supporting medical records.</p>
                    </div>
                    <div className="info-card">
                        <div className="info-icon">{"2"}</div>
                        <h3>AI Investigation</h3>
                        <p>Our AI analyzes your documents using Tree of Thought reasoning to build a comprehensive appeal strategy.</p>
                    </div>
                    <div className="info-card">
                        <div className="info-icon">{"3"}</div>
                        <h3>Get Appeal Letter</h3>
                        <p>Receive a detailed appeal letter with legal citations and medical justifications ready to submit.</p>
                    </div>
                    <div className="info-card">
                        <div className="info-icon">{"4"}</div>
                        <h3>Track Progress</h3>
                        <p>Monitor the investigation in real-time and review all evidence collected for your appeal.</p>
                    </div>
                </div>
            </div>
        </div>
    );
}
