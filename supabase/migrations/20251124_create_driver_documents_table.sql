-- Migration: Créer table driver_documents pour stocker metadata des documents chauffeurs
-- Date: 2025-11-24
-- Description: Stocke les informations sur les documents uploadés (permis, assurance, etc.)

-- Table driver_documents
CREATE TABLE IF NOT EXISTS public.driver_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Type de document
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('license', 'insurance', 'registration', 'criminal_record')),
    
    -- URL du fichier dans Supabase Storage
    file_url TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER, -- en bytes
    mime_type VARCHAR(100),
    
    -- Statut validation
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    
    -- Notes admin
    admin_notes TEXT,
    validated_by UUID REFERENCES auth.users(id), -- ID de l'admin qui a validé
    validated_at TIMESTAMPTZ,
    
    -- Dates
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ, -- Pour documents avec expiration (assurance, permis)
    
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour performances
CREATE INDEX IF NOT EXISTS idx_driver_documents_driver_id ON public.driver_documents(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_documents_user_id ON public.driver_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_driver_documents_status ON public.driver_documents(status);
CREATE INDEX IF NOT EXISTS idx_driver_documents_type ON public.driver_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_driver_documents_uploaded_at ON public.driver_documents(uploaded_at DESC);

-- Trigger pour updated_at
CREATE OR REPLACE FUNCTION update_driver_documents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_driver_documents_updated_at
    BEFORE UPDATE ON public.driver_documents
    FOR EACH ROW
    EXECUTE FUNCTION update_driver_documents_updated_at();

-- RLS (Row Level Security)
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;

-- Policy: Chauffeurs peuvent lire LEURS documents
CREATE POLICY "Drivers can view own documents"
    ON public.driver_documents
    FOR SELECT
    USING (auth.uid() = public.driver_documents.user_id);

-- Policy: Chauffeurs peuvent insérer LEURS documents
CREATE POLICY "Drivers can insert own documents"
    ON public.driver_documents
    FOR INSERT
    WITH CHECK (auth.uid() = public.driver_documents.user_id);

-- Policy: Chauffeurs peuvent mettre à jour LEURS documents (si status=pending)
CREATE POLICY "Drivers can update own pending documents"
    ON public.driver_documents
    FOR UPDATE
    USING (auth.uid() = public.driver_documents.user_id AND public.driver_documents.status = 'pending')
    WITH CHECK (auth.uid() = public.driver_documents.user_id);

-- Policy: Admins peuvent tout voir
CREATE POLICY "Admins can view all documents"
    ON public.driver_documents
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE public.users.id = auth.uid() 
            AND public.users.role = 'admin'
        )
    );

-- Policy: Admins peuvent tout mettre à jour (validation)
CREATE POLICY "Admins can update all documents"
    ON public.driver_documents
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE public.users.id = auth.uid() 
            AND public.users.role = 'admin'
        )
    );

-- Commentaires
COMMENT ON TABLE public.driver_documents IS 'Stocke les documents uploadés par les chauffeurs (permis, assurance, carte grise, casier judiciaire)';
COMMENT ON COLUMN public.driver_documents.document_type IS 'Type: license (permis), insurance (assurance), registration (carte grise), criminal_record (casier judiciaire)';
COMMENT ON COLUMN public.driver_documents.status IS 'Statut validation: pending (en attente), approved (approuvé), rejected (rejeté)';
COMMENT ON COLUMN public.driver_documents.file_url IS 'URL complète du fichier dans Supabase Storage bucket driver-documents';
COMMENT ON COLUMN public.driver_documents.expires_at IS 'Date expiration du document (ex: assurance expire dans 1 an)';
