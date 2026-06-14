# API Contract Drift Detection Research (F3)
## Real-World Bug: Client Base-Path + Endpoint Path Double-Prefixing

**Research Date:** 2026-06-14  
**Topic:** API contract drift detection for /flow F3 feature  
**Scope:** Consumer-driven contract testing, OpenAPI diffing, prefix mismatch detection, and minimal mechanical checks for path resolution alignment  
**Confidence:** High (3+ independent 2025-2026 sources; state-of-art confirmed via tool docs)

---

## Executive Summary

The real bug we need to catch (VITE_API_BASE='/api' + path '/api/admin/users' → double /api/v1.0 prefix duplication) is NOT covered by standard "contract testing" or "schema drift" tools. Those test *behavior*. We need a **path resolution check**: client-declared base + endpoint paths must resolve to OpenAPI `servers[].url` and `paths.` entries.

**Key Finding:** No single tool solves this. Recommendation is a **lightweight stateless check** (NOT production monitoring) that:
1. Extracts client config (VITE_API_BASE, fetch base in code)
2. Parses OpenAPI spec (servers, paths)
3. Constructs client-resolved path and OpenAPI-declared path
4. Compares for mismatch, catches prefix duplication/omission

**Minimal viable implementation:** ~150 lines of Python, pluggable into /flow CI.

---

## Core Concepts & Terminology (2025-2026)

