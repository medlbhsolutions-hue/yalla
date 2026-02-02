-- Autoriser TOUT LE MONDE (Connecté ou non) à modifier les positions des chauffeurs
-- C'est nécessaire car vous simulez le chauffeur tout en étant connecté en tant que Patient.

DROP POLICY IF EXISTS "Simulation Update Policy" ON "public"."driver_locations";
DROP POLICY IF EXISTS "Simulation Insert Policy" ON "public"."driver_locations";

CREATE POLICY "Simulation All Access"
ON "public"."driver_locations"
FOR ALL
USING (true)
WITH CHECK (true);

-- Vérifier également que le rôle 'authenticated' a bien les droits GRANT
GRANT ALL ON TABLE "public"."driver_locations" TO authenticated;
GRANT ALL ON TABLE "public"."driver_locations" TO anon;
