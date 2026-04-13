"""Insurance Service — extracts text from uploaded documents (PDF, images, text)."""

import base64;
import io;

def:priv analyze_document(document_data: str, filename: str = "") -> dict {
    # document_data is base64 encoded file content (after the data:... prefix)
    try {
        # Strip data URL prefix if present
        raw = document_data;
        if "," in raw {
            raw = raw.split(",", 1)[1];
        }
        file_bytes = base64.b64decode(raw);
    } except Exception as e {
        return {"status": "error", "error": "Failed to decode file: " + str(e), "text": ""};
    }
    lower_name = filename.lower() if filename else "";
    # PDF extraction
    if lower_name.endswith(".pdf") {
        try {
            import pypdf;
            reader = pypdf.PdfReader(io.BytesIO(file_bytes));
            pages: list = [];
            for page in reader.pages {
                t = page.extract_text();
                if t { pages.append(t); }
            }
            text = "\n\n".join(pages);
            return {"status": "ok", "text": text, "pages": len(reader.pages), "chars": len(text)};
        } except Exception as e {
            return {"status": "error", "error": "PDF extraction failed: " + str(e), "text": ""};
        }
    }
    # Plain text files
    if lower_name.endswith(".txt") or lower_name.endswith(".doc") or lower_name.endswith(".docx") {
        try {
            text = file_bytes.decode("utf-8", errors="replace");
            return {"status": "ok", "text": text, "chars": len(text)};
        } except Exception as e {
            return {"status": "error", "error": "Text decode failed: " + str(e), "text": ""};
        }
    }
    # Images — return a note that OCR is not yet supported
    if lower_name.endswith(".png") or lower_name.endswith(".jpg") or lower_name.endswith(".jpeg") {
        return {"status": "ok", "text": "[Image uploaded: " + filename + ". OCR not yet supported — please paste the text from this image manually.]", "chars": 0};
    }
    # Fallback: try to decode as text
    try {
        text = file_bytes.decode("utf-8", errors="replace");
        return {"status": "ok", "text": text, "chars": len(text)};
    } except Exception {
        return {"status": "error", "error": "Unsupported file format", "text": ""};
    }
}

def:priv get_claim_summary(claim_id: str) -> dict {
    return {
        "status": "ok",
        "claim_id": claim_id,
        "summary": "Use the investigation engine to analyze this claim."
    };
}
