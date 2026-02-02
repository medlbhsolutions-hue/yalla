-- =========================================
-- INSÉRER POSITION GPS TEST POUR DRIVER
-- =========================================
-- Ce script insère une position GPS simulée pour le driver de test
-- à proximité de l'émulateur Android (37.4219983, -122.084)

-- Insérer position pour le driver avec user_id correspondant au phone 0669337851
INSERT INTO driver_locations (driver_id, lat, lng, heading, speed, accuracy, updated_at)
SELECT 
    d.id,
    37.4219983,  -- Latitude émulateur Android
    -122.084,     -- Longitude émulateur Android
    180.0,        -- Heading (direction Sud)
    0.0,          -- Speed (arrêté)
    10.0,         -- Accuracy (10 mètres)
    NOW()
FROM drivers d
JOIN users u ON d.user_id = u.id
WHERE u.phone_number = '+212669337851'  -- Téléphone du driver test
ON CONFLICT (driver_id) DO UPDATE
SET 
    lat = EXCLUDED.lat,
    lng = EXCLUDED.lng,
    heading = EXCLUDED.heading,
    speed = EXCLUDED.speed,
    accuracy = EXCLUDED.accuracy,
    updated_at = NOW();

-- Vérification
SELECT 
    u.phone_number,
    d.first_name,
    d.last_name,
    d.is_available,
    dl.lat,
    dl.lng,
    dl.updated_at,
    calculate_distance_km(37.4219983, -122.084, dl.lat, dl.lng) AS distance_km
FROM driver_locations dl
JOIN drivers d ON dl.driver_id = d.id
JOIN users u ON d.user_id = u.id
WHERE u.phone_number = '+212669337851';

-- Test find_nearby_drivers
SELECT * FROM find_nearby_drivers(
    37.4219983,  -- Pickup latitude (émulateur)
    -122.084,    -- Pickup longitude (émulateur)
    10           -- Rayon 10km
);

-- ✅ Position GPS insérée !
-- Le driver devrait maintenant apparaître dans les résultats de find_nearby_drivers()
