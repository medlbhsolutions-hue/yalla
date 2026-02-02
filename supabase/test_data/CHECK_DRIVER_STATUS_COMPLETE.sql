-- Vérifier le token FCM du driver test

SELECT 
  d.id AS driver_id,
  d.first_name || ' ' || d.last_name AS driver_name,
  d.is_available,
  d.status,
  u.id AS user_id,
  u.email,
  u.phone_number,
  CASE 
    WHEN u.fcm_token IS NULL THEN '❌ PAS DE TOKEN'
    WHEN u.fcm_token LIKE 'TEST_%' THEN '🧪 TOKEN TEST: ' || LEFT(u.fcm_token, 50)
    ELSE '✅ TOKEN RÉEL: ' || LEFT(u.fcm_token, 50)
  END AS fcm_token_status,
  dl.lat,
  dl.lng,
  dl.updated_at AS gps_updated_at,
  NOW() - dl.updated_at AS gps_age,
  CASE 
    WHEN dl.updated_at > NOW() - INTERVAL '5 minutes' THEN '✅ GPS VALIDE'
    ELSE '❌ GPS EXPIRÉ'
  END AS gps_status
FROM drivers d
JOIN users u ON d.user_id = u.id
LEFT JOIN driver_locations dl ON d.id = dl.driver_id
WHERE d.id = '22222222-2222-2222-2222-222222222222';
