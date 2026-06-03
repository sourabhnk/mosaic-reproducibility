-- ============================================
-- Mosaic Relational Schema (replaces Apache AGE graph)
-- Compatible with Neon, standard PostgreSQL 14+
-- ============================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================
-- Entity Tables (replace AGE vertex labels)
-- ============================================

CREATE TABLE IF NOT EXISTS targets (
    id VARCHAR PRIMARY KEY,          -- gene symbol (e.g. 'EGFR')
    symbol VARCHAR NOT NULL,
    name VARCHAR,
    uniprot_id VARCHAR,
    chembl_id VARCHAR,
    entrez_id VARCHAR,
    target_class VARCHAR,
    protein_family VARCHAR,
    selectivity_group VARCHAR,
    druggability_tier VARCHAR,
    tissue_expression JSONB,
    validation_level VARCHAR,
    disease_association_count INTEGER,
    safety_flags JSONB,
    homology_human_pct FLOAT,
    -- UniProt enrichment fields
    function_description TEXT,
    subcellular_location VARCHAR,
    go_terms JSONB,
    disease_associations JSONB,
    gene_names JSONB,
    protein_length INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS compounds (
    id VARCHAR PRIMARY KEY,          -- chembl_id or name
    name VARCHAR NOT NULL,
    chembl_id VARCHAR UNIQUE,
    pref_name VARCHAR,               -- ChEMBL preferred name (INN/USAN)
    synonyms JSONB,                  -- ["aspirin", "ASA", ...]
    trade_names JSONB,               -- ["Lipitor", "Atorva", ...]
    first_approval INTEGER,          -- year of first regulatory approval
    inchikey VARCHAR,
    smiles TEXT,
    max_phase INTEGER,
    molecular_weight FLOAT,
    logp FLOAT,
    psa FLOAT,
    hbd INTEGER,
    hba INTEGER,
    ro5_violations INTEGER,
    pchembl_value FLOAT,
    selectivity_profile JSONB,
    adme_flags JSONB,
    compound_type VARCHAR,
    series_id VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Idempotent migration: add compound metadata columns if upgrading existing DB
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS pref_name VARCHAR;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS synonyms JSONB;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS trade_names JSONB;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS first_approval INTEGER;

CREATE TABLE IF NOT EXISTS patents (
    id VARCHAR PRIMARY KEY,          -- publication_number
    publication_number VARCHAR UNIQUE NOT NULL,
    title TEXT,
    abstract TEXT,
    filing_date VARCHAR,
    publication_date VARCHAR,
    country_code VARCHAR,
    cpc_codes JSONB,
    claim_count INTEGER,
    priority_date VARCHAR,
    patent_family_id VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS papers (
    id VARCHAR PRIMARY KEY,          -- pmid or doi
    title TEXT,
    pmid VARCHAR,
    doi VARCHAR,
    abstract TEXT,
    publication_date VARCHAR,
    journal VARCHAR,
    citation_count INTEGER,
    mesh_terms JSONB,
    study_type VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS organizations (
    id VARCHAR PRIMARY KEY,          -- name
    name VARCHAR NOT NULL,
    org_type VARCHAR,
    country VARCHAR,
    parent_org VARCHAR,
    is_big_pharma BOOLEAN DEFAULT FALSE,
    therapeutic_focus JSONB,
    founded_year INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS persons (
    id VARCHAR PRIMARY KEY,          -- name
    name VARCHAR NOT NULL,
    orcid VARCHAR,
    affiliation VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS indications (
    id VARCHAR PRIMARY KEY,          -- normalized name
    name VARCHAR NOT NULL,
    mesh_id VARCHAR,
    category VARCHAR,
    therapeutic_area VARCHAR,
    icd_code VARCHAR,
    prevalence_tier VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pathways (
    id VARCHAR PRIMARY KEY,          -- pathway_id
    pathway_id VARCHAR,
    name VARCHAR NOT NULL,
    source VARCHAR,
    category VARCHAR,
    gene_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- Junction / Edge Tables
-- ============================================

-- Compound -> Target activity (TARGETS edge)
CREATE TABLE IF NOT EXISTS compound_targets (
    compound_id VARCHAR NOT NULL REFERENCES compounds(id),
    target_id VARCHAR NOT NULL REFERENCES targets(id),
    activity_type VARCHAR,
    value FLOAT,
    unit VARCHAR,
    pchembl_value FLOAT,
    assay_type VARCHAR,
    source VARCHAR,
    source_doc_id VARCHAR,
    source_doc_type VARCHAR,
    extraction_confidence FLOAT,
    PRIMARY KEY (compound_id, target_id)
);

-- Compound -> Target selectivity (SHOWS_SELECTIVITY edge)
CREATE TABLE IF NOT EXISTS compound_selectivity (
    compound_id VARCHAR NOT NULL REFERENCES compounds(id),
    target_id VARCHAR NOT NULL REFERENCES targets(id),
    selectivity_ratio FLOAT,
    primary_target VARCHAR,
    measurement_type VARCHAR,
    source_doc_id VARCHAR,
    PRIMARY KEY (compound_id, target_id)
);

-- Paper -> Target mentions (MENTIONS_TARGET from Paper)
CREATE TABLE IF NOT EXISTS paper_mentions_target (
    paper_id VARCHAR NOT NULL REFERENCES papers(id),
    target_id VARCHAR NOT NULL REFERENCES targets(id),
    confidence FLOAT DEFAULT 1.0,
    mention_count INTEGER,
    context_type VARCHAR,
    PRIMARY KEY (paper_id, target_id)
);

-- Patent -> Target mentions (MENTIONS_TARGET from Patent)
CREATE TABLE IF NOT EXISTS patent_mentions_target (
    patent_id VARCHAR NOT NULL REFERENCES patents(id),
    target_id VARCHAR NOT NULL REFERENCES targets(id),
    confidence FLOAT DEFAULT 1.0,
    mention_count INTEGER,
    context_type VARCHAR,
    PRIMARY KEY (patent_id, target_id)
);

-- Paper -> Compound mentions (MENTIONS_COMPOUND from Paper)
CREATE TABLE IF NOT EXISTS paper_mentions_compound (
    paper_id VARCHAR NOT NULL REFERENCES papers(id),
    compound_id VARCHAR NOT NULL REFERENCES compounds(id),
    confidence FLOAT DEFAULT 1.0,
    mention_count INTEGER,
    context_type VARCHAR,
    PRIMARY KEY (paper_id, compound_id)
);

-- Patent -> Compound mentions (MENTIONS_COMPOUND from Patent)
CREATE TABLE IF NOT EXISTS patent_mentions_compound (
    patent_id VARCHAR NOT NULL REFERENCES patents(id),
    compound_id VARCHAR NOT NULL REFERENCES compounds(id),
    confidence FLOAT DEFAULT 1.0,
    mention_count INTEGER,
    context_type VARCHAR,
    PRIMARY KEY (patent_id, compound_id)
);

-- Patent -> Organization (ASSIGNED_TO edge)
CREATE TABLE IF NOT EXISTS patent_organizations (
    patent_id VARCHAR NOT NULL REFERENCES patents(id),
    org_id VARCHAR NOT NULL REFERENCES organizations(id),
    PRIMARY KEY (patent_id, org_id)
);

-- Target -> Indication (IMPLICATED_IN edge)
CREATE TABLE IF NOT EXISTS target_indications (
    target_id VARCHAR NOT NULL REFERENCES targets(id),
    indication_id VARCHAR NOT NULL REFERENCES indications(id),
    evidence_type VARCHAR,
    association_score FLOAT,
    source_doc_id VARCHAR,
    PRIMARY KEY (target_id, indication_id)
);

-- Compound -> Indication (TREATS edge)
CREATE TABLE IF NOT EXISTS compound_indications (
    compound_id VARCHAR NOT NULL REFERENCES compounds(id),
    indication_id VARCHAR NOT NULL REFERENCES indications(id),
    max_phase INTEGER,
    clinical_status VARCHAR,
    source_doc_id VARCHAR,
    PRIMARY KEY (compound_id, indication_id)
);

-- Target -> Pathway (PARTICIPATES_IN edge)
CREATE TABLE IF NOT EXISTS target_pathways (
    target_id VARCHAR NOT NULL REFERENCES targets(id),
    pathway_id VARCHAR NOT NULL REFERENCES pathways(id),
    role VARCHAR,
    PRIMARY KEY (target_id, pathway_id)
);

-- Target <-> Target PPI (INTERACTS_WITH edge)
CREATE TABLE IF NOT EXISTS target_interactions (
    target_a_id VARCHAR NOT NULL REFERENCES targets(id),
    target_b_id VARCHAR NOT NULL REFERENCES targets(id),
    interaction_type VARCHAR,
    confidence_score FLOAT,
    source_db VARCHAR,
    PRIMARY KEY (target_a_id, target_b_id)
);

-- Target <-> Target structural similarity (STRUCTURALLY_SIMILAR_TO edge).
-- Populated by scripts/build_foldseek_index.py from the 320 AlphaFold
-- PDBs in data/alphafold/. Move 3 / Task M3.1 — feeds mosaic_find_similar_targets.
-- Asymmetric storage (one row per directed query→neighbor pair) because
-- Foldseek's tm_score normalises over the query length and is therefore
-- direction-dependent — A→B and B→A have different scores.
CREATE TABLE IF NOT EXISTS target_structure_neighbors (
    target_id   VARCHAR NOT NULL REFERENCES targets(id),
    neighbor_id VARCHAR NOT NULL REFERENCES targets(id),
    -- TM-score normalised over the query length (the canonical
    -- "how structurally similar is the query to this hit" metric).
    tm_score    FLOAT,
    -- TM-score normalised over the alignment length only — useful for
    -- detecting shared-fold partial matches between proteins of very
    -- different total length.
    alntmscore  FLOAT,
    -- Alignment expectation (Foldseek default scoring).
    evalue      DOUBLE PRECISION,
    -- Optional rich metrics, kept nullable so a minimal Foldseek output
    -- format can still populate the table.
    lddt        FLOAT,
    rmsd        FLOAT,
    PRIMARY KEY (target_id, neighbor_id),
    CHECK (target_id <> neighbor_id)
);
CREATE INDEX IF NOT EXISTS idx_tsn_target_tm
    ON target_structure_neighbors (target_id, tm_score DESC);

-- Compound <-> Compound SAR (STRUCTURAL_ANALOG_OF edge)
CREATE TABLE IF NOT EXISTS compound_analogs (
    compound_a_id VARCHAR NOT NULL REFERENCES compounds(id),
    compound_b_id VARCHAR NOT NULL REFERENCES compounds(id),
    tanimoto_similarity FLOAT,
    shared_scaffold VARCHAR,
    PRIMARY KEY (compound_a_id, compound_b_id)
);

-- Paper -> Person (AUTHORED_BY edge)
CREATE TABLE IF NOT EXISTS paper_authors (
    paper_id VARCHAR NOT NULL REFERENCES papers(id),
    person_id VARCHAR NOT NULL REFERENCES persons(id),
    position VARCHAR,
    PRIMARY KEY (paper_id, person_id)
);

-- Patent -> Person (INVENTED_BY edge)
CREATE TABLE IF NOT EXISTS patent_inventors (
    patent_id VARCHAR NOT NULL REFERENCES patents(id),
    person_id VARCHAR NOT NULL REFERENCES persons(id),
    PRIMARY KEY (patent_id, person_id)
);

-- Person -> Organization (AFFILIATED_WITH edge)
CREATE TABLE IF NOT EXISTS person_organizations (
    person_id VARCHAR NOT NULL REFERENCES persons(id),
    org_id VARCHAR NOT NULL REFERENCES organizations(id),
    PRIMARY KEY (person_id, org_id)
);

-- Paper -> Target validation (VALIDATES_TARGET edge)
CREATE TABLE IF NOT EXISTS paper_validations (
    paper_id VARCHAR NOT NULL REFERENCES papers(id),
    target_id VARCHAR NOT NULL REFERENCES targets(id),
    validation_type VARCHAR,
    model_system VARCHAR,
    outcome VARCHAR,
    PRIMARY KEY (paper_id, target_id)
);

-- ============================================
-- Indexes for query performance
-- ============================================

-- Entity lookup indexes
CREATE INDEX IF NOT EXISTS idx_targets_symbol ON targets(symbol);
CREATE INDEX IF NOT EXISTS idx_targets_chembl ON targets(chembl_id);
CREATE INDEX IF NOT EXISTS idx_targets_class ON targets(target_class);
CREATE INDEX IF NOT EXISTS idx_targets_name_trgm ON targets USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_compounds_chembl ON compounds(chembl_id);
CREATE INDEX IF NOT EXISTS idx_compounds_name_trgm ON compounds USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_patents_pub_number ON patents(publication_number);
CREATE INDEX IF NOT EXISTS idx_patents_filing_date ON patents(filing_date DESC);

CREATE INDEX IF NOT EXISTS idx_papers_pmid ON papers(pmid);
CREATE INDEX IF NOT EXISTS idx_papers_doi ON papers(doi);
CREATE INDEX IF NOT EXISTS idx_papers_pub_date ON papers(publication_date DESC);

CREATE INDEX IF NOT EXISTS idx_organizations_name ON organizations(name);
CREATE INDEX IF NOT EXISTS idx_indications_name ON indications(name);

-- Junction table FK indexes (for JOIN performance)
CREATE INDEX IF NOT EXISTS idx_ct_target ON compound_targets(target_id);
CREATE INDEX IF NOT EXISTS idx_ct_value ON compound_targets(target_id, value ASC);

CREATE INDEX IF NOT EXISTS idx_pmt_target ON paper_mentions_target(target_id);
CREATE INDEX IF NOT EXISTS idx_pamt_target ON patent_mentions_target(target_id);

CREATE INDEX IF NOT EXISTS idx_pmc_compound ON paper_mentions_compound(compound_id);
CREATE INDEX IF NOT EXISTS idx_pamc_compound ON patent_mentions_compound(compound_id);

CREATE INDEX IF NOT EXISTS idx_po_org ON patent_organizations(org_id);

CREATE INDEX IF NOT EXISTS idx_ti_indication ON target_indications(indication_id);
CREATE INDEX IF NOT EXISTS idx_ci_indication ON compound_indications(indication_id);

CREATE INDEX IF NOT EXISTS idx_tp_pathway ON target_pathways(pathway_id);
CREATE INDEX IF NOT EXISTS idx_tint_b ON target_interactions(target_b_id);

CREATE INDEX IF NOT EXISTS idx_cs_target ON compound_selectivity(target_id);
CREATE INDEX IF NOT EXISTS idx_ca_b ON compound_analogs(compound_b_id);

CREATE INDEX IF NOT EXISTS idx_pv_target ON paper_validations(target_id);

-- ============================================
-- Semantic Relation Extraction (GLiREL)
-- ============================================

CREATE TABLE IF NOT EXISTS semantic_relations (
    id SERIAL PRIMARY KEY,
    source_doc_id VARCHAR NOT NULL,
    source_doc_type VARCHAR NOT NULL,       -- 'paper' or 'patent'
    subject_id VARCHAR NOT NULL,
    subject_type VARCHAR NOT NULL,          -- 'compound', 'target'
    relation_type VARCHAR NOT NULL,         -- from pharma relation taxonomy
    object_id VARCHAR NOT NULL,
    object_type VARCHAR NOT NULL,
    confidence FLOAT NOT NULL,
    evidence_text TEXT,
    model_name VARCHAR NOT NULL,
    extraction_batch_id VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(source_doc_id, subject_id, relation_type, object_id)
);

CREATE TABLE IF NOT EXISTS extraction_batches (
    id VARCHAR PRIMARY KEY,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    doc_type VARCHAR NOT NULL,
    total_docs INTEGER,
    processed_docs INTEGER DEFAULT 0,
    relations_extracted INTEGER DEFAULT 0,
    model_config JSONB,
    status VARCHAR DEFAULT 'running'
);

CREATE INDEX IF NOT EXISTS idx_sr_subject ON semantic_relations(subject_id, subject_type);
CREATE INDEX IF NOT EXISTS idx_sr_object ON semantic_relations(object_id, object_type);
CREATE INDEX IF NOT EXISTS idx_sr_relation ON semantic_relations(relation_type);
CREATE INDEX IF NOT EXISTS idx_sr_doc ON semantic_relations(source_doc_id, source_doc_type);
CREATE INDEX IF NOT EXISTS idx_sr_confidence ON semantic_relations(confidence DESC);

-- Add mechanism_type to compound_targets
ALTER TABLE compound_targets ADD COLUMN IF NOT EXISTS mechanism_type VARCHAR;

-- ============================================
-- Compound enrichment columns (2026-04-11)
-- Fixes "CHEMBL1234 instead of Aspirin" display issue: we now persist
-- pref_name, molecule_synonyms, first_approval, molecule_type, withdrawn_flag
-- and trade_names from ChEMBL /molecule endpoint so tool outputs always
-- have a human-readable name even when molecule.name is NULL.
-- ============================================
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS pref_name VARCHAR;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS synonyms JSONB;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS trade_names JSONB;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS first_approval INTEGER;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS molecule_type VARCHAR;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS withdrawn_flag BOOLEAN DEFAULT FALSE;
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS indication_class VARCHAR;

CREATE INDEX IF NOT EXISTS idx_compounds_pref_name_trgm ON compounds USING gin (pref_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_compounds_molecule_type ON compounds(molecule_type);
CREATE INDEX IF NOT EXISTS idx_compounds_first_approval ON compounds(first_approval);

-- ============================================
-- Trials table (2026-04-11)
-- Replaces synthesized clinical_pipeline (max_phase only) with real
-- ClinicalTrials.gov data so the mosaic_clinical_pipeline tool can
-- surface nct_id, brief_title, phase, status, sponsor, dates.
-- Also unblocks mosaic_trial_results tool (Gosset competitive gap).
-- ============================================
CREATE TABLE IF NOT EXISTS trials (
    nct_id VARCHAR PRIMARY KEY,
    brief_title TEXT,
    official_title TEXT,
    phase VARCHAR,                    -- 'Phase 1' | 'Phase 2' | ... | 'Not Applicable'
    overall_status VARCHAR,           -- 'Recruiting' | 'Completed' | 'Terminated' | ...
    study_type VARCHAR,               -- 'Interventional' | 'Observational'
    lead_sponsor VARCHAR,
    sponsor_class VARCHAR,            -- 'INDUSTRY' | 'NIH' | 'OTHER'
    start_date VARCHAR,
    completion_date VARCHAR,
    enrollment INTEGER,
    conditions JSONB,                 -- array of indication strings
    interventions JSONB,              -- array of {type, name} objects
    primary_outcomes JSONB,
    why_stopped TEXT,
    has_results BOOLEAN DEFAULT FALSE,
    last_update_posted VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trial <-> Target association (resolved by matching intervention names + conditions to our KG)
CREATE TABLE IF NOT EXISTS trial_targets (
    nct_id VARCHAR NOT NULL REFERENCES trials(nct_id) ON DELETE CASCADE,
    target_id VARCHAR NOT NULL REFERENCES targets(id) ON DELETE CASCADE,
    match_confidence FLOAT DEFAULT 1.0,
    match_source VARCHAR,             -- 'intervention_chembl' | 'condition_nlp' | 'manual'
    PRIMARY KEY (nct_id, target_id)
);

CREATE TABLE IF NOT EXISTS trial_compounds (
    nct_id VARCHAR NOT NULL REFERENCES trials(nct_id) ON DELETE CASCADE,
    compound_id VARCHAR NOT NULL REFERENCES compounds(id) ON DELETE CASCADE,
    match_confidence FLOAT DEFAULT 1.0,
    match_source VARCHAR,
    PRIMARY KEY (nct_id, compound_id)
);

CREATE TABLE IF NOT EXISTS trial_indications (
    nct_id VARCHAR NOT NULL REFERENCES trials(nct_id) ON DELETE CASCADE,
    indication_id VARCHAR NOT NULL REFERENCES indications(id) ON DELETE CASCADE,
    PRIMARY KEY (nct_id, indication_id)
);

CREATE INDEX IF NOT EXISTS idx_trials_phase ON trials(phase);
CREATE INDEX IF NOT EXISTS idx_trials_status ON trials(overall_status);
CREATE INDEX IF NOT EXISTS idx_trials_sponsor ON trials(lead_sponsor);
CREATE INDEX IF NOT EXISTS idx_trials_start_date ON trials(start_date DESC);
CREATE INDEX IF NOT EXISTS idx_trial_targets_target ON trial_targets(target_id);
CREATE INDEX IF NOT EXISTS idx_trial_compounds_compound ON trial_compounds(compound_id);
CREATE INDEX IF NOT EXISTS idx_trial_indications_ind ON trial_indications(indication_id);

-- ============================================
-- Webhook idempotency (2026-04-11)
-- Prevents double-processing of Dodo webhook retries.
-- ============================================
CREATE TABLE IF NOT EXISTS webhook_events (
    event_id VARCHAR PRIMARY KEY,     -- Dodo event id from webhook payload
    event_type VARCHAR NOT NULL,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    status VARCHAR DEFAULT 'received', -- 'received' | 'processed' | 'failed'
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_received ON webhook_events(received_at DESC);

-- ============================================
-- Sub-indication taxonomy (Move 1, Sprint 1.1, Task 1.1.1) — 2026-05-15
-- Extends the existing flat `indications` table with a self-referential
-- hierarchy + curated synonyms so tools can resolve fine-grained oncology
-- sub-indications (e.g. "EGFR-mutant NSCLC" -> parent "non_small_cell_lung_carcinoma").
-- Idempotent: yes (ADD COLUMN / CREATE INDEX IF NOT EXISTS).
-- Backward-compatible: all new columns nullable; existing rows untouched.
-- ============================================
ALTER TABLE indications ADD COLUMN IF NOT EXISTS parent_id VARCHAR REFERENCES indications(id);
ALTER TABLE indications ADD COLUMN IF NOT EXISTS source VARCHAR;            -- EFO | MeSH | DOID | manual
ALTER TABLE indications ADD COLUMN IF NOT EXISTS external_id VARCHAR;       -- e.g. EFO_0003060
ALTER TABLE indications ADD COLUMN IF NOT EXISTS synonyms TEXT[];           -- curated surface forms
ALTER TABLE indications ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE indications ADD COLUMN IF NOT EXISTS is_oncology_subtype BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_indications_parent ON indications(parent_id);
CREATE INDEX IF NOT EXISTS idx_indications_external ON indications(external_id);
CREATE INDEX IF NOT EXISTS idx_indications_synonyms ON indications USING gin (synonyms);
CREATE INDEX IF NOT EXISTS idx_indications_onco_subtype
    ON indications(is_oncology_subtype) WHERE is_oncology_subtype;

-- ============================================
-- kg_metadata singleton (Move 1, Sprint 1.2, Task 1.2.1) — 2026-05-15
-- One cached row of KG scope numbers so the scope banner, /kg/metadata
-- endpoint, and mosaic_kg_stats don't run COUNT(*) on every call.
-- Refreshed nightly by scripts/refresh_kg_metadata.py (UPSERT id=1).
-- Idempotent.
-- ============================================
CREATE TABLE IF NOT EXISTS kg_metadata (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    target_count INTEGER DEFAULT 0,
    compound_count INTEGER DEFAULT 0,
    paper_count INTEGER DEFAULT 0,
    patent_count INTEGER DEFAULT 0,
    relation_count INTEGER DEFAULT 0,
    subindication_count INTEGER DEFAULT 0,
    last_refresh_at TIMESTAMPTZ DEFAULT NOW(),
    therapy_areas TEXT[] DEFAULT '{}',
    data_sources JSONB DEFAULT '{}'
);

-- Monotonic KG version (Op-6). Bumped by refresh_kg_metadata.py on every
-- ingestion/refresh; all response caches key on it, so a bump naturally
-- invalidates every cached entry without an explicit purge.
ALTER TABLE kg_metadata ADD COLUMN IF NOT EXISTS kg_version BIGINT NOT NULL DEFAULT 1;

-- Composite graph-edge count (Move 3, 2026-05-27). Sum of rows across
-- the canonical edge tables (compound_targets, target_indications,
-- target_pathways, PPI, coess, variant, analogs, mentions, authors,
-- inventors, resistance_relations, paper_validations). Surfaces the
-- KG-expansion depth in the landing stat band — orthogonal to the
-- existing relation_count (GLiREL semantic_relations only).
ALTER TABLE kg_metadata ADD COLUMN IF NOT EXISTS edge_count BIGINT NOT NULL DEFAULT 0;

-- ============================================
-- Response caches (Op-6) — unit-economics defense.
-- Cache reads are free to the user (don't count against quota).
-- Keys are normalised; no PII enters keys. Entries expire by TTL and a
-- kg_version change makes prior rows unreachable (cleaned nightly).
-- Idempotent.
-- ============================================
CREATE TABLE IF NOT EXISTS tool_response_cache (
    cache_key   TEXT PRIMARY KEY,         -- sha256(tool_name|norm_params|kg_version)
    tool_name   TEXT NOT NULL,
    kg_version  BIGINT NOT NULL,
    response    JSONB NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tool_cache_expires ON tool_response_cache(expires_at);

CREATE TABLE IF NOT EXISTS agent_response_cache (
    cache_key   TEXT PRIMARY KEY,         -- sha256(norm_query|agent_version|kg_version)
    kg_version  BIGINT NOT NULL,
    response    JSONB NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_agent_cache_expires ON agent_response_cache(expires_at);

-- ============================================
-- resistance_relations (Move 2 Task 2.4.R.2) — keyword-mined from paper
-- abstracts. GLiREL's label set has no resistance edge type, so this
-- is a separate deterministic literature pass (mirrors paper_validations).
-- (resistant_target, bypass_target) co-mentioned in a resistance-context
-- abstract; the bypass side is a candidate escape/bypass target.
-- Idempotent.
-- ============================================
CREATE TABLE IF NOT EXISTS resistance_relations (
    id                  BIGSERIAL PRIMARY KEY,
    source_doc_id       VARCHAR NOT NULL,
    resistant_target_id VARCHAR NOT NULL,
    bypass_target_id    VARCHAR NOT NULL,
    resistance_kind     VARCHAR,            -- 'acquired'|'intrinsic'|'bypass'|'general'
    evidence_text       TEXT,
    confidence          FLOAT NOT NULL DEFAULT 0.3,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (source_doc_id, resistant_target_id, bypass_target_id)
);
CREATE INDEX IF NOT EXISTS idx_resist_resistant ON resistance_relations(resistant_target_id);
CREATE INDEX IF NOT EXISTS idx_resist_bypass ON resistance_relations(bypass_target_id);

-- Heuristic modality (Move 2 Task 2.4.R.3), populated by
-- scripts/classify_compound_modality.py for the top-N compounds.
ALTER TABLE compounds ADD COLUMN IF NOT EXISTS modality VARCHAR;

-- ============================================
-- target_wishlist (Move 1, Sprint 1.2, Task 1.2.4) — 2026-05-15
-- Captures requests for out-of-scope targets so the operator can
-- prioritise the next ingestion batch. One row per (gene, email);
-- re-requests bump request_count + last_requested_at. Idempotent.
-- ============================================
CREATE TABLE IF NOT EXISTS target_wishlist (
    gene_symbol VARCHAR NOT NULL,
    user_email VARCHAR NOT NULL DEFAULT 'anonymous',
    notes TEXT,
    request_count INTEGER NOT NULL DEFAULT 1,
    first_requested_at TIMESTAMPTZ DEFAULT NOW(),
    last_requested_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (gene_symbol, user_email)
);

CREATE INDEX IF NOT EXISTS idx_target_wishlist_gene
    ON target_wishlist(gene_symbol);

-- ============================================
-- Watchlists (Move 1, Sprint 1.3, Tasks 1.3.1/1.3.2) — 2026-05-15
-- owner_key holds a users.id (uuid as text), an email, or an
-- 'anon:<token>' session key so anonymous watchlists work before the
-- cookie-session/magic-link auth lands (that is a separate task).
-- Idempotent.
-- ============================================
CREATE TABLE IF NOT EXISTS watchlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_key VARCHAR NOT NULL,
    name VARCHAR NOT NULL DEFAULT 'My watchlist',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_watchlists_owner ON watchlists(owner_key);

CREATE TABLE IF NOT EXISTS watchlist_items (
    watchlist_id UUID NOT NULL REFERENCES watchlists(id) ON DELETE CASCADE,
    item_type VARCHAR NOT NULL,   -- target|indication|organization|compound|relation_type
    item_value VARCHAR NOT NULL,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (watchlist_id, item_type, item_value)
);

CREATE TABLE IF NOT EXISTS watchlist_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    watchlist_id UUID NOT NULL REFERENCES watchlists(id) ON DELETE CASCADE,
    item_type VARCHAR,
    item_value VARCHAR,
    event_type VARCHAR NOT NULL,  -- new_paper|new_patent|new_compound_activity
    event_payload JSONB,
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_watchlist_events_undelivered
    ON watchlist_events(watchlist_id) WHERE delivered_at IS NULL;

-- Generic job watermark (used by detect_watchlist_events + future jobs)
CREATE TABLE IF NOT EXISTS job_state (
    job_name VARCHAR PRIMARY KEY,
    last_ran_at TIMESTAMPTZ,
    state JSONB DEFAULT '{}'
);

-- ============================================
-- Magic-link single-use enforcement (A5) — 2026-05-25
-- Each issued magic-link token has a unique jti; once it is consumed
-- we record the row here so it cannot be replayed even before its
-- 15-minute expiry. Old rows can be pruned >24h after consumed_at
-- (the tokens themselves are long-expired by then).
-- ============================================
CREATE TABLE IF NOT EXISTS magic_link_consumed (
    jti VARCHAR PRIMARY KEY,
    email VARCHAR NOT NULL,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_magic_link_consumed_at
    ON magic_link_consumed(consumed_at);
