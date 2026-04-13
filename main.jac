"""InsurePro - Entry Point.

Imports server-side symbols and mounts the client app.
"""

import from services.appService { greet }
import from services.investigation_v2 { start_investigation, get_investigation_progress, stop_investigation }
import from services.insuranceService { analyze_document, get_claim_summary }

cl import from .index { ClientApp }

cl {
    def:pub app() -> JsxElement {
        return <ClientApp />;
    }
}
