-- 🔍 DIAGNOSTIC: Vérifier la configuration Storage
-- Date: 2025-11-24
-- Exécuter dans Supabase SQL Editor pour diagnostiquer le problème 404

-- ============================================
-- 1. VÉRIFIER LES BUCKETS EXISTANTS
-- ============================================
SELECT 
  id as "Bucket ID",
  name as "Nom",
  public as "Public?",
  file_size_limit as "Taille Max",
  allowed_mime_types as "Types MIME"
FROM storage.buckets
ORDER BY created_at DESC;

-- ✅ Résultat attendu: Une ligne avec id='driver-documents'
-- ❌ Si vide ou pas de ligne: Le bucket n'existe PAS → Créer le bucket

-- ============================================
-- 2. VÉRIFIER LES FICHIERS UPLOADÉS
-- ============================================
SELECT 
  id,
  name as "Chemin fichier",
  bucket_id as "Bucket",
  owner as "Propriétaire (user_id)",
  created_at as "Date upload",
  metadata->>'size' as "Taille (bytes)"
FROM storage.objects
WHERE bucket_id = 'driver-documents'
ORDER BY created_at DESC
LIMIT 10;

-- ✅ Si résultats: Les fichiers existent dans le bucket
-- ❌ Si erreur "bucket not found": Le bucket n'existe PAS
-- ⚠️ Si vide: Aucun fichier uploadé encore (normal si pas encore testé)

-- ============================================
-- 3. VÉRIFIER LES POLICIES RLS SUR STORAGE
-- ============================================
SELECT 
  schemaname as "Schéma",
  tablename as "Table",
  policyname as "Policy",
  permissive as "Type",
  roles as "Rôles",
  cmd as "Commande"
FROM pg_policies 
WHERE tablename = 'objects'
  AND (
    policyname LIKE '%driver%' OR 
    policyname LIKE '%document%' OR
    policyname LIKE '%admin%'
  )
ORDER BY policyname;

-- ✅ Résultat attendu: 4 policies
--    - Drivers can upload documents (INSERT)
--    - Drivers can view own documents (SELECT)
--    - Admins can view all documents (SELECT)
--    - Admins can delete documents (DELETE)

-- ============================================
-- 4. VÉRIFIER LES DOCUMENTS EN BASE
-- ============================================
SELECT 
  id,
  document_type as "Type",
  file_name as "Nom fichier",
  file_url as "URL",
  status as "Statut",
  uploaded_at as "Date upload",
  user_id
FROM driver_documents
ORDER BY uploaded_at DESC
LIMIT 10;

-- ✅ Si URLs commencent par https://...supabase.co/storage/v1/object/public/driver-documents/
-- ❌ Si les URLs sont différentes: Problème de configuration

-- ============================================
-- 5. TESTER UNE URL (copier-coller dans navigateur)
-- ============================================
-- Prenez une URL de la requête #4 et testez-la dans votre navigateur
-- Exemple: https://aijchsvkuocbtzamyojy.supabase.co/storage/v1/object/public/driver-documents/{user_id}/license/123456.jpg

-- ✅ Si l'image/PDF s'affiche: Storage fonctionne ✅
-- ❌ Si erreur 404: Le bucket n'existe PAS ou fichier supprimé
-- ❌ Si erreur 403: Problème de policies RLS

-- ============================================
-- 📊 RÉSUMÉ DIAGNOSTIC
-- ============================================
-- Exécutez TOUTES les requêtes ci-dessus et notez les résultats:

-- Bucket existe? [ ] OUI [ ] NON
-- Fichiers uploadés? [ ] OUI (combien: ___) [ ] NON
-- Policies RLS? [ ] 4 policies [ ] Moins de 4 [ ] Aucune
-- URLs fonctionnelles? [ ] OUI [ ] NON [ ] PAS TESTÉ

-- ============================================
-- 🔧 ACTION CORRECTIVE
-- ============================================
-- Si bucket n'existe PAS:
--   → Exécuter: supabase/migrations/20251124_create_storage_bucket.sql
--   → OU créer manuellement via Dashboard (voir FIX_STORAGE_BUCKET_404.md)

-- Si policies manquantes:
--   → Exécuter les CREATE POLICY de 20251124_create_storage_bucket.sql

-- Si URLs ne fonctionnent pas:
--   → Vérifier que bucket.public = true
--   → UPDATE storage.buckets SET public = true WHERE id = 'driver-documents';
