-- ================================================
-- 🔍 DIAGNOSTIC : Vérifier le profil de l'utilisateur
-- ================================================

-- 1. Vérifier l'utilisateur dans auth.users
SELECT 
  id as user_id,
  email,
  phone,
  created_at
FROM auth.users
WHERE phone = '+212669337821' OR phone = '0669337821';

-- 2. Vérifier si cet utilisateur a un profil PATIENT
SELECT 
  p.id as patient_id,
  p.user_id,
  p.first_name,
  p.last_name,
  p.created_at
FROM patients p
JOIN auth.users u ON p.user_id = u.id
WHERE u.phone = '+212669337821' OR u.phone = '0669337821';

-- 3. Vérifier si cet utilisateur a un profil CHAUFFEUR
SELECT 
  d.id as driver_id,
  d.user_id,
  d.first_name,
  d.last_name,
  d.is_available,
  d.created_at
FROM drivers d
JOIN auth.users u ON d.user_id = u.id
WHERE u.phone = '+212669337821' OR u.phone = '0669337821';

-- ================================================
-- 💡 INTERPRÉTATION DES RÉSULTATS
-- ================================================

-- CAS 1 : Seulement profil PATIENT
--   → L'app devrait rediriger automatiquement vers Dashboard Patient
--   → Si ça ne fonctionne pas, c'est un bug

-- CAS 2 : Seulement profil CHAUFFEUR
--   → L'app devrait rediriger automatiquement vers Dashboard Chauffeur
--   → Si ça ne fonctionne pas, c'est un bug

-- CAS 3 : Les DEUX profils (Patient + Chauffeur)
--   → L'app affiche l'écran de sélection de rôle (NORMAL)
--   → Vous devez choisir votre rôle à chaque connexion

-- ================================================
-- 🔧 SOLUTIONS
-- ================================================

-- SOLUTION 1 : Supprimer le profil patient (si vous voulez être SEULEMENT chauffeur)
-- Décommenter et exécuter :
/*
DELETE FROM patients 
WHERE user_id = (
  SELECT id FROM auth.users 
  WHERE phone = '+212669337821' OR phone = '0669337821'
);
*/

-- SOLUTION 2 : Supprimer le profil chauffeur (si vous voulez être SEULEMENT patient)
-- Décommenter et exécuter :
/*
DELETE FROM drivers 
WHERE user_id = (
  SELECT id FROM auth.users 
  WHERE phone = '+212669337821' OR phone = '0669337821'
);
*/

-- SOLUTION 3 : Garder les deux profils (comportement actuel)
-- → Vous devrez choisir votre rôle à chaque connexion
-- → C'est le comportement normal pour les utilisateurs avec double rôle

-- ================================================
-- 🎯 RECOMMANDATION
-- ================================================

-- Pour un chauffeur professionnel :
--   ✅ Supprimer le profil PATIENT
--   ✅ Garder seulement le profil CHAUFFEUR
--   → Redirection automatique vers Dashboard Chauffeur

-- Pour un patient qui transporte occasionnellement :
--   ✅ Garder les DEUX profils
--   → Choix du rôle à chaque connexion
