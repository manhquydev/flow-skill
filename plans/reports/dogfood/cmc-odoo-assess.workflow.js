export const meta = {
  name: 'cmc-odoo-assess',
  description: 'Brownfield map of CMC Odoo ERP: 36 addons -> module/relationship map + permission matrix + business-logic/test-gap assessment',
  phases: [
    { title: 'Extract', detail: 'one agent per Odoo addon -> structured record (manifest, models, security, tests)' },
    { title: 'Synthesize', detail: 'relationships graph + permission matrix + logic/test gaps' },
    { title: 'Review', detail: 'adversarial critic over the three syntheses' },
  ],
}

const BASE = 'D:/project/CMC/src/odoo/addons/'
const CTX = [
  'PROJECT: CMC = Odoo 17 CE education ERP. Multi-facility (multiple physical centers).',
  'Programs: UCREA (ages 3-6, 100% qualitative grading), Bright I.G (6-9, 60/40), Black Hole (9-11, 30/70). Students are minors (ages 3-11).',
  'Odoo is the SOURCE OF TRUTH for students, grades, attendance, fees. A Fastify sync middleware mirrors data to a Next.js LMS that parents/students read.',
  'You are mapping the ODOO side only. Files are on Windows; use absolute paths with forward slashes (Read/Glob/Grep accept them).',
].join(' ')

// 22 CMC custom + 1 education_auto_invoice = deep business-logic read
const CMC_DEEP = [
  'cmc_access_control','cmc_aftersale','cmc_batch_sequence','cmc_bgd_dashboard','cmc_certificates',
  'cmc_crm_config','cmc_dashboard','cmc_discount','cmc_grading','cmc_kpi_dashboard','cmc_multi_facility',
  'cmc_parent_meeting','cmc_payroll_simple','cmc_shift_registration','cmc_student_analytics','cmc_teacher_kpi',
  'cmc_test_bank','cmc_test_booking','cmc_test_paper','cmc_tests','cmc_web_theme','cmc_xlsx_reports',
  'education_auto_invoice',
]
// 11 OpenEduCat base + 2 OCA utility = light read (manifest depends + security only)
const VENDORED = [
  'openeducat_activity','openeducat_admission','openeducat_assignment','openeducat_attendance',
  'openeducat_certificate','openeducat_classroom','openeducat_core','openeducat_erp','openeducat_exam',
  'openeducat_fees','openeducat_timetable','report_xlsx','server_environment',
]

const ADDON_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['addon', 'summary', 'depends'],
  properties: {
    addon: { type: 'string' },
    kind: { type: 'string', description: 'cmc-custom | vendored | utility' },
    version: { type: 'string' },
    summary: { type: 'string', description: '1-2 sentences: the REAL business purpose' },
    depends: { type: 'array', items: { type: 'string' } },
    models: { type: 'array', items: { type: 'object', additionalProperties: false,
      required: ['name'], properties: { name: { type: 'string' }, file: { type: 'string' }, purpose: { type: 'string' } } } },
    business_logic: { type: 'string', description: 'concrete business operations implemented, with file evidence' },
    ambiguity: { type: 'array', items: { type: 'object', additionalProperties: false,
      required: ['area'], properties: { area: { type: 'string' }, why: { type: 'string' }, evidence: { type: 'string' } } } },
    permissions: { type: 'object', additionalProperties: false, properties: {
      groups: { type: 'array', items: { type: 'string' } },
      access_rows: { type: 'array', items: { type: 'object', additionalProperties: false,
        required: ['model'], properties: { model: { type: 'string' }, group: { type: 'string' }, perms: { type: 'string', description: 'rwcd flags, e.g. rwc-' } } } },
      record_rules: { type: 'array', items: { type: 'object', additionalProperties: false,
        required: ['name'], properties: { name: { type: 'string' }, model: { type: 'string' }, domain: { type: 'string' }, groups: { type: 'string' } } } },
      notes: { type: 'string' },
    } },
    cross_refs: { type: 'array', items: { type: 'string' }, description: 'other addons/models it reaches into' },
    tests: { type: 'object', additionalProperties: false, properties: {
      has_tests: { type: 'boolean' }, files: { type: 'array', items: { type: 'string' } },
      covers: { type: 'string' }, gaps: { type: 'string' } } },
    risks: { type: 'array', items: { type: 'object', additionalProperties: false,
      required: ['risk'], properties: { risk: { type: 'string' }, severity: { type: 'string' }, evidence: { type: 'string' } } } },
  },
}

