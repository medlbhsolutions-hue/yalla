-- Version SIMPLIFIÉE pour debug
-- Exécuter d'abord cette version, puis ajouter les policies après

-- 1. Supprimer la table si elle existe déjà (pour réessayer)
DROP TABLE IF EXISTS public.driver_documents CASCADE;

-- 1.5. Ajouter colonne 'role' dans users si elle n'existe pas
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'users' 
        AND column_name = 'role'
    ) THEN
        ALTER TABLE public.users ADD COLUMN role VARCHAR(20) DEFAULT 'patient' CHECK (role IN ('patient', 'driver', 'admin'));
        COMMENT ON COLUMN public.users.role IS 'Rôle utilisateur: patient, driver, admin';
    END IF;
END $$;

-- 2. Créer la table SANS policies d'abord
CREATE TABLE public.driver_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL,
    user_id UUID NOT NULL,
    document_type VARCHAR(50) NOT NULL,
    file_url TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER,
    mime_type VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    admin_notes TEXT,
    validated_by UUID,
    validated_at TIMESTAMPTZ,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Contraintes
    CONSTRAINT fk_driver FOREIGN KEY (driver_id) REFERENCES public.drivers(id) ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT fk_validator FOREIGN KEY (validated_by) REFERENCES auth.users(id),
    CONSTRAINT chk_document_type CHECK (document_type IN ('license', 'insurance', 'registration', 'criminal_record')),
    CONSTRAINT chk_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

-- 3. Index
CREATE INDEX idx_driver_documents_driver_id ON public.driver_documents(driver_id);
CREATE INDEX idx_driver_documents_user_id ON public.driver_documents(user_id);
CREATE INDEX idx_driver_documents_status ON public.driver_documents(status);
CREATE INDEX idx_driver_documents_type ON public.driver_documents(document_type);
CREATE INDEX idx_driver_documents_uploaded_at ON public.driver_documents(uploaded_at DESC);

-- 4. Trigger updated_at
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

-- 5. Activer RLS
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;

-- 6. Policies - Chauffeurs
CREATE POLICY "Drivers can view own documents"
    ON public.driver_documents
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Drivers can insert own documents"
    ON public.driver_documents
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Drivers can update own pending documents"
    ON public.driver_documents
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id AND status = 'pending')
    WITH CHECK (auth.uid() = user_id);

-- 7. Policies - Admins
CREATE POLICY "Admins can view all documents"
    ON public.driver_documents
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

CREATE POLICY "Admins can update all documents"
    ON public.driver_documents
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- 8. Commentaires
COMMENT ON TABLE public.driver_documents IS 'Documents uploadés par les chauffeurs';
COMMENT ON COLUMN public.driver_documents.document_type IS 'Type: license, insurance, registration, criminal_record';
COMMENT ON COLUMN public.driver_documents.status IS 'Statut: pending, approved, rejected';

-- ✅ Vérification
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'driver_documents'
ORDER BY ordinal_position;
