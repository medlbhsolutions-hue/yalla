-- 🔥 SUPPRIMER LE TRIGGER SUSPECT : on_auth_user_created_sync
-- Date : 14 octobre 2025
-- À exécuter dans Supabase SQL Editor

-- ==========================================
-- ÉTAPE 1 : Voir le contenu de la fonction
-- ==========================================

SELECT 
    proname AS function_name,
    prosrc AS function_code
FROM pg_proc
WHERE proname = 'handle_new_user_complete';

-- 📋 Lisez le code pour confirmer qu'il crée un profil patient

-- ==========================================
-- ÉTAPE 2 : Supprimer le trigger
-- ==========================================

DROP TRIGGER IF EXISTS on_auth_user_created_sync ON auth.users;

-- ✅ Résultat attendu : "DROP TRIGGER"

-- ==========================================
-- ÉTAPE 3 : Supprimer la fonction
-- ==========================================

DROP FUNCTION IF EXISTS public.handle_new_user_complete();

-- ✅ Résultat attendu : "DROP FUNCTION"

-- ==========================================
-- ÉTAPE 4 : Vérification
-- ==========================================

-- Vérifier qu'il n'y a plus de triggers sur auth.users
SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    proname AS function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'auth.users'::regclass
  AND tgname LIKE '%auth_user_created%';

-- ✅ Résultat attendu : Aucune ligne

-- ==========================================
-- ÉTAPE 5 : Nettoyer les profils patients en trop
-- ==========================================

-- Supprimer les profils patients des chauffeurs (double rôle)
DELETE FROM patients 
WHERE user_id IN (
  SELECT p.user_id 
  FROM patients p
  INNER JOIN drivers d ON p.user_id = d.user_id
  WHERE NOT EXISTS (
    SELECT 1 FROM rides WHERE patient_id = p.id
  )
);

-- ✅ Résultat : "DELETE X" où X = nombre de profils supprimés

-- ==========================================
-- ÉTAPE 6 : Test final
-- ==========================================

-- Voir tous les utilisateurs récents
SELECT 
    u.phone,
    u.email,
    CASE 
        WHEN p.id IS NULL AND d.id IS NOT NULL THEN '✅ Chauffeur uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NULL THEN '👤 Patient uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN '⚠️ Double rôle'
        ELSE '❌ Aucun profil'
    END AS status
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.created_at > NOW() - INTERVAL '7 days'
ORDER BY u.created_at DESC
LIMIT 20;

-- ✅ Après nettoyage : Tous les chauffeurs doivent avoir "✅ Chauffeur uniquement"

/*
🎯 RÉSULTAT ATTENDU :

Après exécution de ce script :
1. ✅ Le trigger on_auth_user_created_sync est supprimé
2. ✅ La fonction handle_new_user_complete est supprimée
3. ✅ Les profils patients en trop sont nettoyés
4. ✅ Les nouveaux chauffeurs n'auront PLUS de profil patient automatique

🧪 TEST :
1. Créer un nouveau chauffeur (0669337842)
2. Choisir "Chauffeur" dans l'app
3. Se déconnecter et se reconnecter
4. ✅ Redirection automatique vers DriverDashboard (sans écran de sélection)
*/
