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
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS compounds (
    id VARCHAR PRIMARY KEY,          -- chembl_id or name
    name VARCHAR NOT NULL,
    chembl_id VARCHAR UNIQUE,
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
