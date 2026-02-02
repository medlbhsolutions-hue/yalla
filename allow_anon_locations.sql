-- =============================================
-- POLICY UPDATE: Autoriser insert/update sur driver_locations pour tout le monde (DEBUG ONLY)
-- =============================================

-- Autoriser l'insertion pour le rôle 'anon' (visiteur non connecté - pour le script de simulation)
-- A NE PAS FAIRE EN PRODUCTION REELLE SANS AUTH
CREATE POLICY "Enable insert for anon regarding driver locations" 
ON public.driver_locations
FOR INSERT 
TO anon
WITH CHECK (true);

CREATE POLICY "Enable update for anon regarding driver locations" 
ON public.driver_locations
FOR UPDATE
TO anon
USING (true);

-- Vérifier si la table a RLS activé
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;
