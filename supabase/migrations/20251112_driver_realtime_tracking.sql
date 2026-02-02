-- Migration pour le tracking temps réel de la position des chauffeurs
-- Date: 2025-11-12
-- Description: Table driver_locations pour stocker les positions GPS

-- Créer la table pour les positions des chauffeurs
CREATE TABLE IF NOT EXISTS driver_locations (
  driver_id UUID PRIMARY KEY REFERENCES drivers(id) ON DELETE CASCADE,
  lat DECIMAL(10, 8) NOT NULL,
  lng DECIMAL(11, 8) NOT NULL,
  heading DECIMAL(5, 2), -- Direction en degrés (0-360)
  speed DECIMAL(5, 2), -- Vitesse en km/h
  accuracy DECIMAL(6, 2), -- Précision en mètres
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour optimiser les requêtes géographiques
CREATE INDEX IF NOT EXISTS idx_driver_locations_position ON driver_locations(lat, lng);
CREATE INDEX IF NOT EXISTS idx_driver_locations_updated ON driver_locations(updated_at DESC);

-- Activer Row Level Security
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;

-- Policy: Les chauffeurs peuvent mettre à jour leur propre position
DROP POLICY IF EXISTS "Drivers can update own location" ON driver_locations;
CREATE POLICY "Drivers can update own location" ON driver_locations
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM drivers 
      WHERE drivers.id = driver_id 
      AND drivers.user_id = auth.uid()
    )
  );

-- Policy: Tout le monde peut voir les positions (pour trouver chauffeurs disponibles)
DROP POLICY IF EXISTS "Anyone can view driver locations" ON driver_locations;
CREATE POLICY "Anyone can view driver locations" ON driver_locations
  FOR SELECT
  USING (true);

-- Fonction pour calculer la distance entre 2 points (formule Haversine)
CREATE OR REPLACE FUNCTION calculate_distance_km(
  lat1 DECIMAL,
  lng1 DECIMAL,
  lat2 DECIMAL,
  lng2 DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
  earth_radius DECIMAL := 6371; -- Rayon de la Terre en km
  dlat DECIMAL;
  dlng DECIMAL;
  a DECIMAL;
  c DECIMAL;
BEGIN
  dlat := radians(lat2 - lat1);
  dlng := radians(lng2 - lng1);
  
  a := sin(dlat/2) * sin(dlat/2) +
       cos(radians(lat1)) * cos(radians(lat2)) *
       sin(dlng/2) * sin(dlng/2);
  
  c := 2 * atan2(sqrt(a), sqrt(1-a));
  
  RETURN earth_radius * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Fonction pour trouver les chauffeurs disponibles à proximité
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

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_driver_location_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_driver_location_timestamp ON driver_locations;
CREATE TRIGGER trigger_update_driver_location_timestamp
  BEFORE UPDATE ON driver_locations
  FOR EACH ROW
  EXECUTE FUNCTION update_driver_location_timestamp();

-- Commentaires
COMMENT ON TABLE driver_locations IS 'Stocke les positions GPS temps réel des chauffeurs disponibles';
COMMENT ON FUNCTION find_nearby_drivers IS 'Trouve les chauffeurs disponibles dans un rayon donné (km)';
COMMENT ON FUNCTION calculate_distance_km IS 'Calcule la distance entre 2 coordonnées GPS (formule Haversine)';
