-- ============================================
-- PostgreSQL + pgvector Initialization Script
-- Strategic R&D Intelligence Platform (Mosaic)
-- ============================================
-- This script runs automatically when the container starts for the first time
-- Compatible with Neon, standard PostgreSQL 14+

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;      -- For fuzzy text search
CREATE EXTENSION IF NOT EXISTS vector;       -- pgvector for embeddings

-- ============================================
-- Knowledge Graph — Relational Tables
-- (replaces Apache AGE graph layer)
-- ============================================

-- Load schema from src/db/schema.sql
\i /docker-entrypoint-initdb.d/02_graph_schema.sql

-- ============================================
-- Create Vector Embedding Tables (pgvector)
-- ============================================

CREATE SCHEMA IF NOT EXISTS embeddings;

-- Document embeddings (papers + patents) - PubMedBERT 768 dimensions
CREATE TABLE IF NOT EXISTS embeddings.documents (
    id BIGSERIAL PRIMARY KEY,
    doc_id VARCHAR UNIQUE NOT NULL,
    doc_type VARCHAR NOT NULL,           -- 'patent' or 'paper'
    title VARCHAR,
    source VARCHAR,
    pmid VARCHAR,
    doi VARCHAR,
    publication_date VARCHAR,
    embedding vector(768) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Molecule embeddings - ChemBERTa 384 dimensions
CREATE TABLE IF NOT EXISTS embeddings.molecules (
    id BIGSERIAL PRIMARY KEY,
    molecule_id VARCHAR UNIQUE NOT NULL,
    name VARCHAR,
    smiles VARCHAR,
    chembl_id VARCHAR,
    inchikey VARCHAR,
    embedding vector(384) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- HNSW indexes for fast similarity search
CREATE INDEX IF NOT EXISTS idx_doc_embedding_hnsw
    ON embeddings.documents USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_mol_embedding_hnsw
    ON embeddings.molecules USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Lookup indexes
CREATE INDEX IF NOT EXISTS idx_doc_type ON embeddings.documents(doc_type);
CREATE INDEX IF NOT EXISTS idx_mol_chembl ON embeddings.molecules(chembl_id);

-- ============================================
-- Create Analytics Schema
-- ============================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- Target summary table for dashboard performance
CREATE TABLE IF NOT EXISTS analytics.target_summary (
    target_id VARCHAR PRIMARY KEY,
    indication_id VARCHAR,
    gene_symbol VARCHAR,
    target_name VARCHAR,
    target_class VARCHAR,

    -- Activity counts
    patent_count INTEGER DEFAULT 0,
    paper_count INTEGER DEFAULT 0,
    compound_count INTEGER DEFAULT 0,
    active_org_count INTEGER DEFAULT 0,

    -- Recent activity (configurable window)
    recent_patents_12m INTEGER DEFAULT 0,
    recent_papers_12m INTEGER DEFAULT 0,
    new_orgs_12m INTEGER DEFAULT 0,

    -- Velocity metrics
    patent_qoq_change FLOAT,
    paper_qoq_change FLOAT,

    -- Computed scores (0-100 scale)
    scientific_validation_score FLOAT,
    competitive_intensity_score FLOAT,
    momentum_score FLOAT,
    druggability_score FLOAT,
    target_attractiveness_score FLOAT,

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Organization summary table
CREATE TABLE IF NOT EXISTS analytics.organization_summary (
    org_id VARCHAR,
    indication_id VARCHAR,
    org_name VARCHAR,
    org_type VARCHAR,  -- pharma, biotech, academic

    -- Portfolio metrics
    targets_active INTEGER DEFAULT 0,
    total_patents INTEGER DEFAULT 0,
    total_papers INTEGER DEFAULT 0,

    -- Focus metrics
    concentration_ratio FLOAT,  -- Focus on top target

    -- Activity metrics
    recent_patents_6m INTEGER DEFAULT 0,
    filing_velocity FLOAT,

    -- Computed scores
    portfolio_breadth_score FLOAT,
    activity_intensity_score FLOAT,

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    PRIMARY KEY (org_id, indication_id)
);

-- Compound summary table
CREATE TABLE IF NOT EXISTS analytics.compound_summary (
    compound_id VARCHAR PRIMARY KEY,
    target_id VARCHAR,
    compound_name VARCHAR,
    smiles VARCHAR,
    inchikey VARCHAR,

    -- Properties
    best_ic50_nm FLOAT,
    activity_type VARCHAR,
    molecular_weight FLOAT,

    -- Computed scores
    potency_rank INTEGER,
    novelty_score FLOAT,

    -- Patent coverage
    patent_count INTEGER DEFAULT 0,
    assignee_orgs TEXT[],

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trend data table (replaces DuckDB trend_data)
CREATE TABLE IF NOT EXISTS analytics.trend_data (
    target_id VARCHAR NOT NULL,
    indication_id VARCHAR NOT NULL,
    period VARCHAR NOT NULL,        -- e.g., '2024-Q1'
    patent_count INTEGER DEFAULT 0,
    paper_count INTEGER DEFAULT 0,
    new_org_count INTEGER DEFAULT 0,
    PRIMARY KEY (target_id, indication_id, period)
);

-- Activity data table (replaces DuckDB activity_data)
CREATE TABLE IF NOT EXISTS analytics.activity_data (
    activity_id VARCHAR PRIMARY KEY,
    compound_id VARCHAR,
    target_id VARCHAR,
    activity_type VARCHAR,
    activity_value FLOAT,
    activity_unit VARCHAR,
    pchembl_value FLOAT,
    source VARCHAR,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Document embeddings tracking (replaces DuckDB document_embeddings)
CREATE TABLE IF NOT EXISTS analytics.document_embeddings (
    doc_id VARCHAR PRIMARY KEY,
    doc_type VARCHAR,               -- 'patent' or 'paper'
    indication_id VARCHAR,
    title VARCHAR,
    embedding_id VARCHAR,           -- Reference to embeddings.documents.id
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- Create Indexes for Performance
-- ============================================

-- Analytics table indexes
CREATE INDEX IF NOT EXISTS idx_target_summary_indication
    ON analytics.target_summary(indication_id);

CREATE INDEX IF NOT EXISTS idx_target_summary_tas
    ON analytics.target_summary(target_attractiveness_score DESC);

CREATE INDEX IF NOT EXISTS idx_org_summary_indication
    ON analytics.organization_summary(indication_id);

CREATE INDEX IF NOT EXISTS idx_compound_summary_target
    ON analytics.compound_summary(target_id);

CREATE INDEX IF NOT EXISTS idx_trend_data_target
    ON analytics.trend_data(target_id);

CREATE INDEX IF NOT EXISTS idx_activity_data_compound
    ON analytics.activity_data(compound_id);

CREATE INDEX IF NOT EXISTS idx_activity_data_target
    ON analytics.activity_data(target_id);

-- ============================================
-- Create Ingestion Tracking Table
-- ============================================

CREATE SCHEMA IF NOT EXISTS ingestion;

CREATE TABLE IF NOT EXISTS ingestion.run_log (
    run_id SERIAL PRIMARY KEY,
    source_name VARCHAR NOT NULL,  -- 'epo', 'pubmed', 'chembl'
    indication_id VARCHAR,
    run_type VARCHAR NOT NULL,  -- 'incremental', 'backfill'
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    status VARCHAR DEFAULT 'running',  -- 'running', 'completed', 'failed'
    documents_fetched INTEGER DEFAULT 0,
    documents_processed INTEGER DEFAULT 0,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS ingestion.last_sync (
    source_name VARCHAR NOT NULL,
    indication_id VARCHAR NOT NULL,
    last_sync_date TIMESTAMP NOT NULL,
    last_document_id VARCHAR,
    PRIMARY KEY (source_name, indication_id)
);

-- ============================================
-- Grant Permissions
-- ============================================

GRANT ALL PRIVILEGES ON SCHEMA analytics TO mosaic_user;
GRANT ALL PRIVILEGES ON SCHEMA ingestion TO mosaic_user;
GRANT ALL PRIVILEGES ON SCHEMA embeddings TO mosaic_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO mosaic_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ingestion TO mosaic_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA embeddings TO mosaic_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ingestion TO mosaic_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA embeddings TO mosaic_user;

-- Print success message
DO $$
BEGIN
    RAISE NOTICE 'Mosaic database initialization complete!';
    RAISE NOTICE 'Relational graph: 8 entity tables + 16 junction tables created';
    RAISE NOTICE 'Schemas: analytics, ingestion, embeddings created with tables';
    RAISE NOTICE 'Extensions: pg_trgm, vector (pgvector) enabled';
END $$;
