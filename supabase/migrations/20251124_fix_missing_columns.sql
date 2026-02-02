-- Fix: Ajouter les colonnes manquantes dans patients et drivers
-- Date: 24 novembre 2025

-- ==========================================
-- 1. Table PATIENTS - Ajouter 'allergies'
-- ==========================================

DO $$ 
BEGIN
    -- Vérifier si la colonne 'allergies' existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'patients' 
        AND column_name = 'allergies'
    ) THEN
        -- Ajouter la colonne allergies
        ALTER TABLE public.patients 
        ADD COLUMN allergies TEXT[];
        
        COMMENT ON COLUMN public.patients.allergies IS 'Liste des allergies du patient (array de strings)';
        
        RAISE NOTICE 'Colonne allergies ajoutée à la table patients';
    ELSE
        RAISE NOTICE 'Colonne allergies existe déjà dans patients';
    END IF;
END $$;

-- ==========================================
-- 2. Table DRIVERS - Ajouter 'license_expiry_date'
-- ==========================================

DO $$ 
BEGIN
    -- Vérifier si la colonne 'license_expiry_date' existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'drivers' 
        AND column_name = 'license_expiry_date'
    ) THEN
        -- Ajouter la colonne license_expiry_date
        ALTER TABLE public.drivers 
        ADD COLUMN license_expiry_date DATE;
        
        COMMENT ON COLUMN public.drivers.license_expiry_date IS 'Date d''expiration du permis de conduire';
        
        RAISE NOTICE 'Colonne license_expiry_date ajoutée à la table drivers';
    ELSE
        RAISE NOTICE 'Colonne license_expiry_date existe déjà dans drivers';
    END IF;
END $$;

-- ==========================================
-- 3. Vérification
-- ==========================================

-- Vérifier les colonnes de patients
SELECT 
    'patients' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'patients'
AND column_name IN ('allergies', 'medical_conditions')
ORDER BY column_name;

-- Vérifier les colonnes de drivers
SELECT 
    'drivers' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'drivers'
AND column_name IN ('license_expiry_date', 'license_number')
ORDER BY column_name;
