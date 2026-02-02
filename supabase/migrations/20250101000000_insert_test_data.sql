-- =========================================
-- YALLA TBIB - DONNÉES DE TEST
-- Date: 01/01/2025
-- Objectif: Ajouter des données réalistes pour tester l'application
-- =========================================

-- =========================================
-- 1. UTILISATEURS DE TEST
-- =========================================
INSERT INTO public.users (id, email, phone_number, email_verified, phone_verified, is_active) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'mohamed.tazi@yallatbib.ma', '+212661234567', true, true, true),
    ('550e8400-e29b-41d4-a716-446655440002', 'ahmed.bennani@yallatbib.ma', '+212662345678', true, true, true),
    ('550e8400-e29b-41d4-a716-446655440003', 'fatima.alaoui@yallatbib.ma', '+212663456789', true, true, true),
    ('550e8400-e29b-41d4-a716-446655440004', 'said.ouali@yallatbib.ma', '+212664567890', true, true, true),
    ('550e8400-e29b-41d4-a716-446655440005', 'khadija.el.fassi@gmail.com', '+212665678901', true, true, true),
    ('550e8400-e29b-41d4-a716-446655440006', 'rachid.amrani@gmail.com', '+212666789012', true, true, true)
ON CONFLICT (id) DO NOTHING;

-- =========================================
-- 2. CHAUFFEURS DE TEST
-- =========================================
INSERT INTO public.drivers (
    id, user_id, first_name, last_name, date_of_birth, national_id,
    current_location, address, city, postal_code,
    status, is_available, is_verified,
    specializations, rating, total_rides, completed_rides,
    last_active
) VALUES
    (
        '660e8400-e29b-41d4-a716-446655440001',
        '550e8400-e29b-41d4-a716-446655440001',
        'Mohamed', 'Tazi', '1985-03-15', 'BE123456',
        ST_GeogFromText('POINT(-6.8498 33.9716)'), -- Rabat centre
        '15 Avenue Mohammed V, Hassan', 'Rabat', '10000',
        'active', true, true,
        ARRAY['ambulance', 'emergency']::driver_specialization[],
        4.8, 156, 142,
        NOW() - INTERVAL '5 minutes'
    ),
    (
        '660e8400-e29b-41d4-a716-446655440002',
        '550e8400-e29b-41d4-a716-446655440002',
        'Ahmed', 'Bennani', '1990-07-22', 'BE789012',
        ST_GeogFromText('POINT(-6.8368 33.9592)'), -- Agdal, Rabat
        '42 Rue Patrice Lumumba, Agdal', 'Rabat', '10090',
        'active', true, true,
        ARRAY['medical', 'patientTransfer']::driver_specialization[],
        4.6, 89, 83,
        NOW() - INTERVAL '2 minutes'
    ),
    (
        '660e8400-e29b-41d4-a716-446655440003',
        '550e8400-e29b-41d4-a716-446655440003',
        'Fatima', 'Alaoui', '1988-11-08', 'BE345678',
        ST_GeogFromText('POINT(-6.8704 33.9911)'), -- Hay Riad, Rabat
        '78 Boulevard Ar-Riad, Hay Riad', 'Rabat', '10100',
        'active', false, true,
        ARRAY['handicap', 'medical']::driver_specialization[],
        4.9, 203, 198,
        NOW() - INTERVAL '1 hour'
    ),
    (
        '660e8400-e29b-41d4-a716-446655440004',
        '550e8400-e29b-41d4-a716-446655440004',
        'Said', 'Ouali', '1982-12-03', 'BE901234',
        ST_GeogFromText('POINT(-6.8302 33.9778)'), -- Souissi, Rabat
        '12 Avenue Allal Ben Abdellah, Souissi', 'Rabat', '10170',
        'active', true, true,
        ARRAY['ambulance', 'emergency', 'dialysis']::driver_specialization[],
        4.7, 134, 127,
        NOW() - INTERVAL '8 minutes'
    )
ON CONFLICT (id) DO NOTHING;

