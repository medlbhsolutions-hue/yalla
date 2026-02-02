-- Création du bucket Storage pour les documents chauffeurs
-- Date: 2025-11-24

-- 1. Créer le bucket (si n'existe pas déjà)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver-documents',
  'driver-documents',
  true,  -- PUBLIC: Les URLs seront accessibles directement
  10485760,  -- 10 MB max par fichier
  ARRAY['image/jpeg', 'image/png', 'application/pdf']  -- Types autorisés
)
ON CONFLICT (id) DO NOTHING;

-- 2. Policy: Les chauffeurs peuvent uploader leurs propres documents
DROP POLICY IF EXISTS "Drivers can upload documents" ON storage.objects;
CREATE POLICY "Drivers can upload documents"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'driver-documents' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- 3. Policy: Les chauffeurs peuvent voir leurs propres documents
DROP POLICY IF EXISTS "Drivers can view own documents" ON storage.objects;
CREATE POLICY "Drivers can view own documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'driver-documents' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4. Policy: Les admins peuvent voir TOUS les documents
DROP POLICY IF EXISTS "Admins can view all documents" ON storage.objects;
CREATE POLICY "Admins can view all documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'driver-documents' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'admin'
    )
  );

-- 5. Policy: Les admins peuvent supprimer des documents
DROP POLICY IF EXISTS "Admins can delete documents" ON storage.objects;
CREATE POLICY "Admins can delete documents"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'driver-documents' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'admin'
    )
  );

-- Vérification
SELECT 
  id, 
  name, 
  public, 
  file_size_limit,
  allowed_mime_types
FROM storage.buckets
WHERE id = 'driver-documents';
