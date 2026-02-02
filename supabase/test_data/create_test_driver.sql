-- =========================================
-- CRÉATION D'UN CHAUFFEUR DE TEST
-- =========================================
-- Ce script crée un chauffeur complet pour tester l'acceptation de courses

-- 1. Créer un utilisateur pour le chauffeur
INSERT INTO public.users (id, email, phone_number, created_at, updated_at, is_active)
VALUES (
    'aaaaaaaa-bbbb-cccc-dddd-000000000001',
    'driver.test@yallatbib.ma',
    '+212600000001',
    NOW(),
    NOW(),
    true
) ON CONFLICT (id) DO NOTHING;

-- 2. Créer le profil chauffeur
INSERT INTO public.drivers (
    id,
    user_id,
    first_name,
    last_name,
    date_of_birth,
    national_id,
    status,
    is_available,
    is_verified,
    rating,
    total_rides,
    completed_rides,
    cancelled_rides,
    specializations,
    created_at,
    updated_at
) VALUES (
    'dddddddd-1111-2222-3333-444444444444',
    'aaaaaaaa-bbbb-cccc-dddd-000000000001',
    'Mohamed',
    'Alami',
    '1985-06-15',
    'AB123456',
    'active',
    true,
    true,
    4.8,
    150,
    145,
    5,
    ARRAY['ambulance', 'medical']::driver_specialization[],
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- 3. Créer un véhicule pour le chauffeur
INSERT INTO public.vehicles (
    id,
    driver_id,
    make,
    model,
    year,
    color,
    plate_number,
    vehicle_type,
    wheelchair_accessible,
    stretcher_capacity,
    medical_equipment,
    is_active,
    is_verified,
    created_at,
    updated_at
) VALUES (
    'eeeeeeee-1111-2222-3333-444444444444',
    'dddddddd-1111-2222-3333-444444444444',
    'Mercedes',
    'Sprinter',
    2022,
    'Blanc',
    'A-12345-B',
    'ambulance',
    true,
    1,
    '["Oxygène", "Défibrillateur", "Brancard automatique"]'::jsonb,
    true,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- 4. Vérification
SELECT 
    u.email,
    d.first_name,
    d.last_name,
    d.status,
    d.is_available,
    d.rating,
    v.make,
    v.model,
    v.plate_number
FROM public.users u
JOIN public.drivers d ON u.id = d.user_id
LEFT JOIN public.vehicles v ON d.id = v.driver_id
WHERE u.id = 'aaaaaaaa-bbbb-cccc-dddd-000000000001';

-- ✅ Chauffeur de test créé !
-- Email: driver.test@yallatbib.ma
-- Driver ID: dddddddd-1111-2222-3333-444444444444
-- Véhicule: Mercedes Sprinter 2022 (A-12345-B)