const deepPrompt = (a) => `${CTX}

Map ONE Odoo addon: ${a}
Directory: ${BASE}${a}

Read these from that directory and fill the schema from EVIDENCE:
- __manifest__.py -> version, summary, depends, data files
- models/*.py -> the REAL business logic (not generic Odoo boilerplate): what operations, computed fields, constraints, workflows, _inherit. List key models (name, file, 1-line purpose), cap ~12.
- security/ir.model.access.csv -> each row as {model, group, perms} where perms is rwcd flags (e.g. "rwc-" = read/write/create, no delete)
- security/*.xml or *security*/*groups* -> security groups (name) and record rules (name, model, domain, groups)
- views/*.xml -> note key screens (brief)
- tests/ -> has_tests, file names, what they cover, and gaps

Set kind = "cmc-custom" (or "utility" if it is report_xlsx / server_environment).
For ambiguity: flag where business logic is stubbed/TODO/incomplete/under-specified or where a real business rule is unclear from the code — this is the operator's core pain (vague nghiep vu). Cite file evidence.
For risks: data-isolation, financial correctness, missing constraints, dead code. Be concrete. Your return value IS the data object — no prose outside the schema.`

const lightPrompt = (a) => `${CTX}

This is a VENDORED base addon (OpenEduCat or OCA), NOT CMC custom: ${a}
Directory: ${BASE}${a}

Do a LIGHT pass only (the CMC custom addons build on top of these, so we need the dependency edges + base permissions):
- __manifest__.py -> version, summary (one line of its role), depends
- security/ir.model.access.csv -> rows as {model, group, perms}
- security groups + record rules XML if present
Set kind = "vendored" (or "utility" for report_xlsx / server_environment). Set business_logic to a single line describing its role. models = key model names only. Skip deep model analysis, ambiguity, tests, risks unless something jumps out. Your return value IS the data object.`

const relPrompt = (corpus) => `${CTX}

Below is dependency + cross-reference data for all CMC Odoo addons (JSON: addon, kind, summary, depends, cross_refs, model names):
${corpus}

Produce a Markdown section "## Module map & relationships (phan he)". Include:
1. Subsystem clusters — group the addons into functional phan he (e.g. Academic core, Grading & Exam, Admission & CRM, Finance/Payroll/Discount/Invoice/Fees, Facility & Access control, Dashboards & KPI, Test booking/bank/paper, Parent meetings, Certificates, Theme/Reports). For each cluster list its addons + 1-line role.
2. Dependency overview — the openeducat base layer vs the cmc custom layer; who builds on whom.
3. Coupling hotspots — addons that many depend on; heavy cross-refs; any circular risk.
4. A clean decomposition proposal — how to think about phan he boundaries so permissions and tests can be reasoned about per-cluster.
5. A Mermaid flowchart (\`\`\`mermaid) of the major edges: cmc_* -> openeducat_* and cmc_* -> cmc_*. Keep it readable (group by cluster; omit utility noise).
Cite addon names. Mark inference vs evidence. This is the answer to "what relates to what".`

const permPrompt = (corpus) => `${CTX}

Below is aggregated permission data for all CMC Odoo addons (JSON: addon, kind, summary, permissions{groups, access_rows[model,group,perms], record_rules}):
${corpus}

Produce a Markdown section "## Permission decomposition (phan quyen)". Include:
1. GROUPS inventory — every security group, marked cmc-defined vs openeducat-base, with the role each implies.
2. Permission MATRIX — for each major model domain (students, grades, attendance, fees/finance, facilities, admin/config), a compact table of which groups have r/w/c/d.
3. RECORD RULES — which data-isolation rules exist (especially multi-facility scoping and program scoping for STUDENT data) and, critically, where they are MISSING (a group with write/create on student- or facility-scoped data but no record rule = cross-facility data leak).
4. FINDINGS ranked by severity (with file/addon evidence + confidence high/med/low): over-broad grants (perms on global groups like base.group_user), models with access rows but no group restriction, admin/config models exposed to non-admin groups, financial models (payroll, discount, invoice, fees) with weak controls, and missing multi-facility/program isolation on minors' data.
This is an EDUCATION system holding minors' data across multiple facilities — flag data-isolation gaps hard. Mark inference vs evidence.`

const logicPrompt = (corpus) => `${CTX}

Below is per-module business-logic, ambiguity, tests, and risk data for all CMC Odoo addons (JSON):
${corpus}

Produce a Markdown section "## Business-logic clarity & test gaps". Include:
1. A table: Module | What it does (1 line) | Maturity (solid / partial / vague / stub) | Tests (good / thin / none) | Completion risk (low/med/high). One row per cmc_* addon (+ education_auto_invoice).
2. VAGUE / under-specified modules — the operator says the business logic (nghiep vu) is mo ho (vague) and untested. List the modules where the code does NOT make the business rules clear, ranked, with the specific ambiguity and file evidence. This is the #1 deliverable.
3. Test-coverage reality per module — what is actually tested vs claimed.
4. HONEST reconciliation — CMC's own docs claim "~88-90% complete, 86/86 Odoo TCs pass, production-ready". Does the evidence support that for the Odoo side? Where is the gap between paper-done and real-done? Be direct, evidence-based, cite addons. Mark inference vs evidence.`

