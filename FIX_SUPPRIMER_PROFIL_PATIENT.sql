-- ================================================
-- 🔧 SOLUTION : Rendre le chauffeur UNIQUEMENT chauffeur
-- (Supprimer le profil patient auto-créé)
-- ================================================

-- ⚠️ ATTENTION : Cela supprimera définitivement le profil patient
-- Si vous avez des courses en tant que patient, elles seront affectées

-- ================================================
-- ÉTAPE 1 : Vérifier le user_id
-- ================================================

SELECT 
  id as user_id,
  email,
  phone
FROM auth.users
WHERE phone = '+212669337821' OR phone = '0669337821';

-- Copier le user_id obtenu et le remplacer dans les requêtes ci-dessous

-- ================================================
-- ÉTAPE 2 : Supprimer le profil PATIENT
-- ================================================

-- Remplacer 'REMPLACER_PAR_USER_ID' par le user_id obtenu à l'étape 1

DELETE FROM patients 
WHERE user_id = 'REMPLACER_PAR_USER_ID';

-- Exemple :
-- DELETE FROM patients WHERE user_id = '123e4567-e89b-12d3-a456-426614174000';

-- ================================================
-- ÉTAPE 3 : Vérifier le résultat
-- ================================================

-- Vérifier qu'il ne reste plus que le profil CHAUFFEUR
SELECT 
  'patient' as type,
  p.id,
  p.first_name,
  p.last_name
FROM patients p
WHERE p.user_id = 'REMPLACER_PAR_USER_ID'

UNION ALL

SELECT 
  'driver' as type,
  d.id,
  d.first_name,
  d.last_name
FROM drivers d
WHERE d.user_id = 'REMPLACER_PAR_USER_ID';

-- ✅ Résultat attendu : 
-- Seulement 1 ligne avec type = 'driver'

-- ================================================
-- ÉTAPE 4 : Tester dans l'app
-- ================================================

-- 1. Se déconnecter de l'app
-- 2. Se reconnecter avec +212669337821
-- 3. Entrer le code : 123456
-- 4. ✅ Redirection automatique vers Dashboard Chauffeur (pas de choix)

-- ================================================
-- 🔄 POUR ANNULER (Recréer le profil patient)
-- ================================================

-- Si vous changez d'avis et voulez redevenir patient :
/*
INSERT INTO patients (
  user_id,
  first_name,
  last_name,
  created_at
) VALUES (
  'REMPLACER_PAR_USER_ID',
  'Prénom',
  'Nom',
  NOW()
);
*/

-- ================================================
-- 💡 NOTES IMPORTANTES
-- ================================================

-- 1. Le profil patient est créé AUTOMATIQUEMENT lors de la première connexion
-- 2. C'est pour cela que vous avez les DEUX profils
-- 3. Pour être SEULEMENT chauffeur, il faut supprimer le profil patient
-- 4. Après suppression, vous serez redirigé automatiquement vers Dashboard Chauffeur