-- =========================================
-- 3. VÉHICULES DES CHAUFFEURS
-- =========================================
INSERT INTO public.vehicles (
    id, driver_id, make, model, year, color, plate_number, vehicle_type,
    wheelchair_accessible, stretcher_capacity, medical_equipment,
    is_active, is_verified
) VALUES
    (
        '770e8400-e29b-41d4-a716-446655440001',
        '660e8400-e29b-41d4-a716-446655440001',
        'Mercedes', 'Sprinter', 2021, 'Blanc', 'A-12345-R', 'ambulance',
        true, 1, '["defibrillator", "oxygen_tank", "first_aid_kit", "stretcher"]'::jsonb,
        true, true
    ),
    (
        '770e8400-e29b-41d4-a716-446655440002',
        '660e8400-e29b-41d4-a716-446655440002',
        'Renault', 'Kangoo', 2020, 'Blanc', 'B-67890-R', 'medical_transport',
        true, 0, '["wheelchair_ramp", "first_aid_kit"]'::jsonb,
        true, true
    ),
    (
        '770e8400-e29b-41d4-a716-446655440003',
        '660e8400-e29b-41d4-a716-446655440003',
        'Ford', 'Transit', 2019, 'Blanc', 'C-13579-R', 'adapted_vehicle',
        true, 1, '["wheelchair_ramp", "lifting_system", "first_aid_kit"]'::jsonb,
        true, true
    ),
    (
        '770e8400-e29b-41d4-a716-446655440004',
        '660e8400-e29b-41d4-a716-446655440004',
        'Peugeot', 'Boxer', 2022, 'Blanc', 'D-24680-R', 'ambulance',
        true, 1, '["defibrillator", "oxygen_tank", "dialysis_equipment", "stretcher"]'::jsonb,
        true, true
    )
ON CONFLICT (id) DO NOTHING;

-- =========================================
-- 4. PATIENTS DE TEST
-- =========================================
INSERT INTO public.patients (
    id, user_id, first_name, last_name, date_of_birth,
    medical_conditions, emergency_contact_name, emergency_contact_phone,
    mobility_requirements
) VALUES
    (
        '880e8400-e29b-41d4-a716-446655440001',
        '550e8400-e29b-41d4-a716-446655440005',
        'Khadija', 'El Fassi', '1965-05-20',
        '["diabetes", "hypertension"]'::jsonb,
        'Omar El Fassi', '+212667890123',
        '{"wheelchair": true, "assistance_required": true}'::jsonb
    ),
    (
        '880e8400-e29b-41d4-a716-446655440002',
        '550e8400-e29b-41d4-a716-446655440006',
        'Rachid', 'Amrani', '1978-09-14',
        '["kidney_disease"]'::jsonb,
        'Aicha Amrani', '+212668901234',
        '{"dialysis_patient": true, "mobility_aid": "walker"}'::jsonb
    )
ON CONFLICT (id) DO NOTHING;

-- =========================================
-- 5. COURSES D'EXEMPLE (EN ATTENTE)
-- =========================================
INSERT INTO public.rides (
    id, patient_id, pickup_location, pickup_address, 
    destination_location, destination_address,
    scheduled_time, status, priority, special_requirements,
    estimated_price, currency
) VALUES
    (
        '990e8400-e29b-41d4-a716-446655440001',
        '880e8400-e29b-41d4-a716-446655440001',
        ST_GeogFromText('POINT(-6.8520 33.9697)'), -- Quartier Hassan
        'Quartier Hassan, Rue Al Kharroub, Rabat',
        ST_GeogFromText('POINT(-6.8180 33.9890)'), -- Hôpital Ibn Sina
        'Hôpital Ibn Sina, Avenue Ibn Sina, Rabat',
        NOW() + INTERVAL '15 minutes',
        'pending', 'high',
        '{"wheelchair_required": true, "assistance_needed": true, "patient_condition": "diabetes_emergency"}'::jsonb,
        45.00, 'MAD'
    ),
    (
        '990e8400-e29b-41d4-a716-446655440002',
        '880e8400-e29b-41d4-a716-446655440002',
        ST_GeogFromText('POINT(-6.8368 33.9592)'), -- Agdal
        'Agdal, Rue de Fès, Rabat',
        ST_GeogFromText('POINT(-6.8450 33.9720)'), -- Pharmacie Centrale
        'Pharmacie Centrale, Avenue Mohammed V, Rabat',
        NOW() + INTERVAL '10 minutes',
        'pending', 'medium',
        '{"prescription_pickup": true, "dialysis_medication": true}'::jsonb,
        25.00, 'MAD'
    ),
    (
        '990e8400-e29b-41d4-a716-446655440003',
        '880e8400-e29b-41d4-a716-446655440001',
        ST_GeogFromText('POINT(-6.8704 33.9911)'), -- Hay Riad
        'Hay Riad, Boulevard Ar-Riad, Rabat',
        ST_GeogFromText('POINT(-6.7950 33.9850)'), -- Centre de Dialyse
        'Centre de Dialyse Agdal, Avenue Omar Ibn Khattab, Rabat',
        NOW() + INTERVAL '30 minutes',
        'pending', 'urgent',
        '{"dialysis_appointment": true, "wheelchair_required": true, "medical_escort": false}'::jsonb,
        35.00, 'MAD'
    )
ON CONFLICT (id) DO NOTHING;

