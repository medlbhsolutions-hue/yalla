-- =========================================
-- CORRECTION FONCTION find_nearby_drivers
-- =========================================
-- Cette correction met à jour la fonction pour utiliser la vraie structure de la table drivers
-- Fix: d.phone → u.phone_number, d.vehicle_id → v.driver_id

DROP FUNCTION IF EXISTS find_nearby_drivers(DECIMAL, DECIMAL, INTEGER);

CREATE OR REPLACE FUNCTION find_nearby_drivers(
  pickup_lat DECIMAL,
  pickup_lng DECIMAL,
  radius_km INTEGER DEFAULT 10
)
RETURNS TABLE(
  driver_id UUID,
  driver_name TEXT,
  driver_phone TEXT,
  vehicle_type TEXT,
  rating DECIMAL,
  distance_km DECIMAL,
  lat DECIMAL,
  lng DECIMAL,
  last_update TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    (d.first_name || ' ' || d.last_name)::TEXT AS driver_name,
    u.phone_number::TEXT AS driver_phone,
    v.vehicle_type::TEXT,
    d.rating,
    calculate_distance_km(pickup_lat, pickup_lng, dl.lat, dl.lng) AS distance,
    dl.lat,
    dl.lng,
    dl.updated_at
  FROM drivers d
  JOIN driver_locations dl ON d.id = dl.driver_id
  JOIN users u ON d.user_id = u.id
  LEFT JOIN vehicles v ON v.driver_id = d.id
  WHERE 
    d.is_available = TRUE
    AND calculate_distance_km(pickup_lat, pickup_lng, dl.lat, dl.lng) <= radius_km
    AND dl.updated_at > NOW() - INTERVAL '5 minutes' -- Position récente seulement
  ORDER BY distance ASC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION find_nearby_drivers IS 'Trouve les chauffeurs disponibles dans un rayon donné (km) - Version corrigée avec bonne structure drivers';

-- ✅ Fonction corrigée !
-- Changements:
-- - d.full_name → (d.first_name || ' ' || d.last_name)
-- - d.phone → u.phone_number (JOIN avec users)
-- - d.vehicle_id → v.driver_id (relation inversée dans vehicles)
