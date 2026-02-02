-- Fix: Ajouter RLS policies pour driver_documents
-- Date: 2025-11-24

-- Activer RLS sur driver_documents
ALTER TABLE driver_documents ENABLE ROW LEVEL SECURITY;

-- Policy 1: Les chauffeurs peuvent insérer leurs propres documents
DROP POLICY IF EXISTS "Drivers can insert own documents" ON driver_documents;
CREATE POLICY "Drivers can insert own documents"
  ON driver_documents FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy 2: Les chauffeurs peuvent voir leurs propres documents
DROP POLICY IF EXISTS "Drivers can view own documents" ON driver_documents;
CREATE POLICY "Drivers can view own documents"
  ON driver_documents FOR SELECT
  USING (auth.uid() = user_id);

-- Policy 3: Les chauffeurs peuvent mettre à jour leurs propres documents (status=pending seulement)
DROP POLICY IF EXISTS "Drivers can update own pending documents" ON driver_documents;
CREATE POLICY "Drivers can update own pending documents"
  ON driver_documents FOR UPDATE
  USING (auth.uid() = user_id AND status = 'pending');

-- Policy 4: Les admins peuvent tout voir
DROP POLICY IF EXISTS "Admins can view all documents" ON driver_documents;
CREATE POLICY "Admins can view all documents"
  ON driver_documents FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'admin'
    )
  );

-- Policy 5: Les admins peuvent mettre à jour (approve/reject)
DROP POLICY IF EXISTS "Admins can update all documents" ON driver_documents;
CREATE POLICY "Admins can update all documents"
  ON driver_documents FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'admin'
    )
  );

-- Vérification des policies
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  permissive, 
  roles,
  cmd
FROM pg_policies 
WHERE tablename = 'driver_documents'
ORDER BY policyname;
