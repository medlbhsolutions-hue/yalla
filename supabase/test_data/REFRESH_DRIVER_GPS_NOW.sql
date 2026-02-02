-- 🚨 SCRIPT DE TEST URGENT
-- À exécuter IMMÉDIATEMENT avant de créer une course dans l'app
-- Tu as 5 MINUTES après l'exécution pour créer la course !

-- Étape 1: Rafraîchir la position GPS du chauffeur test
UPDATE driver_locations
SET updated_at = NOW()
WHERE driver_id = '22222222-2222-2222-2222-222222222222';

-- Étape 2: Vérifier que c'est bien fait
SELECT 
  'Position GPS rafraîchie !' AS message,
  driver_id,
  lat,
  lng,
  updated_at,
  NOW() AS maintenant,
  NOW() - updated_at AS age,
  CASE 
    WHEN updated_at > NOW() - INTERVAL '5 minutes' THEN '✅ VALIDE (cours créer la course MAINTENANT !)'
    ELSE '❌ EXPIRÉE'
  END AS position_status
FROM driver_locations
WHERE driver_id = '22222222-2222-2222-2222-222222222222';

-- 🎯 MAINTENANT: Va dans l'app Flutter et crée une nouvelle course dans les 30 secondes !
