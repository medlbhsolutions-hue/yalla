-- =========================================
-- YALLA TBIB - SETUP COMPLET EN UN SEUL SCRIPT
-- Date: 13/10/2025
-- =========================================

-- ÉTAPE 1: NETTOYAGE COMPLET
-- =========================================
DROP VIEW IF EXISTS public.rides_full CASCADE;
DROP VIEW IF EXISTS public.drivers_full CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.rides CASCADE;
DROP TABLE IF EXISTS public.driver_documents CASCADE;
DROP TABLE IF EXISTS public.patients CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;
DROP TABLE IF EXISTS public.drivers CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TYPE IF EXISTS payment_method CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS priority_level CASCADE;
DROP TYPE IF EXISTS ride_status CASCADE;
DROP TYPE IF EXISTS document_status CASCADE;
DROP TYPE IF EXISTS document_type CASCADE;
DROP TYPE IF EXISTS vehicle_type CASCADE;
DROP TYPE IF EXISTS driver_specialization CASCADE;
DROP TYPE IF EXISTS driver_status CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ÉTAPE 2: CRÉER LES TYPES ENUM
-- =========================================
CREATE TYPE driver_status AS ENUM ('pending', 'active', 'inactive', 'suspended', 'rejected');
CREATE TYPE driver_specialization AS ENUM ('ambulance', 'handicap', 'medical', 'emergency', 'patientTransfer', 'dialysis', 'chemotherapy');
CREATE TYPE vehicle_type AS ENUM ('ambulance', 'standard_car', 'adapted_vehicle', 'wheelchair_accessible', 'medical_transport');
CREATE TYPE ride_status AS ENUM ('pending', 'accepted', 'driver_en_route', 'arrived', 'in_progress', 'completed', 'cancelled', 'no_show');
CREATE TYPE priority_level AS ENUM ('low', 'medium', 'high', 'urgent');
CREATE TYPE payment_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'refunded', 'cancelled');
CREATE TYPE payment_method AS ENUM ('cash', 'credit_card', 'insurance', 'bank_transfer');
CREATE TYPE document_type AS ENUM ('driving_license', 'vehicle_registration', 'insurance_certificate', 'medical_certificate', 'criminal_background_check', 'professional_card', 'vehicle_inspection', 'identity_card', 'medical_transport_permit');
CREATE TYPE document_status AS ENUM ('pending', 'approved', 'rejected', 'expired', 'missing');

-- ÉTAPE 3: CRÉER LES TABLES
-- =========================================

-- Table users
CREATE TABLE public.users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Table drivers
CREATE TABLE public.drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    national_id VARCHAR(50) UNIQUE,
    avatar TEXT,
    current_location GEOGRAPHY(POINT),
    address TEXT,
    city VARCHAR(100),
    postal_code VARCHAR(20),
    status driver_status DEFAULT 'pending',
    is_available BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    specializations driver_specialization[] DEFAULT ARRAY[]::driver_specialization[],
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_rides INTEGER DEFAULT 0,
    completed_rides INTEGER DEFAULT 0,
    cancelled_rides INTEGER DEFAULT 0,
    stripe_connected_account_id VARCHAR(255),
    bank_account_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active TIMESTAMP WITH TIME ZONE,
    verified_at TIMESTAMP WITH TIME ZONE
);

-- Table vehicles
CREATE TABLE public.vehicles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID REFERENCES public.drivers(id) ON DELETE CASCADE,
    make VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INTEGER,
    color VARCHAR(50),
    plate_number VARCHAR(20) UNIQUE NOT NULL,
    vehicle_type vehicle_type NOT NULL,
    wheelchair_accessible BOOLEAN DEFAULT FALSE,
    stretcher_capacity INTEGER DEFAULT 0,
    medical_equipment JSONB DEFAULT '[]',
    insurance_expiry DATE,
    registration_expiry DATE,
    inspection_expiry DATE,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table patients
CREATE TABLE public.patients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    medical_conditions JSONB DEFAULT '[]',
    medications JSONB DEFAULT '[]',
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(20),
    mobility_requirements JSONB DEFAULT '{}',
    preferred_language VARCHAR(10) DEFAULT 'fr',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table rides
CREATE TABLE public.rides (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id),
    driver_id UUID REFERENCES public.drivers(id),
    pickup_location GEOGRAPHY(POINT) NOT NULL,
    pickup_address TEXT NOT NULL,
    destination_location GEOGRAPHY(POINT) NOT NULL,
    destination_address TEXT NOT NULL,
    scheduled_time TIMESTAMP WITH TIME ZONE,
    pickup_time TIMESTAMP WITH TIME ZONE,
    arrival_time TIMESTAMP WITH TIME ZONE,
    completion_time TIMESTAMP WITH TIME ZONE,
    status ride_status DEFAULT 'pending',
    priority priority_level DEFAULT 'medium',
    special_requirements JSONB DEFAULT '{}',
    medical_notes TEXT,
    estimated_price DECIMAL(10,2),
    final_price DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'MAD',
    patient_rating INTEGER CHECK (patient_rating >= 1 AND patient_rating <= 5),
    driver_rating INTEGER CHECK (driver_rating >= 1 AND driver_rating <= 5),
    patient_feedback TEXT,
    driver_feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table payments
