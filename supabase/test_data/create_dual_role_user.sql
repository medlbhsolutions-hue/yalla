-- =========================================
-- CRÉER UN UTILISATEUR PATIENT + CHAUFFEUR
-- =========================================
-- Cet utilisateur pourra tester les 2 interfaces

-- 1. L'utilisateur existe déjà: 383bed51-60f1-4566-928f-468a7ad22eec
-- On va juste lui créer un profil chauffeur + véhicule

-- 2. Créer le profil chauffeur pour l'utilisateur de test
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
    'bbbbbbbb-2222-3333-4444-555555555555',
    '383bed51-60f1-4566-928f-468a7ad22eec',  -- Notre utilisateur de test
    'Ahmed',
    'Test',
    '1990-05-20',
    'CD789012',
    'active',
    true,
    true,
    4.9,
    0,
    0,
    0,
    ARRAY['ambulance', 'medical', 'standard']::driver_specialization[],
    NOW(),
    NOW()
) ON CONFLICT (id) DO UPDATE
SET 
    is_available = true,
    updated_at = NOW();

-- 3. Créer un véhicule pour ce chauffeur
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
    'cccccccc-3333-4444-5555-666666666666',
    'bbbbbbbb-2222-3333-4444-555555555555',
    'Renault',
    'Kangoo',
    2021,
    'Blanc',
    'B-67890-C',
    'ambulance',
    true,
    1,
    '["Oxygène", "Trousse premiers secours", "Brancard"]'::jsonb,
    true,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO UPDATE
SET 
    is_active = true,
    updated_at = NOW();

-- 4. Vérification
SELECT 
    u.email,
    u.phone_number,
    p.id as patient_id,
    p.first_name || ' ' || p.last_name as patient_name,
    d.id as driver_id,
    d.first_name || ' ' || d.last_name as driver_name,
    d.is_available,
    v.make || ' ' || v.model as vehicle
FROM public.users u
LEFT JOIN public.patients p ON u.id = p.user_id
LEFT JOIN public.drivers d ON u.id = d.user_id
LEFT JOIN public.vehicles v ON d.id = v.driver_id
WHERE u.id = '383bed51-60f1-4566-928f-468a7ad22eec';

-- ✅ Résultat attendu:
-- Cet utilisateur aura DEUX rôles: Patient ET Chauffeur
-- Il pourra basculer entre les deux dashboards
