-- ============================================
-- NETTOYAGE COMPLET DES POLICIES DANGEREUSES
-- ============================================
-- EXÉCUTER CE SCRIPT EN PREMIER
-- ============================================

-- Supprimer TOUTES les policies existantes (bonnes et mauvaises)
DROP POLICY IF EXISTS "Simulation All Access" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Simulation Update Policy" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Simulation Insert Policy" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Drivers can insert own location" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Drivers can update own location" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Anyone authenticated can view driver locations" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Anonymous can view driver locations" ON "public"."driver_locations";

-- ⚠️ SUPPRIMER LES POLICIES DANGEREUSES DÉTECTÉES
DROP POLICY IF EXISTS "Enable insert for anon regarding driver locations" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Enable select for anon regarding driver locations" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Enable update for anon regarding driver locations" ON "public"."driver_locations";
DROP POLICY IF EXISTS "authenticated_view_driver_locations" ON "public"."driver_locations";

-- Supprimer toute autre policy qui pourrait exister
DO $$
DECLARE
  policy_record RECORD;
BEGIN
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'driver_locations'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.driver_locations', policy_record.policyname);
    RAISE NOTICE 'Supprimée: %', policy_record.policyname;
  END LOOP;
END $$;

-- Vérifier que tout est supprimé
SELECT 
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ SUCCÈS: Toutes les policies ont été supprimées'
    ELSE '❌ ERREUR: Il reste ' || COUNT(*) || ' policies'
  END AS "Statut"
FROM pg_policies
WHERE tablename = 'driver_locations';