CREATE TABLE public.payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ride_id UUID REFERENCES public.rides(id),
    patient_id UUID REFERENCES public.patients(id),
    driver_id UUID REFERENCES public.drivers(id),
    amount DECIMAL(10,2) NOT NULL,
    driver_earnings DECIMAL(10,2),
    platform_fee DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'MAD',
    payment_method payment_method NOT NULL,
    status payment_status DEFAULT 'pending',
    external_payment_id VARCHAR(255),
    external_transaction_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE
);

-- ÉTAPE 4: GRANT PERMISSIONS
-- =========================================
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- ÉTAPE 5: DÉSACTIVER RLS POUR LES TESTS
-- =========================================
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments DISABLE ROW LEVEL SECURITY;

-- ÉTAPE 6: INSÉRER LES DONNÉES DE TEST
-- =========================================

-- Utilisateurs
INSERT INTO public.users (id, email, phone_number, email_verified, phone_verified, is_active) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'mohamed.tazi@yallatbib.ma', '+212661234567', true, true, true),
    ('550e8400-e29b-41d4-a716-446655440002', 'ahmed.bennani@yallatbib.ma', '+212662345678', true, true, true),
    ('550e8400-e29b-41d4-a716-446655440003', 'fatima.alaoui@yallatbib.ma', '+212663456789', true, true, true),
    ('550e8400-e29b-41d4-a716-446655440004', 'said.ouali@yallatbib.ma', '+212664567890', true, true, true);

-- Chauffeurs
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
        ST_GeogFromText('POINT(-6.8498 33.9716)'),
        '15 Avenue Mohammed V, Hassan', 'Rabat', '10000',
        'active', true, true,
        ARRAY['ambulance', 'emergency']::driver_specialization[],
        4.8, 156, 142,
        NOW()
    ),
    (
        '660e8400-e29b-41d4-a716-446655440002',
        '550e8400-e29b-41d4-a716-446655440002',
        'Ahmed', 'Bennani', '1990-07-22', 'BE789012',
        ST_GeogFromText('POINT(-6.8368 33.9592)'),
        '42 Rue Patrice Lumumba, Agdal', 'Rabat', '10090',
        'active', true, true,
        ARRAY['medical', 'patientTransfer']::driver_specialization[],
        4.6, 89, 83,
        NOW()
    ),
    (
        '660e8400-e29b-41d4-a716-446655440003',
        '550e8400-e29b-41d4-a716-446655440003',
        'Fatima', 'Alaoui', '1988-11-08', 'BE345678',
        ST_GeogFromText('POINT(-6.8704 33.9911)'),
        '78 Boulevard Ar-Riad, Hay Riad', 'Rabat', '10100',
        'active', false, true,
        ARRAY['handicap', 'medical']::driver_specialization[],
        4.9, 203, 198,
        NOW()
    ),
    (
        '660e8400-e29b-41d4-a716-446655440004',
        '550e8400-e29b-41d4-a716-446655440004',
        'Said', 'Ouali', '1982-12-03', 'BE901234',
        ST_GeogFromText('POINT(-6.8302 33.9778)'),
        '12 Avenue Allal Ben Abdellah, Souissi', 'Rabat', '10170',
        'active', true, true,
        ARRAY['ambulance', 'emergency', 'dialysis']::driver_specialization[],
        4.7, 134, 127,
        NOW()
    );

-- Véhicules
INSERT INTO public.vehicles (
    id, driver_id, make, model, year, color, plate_number, vehicle_type,
    wheelchair_accessible, stretcher_capacity, is_active, is_verified
) VALUES
    ('770e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001',
     'Mercedes', 'Sprinter', 2021, 'Blanc', 'A-12345-R', 'ambulance', true, 1, true, true),
    ('770e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440002',
     'Renault', 'Kangoo', 2020, 'Blanc', 'B-67890-R', 'medical_transport', true, 0, true, true),
    ('770e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440003',
     'Ford', 'Transit', 2019, 'Blanc', 'C-13579-R', 'adapted_vehicle', true, 1, true, true),
    ('770e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440004',
     'Peugeot', 'Boxer', 2022, 'Blanc', 'D-24680-R', 'ambulance', true, 1, true, true);

-- ÉTAPE 7: RAFRAÎCHIR POSTGREST
-- =========================================
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';

-- ÉTAPE 8: VÉRIFICATION
-- =========================================
SELECT 
    d.first_name, 
    d.last_name,
    d.is_available,
    d.rating,
    v.make,
    v.model
FROM drivers d
LEFT JOIN vehicles v ON v.driver_id = d.id
WHERE d.is_available = true;

-- Message final
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'SETUP COMPLET !';
    RAISE NOTICE '4 chauffeurs créés';
    RAISE NOTICE '3 disponibles (Mohamed, Ahmed, Said)';
    RAISE NOTICE '========================================';
END $$;
