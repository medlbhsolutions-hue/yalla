-- =========================================
-- DEBUG: Pourquoi le driver n'est pas trouvé ?
-- =========================================

-- 1. Vérifier le driver existe et est disponible
SELECT 
  u.phone_number,
  u.id as user_id,
  d.id as driver_id,
  d.first_name,
  d.last_name,
  d.is_available,
  d.status,
  d.is_verified
FROM drivers d
JOIN users u ON d.user_id = u.id
WHERE u.phone_number = '+212669337851';

-- 2. Vérifier la position GPS du driver
SELECT 
  dl.driver_id,
  dl.lat,
  dl.lng,
  dl.updated_at,
  NOW() - dl.updated_at AS age,
  CASE 
    WHEN dl.updated_at > NOW() - INTERVAL '5 minutes' THEN '✅ Position VALIDE (< 5min)'
    ELSE '❌ Position EXPIRÉE (> 5min)'
  END AS status
FROM driver_locations dl
WHERE dl.driver_id IN (
  SELECT d.id FROM drivers d 
  JOIN users u ON d.user_id = u.id 
  WHERE u.phone_number = '+212669337851'
);

-- 3. Test direct de find_nearby_drivers
SELECT * FROM find_nearby_drivers(
  37.4219983,  -- Pickup latitude (émulateur)
  -122.084,    -- Pickup longitude (émulateur)
  10           -- Rayon 10km
);

-- ===== SOLUTION: Forcer le driver disponible avec position récente =====

-- A. Rendre le driver disponible
UPDATE drivers
SET is_available = TRUE
WHERE id IN (
  SELECT d.id FROM drivers d 
  JOIN users u ON d.user_id = u.id 
  WHERE u.phone_number = '+212669337851'
);

-- B. Mettre à jour la position GPS avec timestamp actuel
INSERT INTO driver_locations (driver_id, lat, lng, heading, speed, accuracy, updated_at)
SELECT 
    d.id,
    37.4219983,  -- Latitude émulateur
    -122.084,     -- Longitude émulateur
    180.0,
    0.0,
    10.0,
    NOW()
FROM drivers d
JOIN users u ON d.user_id = u.id
WHERE u.phone_number = '+212669337851'
ON CONFLICT (driver_id) DO UPDATE
SET 
    lat = EXCLUDED.lat,
    lng = EXCLUDED.lng,
    updated_at = NOW();

-- C. Vérifier que ça fonctionne maintenant
SELECT 
  '✅ Driver configuré pour tests' AS status,
  u.phone_number,
  d.first_name || ' ' || d.last_name AS driver_name,
  d.is_available,
  dl.updated_at,
  calculate_distance_km(37.4219983, -122.084, dl.lat, dl.lng) AS distance_km
FROM drivers d
JOIN users u ON d.user_id = u.id
JOIN driver_locations dl ON d.id = dl.driver_id
WHERE u.phone_number = '+212669337851';

-- D. Test final find_nearby_drivers (devrait retourner 1 driver)
SELECT * FROM find_nearby_drivers(37.4219983, -122.084, 10);

-- ✅ Si vous voyez 1 ligne dans le résultat final, c'est bon !
-- Créez maintenant une nouvelle course dans l'app Flutter
