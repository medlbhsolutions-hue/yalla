-- ================================================
-- 🧪 SCRIPT SQL DE TEST - Corrections Course en cours
-- Date: 14 Octobre 2025
-- ================================================

-- ================================================
-- 1️⃣ CRÉER UNE COURSE DE TEST
-- ================================================

-- Remplacer ces valeurs avec vos IDs réels
-- Obtenir patient_id: SELECT id FROM patients WHERE user_id = (SELECT id FROM auth.users WHERE email = 'votre_email');
-- Obtenir driver_id: SELECT id FROM drivers WHERE user_id = (SELECT id FROM auth.users WHERE email = 'driver_email');

INSERT INTO rides (
  patient_id,
  driver_id,
  pickup_address,
  pickup_latitude,
  pickup_longitude,
  destination_address,
  destination_latitude,
  destination_longitude,
  status,
  total_price,
  base_price,
  distance_km,
  duration_minutes, -- ✅ Tester avec différentes valeurs
  priority,
  created_at
) VALUES (
  'REMPLACER_PAR_PATIENT_ID',
  'REMPLACER_PAR_DRIVER_ID',
  'Casablanca, Mohammed V Airport',
  33.3675,
  -7.5898,
  'Rabat, Avenue Hassan II',
  34.0209,
  -6.8416,
  'pending',
  150.00,
  120.00,
  90.5,
  15, -- ✅ TEST 1: Durée en minutes (devrait afficher "15 min")
  'medium',
  NOW()
);

-- ================================================
-- 2️⃣ TESTER DIFFÉRENTS FORMATS DE DURÉE
-- ================================================

-- TEST 1: Durée en minutes (normale)
UPDATE rides 
SET duration_minutes = 15 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- Résultat attendu: "15 min"

-- TEST 2: Durée en millisecondes (15 min = 900000 ms)
UPDATE rides 
SET duration_minutes = 900000 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- Résultat attendu: "15 min" (auto-conversion)

-- TEST 3: Durée en millisecondes (30 min = 1800000 ms)
UPDATE rides 
SET duration_minutes = 1800000 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- Résultat attendu: "30 min" (auto-conversion)

-- ================================================
-- 3️⃣ TESTER LES DIFFÉRENTS STATUTS
-- ================================================

-- STATUT 1: pending (En attente)
UPDATE rides 
SET status = 'pending' 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- ✅ Visible dans historique
-- ❌ Pas de card "Course en cours"

-- STATUT 2: accepted (Acceptée)
UPDATE rides 
SET status = 'accepted' 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- ❌ PAS visible dans historique
-- ✅ Card bleue "Chauffeur en route vers vous"

-- STATUT 3: driver_en_route (Chauffeur en route)
UPDATE rides 
SET status = 'driver_en_route' 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- ❌ PAS visible dans historique
-- ✅ Card bleue "Chauffeur en chemin"

-- STATUT 4: arrived (Chauffeur arrivé)
UPDATE rides 
SET status = 'arrived' 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- ❌ PAS visible dans historique
-- ✅ Card violette "Chauffeur arrivé !"

-- STATUT 5: in_progress (En cours)
UPDATE rides 
SET status = 'in_progress' 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- ❌ PAS visible dans historique
-- ✅ Card verte "Course en cours"

-- STATUT 6: completed (Terminée)
UPDATE rides 
SET status = 'completed',
    completion_time = NOW()
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- ✅ Visible dans historique
-- ❌ Pas de card "Course en cours"

-- STATUT 7: cancelled (Annulée)
UPDATE rides 
SET status = 'cancelled' 
WHERE id = 'REMPLACER_PAR_RIDE_ID';
-- ✅ Visible dans historique
-- ❌ Pas de card "Course en cours"

-- ================================================
-- 4️⃣ REQUÊTES UTILES POUR VÉRIFICATION
-- ================================================

-- Voir toutes les courses d'un patient
SELECT 
  id,
  status,
  destination_address,
  duration_minutes,
  total_price,
  created_at
FROM rides
WHERE patient_id = 'REMPLACER_PAR_PATIENT_ID'
ORDER BY created_at DESC;

-- Voir seulement les courses actives (celles qui doivent afficher la card)
SELECT 
  id,
  status,
  destination_address,
  duration_minutes
FROM rides
WHERE patient_id = 'REMPLACER_PAR_PATIENT_ID'
  AND status IN ('accepted', 'driver_en_route', 'arrived', 'in_progress')
ORDER BY created_at DESC;

-- Voir seulement les courses pour l'historique (terminées ou annulées)
SELECT 
  id,
  status,
  destination_address,
  duration_minutes,
  total_price
FROM rides
WHERE patient_id = 'REMPLACER_PAR_PATIENT_ID'
  AND status NOT IN ('accepted', 'driver_en_route', 'arrived', 'in_progress')
ORDER BY created_at DESC;

-- ================================================
-- 5️⃣ SCÉNARIO DE TEST COMPLET
-- ================================================

