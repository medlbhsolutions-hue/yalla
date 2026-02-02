-- ============================================
-- CRÉATION DES POLICIES SÉCURISÉES
-- ============================================
-- EXÉCUTER CE SCRIPT APRÈS LE NETTOYAGE
-- ============================================

-- Vérifier qu'il n'y a aucune policy existante
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'driver_locations';
  
  IF policy_count > 0 THEN
    RAISE EXCEPTION '❌ ERREUR: Il reste % policies. Exécutez d''abord le script de nettoyage.', policy_count;
  ELSE
    RAISE NOTICE '✅ OK: Aucune policy existante, on peut créer les nouvelles';
  END IF;
END $$;

-- Révoquer toutes les permissions
REVOKE ALL ON TABLE "public"."driver_locations" FROM anon;
REVOKE ALL ON TABLE "public"."driver_locations" FROM authenticated;
REVOKE ALL ON TABLE "public"."driver_locations" FROM public;

-- ============================================
-- CRÉER LES 4 POLICIES SÉCURISÉES
-- ============================================

-- Policy 1: Les chauffeurs peuvent INSÉRER leur propre position
CREATE POLICY "Drivers can insert own location"
ON "public"."driver_locations"
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM drivers
    WHERE drivers.id = driver_locations.driver_id
    AND drivers.user_id = auth.uid()
  )
);

-- Policy 2: Les chauffeurs peuvent METTRE À JOUR leur propre position
CREATE POLICY "Drivers can update own location"
ON "public"."driver_locations"
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM drivers
    WHERE drivers.id = driver_locations.driver_id
    AND drivers.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM drivers
    WHERE drivers.id = driver_locations.driver_id
    AND drivers.user_id = auth.uid()
  )
);

-- Policy 3: Les utilisateurs authentifiés peuvent LIRE les positions
CREATE POLICY "Anyone authenticated can view driver locations"
ON "public"."driver_locations"
FOR SELECT
TO authenticated
USING (true);

-- Policy 4: Les utilisateurs anonymes peuvent LIRE les positions
-- (Nécessaire pour la carte publique - peut être supprimé si non souhaité)
CREATE POLICY "Anonymous can view driver locations"
ON "public"."driver_locations"
FOR SELECT
TO anon
USING (true);

-- ============================================
-- ACCORDER LES PERMISSIONS MINIMALES
-- ============================================

-- Lecture pour tout le monde
GRANT SELECT ON TABLE "public"."driver_locations" TO authenticated;
GRANT SELECT ON TABLE "public"."driver_locations" TO anon;

-- Écriture SEULEMENT pour les utilisateurs authentifiés
-- (La policy vérifiera que c'est bien le bon chauffeur)
GRANT INSERT, UPDATE ON TABLE "public"."driver_locations" TO authenticated;

-- ============================================
-- VÉRIFICATION FINALE
-- ============================================

DO $$
DECLARE
  policy_count INTEGER;
  dangerous_policies INTEGER;
BEGIN
  -- Compter toutes les policies
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'driver_locations';
  
  -- Compter les policies dangereuses (INSERT/UPDATE pour anon)
  -- FIX: Conversion correcte du type name[] vers text[]
  SELECT COUNT(*) INTO dangerous_policies
  FROM pg_policies
  WHERE tablename = 'driver_locations'
  AND 'anon' = ANY(roles::text[])
  AND cmd IN ('INSERT', 'UPDATE');
  
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '📊 RÉSULTAT DE LA SÉCURISATION';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'Nombre total de policies: %', policy_count;
  RAISE NOTICE 'Policies dangereuses (anon INSERT/UPDATE): %', dangerous_policies;
  
  IF policy_count = 4 AND dangerous_policies = 0 THEN
    RAISE NOTICE '✅ SUCCÈS: Configuration sécurisée !';
  ELSIF dangerous_policies > 0 THEN
    RAISE EXCEPTION '❌ ÉCHEC: Il reste % policies dangereuses !', dangerous_policies;
  ELSE
    RAISE WARNING '⚠️ ATTENTION: Nombre de policies incorrect (attendu: 4, trouvé: %)', policy_count;
  END IF;
  
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Afficher le résumé des policies
SELECT 
  policyname AS "Policy",
  cmd AS "Opération",
  roles::text[] AS "Rôles",
  CASE 
    WHEN cmd IN ('INSERT', 'UPDATE') AND 'anon' = ANY(roles::text[]) THEN '🔴 DANGEREUX'
    WHEN cmd = 'SELECT' THEN '🟢 Lecture seule'
    ELSE '🟡 Écriture sécurisée'
  END AS "Sécurité"
FROM pg_policies
WHERE tablename = 'driver_locations'
ORDER BY 
  CASE cmd
    WHEN 'INSERT' THEN 1
    WHEN 'UPDATE' THEN 2
    WHEN 'SELECT' THEN 3
    ELSE 4
  END,
  policyname;
