-- Ajouter un FCM token au chauffeur test pour tester les notifications

-- Mettre à jour le token FCM du user associé au driver test
UPDATE users
SET fcm_token = 'TEST_DRIVER_FCM_TOKEN_' || gen_random_uuid()::text
WHERE id = (
  SELECT user_id 
  FROM drivers 
  WHERE id = '22222222-2222-2222-2222-222222222222'
);

-- Vérification
SELECT 
  u.id AS user_id,
  u.email,
  u.phone_number,
  LEFT(u.fcm_token, 50) AS fcm_token_preview,
  d.id AS driver_id,
  d.first_name || ' ' || d.last_name AS driver_name,
  d.is_available,
  d.status
FROM users u
JOIN drivers d ON u.id = d.user_id
WHERE d.id = '22222222-2222-2222-2222-222222222222';
