-- Utiliser le token FCM du patient pour tester la livraison de notification réelle
-- Ceci remplace temporairement le token du driver par celui du patient (qui fonctionne)

-- Étape 1: Récupérer le token FCM actuel du patient
SELECT 
  'Token FCM patient (à copier)' AS info,
  u.id AS patient_user_id,
  u.email,
  u.fcm_token
FROM users u
JOIN patients p ON u.id = p.user_id
WHERE p.id = 'd74a9f35-c8bd-4c9c-82eb-a80accc645c6';

-- Étape 2: Copie le token FCM du résultat ci-dessus, puis exécute cette requête
-- en remplaçant 'COLLE_ICI_LE_TOKEN_PATIENT' par le token réel
/*
UPDATE users
SET fcm_token = 'COLLE_ICI_LE_TOKEN_PATIENT'
WHERE id = (
  SELECT user_id 
  FROM drivers 
  WHERE id = '22222222-2222-2222-2222-222222222222'
);
*/

-- Étape 3: Vérification
SELECT 
  'Driver avec token patient (pour test)' AS info,
  d.id AS driver_id,
  d.first_name || ' ' || d.last_name AS driver_name,
  u.id AS user_id,
  LEFT(u.fcm_token, 50) AS fcm_token_preview
FROM users u
JOIN drivers d ON u.id = d.user_id
WHERE d.id = '22222222-2222-2222-2222-222222222222';

-- 🎯 Après cette modification:
-- 1. Rafraîchir GPS avec REFRESH_DRIVER_GPS_NOW.sql
-- 2. Créer une course dans l'app (< 30 sec)
-- 3. La notification devrait apparaître sur ton device patient !
