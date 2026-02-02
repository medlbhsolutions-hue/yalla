-- ============================================================
-- SCRIPT SQL: Insertion de Courses de Test - Yalla Tbib
-- ============================================================
-- Date: 13 Octobre 2025
-- Objectif: Faciliter l'insertion de courses de test pour
--           valider l'affichage de l'historique patient/driver
-- ============================================================

-- ============================================================
-- ÉTAPE 1: Récupérer les IDs existants
-- ============================================================

-- 1.1 Lister tous les patients créés
SELECT 
  id AS patient_id,
  user_id,
  first_name,
  last_name,
  phone,
  created_at
FROM patients 
ORDER BY created_at DESC;

-- Copier le 'patient_id' pour ÉTAPE 2

-- 1.2 Lister tous les drivers créés
SELECT 
  id AS driver_id,
  user_id,
  first_name,
  last_name,
  phone,
  is_available,
  created_at
FROM drivers 
ORDER BY created_at DESC;

-- Copier le 'driver_id' pour ÉTAPE 2

-- ============================================================
-- ÉTAPE 2: Insérer une Course de Test
-- ============================================================

-- ⚠️ IMPORTANT: Remplacer les valeurs suivantes:
--    - PATIENT_ID_HERE : par le patient_id de l'ÉTAPE 1.1
--    - DRIVER_ID_HERE  : par le driver_id de l'ÉTAPE 1.2

INSERT INTO rides (
  patient_id,
  driver_id,
  pickup_address,
  destination_address,
  status,
  total_price,
  base_price,
  distance_km,
  duration_minutes,
  created_at,
  updated_at
) VALUES (
  'PATIENT_ID_HERE',  -- ⚠️ REMPLACER
  'DRIVER_ID_HERE',   -- ⚠️ REMPLACER
  'Casablanca Centre, Boulevard Mohammed V',
  'Hôpital Ibn Rochd, Rue de l''Hôpital',
  'completed',
  120.00,
  100.00,
  8.5,
  25,
  NOW() - INTERVAL '2 days',  -- Course d'il y a 2 jours
  NOW() - INTERVAL '2 days'
);

-- ============================================================
-- ÉTAPE 3: Vérifier l'Insertion
-- ============================================================

-- 3.1 Vérifier que la course est bien insérée
SELECT 
  r.id,
  r.pickup_address,
  r.destination_address,
  r.status,
  r.total_price,
  r.created_at,
  p.first_name || ' ' || p.last_name AS patient_name,
  d.first_name || ' ' || d.last_name AS driver_name
FROM rides r
LEFT JOIN patients p ON r.patient_id = p.id
LEFT JOIN drivers d ON r.driver_id = d.id
ORDER BY r.created_at DESC
LIMIT 5;

-- Si patient_name ou driver_name est NULL, les IDs sont invalides !

-- ============================================================
-- ÉTAPE 4: Insérer Plusieurs Courses de Test (Optionnel)
-- ============================================================

-- ⚠️ REMPLACER PATIENT_ID_HERE et DRIVER_ID_HERE

