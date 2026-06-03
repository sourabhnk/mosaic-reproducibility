-- ============================================
-- Mosaic — Target Structure (AlphaFold + druggability)
-- Idempotent: safe to re-run on existing DBs.
-- ============================================

CREATE TABLE IF NOT EXISTS target_structure (
    target_id            VARCHAR PRIMARY KEY REFERENCES targets(id) ON DELETE CASCADE,
    uniprot_id           VARCHAR,
    afdb_version         VARCHAR,
    afdb_url             VARCHAR,
    pdb_url              VARCHAR,
    cif_url              VARCHAR,
    pae_url              VARCHAR,

    -- Confidence summary
    seq_length           INTEGER,
    mean_plddt           FLOAT,
    median_plddt         FLOAT,
    plddt_high_frac      FLOAT,   -- frac residues pLDDT >= 90 (very high)
    plddt_confident_frac FLOAT,   -- frac pLDDT >= 70 (confident)
    plddt_low_frac       FLOAT,   -- frac pLDDT <  50 (likely disordered)
    disorder_frac        FLOAT,   -- alias for plddt_low_frac, kept for clarity
    plddt_per_residue    JSONB,   -- raw [float] array (optional, capped)

    -- Druggability (fpocket / pocket detection)
    pocket_count         INTEGER,
    top_pocket_volume    FLOAT,
    top_pocket_score     FLOAT,   -- fpocket "Druggability Score" 0-1
    pockets              JSONB,   -- top-N pocket detail [{rank,score,volume,residues}]

    -- Derived druggability tier from structural signals only
    structural_tier      VARCHAR, -- 'highly_druggable' | 'druggable' | 'challenging' | 'undruggable'

    -- Provenance
    source               VARCHAR DEFAULT 'alphafold',
    fetched_at           TIMESTAMPTZ,
    computed_at          TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_target_structure_uniprot
    ON target_structure(uniprot_id);
CREATE INDEX IF NOT EXISTS idx_target_structure_tier
    ON target_structure(structural_tier);
CREATE INDEX IF NOT EXISTS idx_target_structure_pocket_score
    ON target_structure(top_pocket_score DESC NULLS LAST);
