-- =========================================
-- SCRIPT DE TEST : Simulation acceptation de course
-- =========================================

-- 1. Exécuter d'abord create_test_driver.sql pour créer le chauffeur

-- 2. Obtenir l'ID du chauffeur de test
DO $$
DECLARE
    test_driver_id UUID;
    latest_ride_id UUID;
BEGIN
    -- Récupérer l'ID du chauffeur de test
    SELECT d.id INTO test_driver_id
    FROM public.drivers d
    JOIN public.users u ON d.user_id = u.id
    WHERE u.email = 'driver.test@yallatbib.ma'
    LIMIT 1;
    
    IF test_driver_id IS NULL THEN
        RAISE EXCEPTION 'Chauffeur de test non trouvé. Exécutez d''abord create_test_driver.sql';
    END IF;
    
    RAISE NOTICE 'Driver ID trouvé: %', test_driver_id;
    
    -- Récupérer la dernière course en attente
    SELECT id INTO latest_ride_id
    FROM public.rides
    WHERE status = 'pending' AND driver_id IS NULL
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF latest_ride_id IS NULL THEN
        RAISE NOTICE 'Aucune course en attente trouvée';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Course en attente trouvée: %', latest_ride_id;
    
    -- Accepter la course
    UPDATE public.rides
    SET 
        driver_id = test_driver_id,
        status = 'accepted',
        updated_at = NOW()
    WHERE id = latest_ride_id;
    
    RAISE NOTICE '✅ COURSE ACCEPTÉE PAR LE CHAUFFEUR !';
    RAISE NOTICE '===================================';
    RAISE NOTICE 'Ride ID: %', latest_ride_id;
    RAISE NOTICE 'Driver ID: %', test_driver_id;
    RAISE NOTICE 'Nouveau statut: accepted';
    RAISE NOTICE '';
    RAISE NOTICE 'L''app devrait maintenant afficher RideTrackingScreen';
    
END $$;

-- Vérification : afficher les détails de la course acceptée
SELECT 
    r.id as ride_id,
    r.status,
    r.pickup_address,
    r.destination_address,
    r.total_price,
    d.first_name || ' ' || d.last_name as driver_name,
    d.rating as driver_rating,
    p.first_name || ' ' || p.last_name as patient_name
FROM public.rides r
LEFT JOIN public.drivers d ON r.driver_id = d.id
LEFT JOIN public.patients p ON r.patient_id = p.id
WHERE r.status = 'accepted'
ORDER BY r.updated_at DESC
LIMIT 1;