-- =========================================
-- 6. HISTORIQUE DES COURSES TERMINÉES
-- =========================================
INSERT INTO public.rides (
    id, patient_id, driver_id, 
    pickup_location, pickup_address, 
    destination_location, destination_address,
    scheduled_time, pickup_time, completion_time,
    status, priority, final_price, currency,
    patient_rating, driver_rating, patient_feedback
) VALUES
    (
        '990e8400-e29b-41d4-a716-446655440101',
        '880e8400-e29b-41d4-a716-446655440001',
        '660e8400-e29b-41d4-a716-446655440001',
        ST_GeogFromText('POINT(-6.8520 33.9697)'),
        'Quartier Hassan, Rue Al Kharroub, Rabat',
        ST_GeogFromText('POINT(-6.8180 33.9890)'),
        'Hôpital Ibn Sina, Avenue Ibn Sina, Rabat',
        NOW() - INTERVAL '2 days',
        NOW() - INTERVAL '2 days' + INTERVAL '8 minutes',
        NOW() - INTERVAL '2 days' + INTERVAL '25 minutes',
        'completed', 'high', 45.00, 'MAD',
        5, 5, 'Excellent service, chauffeur très professionnel et attentionné'
    ),
    (
        '990e8400-e29b-41d4-a716-446655440102',
        '880e8400-e29b-41d4-a716-446655440002',
        '660e8400-e29b-41d4-a716-446655440002',
        ST_GeogFromText('POINT(-6.8368 33.9592)'),
        'Agdal, Rue de Fès, Rabat',
        ST_GeogFromText('POINT(-6.7950 33.9850)'),
        'Centre de Dialyse Agdal, Rabat',
        NOW() - INTERVAL '1 day',
        NOW() - INTERVAL '1 day' + INTERVAL '5 minutes',
        NOW() - INTERVAL '1 day' + INTERVAL '18 minutes',
        'completed', 'urgent', 35.00, 'MAD',
        4, 5, 'Transport ponctuel pour la dialyse, merci'
    )
ON CONFLICT (id) DO NOTHING;

-- =========================================
-- 7. PAIEMENTS ASSOCIÉS
-- =========================================
INSERT INTO public.payments (
    id, ride_id, patient_id, driver_id,
    amount, driver_earnings, platform_fee, currency,
    payment_method, status, paid_at
) VALUES
    (
        'aa0e8400-e29b-41d4-a716-446655440001',
        '990e8400-e29b-41d4-a716-446655440101',
        '880e8400-e29b-41d4-a716-446655440001',
        '660e8400-e29b-41d4-a716-446655440001',
        45.00, 38.25, 6.75, 'MAD',
        'cash', 'completed', NOW() - INTERVAL '2 days' + INTERVAL '30 minutes'
    ),
    (
        'aa0e8400-e29b-41d4-a716-446655440002',
        '990e8400-e29b-41d4-a716-446655440102',
        '880e8400-e29b-41d4-a716-446655440002',
        '660e8400-e29b-41d4-a716-446655440002',
        35.00, 29.75, 5.25, 'MAD',
        'cash', 'completed', NOW() - INTERVAL '1 day' + INTERVAL '20 minutes'
    )
ON CONFLICT (id) DO NOTHING;

-- =========================================
-- 8. DOCUMENTS CHAUFFEURS (EXEMPLES)
-- =========================================
INSERT INTO public.driver_documents (
    id, driver_id, document_type, status, expiry_date, verified_at
) VALUES
    ('bb0e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', 'driving_license', 'approved', '2026-03-15', NOW() - INTERVAL '30 days'),
    ('bb0e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440001', 'medical_transport_permit', 'approved', '2025-12-31', NOW() - INTERVAL '30 days'),
    ('bb0e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440002', 'driving_license', 'approved', '2027-07-22', NOW() - INTERVAL '25 days'),
    ('bb0e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440002', 'medical_transport_permit', 'approved', '2025-10-15', NOW() - INTERVAL '25 days')
ON CONFLICT (id) DO NOTHING;

-- =========================================
-- MISE À JOUR DES STATISTIQUES
-- =========================================

-- Mettre à jour les statistiques des chauffeurs
UPDATE public.drivers SET 
    rating = 4.8, 
    total_rides = 157, 
    completed_rides = 143,
    updated_at = NOW()
WHERE id = '660e8400-e29b-41d4-a716-446655440001';

UPDATE public.drivers SET 
    rating = 4.6, 
    total_rides = 90, 
    completed_rides = 84,
    updated_at = NOW()
WHERE id = '660e8400-e29b-41d4-a716-446655440002';

-- =========================================
-- COMMENTAIRE FINAL
-- =========================================

-- Ces données de test fournissent:
-- ✅ 4 Chauffeurs actifs avec spécialisations différentes
-- ✅ 2 Patients avec conditions médicales 
-- ✅ 3 Courses en attente pour tester l'acceptation
-- ✅ 2 Courses terminées avec évaluations
-- ✅ Véhicules équipés selon spécialisations
-- ✅ Géolocalisation réaliste dans Rabat
-- ✅ Paiements et documents validés

COMMENT ON TABLE public.rides IS 'Courses avec données de test réalistes pour Rabat';