-- ============================================
-- CORRECTION SÉCURITÉ CRITIQUE #1 - VERSION 2
-- Nettoyage et recréation sécurisée des RLS policies
-- ============================================
-- Date: 16 Décembre 2025
-- Priorité: CRITIQUE
-- Version: 2.0 (Idempotent - peut être exécuté plusieurs fois)
-- ============================================

-- ÉTAPE 1: SUPPRIMER TOUTES LES POLICIES EXISTANTES
-- Cela garantit un état propre avant de recréer
DROP POLICY IF EXISTS "Simulation All Access" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Simulation Update Policy" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Simulation Insert Policy" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Drivers can insert own location" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Drivers can update own location" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Anyone authenticated can view driver locations" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Anonymous can view driver locations" ON "public"."driver_locations";

-- ÉTAPE 2: RÉVOQUER LES PERMISSIONS TROP LARGES
REVOKE ALL ON TABLE "public"."driver_locations" FROM anon;
REVOKE ALL ON TABLE "public"."driver_locations" FROM authenticated;

-- ÉTAPE 3: CRÉER LES POLICIES SÉCURISÉES

-- Policy 1: Les chauffeurs peuvent INSÉRER leur propre position
CREATE POLICY "Drivers can insert own location"
ON "public"."driver_locations"
FOR INSERT
TO authenticated
WITH CHECK (
  -- Vérifier que l'utilisateur connecté est bien le chauffeur
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

-- Policy 3: Tout le monde (authentifié) peut LIRE les positions des chauffeurs
-- Nécessaire pour que les patients voient où est leur chauffeur
CREATE POLICY "Anyone authenticated can view driver locations"
ON "public"."driver_locations"
FOR SELECT
TO authenticated
USING (true);

-- Policy 4: Les utilisateurs anonymes peuvent LIRE les positions (pour la carte publique)
-- OPTIONNEL: Commenter cette policy si vous ne voulez pas de carte publique
CREATE POLICY "Anonymous can view driver locations"
ON "public"."driver_locations"
FOR SELECT
TO anon
USING (true);

-- ÉTAPE 4: ACCORDER LES PERMISSIONS MINIMALES NÉCESSAIRES
GRANT SELECT ON TABLE "public"."driver_locations" TO authenticated;
GRANT SELECT ON TABLE "public"."driver_locations" TO anon;
GRANT INSERT, UPDATE ON TABLE "public"."driver_locations" TO authenticated;

-- ÉTAPE 5: VÉRIFICATION FINALE
-- Cette requête doit retourner exactement 4 policies
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'driver_locations';
  
  RAISE NOTICE '✅ Nombre de policies créées: %', policy_count;
  
  IF policy_count = 4 THEN
    RAISE NOTICE '✅ SUCCÈS: Toutes les policies de sécurité sont en place';
  ELSE
    RAISE WARNING '⚠️ ATTENTION: Nombre de policies incorrect (attendu: 4, trouvé: %)', policy_count;
  END IF;
END $$;

-- Afficher les policies créées
SELECT 
  policyname AS "Nom de la Policy",
  cmd AS "Opération",
  roles AS "Rôles",
  CASE 
    WHEN permissive = 'PERMISSIVE' THEN '✅ Permissive'
    ELSE '❌ Restrictive'
  END AS "Type"
FROM pg_policies
WHERE tablename = 'driver_locations'
ORDER BY policyname;

-- ============================================
-- RÉSULTAT ATTENDU
-- ============================================
-- Vous devriez voir:
-- 1. "Anonymous can view driver locations" | SELECT | {anon}
-- 2. "Anyone authenticated can view driver locations" | SELECT | {authenticated}
-- 3. "Drivers can insert own location" | INSERT | {authenticated}
-- 4. "Drivers can update own location" | UPDATE | {authenticated}
-- ============================================