const criticPrompt = (rel, perm, logic, index) => `${CTX}

You are an ADVERSARIAL reviewer. Three synthesis sections about CMC's Odoo ERP follow, plus an addon index. Your job: find what they got wrong or missed — do NOT rubber-stamp, but do NOT manufacture issues either; if a section is sound, say so plainly.

ADDON INDEX:
${index}

=== RELATIONSHIPS ===
${rel}

=== PERMISSIONS ===
${perm}

=== LOGIC/TESTS ===
${logic}

Produce a Markdown section "## Adversarial review & gaps". Check specifically:
1. Unsupported / overstated claims (a module rated "solid" or a permission called "safe" without evidence).
2. MISSED high-risk areas — permission/data-isolation gaps for multi-facility minors' data; financial modules (cmc_payroll_simple, cmc_discount, education_auto_invoice, openeducat_fees) with weak controls; modules whose business logic is critically vague but rated too generously.
3. Whether the docs-claim-vs-evidence reconciliation is honest and not softened.
List specific corrections + any NEW findings, each with evidence + confidence. End with the 3 things the operator should look at FIRST.`

// ---- Phase 1: extract ----
phase('Extract')
const deepThunks = CMC_DEEP.map((a) => () => agent(deepPrompt(a), { label: `extract:${a}`, phase: 'Extract', schema: ADDON_SCHEMA }))
const lightThunks = VENDORED.map((a) => () => agent(lightPrompt(a), { label: `vendor:${a}`, phase: 'Extract', schema: ADDON_SCHEMA }))
const records = (await parallel(deepThunks.concat(lightThunks))).filter(Boolean)
log(`extracted ${records.length}/${CMC_DEEP.length + VENDORED.length} addons`)

// in-script aggregation (deterministic, free)
const known = new Set(records.map((r) => r.addon))
const depEdges = []
for (const r of records) for (const d of (r.depends || [])) if (known.has(d)) depEdges.push({ from: r.addon, to: d })
const permRows = []
for (const r of records) {
  const p = r.permissions || {}
  for (const row of (p.access_rows || [])) permRows.push({ addon: r.addon, model: row.model, group: row.group || '', perms: row.perms || '' })
}
const recordRules = []
for (const r of records) {
  const p = r.permissions || {}
  for (const rr of (p.record_rules || [])) recordRules.push({ addon: r.addon, name: rr.name, model: rr.model || '', domain: rr.domain || '', groups: rr.groups || '' })
}

// ---- Phase 2: synthesize ----
phase('Synthesize')
const relInput = JSON.stringify(records.map((r) => ({ addon: r.addon, kind: r.kind, summary: r.summary, depends: r.depends, cross_refs: r.cross_refs, models: (r.models || []).map((m) => m.name) })))
const permInput = JSON.stringify(records.map((r) => ({ addon: r.addon, kind: r.kind, summary: r.summary, permissions: r.permissions })))
const logicInput = JSON.stringify(records.filter((r) => r.kind !== 'vendored').map((r) => ({ addon: r.addon, kind: r.kind, summary: r.summary, business_logic: r.business_logic, ambiguity: r.ambiguity, tests: r.tests, risks: r.risks })))

const [rel, perm, logic] = await parallel([
  () => agent(relPrompt(relInput), { label: 'synth:relationships', phase: 'Synthesize' }),
  () => agent(permPrompt(permInput), { label: 'synth:permissions', phase: 'Synthesize' }),
  () => agent(logicPrompt(logicInput), { label: 'synth:logic-tests', phase: 'Synthesize' }),
])

// ---- Phase 3: adversarial review ----
phase('Review')
const indexMd = records.map((r) => `- ${r.addon} [${r.kind || '?'}]: ${(r.summary || '').slice(0, 140)}`).join('\n')
const critic = await agent(criticPrompt(rel || '(missing)', perm || '(missing)', logic || '(missing)', indexMd), { label: 'critic', phase: 'Review' })

return {
  count: records.length,
  expected: CMC_DEEP.length + VENDORED.length,
  addons: records.map((r) => ({ addon: r.addon, kind: r.kind, summary: r.summary, depends: r.depends || [], has_tests: !!(r.tests && r.tests.has_tests), risk_n: (r.risks || []).length, ambiguity_n: (r.ambiguity || []).length })),
  depEdges,
  permRows,
  recordRules,
  relationships_md: rel,
  permissions_md: perm,
  logic_test_md: logic,
  critic_md: critic,
}