-- Étape 1: Créer une course de test
INSERT INTO rides (
  patient_id,
  driver_id,
  pickup_address,
  pickup_latitude,
  pickup_longitude,
  destination_address,
  destination_latitude,
  destination_longitude,
  status,
  total_price,
  base_price,
  distance_km,
  duration_minutes,
  priority,
  created_at
) VALUES (
  (SELECT id FROM patients WHERE user_id = (SELECT id FROM auth.users WHERE email = 'u669337820@t.co')),
  (SELECT id FROM drivers LIMIT 1),
  'Casa, Bd Mohamed V',
  33.5731,
  -7.5898,
  'Rabat Hassan',
  33.9716,
  -6.8498,
  'pending',
  180.00,
  150.00,
  95.0,
  18,
  'medium',
  NOW()
) RETURNING id;

-- Copier l'ID retourné et l'utiliser ci-dessous
-- Exemple: 123e4567-e89b-12d3-a456-426614174000

-- Étape 2: Accepter la course (Driver)
UPDATE rides 
SET status = 'accepted' 
WHERE id = '123e4567-e89b-12d3-a456-426614174000';

-- ✅ VÉRIFIER: Card bleue "Chauffeur en route" visible sur dashboard patient
-- ✅ VÉRIFIER: Course PAS visible dans historique
-- ✅ VÉRIFIER: Clic sur card → Navigation vers GPS
-- ✅ VÉRIFIER: GPS affiche "18 min" (pas 18000 min)

-- Étape 3: Chauffeur en route
UPDATE rides 
SET status = 'driver_en_route' 
WHERE id = '123e4567-e89b-12d3-a456-426614174000';

-- ✅ VÉRIFIER: Card toujours visible (bleue)

-- Étape 4: Chauffeur arrivé
UPDATE rides 
SET status = 'arrived',
    arrival_time = NOW()
WHERE id = '123e4567-e89b-12d3-a456-426614174000';

-- ✅ VÉRIFIER: Card violette "Chauffeur arrivé !"

-- Étape 5: Course en cours
UPDATE rides 
SET status = 'in_progress',
    pickup_time = NOW()
WHERE id = '123e4567-e89b-12d3-a456-426614174000';

-- ✅ VÉRIFIER: Card verte "Course en cours"

-- Étape 6: Course terminée
UPDATE rides 
SET status = 'completed',
    completion_time = NOW()
WHERE id = '123e4567-e89b-12d3-a456-426614174000';

-- ✅ VÉRIFIER: Card disparue du dashboard
-- ✅ VÉRIFIER: Course visible dans historique
-- ✅ VÉRIFIER: Durée affichée "18 min"

-- ================================================
-- 6️⃣ NETTOYER LES DONNÉES DE TEST
-- ================================================

-- Supprimer une course de test
DELETE FROM rides 
WHERE id = 'REMPLACER_PAR_RIDE_ID';

-- Supprimer toutes les courses de test d'un patient
DELETE FROM rides 
WHERE patient_id = 'REMPLACER_PAR_PATIENT_ID'
  AND created_at > NOW() - INTERVAL '1 hour';

-- ================================================
-- 7️⃣ STATISTIQUES POUR VÉRIFICATION
-- ================================================

-- Compter les courses par statut
SELECT 
  status,
  COUNT(*) as nombre
FROM rides
WHERE patient_id = 'REMPLACER_PAR_PATIENT_ID'
GROUP BY status
ORDER BY nombre DESC;

-- Durées moyennes par trajet
SELECT 
  AVG(duration_minutes) as duree_moyenne_min,
  MIN(duration_minutes) as duree_min,
  MAX(duration_minutes) as duree_max
FROM rides
WHERE patient_id = 'REMPLACER_PAR_PATIENT_ID'
  AND status = 'completed';

-- ================================================
-- 💡 NOTES IMPORTANTES
-- ================================================

-- 1. Remplacer tous les placeholders avec vos IDs réels
-- 2. Tester chaque statut un par un
-- 3. Vérifier l'affichage dans l'app après chaque UPDATE
-- 4. Utiliser les requêtes de vérification pour déboguer
-- 5. Ne pas oublier de nettoyer les données de test

-- ================================================
-- 🎯 RÉSULTATS ATTENDUS
-- ================================================

-- Statut         | Historique | Card "Course en cours"
-- ---------------|------------|----------------------
-- pending        | ✅ Oui     | ❌ Non
-- accepted       | ❌ Non     | ✅ Oui (Bleue)
-- driver_en_route| ❌ Non     | ✅ Oui (Bleue)
-- arrived        | ❌ Non     | ✅ Oui (Violette)
-- in_progress    | ❌ Non     | ✅ Oui (Verte)
-- completed      | ✅ Oui     | ❌ Non
-- cancelled      | ✅ Oui     | ❌ Non

-- ================================================
-- FIN DU SCRIPT
-- ================================================
