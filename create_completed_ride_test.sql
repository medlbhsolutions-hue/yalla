-- Script pour créer une course terminée pour tester l'évaluation
-- À exécuter dans Supabase SQL Editor

-- 1. Récupérer l'ID du patient actuel (remplacez par votre patient_id)
-- SELECT id FROM patients WHERE user_id = auth.uid();

-- 2. Créer une course terminée
INSERT INTO rides (
  patient_id,
  driver_id,
  pickup_address,
  destination_address,
  pickup_lat,
  pickup_lng,
  destination_lat,
  destination_lng,
  status,
  distance_km,
  duration_minutes,
  base_price,
  total_price,
  created_at,
  updated_at
)
VALUES (
  -- Remplacez 'VOTRE_PATIENT_ID' par l'ID de votre profil patient
  'VOTRE_PATIENT_ID',
  -- Utilisez un driver_id existant ou NULL
  (SELECT id FROM drivers LIMIT 1),
  'Casablanca, Maroc',
  'Hôpital Ibn Rochd, Casablanca',
  33.5731,
  -7.5898,
  33.5892,
  -7.6031,
  'completed', -- ✅ STATUS COMPLETED
  5.2,
  15,
  50.0,
  50.0,
  NOW() - INTERVAL '1 hour',
  NOW()
);

-- 3. Vérifier la course créée
SELECT 
  id,
  patient_id,
  driver_id,
  status,
  destination_address,
  patient_rating,
  driver_rating
FROM rides 
WHERE status = 'completed' 
ORDER BY created_at DESC 
LIMIT 5;
