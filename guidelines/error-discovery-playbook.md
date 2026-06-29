# Error-Discovery & System-Audit Playbook

> **Purpose.** A portable, cross-project playbook for *hunting* errors — not just fixing the one in front of you —
> and for guaranteeing the **accuracy, completeness, and performance** of any system we build. It distills hard-won
> lessons into a reusable framework: what to look for, when and where to check, how to prove correctness, and what to avoid.
>
> **Scope.** Domain-agnostic. Written for data/ETL/analytics/conversion work (where it was born) but the principles
> apply to any engineering. Concrete examples are marked *(case study)* and are illustrations, not requirements.
>
> **How to use.** This is a **living checklist + doctrine**. At the start of any verification, audit, "is this correct?",
> "convert this", or "re-certify" task, load this file and work the relevant sections. It is shareable as-is: drop it into
> any project's `guidelines/` (or reference it globally) to upgrade that project instantly.
>
> **Status:** LIVING DOCUMENT — must be updated proactively whenever a new mistake, learning, skill, or guideline emerges
> (see §10). **Last updated:** 2026-06-29.

---

## 0. The one-line creed
**A "✅ certified / correct" claim is only as trustworthy as the weakest link in how it was verified.** Find the weakest
link *before* you trust the claim. Most bugs are not wrong math — they are **unverified assumptions** that happened to look right.

---

## 1. Core principles (the doctrine)

1. **Discover, don't just fix.** The goal of debugging is to find *all* errors of a *class*, not patch the one symptom you
   tripped over. Every bug found is a prompt: "what else of this kind exists?" Turn one finding into a sweep.
2. **Never infer what you can read.** If a source defines something (a formula, a spec, a schema, an API contract), **read
   the actual definition**. Inferring a mapping from a coincidental value match is the single most dangerous habit. *(case
   study: claimed a column "uses the sheet's own cost basis" from value mismatches — the real formula pointed somewhere else entirely.)*
3. **A match is not a proof.** Two numbers being equal does not mean they were computed the same way, on the same population,
   from the same source. Equal-by-coincidence is rampant. Demand *mechanism* parity, not just *value* parity.
4. **Anchors must be real.** Every spot-check / certification must be pinned to a **real, present, non-blank, correctly-identified**
   entity. A check against a blank or mis-identified key passes vacuously and lies to you. *(case study: a parity test anchored
   on a spreadsheet row whose key cell was blank — the "exact match" was pure coincidence.)*
5. **Spot-checks pass while the bulk is wrong.** Reconcile **whole populations**, not 3–8 hand-picked rows. Counts, sums,
   distributions, and set-membership across the entire table catch what anchors miss.
