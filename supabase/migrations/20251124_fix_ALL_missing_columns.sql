-- Fix COMPLET: Ajouter TOUTES les colonnes manquantes
-- Date: 24 novembre 2025
-- Tables: patients, drivers

-- ==========================================
-- TABLE PATIENTS - Toutes les colonnes
-- ==========================================

-- 1. phone_number
ALTER TABLE public.patients 
ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);

-- 2. notes
ALTER TABLE public.patients 
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Commentaires
COMMENT ON COLUMN public.patients.phone_number IS 'Numéro de téléphone du patient';
COMMENT ON COLUMN public.patients.notes IS 'Notes médicales ou commentaires sur le patient';

-- ==========================================
-- TABLE DRIVERS - Toutes les colonnes
-- ==========================================

-- 1. phone_number
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);

-- 2. license_number
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS license_number VARCHAR(50);

-- 3. vehicle_brand
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS vehicle_brand VARCHAR(50);

-- 4. vehicle_model
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS vehicle_model VARCHAR(50);

-- 5. vehicle_plate_number
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS vehicle_plate_number VARCHAR(20);

-- 6. vehicle_year
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS vehicle_year INTEGER;

-- 7. vehicle_color
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS vehicle_color VARCHAR(30);

-- 8. vehicle_capacity
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS vehicle_capacity INTEGER;

-- Commentaires
COMMENT ON COLUMN public.drivers.phone_number IS 'Numéro de téléphone du chauffeur';
COMMENT ON COLUMN public.drivers.license_number IS 'Numéro du permis de conduire';
COMMENT ON COLUMN public.drivers.vehicle_brand IS 'Marque du véhicule (ex: Toyota, Peugeot)';
COMMENT ON COLUMN public.drivers.vehicle_model IS 'Modèle du véhicule (ex: Corolla, 208)';
COMMENT ON COLUMN public.drivers.vehicle_plate_number IS 'Plaque d''immatriculation';
COMMENT ON COLUMN public.drivers.vehicle_year IS 'Année du véhicule';
COMMENT ON COLUMN public.drivers.vehicle_color IS 'Couleur du véhicule';
COMMENT ON COLUMN public.drivers.vehicle_capacity IS 'Nombre de places (passagers)';

-- ==========================================
-- VÉRIFICATION FINALE
-- ==========================================

-- Vérifier toutes les colonnes PATIENTS
SELECT 
    '✅ PATIENTS' as table_info,
    column_name,
    data_type,
    CASE WHEN is_nullable = 'YES' THEN 'NULL' ELSE 'NOT NULL' END as nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'patients'
ORDER BY column_name;

-- Vérifier toutes les colonnes DRIVERS
SELECT 
    '✅ DRIVERS' as table_info,
    column_name,
    data_type,
    CASE WHEN is_nullable = 'YES' THEN 'NULL' ELSE 'NOT NULL' END as nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'drivers'
ORDER BY column_name;

-- ==========================================
-- RÉSUMÉ
-- ==========================================
-- PATIENTS: +2 colonnes (phone_number, notes)
-- DRIVERS: +8 colonnes (phone_number, license_number, vehicle_brand, vehicle_model, 
--                       vehicle_plate_number, vehicle_year, vehicle_color, vehicle_capacity)
-- TOTAL: 10 colonnes ajoutées
-- ==========================================
