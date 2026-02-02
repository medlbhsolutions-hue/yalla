-- Vérifier où sont stockés les FCM tokens

-- 1. Chercher dans users.fcm_token
SELECT 'users.fcm_token' AS location, id, email, phone_number, LEFT(fcm_token, 50) AS fcm_preview
FROM users
WHERE fcm_token IS NOT NULL
LIMIT 5;

-- 2. Vérifier si driver_fcm_tokens existe
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE '%fcm%';

-- 3. Trouver notre driver test
SELECT u.id, u.email, u.phone_number, u.fcm_token, d.id as driver_id
FROM users u
JOIN drivers d ON u.id = d.user_id
WHERE u.email = 'driver.test@yallatbib.ma';
