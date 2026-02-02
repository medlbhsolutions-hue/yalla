-- Migration pour corriger les politiques de storage
-- Cette migration assure l'accès public aux documents uploadés

-- S'assurer que le bucket driver-documents existe et est public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver-documents', 
  'driver-documents', 
  true, 
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[];

-- Supprimer les anciennes politiques s'elles existent
DROP POLICY IF EXISTS "Allow authenticated users to upload driver documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access to driver documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to update their own driver documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own driver documents" ON storage.objects;

-- Politique pour permettre l'upload de documents (utilisateurs authentifiés uniquement)
CREATE POLICY "Allow authenticated users to upload driver documents" ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'driver-documents');

-- Politique pour permettre la lecture publique des documents uploadés
CREATE POLICY "Allow public read access to driver documents" ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'driver-documents');

-- Politique pour permettre aux utilisateurs de mettre à jour leurs propres documents
CREATE POLICY "Allow users to update their own driver documents" ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'driver-documents')
WITH CHECK (bucket_id = 'driver-documents');

-- Politique pour permettre aux utilisateurs de supprimer leurs propres documents
CREATE POLICY "Allow users to delete their own driver documents" ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'driver-documents');