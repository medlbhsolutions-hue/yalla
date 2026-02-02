-- 🧹 NETTOYAGE : Supprimer le profil patient du chauffeur 0669337821
-- Date : 14 octobre 2025
-- Objectif : Préparer le test du nouveau flux de sélection de rôle

-- 🔍 ÉTAPE 1 : Vérifier les profils existants
SELECT 
    u.id AS user_id,
    u.phone,
    u.email,
    u.created_at,
    p.id AS patient_id,
    p.first_name AS patient_first_name,
    p.last_name AS patient_last_name,
    d.id AS driver_id,
    d.first_name AS driver_first_name,
    d.last_name AS driver_last_name,
    d.is_available AS driver_available
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.phone = '+212669337821'
ORDER BY u.created_at DESC;

-- 📊 Résultat attendu :
-- | user_id | phone | patient_id | driver_id | patient_first_name | driver_first_name |
-- |---------|-------|------------|-----------|-------------------|-------------------|
-- | xxx-xxx | +212669337821 | EXISTE | EXISTE | Nouveau | Karim |

-- ⚠️ Si patient_id existe, continuer avec l'étape 2

-- 🗑️ ÉTAPE 2 : Supprimer le profil patient (SEULEMENT patient, pas driver !)
DELETE FROM patients 
WHERE user_id = (
  SELECT id 
  FROM auth.users 
  WHERE phone = '+212669337821'
);

-- ✅ Message attendu : DELETE 1 (si le profil existait)

-- 🔍 ÉTAPE 3 : Vérification finale
SELECT 
    u.id AS user_id,
    u.phone,
    p.id AS patient_id,
    d.id AS driver_id,
    CASE 
        WHEN p.id IS NULL AND d.id IS NOT NULL THEN '✅ Chauffeur uniquement (CORRECT)'
        WHEN p.id IS NOT NULL AND d.id IS NULL THEN '👤 Patient uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN '⚠️ Double rôle (PROBLÈME)'
        ELSE '❌ Aucun profil'
    END AS status
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.phone = '+212669337821';

-- 📊 Résultat attendu :
-- | user_id | phone | patient_id | driver_id | status |
-- |---------|-------|------------|-----------|--------|
-- | xxx-xxx | +212669337821 | NULL | xxx-xxx | ✅ Chauffeur uniquement (CORRECT) |

-- 🎯 ÉTAPE 4 : Vérifier qu'il n'y a pas de courses associées au profil patient supprimé
-- (Normalement, il ne devrait pas y en avoir)
SELECT COUNT(*) AS rides_count
FROM rides
WHERE patient_id IN (
  SELECT id 
  FROM patients 
  WHERE user_id = (
    SELECT id FROM auth.users WHERE phone = '+212669337821'
  )
);

-- 📊 Résultat attendu : rides_count = 0

-- ✅ FIN DU SCRIPT
-- Fichier : CLEANUP_CHAUFFEUR_0669337821.sql

/*
💡 INFORMATIONS COMPLÉMENTAIRES
================================

🎯 OBJECTIF
-----------
Supprimer le profil patient du chauffeur 0669337821 pour tester le nouveau flux :
1. Connexion → AppLoaderScreen
2. Détection : aucun profil patient → role = driver only
3. Redirection automatique → DriverDashboard ✅

⚠️ ATTENTION
------------
- Cette requête supprime SEULEMENT le profil patient
- Le profil chauffeur est CONSERVÉ
- Les courses associées au chauffeur (table rides, colonne driver_id) sont CONSERVÉES
- Si le profil patient avait des courses (peu probable), elles seront supprimées en cascade

🧪 APRÈS EXÉCUTION
------------------
1. Redémarrer Flutter : flutter run
2. Se connecter avec 0669337821 (code 123456)
3. Vérifier : Redirection automatique vers DriverDashboard
4. Pas d'écran FirstTimeRoleSelectionScreen car profil driver existe

📝 ROLLBACK (SI BESOIN)
------------------------
Si vous souhaitez recréer le profil patient :

INSERT INTO patients (user_id, first_name, last_name, created_at)
VALUES (
  (SELECT id FROM auth.users WHERE phone = '+212669337821'),
  'Nouveau',
  'Patient',
  NOW()
);
*/
