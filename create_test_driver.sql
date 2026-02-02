-- =========================================
-- CRÉATION D'UN CHAUFFEUR DE TEST
-- Pour tester l'acceptation de courses
-- =========================================

-- 1. Créer un utilisateur pour le chauffeur (si pas déjà existant)
-- Note: Vous devrez créer cet utilisateur via Firebase Auth ou Supabase Auth d'abord
-- Format: u{phone}@t.co, mot de passe: Pwd123!{phone}
-- Exemple: u777777777@t.co avec mot de passe Pwd123!777777777

-- Pour cet exemple, utilisons un user_id fictif ou existant
-- Remplacez 'VOTRE_USER_ID_CHAUFFEUR' par l'UUID d'un utilisateur réel

DO $$
DECLARE
    test_user_id UUID;
    test_driver_id UUID;
BEGIN
    -- Créer un utilisateur de test pour le chauffeur
    INSERT INTO public.users (email, phone_number, created_at, updated_at)
    VALUES ('driver.test@yallatbib.ma', '+212777777777', NOW(), NOW())
    ON CONFLICT (email) DO UPDATE SET updated_at = NOW()
    RETURNING id INTO test_user_id;
    
    RAISE NOTICE 'User ID créé/trouvé: %', test_user_id;
    
    -- Créer le profil chauffeur
    INSERT INTO public.drivers (
        user_id,
        first_name,
        last_name,
        status,
        is_available,
        is_verified,
        rating,
        city,
        created_at,
        updated_at
    ) VALUES (
        test_user_id,
        'Ahmed',
        'Benali',
        'active',          -- Compte actif
        true,              -- Disponible pour accepter des courses
        true,              -- Vérifié
        4.8,               -- Bonne note
        'Casablanca',
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE 
    SET is_available = true, updated_at = NOW()
    RETURNING id INTO test_driver_id;
    
    RAISE NOTICE 'Driver ID créé/trouvé: %', test_driver_id;
    
    -- Créer un véhicule pour le chauffeur
    INSERT INTO public.vehicles (
        driver_id,
        make,
        model,
        year,
        color,
        plate_number,
        vehicle_type,
        wheelchair_accessible,
        is_active,
        is_verified,
        created_at,
        updated_at
    ) VALUES (
        test_driver_id,
        'Dacia',
        'Logan',
        2022,
        'Blanc',
        'A-12345-99',
        'standard_car',
        false,
        true,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (plate_number) DO NOTHING;
    
    RAISE NOTICE 'Véhicule créé pour le chauffeur';
    
    -- Afficher le résumé
    RAISE NOTICE '===================================';
    RAISE NOTICE 'CHAUFFEUR DE TEST CRÉÉ AVEC SUCCÈS';
    RAISE NOTICE '===================================';
    RAISE NOTICE 'User ID: %', test_user_id;
    RAISE NOTICE 'Driver ID: %', test_driver_id;
    RAISE NOTICE 'Email: driver.test@yallatbib.ma';
    RAISE NOTICE 'Téléphone: +212777777777';
    RAISE NOTICE 'Nom: Ahmed Benali';
    RAISE NOTICE 'Véhicule: Dacia Logan 2022 (A-12345-99)';
    RAISE NOTICE 'Statut: Actif et disponible';
    
END $$;

-- Vérification finale
SELECT 
    d.id as driver_id,
    d.first_name,
    d.last_name,
    d.status,
    d.is_available,
    d.rating,
    u.email,
    u.phone_number,
    v.make,
    v.model,
    v.plate_number
FROM public.drivers d
JOIN public.users u ON d.user_id = u.id
LEFT JOIN public.vehicles v ON v.driver_id = d.id
WHERE u.email = 'driver.test@yallatbib.ma';