6. **Cross-check independently.** The same quantity computed two different ways (by two engines, two queries, two agents) must
   agree. Disagreement = a real bug somewhere. Independent/adversarial verification catches errors that self-review never will.
   *(case study: in a multi-agent audit, the verifier agents caught the tracer agents' own mistakes — wrong anchor, wrong counts, wrong file.)*
7. **Confirm domain intent; don't assume it.** Definitions ("what is a *new* customer?", "what does *rank* mean here?") are
   owned by the domain expert. Guessing the definition produces a technically-clean, semantically-wrong system. Ask. *(case
   studies: a ranking was 60-day-first-then-all-time, not all-time; a "monitor" was a *new-acquisition* tracker on a different population.)*
8. **Surface gaps loudly; never hide them.** Silent truncation, silent NULLs, silent "top-N", silent deferrals all read as
   "fully covered" when they aren't. If you bound coverage, **log/warn it**. Visible warnings > invisible debt.
9. **Verify before you fix, and verify after.** Reproduce and root-cause first; fix at the **source** (the ETL/ingestion/spec,
   not the symptom); then re-run and re-verify end-to-end. Then **lock a regression test** so it can't silently come back.
10. **Make verification permanent and automatic.** A one-time check rots. Encode audits as repeatable tests wired into the
    build/rebuild pipeline that **fail loud**. The audit is a product, not an event.
11. **Honesty over green checkmarks.** Report what is *actually* proven vs. merely *not-yet-disproven*. "Not reproduced" and
    "cannot determine" are valid, valuable verdicts. Relabel over-claims the moment you find them.
12. **Mirror the reference as a *checker*, never as the *system*.** When converting from a reference artifact (a spreadsheet,
    a legacy system, another team's model), the **source of truth is the canonical raw data, not the reference**. Re-implement
    the *business logic* against the raw data (so you can normalize, correct the reference's bugs, evolve, and scale). Do **not**
    transcribe the reference one-to-one into code — that bakes in its bugs/artifacts/stale snapshots, locks you to its structure,
    and recreates the very ceiling you're trying to escape. The reference's one virtue — total fidelity — is worth harvesting,
    but **only as an independent verification oracle** (see §6.10), not as the production system. *(architecture decision: kept a
    per-logic ETL as the system; added a workbook-value oracle as an automated witness, rather than building a formula transpiler.)*
13. **Size the surface; report bounds, not false precision.** Before claiming "X of N converted/covered/verified", define the
    unit honestly. Logic often collapses to far fewer **distinct templates** than raw cells/lines (e.g. millions of formula cells →
    a few hundred distinct templates → a few dozen load-bearing ones). When a clean 1:1 count doesn't exist, give **defensible
    bounds + status**, not a fabricated exact number — quoting false precision is itself the inference error (P2).

---

## 2. Taxonomy of error classes (what actually goes wrong)

Hunt for each of these explicitly — they recur across every project:

| # | Error class | Smell / how it hides | Real example |
|---|---|---|---|
| E1 | **Unverified anchor** | a spot-check keyed on a blank/missing/mis-identified id | cert anchored on a blank-key row → coincidental "exact" |
| E2 | **Coincidental value-match** | "the number matches!" but the formula/source/window differ | 30D ratio equalled a different row's value by luck |
| E3 | **Untraced source / inference** | "it probably comes from X" without reading X | mis-attributed a column's source; real formula elsewhere |
| E4 | **Internal-recompute ≠ source parity** | validated against your own recompute, never against the source of truth | a module "verified" only by re-deriving from your own data |
| E5 | **Silent incompleteness** | header/sentinel rows ingested as data; NULL columns; deferred-but-undocumented | a column-header label ingested as a real entity (all-zeros) |
| E6 | **Sentinel/bucket leakage** | "unattributed/other/0" buckets leak into per-entity tables | `'0'` unattributed bucket leaked into a per-entity matrix |
| E7 | **Wrong population** | right metric, wrong set of rows | built on the full cohort when the spec meant newly-acquired only |
| E8 | **Count-invisible gaps** | row-count looks fine; coverage is not | 173 vs 170 implied ~3 missing; real gap was 27 |
| E9 | **Sign / unit / type errors** | negatives stored positive; % vs proportion; ids cast to number | commission sign, ¥ vs ¥/kg, id as int dropping leading zeros |
| E10 | **Definition drift** | your definition ≠ the domain's definition | "rank by all-time GMV" vs the real "60D-first, all-time fallback" |
| E11 | **Different-formula-same-name** | a KPI matches loosely but is computed differently | `count(*)` vs `AGGREGATE(per-group COUNTIF)` — passed only via tolerance |
| E12 | **Stale/again-after-fix** | a fixed bug returns because nothing locked it | no regression test → drift on next rebuild |

---

## 3. The 5-dimension audit framework (what to look for)

Run all five. They are complementary; each catches a different class.

### D1 — Anchor validity
- Every parity/spot-check anchor exists, is non-blank, and is the entity you think it is (verify the *key*, not just the value).
- Catches: E1, E10.

### D2 — Coverage & completeness
- Row counts vs. expected; **population definition** matches the spec; no header/sentinel rows; no silent NULL columns.
- Reconcile the *whole* set: totals, distinct counts, set membership, min/max — not just anchors.
- Catches: E5, E7, E8.

### D3 — Cross-engine consistency
- The same quantity from different producers must agree (e.g. a total in module A == sum of detail in module B == the KPI in dashboard C).
- Hierarchies are nested (subset ⊆ set), parts sum to whole, joins don't drop/duplicate rows.
- Catches: E2, E4, E11.

### D4 — Invariants & integrity
- **Signs/ranges**: costs ≤ 0 (or ≥ 0) consistently; ratios in [0,1] or [-1,1]; no negative counts; dates in range.
- **Keys**: primary keys unique; no blank/`'0'`/null keys; referential integrity (every foreign key resolves).
- **Sentinels**: scan text/numeric columns for residual `BLANK / #REF! / #VALUE! / #N/A / NaN / None / 不合格 / nan`.
- **Internal recompute**: a derived column equals its definition recomputed from its own row (e.g. `pct == num/den`).
- Catches: E5, E6, E9, E12.

### D5 — Formula / spec trace re-certification (the gold standard)
- Read the **actual** source definition (formula text, spec, contract) and reproduce its *mechanism*, then match the source's
  own output values on **real** anchors. This is the only thing that disproves E2/E3/E4.
- For each metric, classify the verdict precisely (see §5 ladder). Mark `cannot_determine` rather than guess.
- Catches: E2, E3, E4, E10, E11.

---

## 4. When & where to check (triggers and checkpoints)

- **On every "convert / reproduce / certify" task** → D5 (trace the real definition) + D1 (real anchor) before claiming parity.
- **On "is this correct?" / "audit this"** → run all of D1–D5.
- **After any fix** → re-run the affected build + the full audit; confirm the fix and confirm no regressions.
- **After any schema/population/definition change** → update the audit's own assumptions (the audit can go stale too — *(case
  study: a system-integrity audit hard-coded the old population and had to be updated when the definition was corrected)*).
- **Before sign-off / "done"** → tests pass *and* audit clean *and* claims honestly labeled; verify against **real/live data**, not fixtures.
- **Continuously** → the permanent audit runs on every rebuild and fails loud.
- **Right after green / right before summarizing** → scan what you touched for dead artifacts, stale docs, sentinel leakage, untested paths.

---

## 5. The verification ladder — how to guarantee accuracy

Rank every "it matches" claim by *how* it was verified. **Only the top rung is true parity.** State which rung you're on.

1. **Asserted / inferred** (no verification) — worthless. Never ship as "verified."
2. **Value-match** — your output equals the source's displayed value, but you did not trace the source's mechanism.
   Vulnerable to E2/E11 (coincidence, different formula). Acceptable only as a *weak* signal, explicitly labeled.
3. **Internal-recompute** — validated against your own independent recomputation, not the source of truth. Proves internal
   consistency, **not** correctness vs the source. Label as such.
4. **Formula/spec-trace + cell/record parity** — you read the actual definition, reproduced the mechanism, and matched the
   source's own output on **real, full-precision anchors** across **multiple** real rows. **This is the only rung that certifies parity.**
5. **Adversarial multi-witness** — rung 4, independently reproduced by a separate party/agent instructed to *refute* it, plus
   whole-population reconciliation. Reserve for high-stakes numbers.

> Tolerances are a smell. If a check "passes only within 0.5%", that often means a **different formula** (E11), not a rounding
> difference — investigate the mechanism before accepting it.

---

## 6. Techniques & recipes (the skills)

**6.1 Cross-engine reconciliation.** For each headline number, write it as an equality across producers and assert it
(`Σ detail == rollup == dashboard KPI`). Disagreement localizes the bug.

**6.2 Whole-population reconciliation.** Beyond anchors: assert row counts, distinct-key counts, group-by sums, set
membership (A⊆B), and min/max ranges over the entire table.

**6.3 Invariant battery.** Encode sign conventions, ratio ranges, hierarchy nesting (core⊆net⊆full), PK uniqueness,
referential integrity, and "derived == recomputed-from-its-own-row" as assertions.

**6.4 Residual-sentinel scan.** Sweep text/number columns for source sentinels that should have become NULL/typed
(`BLANK/#REF!/#VALUE!/#N/A/NaN/None/不合格`). Their presence means a cleaning step was skipped.

**6.5 Read the real definition.** Don't trust documentation or memory of the source — open it. For locked/large/odd source
files, find a robust read path (e.g. read-shared file handles for locked files; stream rather than load gigabytes; resolve
indirections like shared-string tables / lookups / spill anchors). Decode the mechanism, then reproduce it.

**6.6 Multi-agent trace → adversarial verify → synthesize.** For breadth + confidence: fan out one tracer per target to read
the real definitions; then an independent verifier per target instructed to **refute** each finding against the source *and*
the live system; then synthesize. Diversity of witnesses catches both system bugs *and* the tracers' own errors. Give agents
the read recipe, the live-data access method, and the hard rule: **trace, never infer; mark `cannot_determine` over guessing.**

**6.7 Permanent audit as a wired-in test.** Codify D1–D4 (and any reproducible D5 checks) as a single repeatable audit that
runs on every rebuild and exits non-zero on hard inconsistencies. Separate **FAIL** (hard contradiction, must fix) from **WARN**
(known/benign gap, kept visible). Keep WARNs in the output forever — visible debt, not hidden.

**6.8 Verify-before-fix loop.** Reproduce → root-cause at the **source** → fix → re-run the affected build → re-run the full
audit + parity suite → update docs/schema → **lock a regression test** → record the learning (here + project memory).

**6.9 Honest labeling.** Distinguish, in code and docs: *source-converted* (traced + certified) vs *derived/native* (our own
addition, no source anchor) vs *deferred* (explicit NULL + reason). Never let a native invention masquerade as a conversion.

**6.10 Source-fidelity oracle (automated independent witness).** Harvest the reference artifact's *total fidelity* as a
**checker**, not the system (P12). Build a small, repeatable oracle that, for each load-bearing metric, reads the reference's
**own computed value** (e.g. a spreadsheet cell's cached result, a legacy report's printed number, a golden file) and compares
it to your pipeline's **independent recompute from canonical data**. Two independent computations of the same number, diffed
automatically, on every rebuild → catches *your* logic drift without hand-picking anchors and without trusting the parity tests
you wrote yourself. Keep it **targeted** (the load-bearing few dozen, not every cell) and wire it into the build. *(case study:
a workbook oracle (grown to ~39 metrics across 7 sheets) reading `<v>` cached values vs our SQL recompute — flagged a 0.02
rounding gap, proving it compares rather than rubber-stamps; growing it also caught a bug in the oracle's *own* cell reader
— the checker needed checking, see CS-9.)* Note: a *full* transpiler/evaluator of the reference is usually impractical (and re-imports its
bugs); a targeted value-oracle gives ~all the assurance at a fraction of the cost.

**6.11 Size the conversion/verification surface.** Count the *distinct logic templates*, not raw cells/lines, to know how much
there really is to trace (collapse by normalizing identifiers/coordinates). Then triage to the **load-bearing** subset (the
handful that everything else references or rolls up to) and trace those exhaustively first. Report coverage as **bounds + status**
when a clean 1:1 mapping doesn't exist (P13).

---

## 7. What to AVOID (anti-patterns)

- ❌ Inferring a source/mapping from a value coincidence instead of reading the actual definition. *(the original sin)*
- ❌ Certifying against one hand-picked anchor — especially without verifying the anchor's key is real and non-blank.
- ❌ Treating value-match or internal-recompute as if it were source parity.
- ❌ Trusting row-count equality as proof of coverage (E8).
- ❌ Loosening a tolerance to make a check pass instead of investigating the mechanism (E11).
- ❌ Ingesting whatever the source emits without filtering headers, totals, and sentinel/`'0'`/"other" buckets (E5/E6).
- ❌ Building to your *assumption* of a domain definition without confirming intent (E10).
- ❌ Silent truncation / silent NULL columns / undocumented deferrals.
- ❌ Fixing the symptom (patching the output) instead of the source (the ETL/spec).
- ❌ Fixing without locking a regression test (E12).
- ❌ Letting the audit itself go stale after a definition change (update the audit's assumptions too).
- ❌ Reporting "done/verified" when it is "not-yet-disproven." Overclaiming destroys trust faster than a known gap.

---

## 8. The standard operating procedure (put it together)

For any "make this correct / convert / audit" unit of work:
1. **Read the real definition** of every output (D5). Decode the mechanism.
2. **Confirm domain intent** with the owner where the definition encodes a business choice.
3. **Reproduce the mechanism**, sourced from the right inputs/population.
4. **Certify on real, multi-row, full-precision anchors** (rung 4+).
5. **Reconcile the whole population + cross-engine + invariants** (D2/D3/D4).
6. **Surface every gap** as an explicit WARN/NULL+reason; label native vs converted vs deferred.
7. **Lock a regression test**; wire the system-wide audit into the rebuild.
8. **Record the learning** — update this playbook (§10) and the project's memory.

---

## 9. Case studies (concrete, anonymizable)

- **CS-1 — Inference instead of trace.** A column was documented as "uses the source's own cost basis," concluded from value
  mismatches. Reading the real formula showed it indexed a *different* block entirely. → Lesson: never infer a source (E3, P2).
- **CS-2 — Blank anchor.** A parity test was pinned to row N, but row N's key cell was blank; the spill of real entities started
  one row later. The "exact match" was coincidence. → Always validate the anchor key (E1, D1).
- **CS-3 — Header ingested as data.** The source's own column-header label was ingested as a real entity (all-zeros), inflating
  counts. Found by cross-count reconciliation. → Filter headers/sentinels at ingestion (E5, D2).
- **CS-4 — Bucket leakage.** The `'0'` unattributed-sales bucket leaked into a per-entity matrix (84 rows). → Exclude
  "other/unattributed/0" from per-entity tables; scan for blank/`'0'` keys (E6, D4).
- **CS-5 — Count-invisible gap.** A 173-vs-170 row difference implied ~3 missing; the real coverage hole was 27. → Reconcile
  membership, not just counts (E8, D2).
- **CS-6 — Different formula, same name.** An "events total" matched within 0.5% — but the source used `AGGREGATE(per-group
  COUNTIF)` while we used `count(*)`. Passing only via tolerance was the tell. → Trace the mechanism (E11, §5 note).
- **CS-7 — Wrong definition (rank).** A rank shipped as all-time-GMV; the real spec was **60-day-GMV first, all-time fallback**.
  → Confirm domain intent; read the ordering formula (E10, P7).
- **CS-8 — Wrong population.** A "daily monitor" was built over the full sales cohort; it was actually a **new-influencer
  acquisition tracker** over a different population (those with a confirmed first sample). → Confirm what the artifact is *for*
  before choosing its rows (E7, P7).
- **CS-9 — The audit went stale.** After CS-8's definition change, the system-integrity audit still asserted the old
  population and failed — correctly flagging that *its own* assumptions needed updating. → Audits are code; maintain them (D-§4).
- **CS-10 — Multi-witness caught the witnesses.** In a multi-agent audit, adversarial verifiers caught the tracer agents'
  *own* errors (value mis-attributed to the wrong entity, a wrong distinct-count, a wrong source-file pointer). → Independent,
  refutation-oriented verification is worth its cost (P6, 6.6).
- **CS-11 — Mirror as checker, not system.** Faced with "should we transcribe every formula 1:1 into code?", chose to keep the
  per-logic system (sourced from raw data, able to correct the reference's bugs and evolve) and instead built a **targeted
  value-oracle** (§6.10): 11 load-bearing cells read straight from the reference vs the pipeline's recompute, wired into the
  rebuild. Got the fidelity-check benefit without importing the reference's bugs or losing evolvability (P12, 6.10).
- **CS-12 — Bounds over false precision.** Asked "how many of N templates are converted?", there was no clean 1:1 answer
  (we convert outputs, not formulas; templates repeat across sheets). Reporting honest **bounds + status** (e.g. "≤538 of 723,
  ~146 definitely not, ~38 ingested-as-values") was correct; a fabricated exact number would have been the inference sin (P13, P2).

---

## 10. Maintenance protocol (this file is alive — keep it that way)

**This is a MUST, every session:**
- When a **new mistake** is made or found → add it to §2 (taxonomy) and/or §9 (case study), and derive a guideline.
- When a **new technique/skill** proves useful → add it to §6.
- When a **new guardrail** is learned → add it to §1, §5, §7, or §8 as appropriate.
- Keep examples **anonymizable/portable** — state the *lesson* generically; the case is just illustration.
- Bump **Last updated** and add a **Changelog** line on every edit.
- This file lives in `~/.claude/guidelines/` so **all projects inherit it automatically**; it is referenced from the canonical
  `guidelines.md`. To share with an external project, copy this file into that project's `guidelines/` (or reference it) —
  it is self-contained by design.
- Proactively offer to update this file whenever a verification/audit/correction episode yields a new lesson — do not wait to be asked.

---

## Changelog
- **2026-06-29 (b)** — Added P12 (mirror as checker, not system) + P13 (size the surface; bounds over false precision);
  techniques §6.10 (source-fidelity oracle) + §6.11 (size the conversion/verification surface); case studies CS-11, CS-12.
  Born from the architecture decision to keep a per-logic ETL and add a targeted workbook-value oracle (11/11 metrics witnessed) rather than transcribe formulas 1:1.
- **2026-06-29** — Created. Distilled from an error-discovery exercise: the originating inference bug (CS-1), the blank-anchor
  certification (CS-2), a system-wide integrity audit that found a header artifact (CS-3) and a sentinel-bucket leak (CS-4) and
  a count-invisible coverage gap (CS-5), a multi-agent formula-trace audit that exposed a different-formula KPI (CS-6), a wrong
  ranking definition (CS-7) and a wrong population (CS-8), the audit-went-stale lesson (CS-9), and adversarial verifiers catching
  the tracers' own errors (CS-10). Established the creed (§0), doctrine (§1), taxonomy (§2), 5-dimension framework (§3),
  trigger checkpoints (§4), the verification ladder (§5), techniques (§6), anti-patterns (§7), SOP (§8), and this maintenance protocol (§10).