-- Course 1: Complétée
INSERT INTO rides (patient_id, driver_id, pickup_address, destination_address, status, total_price, base_price, distance_km, duration_minutes, created_at, updated_at)
VALUES ('PATIENT_ID_HERE', 'DRIVER_ID_HERE', 'Casablanca Marina', 'Clinique Al Madina', 'completed', 80.00, 70.00, 5.2, 15, NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days');

-- Course 2: En cours
INSERT INTO rides (patient_id, driver_id, pickup_address, destination_address, status, total_price, base_price, distance_km, duration_minutes, created_at, updated_at)
VALUES ('PATIENT_ID_HERE', 'DRIVER_ID_HERE', 'Aéroport Mohammed V', 'Hôpital Cheikh Khalifa', 'in_progress', 200.00, 180.00, 35.0, 45, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour');

-- Course 3: Annulée
INSERT INTO rides (patient_id, driver_id, pickup_address, destination_address, status, total_price, base_price, distance_km, duration_minutes, created_at, updated_at)
VALUES ('PATIENT_ID_HERE', 'DRIVER_ID_HERE', 'Rabat Centre', 'Hôpital Militaire Rabat', 'cancelled', 150.00, 130.00, 20.0, 30, NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days');

-- Course 4: En attente
INSERT INTO rides (patient_id, driver_id, pickup_address, destination_address, status, total_price, base_price, distance_km, duration_minutes, created_at, updated_at)
VALUES ('PATIENT_ID_HERE', 'DRIVER_ID_HERE', 'Marrakech Médina', 'CHU Marrakech', 'pending', 100.00, 90.00, 12.0, 20, NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '30 minutes');

-- ============================================================
-- ÉTAPE 5: Statistiques et Vérifications
-- ============================================================

-- 5.1 Nombre de courses par patient
SELECT 
  p.first_name || ' ' || p.last_name AS patient_name,
  COUNT(r.id) AS total_courses,
  SUM(CASE WHEN r.status = 'completed' THEN 1 ELSE 0 END) AS completed,
  SUM(CASE WHEN r.status = 'in_progress' THEN 1 ELSE 0 END) AS in_progress,
  SUM(CASE WHEN r.status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
  SUM(r.total_price) AS total_spent
FROM patients p
LEFT JOIN rides r ON p.id = r.patient_id
GROUP BY p.id, p.first_name, p.last_name
ORDER BY total_courses DESC;

-- 5.2 Nombre de courses par driver
SELECT 
  d.first_name || ' ' || d.last_name AS driver_name,
  COUNT(r.id) AS total_courses,
  SUM(CASE WHEN r.status = 'completed' THEN 1 ELSE 0 END) AS completed,
  SUM(r.total_price) AS total_earnings,
  SUM(r.total_price * 0.9) AS net_earnings_90
FROM drivers d
LEFT JOIN rides r ON d.id = r.driver_id
GROUP BY d.id, d.first_name, d.last_name
ORDER BY total_courses DESC;

-- ============================================================
-- ÉTAPE 6: Debugging - Trouver les Courses Orphelines
-- ============================================================

-- 6.1 Courses sans patient valide
SELECT 
  r.id,
  r.patient_id,
  r.pickup_address,
  r.destination_address,
  r.status,
  'Patient invalide ou manquant' AS probleme
FROM rides r
LEFT JOIN patients p ON r.patient_id = p.id
WHERE p.id IS NULL;

-- 6.2 Courses sans driver valide
SELECT 
  r.id,
  r.driver_id,
  r.pickup_address,
  r.destination_address,
  r.status,
  'Driver invalide ou manquant' AS probleme
FROM rides r
LEFT JOIN drivers d ON r.driver_id = d.id
WHERE d.id IS NULL;

-- ============================================================
-- ÉTAPE 7: Correction Rapide des IDs Invalides
-- ============================================================

-- Si vous avez des courses avec des IDs invalides, les corriger:

-- 7.1 Mettre à jour le patient_id d'une course
UPDATE rides 
SET patient_id = 'CORRECT_PATIENT_ID'
WHERE id = 'RIDE_ID_TO_FIX';

-- 7.2 Mettre à jour le driver_id d'une course
UPDATE rides 
SET driver_id = 'CORRECT_DRIVER_ID'
WHERE id = 'RIDE_ID_TO_FIX';

-- ============================================================
-- ÉTAPE 8: Nettoyer les Données de Test (Optionnel)
-- ============================================================

-- ⚠️ ATTENTION: Cette requête supprime TOUTES les courses !
-- À utiliser uniquement pour nettoyer les données de test

-- DELETE FROM rides WHERE created_at > NOW() - INTERVAL '30 days';

-- Suppression plus ciblée (par patient_id)
-- DELETE FROM rides WHERE patient_id = 'PATIENT_ID_HERE';

-- ============================================================
-- EXEMPLE COMPLET: Workflow de Test
-- ============================================================

-- Étape A: Je veux tester l'historique patient
-- 1. Récupérer l'ID du patient connecté (+212 600 000 001)
SELECT id FROM patients 
WHERE user_id IN (
  SELECT id FROM auth.users WHERE phone = '+212600000001'
);
-- Résultat: 660e8400-e29b-41d4-a716-446655440500

-- 2. Récupérer un driver_id (n'importe lequel)
SELECT id FROM drivers ORDER BY created_at DESC LIMIT 1;
-- Résultat: 660e8400-e29b-41d4-a716-446655440001

-- 3. Insérer la course
INSERT INTO rides (patient_id, driver_id, pickup_address, destination_address, status, total_price, base_price, distance_km, duration_minutes, created_at, updated_at)
VALUES (
  '660e8400-e29b-41d4-a716-446655440500',
  '660e8400-e29b-41d4-a716-446655440001',
  'Casablanca Centre',
  'Hôpital Ibn Rochd',
  'completed',
  120.00,
  100.00,
  8.5,
  25,
  NOW(),
  NOW()
);

-- 4. Vérifier
SELECT 
  r.destination_address,
  r.status,
  r.total_price,
  p.first_name || ' ' || p.last_name AS patient,
  d.first_name || ' ' || d.last_name AS driver
FROM rides r
JOIN patients p ON r.patient_id = p.id
JOIN drivers d ON r.driver_id = d.id
WHERE r.patient_id = '660e8400-e29b-41d4-a716-446655440500';

-- 5. Retourner dans l'app → Historique → La course doit apparaître !

-- ============================================================
-- FIN DU SCRIPT
-- ============================================================
