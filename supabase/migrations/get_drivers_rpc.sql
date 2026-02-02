-- =========================================
-- FONCTION RPC POUR RÉCUPÉRER LES CHAUFFEURS
-- Contourne le problème PostgREST schema cache
-- =========================================

-- Supprimer l'ancienne fonction si elle existe
DROP FUNCTION IF EXISTS get_nearby_drivers_rpc(double precision, double precision, double precision);

CREATE OR REPLACE FUNCTION get_nearby_drivers_rpc(
    radius_km DOUBLE PRECISION DEFAULT 10.0,
    user_lat DOUBLE PRECISION DEFAULT 0.0,
    user_lng DOUBLE PRECISION DEFAULT 0.0
)
RETURNS TABLE (
    id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    rating DECIMAL,
    is_available BOOLEAN,
    current_location_lat DOUBLE PRECISION,
    current_location_lng DOUBLE PRECISION,
    vehicle_make VARCHAR,
    vehicle_model VARCHAR,
    vehicle_year INTEGER,
    vehicle_type VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.first_name,
        d.last_name,
        d.rating,
        d.is_available,
        ST_Y(d.current_location::geometry) as current_location_lat,
        ST_X(d.current_location::geometry) as current_location_lng,
        v.make as vehicle_make,
        v.model as vehicle_model,
        v.year as vehicle_year,
        v.vehicle_type::VARCHAR as vehicle_type
    FROM drivers d
    LEFT JOIN vehicles v ON v.driver_id = d.id
    WHERE d.is_available = true
      AND d.status = 'active'
    ORDER BY d.rating DESC
    LIMIT 20;
END;
$$;

-- Donner accès à anon
GRANT EXECUTE ON FUNCTION get_nearby_drivers_rpc TO anon, authenticated;

-- Test
SELECT * FROM get_nearby_drivers_rpc(33.9716, -6.8498, 10.0);
