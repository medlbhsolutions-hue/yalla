-- =========================================
-- YALLA TBIB - NETTOYAGE SCHÉMA EXISTANT
-- À exécuter AVANT le schéma complet si erreur "already exists"
-- =========================================

-- Désactiver RLS temporairement
ALTER TABLE IF EXISTS public.payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.rides DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.driver_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.users DISABLE ROW LEVEL SECURITY;

-- Supprimer les vues
DROP VIEW IF EXISTS public.rides_full CASCADE;
DROP VIEW IF EXISTS public.drivers_full CASCADE;

-- Supprimer les tables (dans l'ordre inverse des dépendances)
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.rides CASCADE;
DROP TABLE IF EXISTS public.driver_documents CASCADE;
DROP TABLE IF EXISTS public.patients CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;
DROP TABLE IF EXISTS public.drivers CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Supprimer les types ENUM
DROP TYPE IF EXISTS payment_method CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS priority_level CASCADE;
DROP TYPE IF EXISTS ride_status CASCADE;
DROP TYPE IF EXISTS document_status CASCADE;
DROP TYPE IF EXISTS document_type CASCADE;
DROP TYPE IF EXISTS vehicle_type CASCADE;
DROP TYPE IF EXISTS driver_specialization CASCADE;
DROP TYPE IF EXISTS driver_status CASCADE;

-- Supprimer la fonction de trigger
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Nettoyage terminé ! Vous pouvez maintenant exécuter le schéma complet.';
END $$;
