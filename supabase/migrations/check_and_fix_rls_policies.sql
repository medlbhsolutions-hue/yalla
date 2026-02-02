-- =========================================
-- VÉRIFICATION ET CORRECTION DES POLITIQUES RLS
-- Pour permettre aux utilisateurs de créer leur profil
-- =========================================

-- 1. Vérifier les politiques existantes sur patients
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual, 
    with_check 
FROM pg_policies 
WHERE tablename IN ('patients', 'drivers', 'users')
ORDER BY tablename, policyname;

-- 2. Corriger/ajouter la politique INSERT pour patients
-- Permet à un utilisateur authentifié de créer SON profil patient
DROP POLICY IF EXISTS "Users can create own patient profile" ON public.patients;
CREATE POLICY "Users can create own patient profile" ON public.patients
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- 3. Corriger/ajouter la politique INSERT pour drivers
DROP POLICY IF EXISTS "Users can create own driver profile" ON public.drivers;
CREATE POLICY "Users can create own driver profile" ON public.drivers
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- 4. Vérifier que RLS est activé
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 5. Politique SELECT pour patients (peuvent voir leur propre profil)
DROP POLICY IF EXISTS "Users can view own patient profile" ON public.patients;
CREATE POLICY "Users can view own patient profile" ON public.patients
    FOR SELECT 
    USING (auth.uid() = user_id);

-- 6. Politique UPDATE pour patients (peuvent modifier leur propre profil)
DROP POLICY IF EXISTS "Users can update own patient profile" ON public.patients;
CREATE POLICY "Users can update own patient profile" ON public.patients
    FOR UPDATE 
    USING (auth.uid() = user_id);

-- 7. Politique SELECT pour drivers
DROP POLICY IF EXISTS "Users can view own driver profile" ON public.drivers;
CREATE POLICY "Users can view own driver profile" ON public.drivers
    FOR SELECT 
    USING (auth.uid() = user_id);

-- 8. Politique UPDATE pour drivers
DROP POLICY IF EXISTS "Users can update own driver profile" ON public.drivers;
CREATE POLICY "Users can update own driver profile" ON public.drivers
    FOR UPDATE 
    USING (auth.uid() = user_id);

-- 9. Politiques pour la table users (si nécessaire)
DROP POLICY IF EXISTS "Users can view own user record" ON public.users;
CREATE POLICY "Users can view own user record" ON public.users
    FOR SELECT 
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own user record" ON public.users;
CREATE POLICY "Users can update own user record" ON public.users
    FOR UPDATE 
    USING (auth.uid() = id);

-- 10. Message de confirmation
SELECT 'Politiques RLS configurées avec succès!' as message;

-- 11. Vérifier que les politiques sont bien appliquées
SELECT 
    tablename, 
    policyname, 
    cmd 
FROM pg_policies 
WHERE tablename IN ('patients', 'drivers', 'users')
ORDER BY tablename, cmd, policyname;
