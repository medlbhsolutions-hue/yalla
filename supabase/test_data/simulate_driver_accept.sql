-- =========================================
-- SIMULER UN CHAUFFEUR QUI ACCEPTE UNE COURSE
-- =========================================
-- Ce script simule l'acceptation d'une course par le chauffeur de test

-- INSTRUCTIONS :
-- 1. Remplacez 'VOTRE_RIDE_ID' par l'ID de la course créée dans l'app
-- 2. Exécutez ce script dans Supabase SQL Editor
-- 3. Retournez dans l'app Flutter - elle devrait détecter l'acceptation

-- Accepter la course (remplacez VOTRE_RIDE_ID)
UPDATE public.rides
SET 
    driver_id = 'dddddddd-1111-2222-3333-444444444444',
    status = 'accepted',
    updated_at = NOW()
WHERE id = 'e5737f08-b2c6-4e6b-a1fd-8a40dbd2ca1b'  -- ⚠️ REMPLACEZ PAR VOTRE RIDE_ID
RETURNING id, patient_id, driver_id, status, pickup_address, destination_address;

-- Vérification : voir la course avec les infos du chauffeur
SELECT 
    r.id as ride_id,
    r.status,
    r.pickup_address,
    r.destination_address,
    r.total_price,
    d.first_name as driver_first_name,
    d.last_name as driver_last_name,
    d.rating as driver_rating,
    v.make as vehicle_make,
    v.model as vehicle_model,
    v.plate_number
FROM public.rides r
JOIN public.drivers d ON r.driver_id = d.id
LEFT JOIN public.vehicles v ON d.id = v.driver_id
WHERE r.id = 'e5737f08-b2c6-4e6b-a1fd-8a40dbd2ca1b';  -- ⚠️ REMPLACEZ PAR VOTRE RIDE_ID

-- =========================================
-- AUTRES SIMULATIONS UTILES
-- =========================================

-- Chauffeur en route vers le patient
/*
UPDATE public.rides
SET status = 'driver_en_route', updated_at = NOW()
WHERE id = 'VOTRE_RIDE_ID';
*/

-- Chauffeur arrivé chez le patient
/*
UPDATE public.rides
SET status = 'arrived', arrival_time = NOW(), updated_at = NOW()
WHERE id = 'VOTRE_RIDE_ID';
*/

-- Course en cours
/*
UPDATE public.rides
SET status = 'in_progress', pickup_time = NOW(), updated_at = NOW()
WHERE id = 'VOTRE_RIDE_ID';
*/

-- Course terminée
/*
UPDATE public.rides
SET 
    status = 'completed',
    completion_time = NOW(),
    final_price = total_price,
    updated_at = NOW()
WHERE id = 'VOTRE_RIDE_ID';
*/
