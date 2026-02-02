-- =========================================
-- CRÉER UN DRIVER DE TEST COMPLET
-- =========================================
-- Ce script crée un driver de test avec GPS position et FCM token

-- 1. Créer l'utilisateur driver (si n'existe pas déjà)
INSERT INTO users (id, email, phone_number, created_at, is_active)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'driver.test@yallatbib.ma',
  '+212669337851',
  NOW(),
  TRUE
)
ON CONFLICT (email) DO UPDATE
SET phone_number = '+212669337851', is_active = TRUE;

-- 2. Créer le profil driver
INSERT INTO drivers (id, user_id, first_name, last_name, rating, is_available, is_verified, status, created_at)
SELECT 
  '22222222-2222-2222-2222-222222222222',
  u.id,
  'Ahmed',
  'Bennani',
  4.8,
  TRUE,  -- Disponible
  TRUE,  -- Vérifié
  'active',
  NOW()
FROM users u
WHERE u.email = 'driver.test@yallatbib.ma'
ON CONFLICT (id) DO UPDATE
SET 
  is_available = TRUE,
  is_verified = TRUE,
  status = 'active';

-- 3. Créer le véhicule
INSERT INTO vehicles (id, driver_id, vehicle_type, make, model, year, plate_number, color, is_active, is_verified, created_at)
VALUES (
  '33333333-3333-3333-3333-333333333333',
  '22222222-2222-2222-2222-222222222222',
  'ambulance',
  'Mercedes',
  'Sprinter',
  2020,
  'A-12345-20',
  'Blanc',
  TRUE,
  TRUE,
  NOW()
)
ON CONFLICT (id) DO UPDATE
SET vehicle_type = 'ambulance', is_active = TRUE;

-- 4. Insérer la position GPS (même position que l'émulateur)
INSERT INTO driver_locations (driver_id, lat, lng, heading, speed, accuracy, updated_at)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  37.4219983,  -- Latitude émulateur
  -122.084,    -- Longitude émulateur
  180.0,
  0.0,
  10.0,
  NOW()
)
ON CONFLICT (driver_id) DO UPDATE
SET 
  lat = 37.4219983,
  lng = -122.084,
  updated_at = NOW();

-- 5. FCM token sera ajouté quand le driver se connectera à l'app
-- (La table driver_fcm_tokens n'existe pas encore dans ce schéma)

-- ===== VÉRIFICATIONS =====

-- A. Vérifier l'utilisateur
SELECT 'Utilisateur:' AS check_type, u.phone_number, u.email, u.is_active
FROM users u
WHERE u.phone_number = '+212669337851';

-- B. Vérifier le driver
SELECT 'Driver:' AS check_type, d.id, d.first_name, d.last_name, d.is_available, d.status::text
FROM drivers d
JOIN users u ON d.user_id = u.id
WHERE u.email = 'driver.test@yallatbib.ma';

-- C. Vérifier le véhicule
SELECT 'Véhicule:' AS check_type, v.vehicle_type, v.make, v.model
FROM vehicles v
WHERE v.driver_id = '22222222-2222-2222-2222-222222222222';

-- D. Vérifier la position GPS
SELECT 'Position GPS:' AS check_type, dl.lat, dl.lng, dl.updated_at,
  CASE 
    WHEN dl.updated_at > NOW() - INTERVAL '5 minutes' THEN '✅ VALIDE'
    ELSE '❌ EXPIRÉE'
  END AS status
FROM driver_locations dl
WHERE dl.driver_id = '22222222-2222-2222-2222-222222222222';

-- F. TEST FINAL: find_nearby_drivers doit retourner 1 driver
SELECT '=== TEST FINAL ===' AS test;
SELECT * FROM find_nearby_drivers(37.4219983, -122.084, 10);

-- ✅ Si vous voyez 1 ligne dans le résultat final, c'est BON !
-- Vous pouvez maintenant créer une nouvelle course dans l'app Flutter
