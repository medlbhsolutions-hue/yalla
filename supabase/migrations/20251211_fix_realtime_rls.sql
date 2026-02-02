-- ============================================
-- FIX REALTIME & RLS POUR PATIENT TRACKING
-- À exécuter dans Supabase SQL Editor
-- ============================================

-- 1. Realtime déjà activé - SKIP cette partie
-- Les tables rides, driver_locations, chat_messages sont déjà dans supabase_realtime

-- 2. Vérifier les RLS policies pour SELECT sur rides
-- Le patient doit pouvoir lire sa propre course

-- Supprimer et recréer la policy de lecture rides pour les patients
DROP POLICY IF EXISTS "Patients can view their own rides" ON rides;
DROP POLICY IF EXISTS "patients_view_own_rides" ON rides;

CREATE POLICY "patients_view_own_rides" ON rides
FOR SELECT USING (
    patient_id IN (
        SELECT id FROM patients WHERE user_id = auth.uid()
    )
);

-- 3. Vérifier les RLS policies pour SELECT sur driver_locations
DROP POLICY IF EXISTS "Anyone can view driver locations" ON driver_locations;
DROP POLICY IF EXISTS "authenticated_view_driver_locations" ON driver_locations;

-- Permettre aux utilisateurs authentifiés de voir les positions des chauffeurs
-- (nécessaire pour le tracking en temps réel)
CREATE POLICY "authenticated_view_driver_locations" ON driver_locations
FOR SELECT USING (
    auth.role() = 'authenticated'
);

-- 4. Vérifier que RLS est activé
ALTER TABLE rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;

-- 5. Vérifier les permissions pour le rôle authenticated
GRANT SELECT ON rides TO authenticated;
GRANT SELECT ON driver_locations TO authenticated;
GRANT SELECT ON patients TO authenticated;
GRANT SELECT ON drivers TO authenticated;

-- 6. Afficher le statut Realtime des tables (pour vérification)
SELECT schemaname, tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';

-- 7. Afficher les policies existantes sur rides
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'rides';

-- 8. Afficher les policies existantes sur driver_locations
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'driver_locations';

-- ============================================
-- DIAGNOSTIC: Vérifier si le patient peut voir sa course
-- Remplacer 'RIDE_ID_ICI' par l'ID de la course en cours
-- ============================================
-- SELECT * FROM rides WHERE id = 'RIDE_ID_ICI';

-- ============================================
-- NOTES:
-- - Realtime nécessite que RLS permette SELECT
-- - Si la subscription se ferme immédiatement, c'est que RLS bloque
-- - Le patient doit être dans la table patients avec son user_id
-- ============================================
