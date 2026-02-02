-- =========================================
-- YALLA TBIB - DÉSACTIVER RLS POUR TESTS
-- ⚠️ À UTILISER UNIQUEMENT EN DÉVELOPPEMENT
-- =========================================

-- Désactiver RLS sur toutes les tables pour permettre les tests
ALTER TABLE IF EXISTS public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.driver_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.rides DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.payments DISABLE ROW LEVEL SECURITY;

-- Supprimer toutes les politiques existantes
DROP POLICY IF EXISTS "Drivers can view own data" ON public.drivers;
DROP POLICY IF EXISTS "Drivers can update own data" ON public.drivers;
DROP POLICY IF EXISTS "Drivers can manage own vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Drivers can manage own documents" ON public.driver_documents;
DROP POLICY IF EXISTS "Patients can view own data" ON public.patients;
DROP POLICY IF EXISTS "Patients can update own data" ON public.patients;
DROP POLICY IF EXISTS "Users can view own rides" ON public.rides;

-- Créer des politiques permissives pour les tests
CREATE POLICY "Allow all access for testing - drivers" ON public.drivers
    FOR ALL USING (true);

CREATE POLICY "Allow all access for testing - vehicles" ON public.vehicles
    FOR ALL USING (true);

CREATE POLICY "Allow all access for testing - patients" ON public.patients
    FOR ALL USING (true);

CREATE POLICY "Allow all access for testing - rides" ON public.rides
    FOR ALL USING (true);

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '⚠️  RLS désactivé et politiques permissives créées pour TESTS uniquement';
    RAISE NOTICE '✅ Vous pouvez maintenant lire les données sans authentification';
END $$;
