-- 🔥 SCRIPT COMPLET : Supprimer le trigger et nettoyer les profils
-- Date : 14 octobre 2025
-- À exécuter dans Supabase SQL Editor

-- ==========================================
-- ÉTAPE 1 : Supprimer le trigger automatique
-- ==========================================

-- Supprimer le trigger qui crée automatiquement un profil patient
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Supprimer la fonction associée
DROP FUNCTION IF EXISTS public.handle_new_patient();

-- ✅ Résultat attendu : "DROP TRIGGER" et "DROP FUNCTION"

-- ==========================================
-- ÉTAPE 2 : Nettoyer les profils patients des chauffeurs
-- ==========================================

-- Supprimer SEULEMENT les profils patients des utilisateurs qui ont AUSSI un profil chauffeur
-- (double rôle involontaire) ET qui n'ont pas de courses
DELETE FROM patients 
WHERE user_id IN (
  SELECT p.user_id 
  FROM patients p
  INNER JOIN drivers d ON p.user_id = d.user_id
  WHERE NOT EXISTS (
    SELECT 1 FROM rides WHERE patient_id = p.id
  )
);

-- ✅ Résultat attendu : "DELETE X" (où X = nombre de profils supprimés)

-- ==========================================
-- ÉTAPE 3 : Vérification complète
-- ==========================================

-- Voir tous les utilisateurs créés dans les 7 derniers jours
SELECT 
    u.phone,
    u.email,
    TO_CHAR(u.created_at, 'YYYY-MM-DD HH24:MI:SS') AS inscription,
    CASE 
        WHEN p.id IS NULL AND d.id IS NOT NULL THEN '✅ Chauffeur uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NULL THEN '👤 Patient uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN '⚠️ Double rôle (PROBLÈME)'
        ELSE '❌ Aucun profil'
    END AS status,
    p.id AS patient_id,
    d.id AS driver_id
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.created_at > NOW() - INTERVAL '7 days'
ORDER BY u.created_at DESC
LIMIT 20;

-- ✅ Résultat attendu : 
-- - Tous les chauffeurs doivent avoir "✅ Chauffeur uniquement"
-- - Tous les patients doivent avoir "👤 Patient uniquement"
-- - AUCUN "⚠️ Double rôle"

-- ==========================================
-- ÉTAPE 4 : Vérifier qu'il n'y a plus de trigger
-- ==========================================

SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    proname AS function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'auth.users'::regclass
AND tgname = 'on_auth_user_created';

-- ✅ Résultat attendu : Aucune ligne (le trigger a bien été supprimé)

-- ==========================================
-- INFORMATIONS
-- ==========================================

/*
✅ APRÈS EXÉCUTION DE CE SCRIPT :

1. Le trigger automatique est supprimé
2. Les profils patients des chauffeurs sont nettoyés
3. Les nouveaux utilisateurs n'auront PLUS de profil patient créé automatiquement
4. Seul Flutter décide quel profil créer

🧪 TEST À FAIRE :

1. Créer un nouveau chauffeur : 0669337824
2. Choisir "Chauffeur" dans l'app
3. Se déconnecter puis se reconnecter
4. ✅ Redirection automatique vers DriverDashboard (pas d'écran de sélection)

📊 VÉRIFICATION SQL :

SELECT u.phone, p.id AS patient_id, d.id AS driver_id
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.phone = '+212669337824';

Résultat attendu : patient_id = NULL, driver_id = xxx-xxx
*/