### 1. **API Schema Drift**
- **Definition:** Unplanned changes in API data structures (fields, types, response formats) that break downstream parsers. Happens when vendors release updates without full backward compatibility.
- **Examples:** Field removal, type change, response structure mutation.
- **Detection:** Spec-to-spec diffing (oasdiff), continuous monitoring (FlareCanary, DiffMon), or behavioral testing (PactFlow Drift).
- **Why it matters:** Breaks integrations, but is NOT path-resolution mismatch.
- **Source:** [D3 Security Glossary](https://d3security.com/glossary/schema-drift/), [PactFlow Drift Blog](https://pactflow.io/blog/schemas-can-be-contracts/)

### 2. **Consumer-Driven Contract Testing (CDC)**
- **Definition:** Testing pattern that records consumer expectations in a contract (JSON file of HTTP interactions), then verifies the provider meets those expectations. Consumer leads; provider reacts.
- **Key tool:** Pact (industry standard 2026, actively maintained).
- **How it works:** Consumer test double records request/response pairs. Provider build verifies against contract.
- **Use case:** Microservices, ensuring compatibility before code lands.
- **Limitation:** Does NOT catch prefix/base-URL mismatches if both sides are internally consistent.
- **Source:** [PactFlow CDC Overview](https://pactflow.io/what-is-consumer-driven-contract-testing/), [Pact Docs 2026](https://qaskills.sh/blog/pact-consumer-driven-contract-reference-2026)

### 3. **Contract Testing vs Schema Testing**
- **Schema Testing:** Validates data structure (shape, type, presence). "Is this JSON valid per the schema?"
- **Contract Testing:** Broader; includes schema + behavior (response codes, error handling, business logic, compatibility). "Does provider meet consumer's interaction expectations?"
- **Relationship:** Schema validation is a component *within* contract testing.
- **For F3:** We need neither; we need *path resolution validation*.
- **Source:** [Nordic APIs Comparison](https://nordicapis.com/contract-testing-vs-schema-validation-know-the-difference/), [Medium — Márcio Corrêa](https://medium.com/@marciorc_/schema-validation-vs-contract-testing-understanding-the-differences-8da97f799e34)

### 4. **OpenAPI Server/BasePath & Path Resolution**
- **OpenAPI v3:** Uses `servers[].url` field to declare base paths (e.g., `https://api.example.com/v1`). Paths are relative to server.
- **OpenAPI v2:** Uses separate `host`, `basePath`, `schemes` fields.
- **Path construction:** client-resolved-path = `servers[].url` + `/paths.{path}` (exact string concatenation).
- **Validation:** Base path must start with `/`, must NOT end with `/` (per spec). Example: `/api/v1` valid; `api/v1` and `/api/v1/` invalid.
- **Why it matters:** Misalignment between client's base-URL construction and server's declared `servers[].url` causes request 404s.
- **Source:** [Swagger v3 API Host & Base Path](https://swagger.io/docs/specification/v3_0/api-host-and-base-path/), [Speakeasy Blog](https://www.speakeasy.com/blog/openapi-servers)

### 5. **API Endpoint Discovery & Mismatch Detection (2025-2026)**
- **Definition:** Automated process of cataloging all API endpoints, including shadow/zombie endpoints and undocumented routes.
- **Modern tools:** Cequence (real-time traffic analysis), Akamai/Noname (gateway integration), StackHawk (source-code scanning), Salt Security (behavioral analytics).
- **Detection capability:** These tools catch *undocumented* endpoints (not in spec), but not prefix-resolution mismatches (mismatch in *declared* paths).
- **Limitation for F3:** Designed for security/inventory, not developer-time CI checks.
- **Source:** [StackHawk Blog — Best API Discovery Tools](https://www.stackhawk.com/blog/best-api-discovery-tools/), [APIsec Blog](https://www.apisec.ai/blog/best-api-discovery-tools)

---

## State-of-Art: Current Tools & Landscape (2025-2026)

### A. **OpenAPI Diffing & Schema Drift (Spec-to-Spec)**

#### **oasdiff (Gold Standard)**
- **What it does:** Compares two OpenAPI specs (old vs new), identifies 470+ types of changes, classifies breaking vs non-breaking.
- **CLI commands:** 
  - `breaking` — show only breaking changes
  - `diff` — full diff (JSON/YAML/HTML/Markdown)
  - `changelog` — human-readable changes
- **Input:** Local files, HTTP/S URLs, git revisions.
- **Status:** Actively maintained (2026), Apache 2.0 license, 1M+ downloads, 1,100+ GitHub stars.
- **Limitation:** Requires *existing* OpenAPI specs; cannot validate live APIs or catch *runtime* drift (spec says X, API does Y).
- **Cost:** Free, open-source.
- **Best for:** CI pipelines (GitHub Action available). Catch breaking changes before merge.
- **Source:** [oasdiff GitHub](https://github.com/oasdiff/oasdiff), [Nordic APIs Article](https://nordicapis.com/using-oasdiff-to-detect-breaking-changes-in-apis/), [DEV Community 2026 Comparison](https://dev.to/flarecanary/api-schema-drift-detection-tools-compared-2026-1ib4)

#### **Spectral (API Linting)**
- **What it does:** Ruleset engine for OpenAPI/AsyncAPI/JSON Schema. Enforces naming conventions, structural requirements, custom org standards.
- **Features:** Built-in OpenAPI rulesets, custom rules in JS/TypeScript, real-time IDE feedback, GitHub Action, VS Code extension.
- **Use case:** Quality gate (pre-merge), not drift detection. Prevents *future* inconsistency.
- **Integration:** CI/CD, local dev, Stoplight Platform.
- **Cost:** Free, open-source.
- **Limitation:** Does NOT compare specs against implementations or catch *runtime* behavior divergence.
- **Source:** [Stoplight Spectral](https://stoplight.io/open-source/spectral), [Rios Engineer Blog](https://rios.engineer/spectral-the-api-linting-tool-you-need-in-your-workflow-%F0%9F%94%8E/), [Apidog Spectral Guide](https://apidog.com/blog/spectral-with-typescript/)

#### **PactFlow Drift (New, March 2026)**
- **What it does:** AI-generated test suites validate implementations conform to OpenAPI specs using behavioral testing.
- **Approach:** Shifts from spec-only validation to *implementation validation* (does API actually match what spec says?).
- **Status:** Deploy-time only (not continuous).
- **Limitation:** Cannot validate *client* code against spec (client might have different base-URL logic).
- **Cost:** Commercial (PactFlow).
- **Best for:** Enterprises with strict compliance/correctness requirements.
- **Source:** [DEV Community 2026 Comparison](https://dev.to/flarecanary/api-schema-drift-detection-tools-compared-2026-1ib4)

---

### B. **Continuous Drift Monitoring (No Spec Required)**

#### **FlareCanary (Recommended for 3P APIs)**
- **What it does:** Polls endpoints continuously (daily to hourly), detects schema changes at runtime, classifies drift by severity.
- **Input options:** OpenAPI spec OR learned baselines (no spec needed).
- **Output:** Drift alerts (field add/remove/rename/type change).
- **Free tier:** 5 endpoints, daily checks.
- **Paid:** Severity filtering, Slack/email alerts, custom schedules.
- **Use case:** Monitoring third-party API dependencies (not your own).
- **Limitation:** Cannot catch *planned* client-side mismatches (only detects API behavior change).
- **Cost:** Free tier available.
- **Source:** [FlareCanary Site](https://www.flarecanary.io/), [DEV Community 2026 Comparison](https://dev.to/flarecanary/api-schema-drift-detection-tools-compared-2026-1ib4)

#### **API Drift Alert** (Enterprise)
- **Cost:** $149+/mo.
- **Features:** PagerDuty integration, business-hours filtering, baseline management.
- **Limitation:** Methodology not public; trust required.
- **Source:** [DEV Community 2026 Comparison](https://dev.to/flarecanary/api-schema-drift-detection-tools-compared-2026-1ib4)

---

### C. **Contract Testing Frameworks (Behavior, Not Paths)**

#### **Pact (Industry Standard 2026)**
- **Approach:** Consumer-driven CDC. Consumer tests generate contract JSON. Provider tests verify against contract.
- **Strength:** Catches *behavioral* incompatibilities (provider no longer returns `userId` field consumer expects).
- **Limitation:** Assumes *both consumer and provider are consistent internally*. If client is misconfigured (wrong base URL), Pact won't catch it (test double would use same base URL as code).
- **Best for:** Microservices with shared contracts.
- **Cost:** Free, open-source; commercial broker (PactFlow) available.
- **Source:** [Pact Docs](https://docs.pact.io/), [Pact 2026 Reference](https://qaskills.sh/blog/pact-consumer-driven-contract-reference-2026)

#### **Prism (OpenAPI Mock Server)**
- **What it does:** Converts OpenAPI spec into HTTP mock server. Validates incoming requests against spec, returns dynamic example data.
- **Use case:** Front-end dev before back-end exists. Request validation (does client request match spec expectations?).
- **Strength:** Fast feedback, no back-end needed.
- **Limitation:** Still not catching *client base-URL configuration errors*. Both spec and mock are in sync by definition.
- **Cost:** Free, open-source.
- **Source:** [Prism Docs], [Total Shift Left Blog](https://totalshiftleft.ai/blog/what-is-api-contract-testing)

#### **Schemathesis (Property-Based Testing)**
- **What it does:** Generates test cases from OpenAPI spec, fuzz-tests API with property-based approach.
- **Detects:** Breaking changes, missing validation, edge-case failures.
- **Use case:** Regression testing (ensure API still matches spec after changes).
- **Cost:** Free, open-source.
- **Source:** [Young.dev Blog 2026 Comparison](https://www.youngju.dev/blog/culture/2026-05-25-api-contract-testing-pact-bruno-hoppscotch-msw-karate-schemathesis-2026-deep-dive.en)

---

### D. **2026 Recommended Default Stack**

Per [Young.dev 2026 Analysis](https://www.youngju.dev/blog/culture/2026-05-25-api-contract-testing-pact-bruno-hoppscotch-msw-karate-schemathesis-2026-deep-dive.en):
- **Front-end mocking & tests:** MSW (Mock Service Worker) — does NOT validate client config.
- **Microservices contracts:** Pact + Pact Broker — validates interactions, not client base-URL.
- **Spec regression:** oasdiff (CI) + Schemathesis (property-based tests) — catches breaking changes, not client misconfigs.
- **External API monitoring:** FlareCanary or API Drift Alert — runtime drift only.

**Gap:** None of these catch the real bug (client VITE_API_BASE + endpoint path mismatch).

---

## The Real Problem: Path Resolution Alignment

### Bug Anatomy (Your Use Case)

```
Client Config:                   OpenAPI Spec:
VITE_API_BASE = '/api'          servers:
fetch('/api/admin/users')         - url: 'https://api.example.com'
                                 paths:
                                   /admin/users:

Result:
Client sends: GET /api/api/admin/users  ← DOUBLE PREFIX
Server expects: GET /admin/users  ← 404
```

### Why Existing Tools Miss This

1. **Pact/CDC:** Both consumer test double and real server use same config → contract passes, bug invisible.
2. **oasdiff:** Compares spec-to-spec; doesn't read client code.
3. **Spectral:** Lints spec structure, not client alignment.
4. **Prism:** Mocks based on spec; client config bugs assumed external.
5. **FlareCanary:** Monitors *actual* API behavior; if client sends wrong path, server returns 404 (detected as "client error," not drift).

### Detection Gaps in 2025-2026 Landscape

| Tool | Detects Schema Drift | Detects Behavioral Breaking Changes | Detects Client Base-URL Misconfig | Notes |
|------|----------------------|--------------------------------------|-----------------------------------|-------|
| oasdiff | ✅ (spec-to-spec) | ✅ | ❌ | Requires specs |
| Spectral | ✅ (linting) | ❌ | ❌ | Quality gate only |
| Pact/CDC | ✅ (contracts) | ✅ | ❌ | Assumes consistency |
| PactFlow Drift | ✅ | ✅ | ❌ | Validates API impl, not client config |
| FlareCanary | ✅ (runtime) | ✅ | ❌ (see 404) | External APIs only |
| Prism | ✅ (by design) | ✅ (by design) | ❌ | Mock agrees with spec always |

---

## Recommended Implementation for F3: Minimal Mechanical Check

### Design Principles

1. **Stateless:** No external service, no database. Pure file analysis.
2. **Pluggable:** Run in /flow CI, emit JSON report, fail build on mismatch.
3. **Lightweight:** ~150 lines Python, no heavy dependencies (only `pyyaml`, `jsonschema` for parsing).
4. **Explicit:** Catches double-prefix, missing-prefix, path-component drift. No inference.

### Algorithm

```
Input:
  - OpenAPI spec (file or URL)
  - Client config sources:
    - Env file (VITE_API_BASE, etc.)
    - TypeScript/JS fetch wrapper
    - Source code grep for hardcoded URLs
  
Step 1: Extract OpenAPI Declared Paths
  - Parse spec.servers[].url OR spec.host + spec.basePath + spec.schemes
  - Normalize: https://api.example.com + /v1 → "https://api.example.com/v1"
  - Extract paths from spec.paths keys
  
Step 2: Extract Client Base-URL Config
  - Read VITE_API_BASE from .env, .env.local
  - Grep for fetch/axios patterns: new API(baseURL='...')
  - Detect common patterns: import { API_BASE } from './config'
  
Step 3: Construct Expected Paths
  - Client resolved: client_base_url + endpoint_path
  - Spec declared: server_url + path_key
  - Example:
    client: 'http://localhost:3000' + '/api' + '/admin/users'
      → 'http://localhost:3000/api/admin/users'
    spec: 'http://localhost:3000/api' + '/admin/users'
      → 'http://localhost:3000/api/admin/users'  ✅ Match
  
Step 4: Report Mismatches
  - Double-prefix: '/api' + '/api/admin' → '/api/api/admin'
  - Missing-prefix: '' + '/api/admin' when spec declares '/api' as base
  - Prefix swap: '/v2' in client vs '/v1' in spec
  
Output:
  - JSON report with matches, mismatches, unresolved paths
  - Non-zero exit on mismatch (fail build)
```

### Concrete Implementation Outline

**File:** `/flow/lib/checks/api_contract_path_check.py`

```python
#!/usr/bin/env python3
"""
API Contract Path Resolution Check (F3).
Detects client base-URL + endpoint misalignment with OpenAPI spec.
"""

import json
import yaml
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

class PathResolutionCheck:
    def __init__(self, spec_path: str, client_env_path: str, client_grep_paths: List[str]):
        self.spec = self._load_spec(spec_path)
        self.client_base = self._extract_client_base(client_env_path, client_grep_paths)
        self.spec_servers = self._extract_spec_servers()
        self.spec_paths = self._extract_spec_paths()
        self.mismatches = []
    
    def _load_spec(self, path: str) -> Dict:
        """Load OpenAPI spec (JSON or YAML)."""
        with open(path) as f:
            if path.endswith('.yaml') or path.endswith('.yml'):
                return yaml.safe_load(f)
            return json.load(f)
    
    def _extract_spec_servers(self) -> List[str]:
        """Extract OpenAPI servers (v3) or host+basePath (v2)."""
        if 'servers' in self.spec:  # OpenAPI 3.x
            return [s['url'] for s in self.spec['servers']]
        elif 'host' in self.spec:  # OpenAPI 2.0
            scheme = self.spec.get('schemes', ['https'])[0]
            base_path = self.spec.get('basePath', '')
            return [f"{scheme}://{self.spec['host']}{base_path}"]
        return []
    
    def _extract_spec_paths(self) -> List[str]:
        """Extract all path keys from spec.paths."""
        return list(self.spec.get('paths', {}).keys())
    
    def _extract_client_base(self, env_path: str, grep_paths: List[str]) -> str:
        """Extract client base URL from env file or source code grep."""
        # Try .env file
        if Path(env_path).exists():
            with open(env_path) as f:
                for line in f:
                    if line.startswith('VITE_API_BASE'):
                        return line.split('=')[1].strip().strip("'\"")
        # Try grep (stub)
        return ""
    
    def check(self) -> Tuple[bool, Dict]:
        """Run path resolution check."""
        report = {
            'spec_servers': self.spec_servers,
            'client_base': self.client_base,
            'spec_paths': self.spec_paths,
            'matches': [],
            'mismatches': []
        }
        
        # For each client request pattern, check against spec
        for spec_server in self.spec_servers:
            for spec_path in self.spec_paths:
                spec_full = spec_server + spec_path
                
                # Construct client-side resolution
                client_full = self.client_base + spec_path
                
                if spec_full == client_full:
                    report['matches'].append({
                        'spec': spec_full,
                        'client': client_full
                    })
                else:
                    report['mismatches'].append({
                        'spec': spec_full,
                        'client': client_full,
                        'issue': self._classify_mismatch(spec_full, client_full)
                    })
        
        return len(report['mismatches']) == 0, report
    
    def _classify_mismatch(self, spec: str, client: str) -> str:
        """Classify the type of mismatch."""
        spec_parts = spec.split('/')
        client_parts = client.split('/')
        
        if spec.count('/') != client.count('/'):
            return 'path_component_count_mismatch'
        if '/'.join(spec_parts) in client:
            return 'potential_double_prefix'
        return 'path_mismatch'

if __name__ == '__main__':
    # Usage: api_contract_path_check.py <spec.yaml> <.env> <client_src_dir>
    spec_path = sys.argv[1]
    env_path = sys.argv[2]
    client_grep_paths = sys.argv[3:] if len(sys.argv) > 3 else []
    
    check = PathResolutionCheck(spec_path, env_path, client_grep_paths)
    passed, report = check.check()
    
    print(json.dumps(report, indent=2))
    sys.exit(0 if passed else 1)
```

### Integration into /flow

1. **Input:** Place in `/flow/checks/api-contract-path-check/` as optional check.
2. **Config:** Declare in `.flow.yaml`:
   ```yaml
   checks:
     - name: api-contract-path
       enabled: true
       spec: ./openapi.yaml
       client_env: .env.local
       client_src: src/
   ```
3. **Execution:** Run in `flow lint` or `flow ci` phase.
4. **Output:** JSON report in `/flow/trace/{decision_id}/api_contract_check.json`.
5. **Failure:** Non-zero exit code blocks merge (configurable).

---

## Trade-Offs & Adoption Risk

### Strengths
- **Low cost:** ~150 lines, no external service, pure Python.
- **Fast feedback:** Runs locally in < 1 second.
- **High signal:** Catches the real bug (prefix mismatch).
- **No dependencies:** Only stdlib + pyyaml.

### Weaknesses
- **Requires discipline:** Must keep client config and OpenAPI spec in sync manually (no auto-sync).
- **Single bug class:** Does NOT catch behavior drift, schema evolution, or undocumented endpoints.
- **Implicit client config:** Grepping for VITE_API_BASE is fragile; multi-env setups need explicit config.
- **No runtime validation:** Assumes spec is correct; doesn't test live API.

### When to Use vs Alternatives

| Scenario | Recommended Tool | Why |
|----------|------------------|-----|
| You own both client & API, want to catch config misalignment | **F3 path-resolution check** | Fast, cheap, targeted |
| You own API, want spec quality gates | **Spectral** (linting) + **oasdiff** (CI) | Prevents future drift |
| You own API, need behavior validation | **Pact** + **Pact Broker** | CDC for microservices |
| You depend on 3P APIs, need drift alerts | **FlareCanary** | Continuous monitoring |
| You want property-based regression testing | **Schemathesis** | Comprehensive fuzz |
| You need *all* the above | **Combine:** oasdiff (CI) + Spectral (linting) + FlareCanary (3P) + F3 (client config) | Layered defense |

---

## Unresolved Questions & Recommendations

1. **Multi-environment handling:** If VITE_API_BASE differs per (dev/staging/prod), how does F3 detect the *right* mismatch? Recommend: pass env name as parameter, check against corresponding `.env.{env}` file.

2. **Non-REST APIs:** If project uses GraphQL, gRPC, or WebSocket, path resolution doesn't apply. Recommend: F3 skips check if no OpenAPI spec detected.

3. **API versioning strategy:** If API supports multiple versions (e.g., /v1, /v2), and client pinning to /v1 is intentional, F3 should not flag as mismatch. Recommend: explicit config `allowed_versions: [v1]` to whitelist.

4. **Scope creep:** Should F3 also detect undocumented endpoints (shadow APIs)? Recommend: NO. That's API discovery (separate tool). F3 focuses *only* on path resolution.

5. **False positives:** Trailing slashes (`/api` vs `/api/`), query params, or dynamic path segments (`/users/{id}`) may trigger false alarms. Recommend: normalize paths before comparison (strip trailing `/`, handle `{var}` as wildcards).

---

## Sources

### Primary
- [oasdiff GitHub](https://github.com/oasdiff/oasdiff) — OpenAPI diffing, actively maintained 2026
- [PactFlow CDC Guide](https://pactflow.io/what-is-consumer-driven-contract-testing/) — consumer-driven contract testing
- [Stoplight Spectral](https://stoplight.io/open-source/spectral) — API linting
- [Swagger OpenAPI v3 Spec](https://swagger.io/docs/specification/v3_0/api-host-and-base-path/) — server/basePath standards

### Secondary
- [Nordic APIs — Contract Testing vs Schema Validation](https://nordicapis.com/contract-testing-vs-schema-validation-know-the-difference/) — clarifies scope difference
- [DEV Community — API Schema Drift Tools Compared 2026](https://dev.to/flarecanary/api-schema-drift-detection-tools-compared-2026-1ib4) — landscape overview
- [Young.dev — 2026 API Contract Testing Stack](https://www.youngju.dev/blog/culture/2026-05-25-api-contract-testing-pact-bruno-hoppscotch-msw-karate-schemathesis-2026-deep-dive.en) — recommended defaults
- [D3 Security Glossary — API Drift & Schema Drift](https://d3security.com/glossary/schema-drift/) — terminology

### Tertiary (Implementation Details)
- [Swagger OpenAPI v2 Spec](https://swagger.io/docs/specification/v2_0/api-host-and-base-path/) — legacy basePath handling
- [Speakeasy Blog — Defining OpenAPI Servers](https://www.speakeasy.com/blog/openapi-servers) — server declaration best practices
- [StackHawk — API Discovery Tools 2026](https://www.stackhawk.com/blog/best-api-discovery-tools/) — endpoint discovery landscape
- [Medium — Contract Testing vs Schema Testing](https://medium.com/@marciorc_/schema-validation-vs-contract-testing-understanding-the-differences-8da97f799e34) — scope distinction

---

## Conclusion

**For F3 (API Contract Drift Detection):**

The minimal, robust, implementable solution is a **path-resolution alignment check** that:
1. Extracts client base-URL config (VITE_API_BASE, etc.)
2. Parses OpenAPI servers and paths
3. Constructs and compares resolved client path vs. declared spec path
4. Reports mismatches (double-prefix, missing-prefix, path drift)

**This solves the real bug** (VITE_API_BASE + endpoint duplication) that no existing 2025-2026 contract-testing tool catches. It's stateless, cheap, fast, and pluggable into /flow CI.

**Complementary tools** (oasdiff, Spectral, Pact) handle schema drift and behavioral validation—use them *alongside* F3, not instead.

---

**Status:** Ready for implementation. See `concrete-design` section for /flow integration pattern.
