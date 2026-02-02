-- =========================================
-- YALLA TBIB - RAFRAÎCHIR LE CACHE DE SCHÉMA
-- Date: 13/10/2025
-- Objectif: Forcer Supabase à détecter les nouvelles tables
-- =========================================

-- Notifier PostgREST de recharger le schéma
NOTIFY pgrst, 'reload schema';

-- Autoriser l'accès anonyme aux tables pour les tests
-- (À RETIRER EN PRODUCTION - utiliser RLS proprement)

-- Désactiver temporairement RLS pour les tests
ALTER TABLE public.drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- Créer des politiques permissives pour les tests
DROP POLICY IF EXISTS "Allow public read access to drivers" ON public.drivers;
CREATE POLICY "Allow public read access to drivers" ON public.drivers
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read access to vehicles" ON public.vehicles;
CREATE POLICY "Allow public read access to vehicles" ON public.vehicles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read access to patients" ON public.patients;
CREATE POLICY "Allow public read access to patients" ON public.patients
    FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow public access to rides" ON public.rides;
CREATE POLICY "Allow public access to rides" ON public.rides
    FOR ALL USING (true);

-- Réactiver RLS avec politiques permissives
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Schema cache rafraîchi et RLS configuré pour les tests';
    RAISE NOTICE '⚠️  ATTENTION: En production, utilisez des politiques RLS strictes !';
END $$;
