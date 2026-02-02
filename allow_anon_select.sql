-- AJOUTER LA PERMISSION SELECT POUR ANON (Requis pour upsert)
CREATE POLICY "Enable select for anon regarding driver locations" 
ON public.driver_locations
FOR SELECT 
TO anon
USING (true);
