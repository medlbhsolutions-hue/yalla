-- =========================================
-- YALLA TBIB - SCHÉMA BASE DE DONNÉES COMPLET
-- Date: 01/10/2025 
-- Planning: Base de Données & Modèles
-- =========================================

-- Extension pour UUID et PostGIS (géolocalisation)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- =========================================
-- 1. TABLE DES UTILISATEURS (BASE)
-- =========================================
CREATE TABLE IF NOT EXISTS public.users (
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

-- =========================================
-- 2. TABLE DES CHAUFFEURS
-- =========================================
CREATE TYPE driver_status AS ENUM (
    'pending',      -- En attente de vérification
    'active',       -- Compte vérifié et actif
    'inactive',     -- Compte vérifié mais temporairement inactif
    'suspended',    -- Compte suspendu par l'administration
    'rejected'      -- Compte refusé
);

CREATE TYPE driver_specialization AS ENUM (
    'ambulance',
    'handicap',
    'medical',
    'emergency',
    'patientTransfer',
    'dialysis',
    'chemotherapy'
);

CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    national_id VARCHAR(50) UNIQUE,
    avatar TEXT,
    
    -- Localisation
    current_location GEOGRAPHY(POINT),
    address TEXT,
    city VARCHAR(100),
    postal_code VARCHAR(20),
    
    -- Statut et disponibilité
    status driver_status DEFAULT 'pending',
    is_available BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Spécialisations médicales
    specializations driver_specialization[] DEFAULT ARRAY[]::driver_specialization[],
    
    -- Évaluations et statistiques
    rating DECIMAL(3,2) DEFAULT 0.00,
    total_rides INTEGER DEFAULT 0,
    completed_rides INTEGER DEFAULT 0,
    cancelled_rides INTEGER DEFAULT 0,
    
    -- Informations financières
    stripe_connected_account_id VARCHAR(255),
    bank_account_verified BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active TIMESTAMP WITH TIME ZONE,
    verified_at TIMESTAMP WITH TIME ZONE
);

-- =========================================
-- 3. TABLE DES VÉHICULES
-- =========================================
CREATE TYPE vehicle_type AS ENUM (
    'ambulance',
    'standard_car',
    'adapted_vehicle',
    'wheelchair_accessible',
    'medical_transport'
);

CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID REFERENCES public.drivers(id) ON DELETE CASCADE,
    
    -- Informations véhicule
    make VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INTEGER,
    color VARCHAR(50),
    plate_number VARCHAR(20) UNIQUE NOT NULL,
    vehicle_type vehicle_type NOT NULL,
    
    -- Capacités médicales
    wheelchair_accessible BOOLEAN DEFAULT FALSE,
    stretcher_capacity INTEGER DEFAULT 0,
    medical_equipment JSONB DEFAULT '[]',
    
    -- Assurance et documents
    insurance_expiry DATE,
    registration_expiry DATE,
    inspection_expiry DATE,
    
    -- Statut
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =========================================
-- 4. TABLE DES DOCUMENTS
-- =========================================
CREATE TYPE document_type AS ENUM (
    'driving_license',
    'vehicle_registration',
    'insurance_certificate',
    'medical_certificate',
    'criminal_background_check',
    'professional_card',
    'vehicle_inspection',
    'identity_card',
    'medical_transport_permit'
);

CREATE TYPE document_status AS ENUM (
    'pending',      -- En attente de vérification
    'approved',     -- Document approuvé
    'rejected',     -- Document rejeté
    'expired',      -- Document expiré
    'missing'       -- Document manquant
);

CREATE TABLE IF NOT EXISTS public.driver_documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID REFERENCES public.drivers(id) ON DELETE CASCADE,
    document_type document_type NOT NULL,
    
    -- Fichier et métadonnées
    file_url TEXT,
    file_name VARCHAR(255),
    file_size INTEGER,
    mime_type VARCHAR(100),
    
    -- Statut et validation
    status document_status DEFAULT 'pending',
    expiry_date DATE,
    issued_date DATE,
    issuing_authority VARCHAR(255),
    
    -- Validation par admin
    verified_by UUID,
    verified_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Contrainte d'unicité par chauffeur et type de document
    UNIQUE(driver_id, document_type)
);

-- =========================================
-- 5. TABLE DES PATIENTS
-- =========================================
CREATE TABLE IF NOT EXISTS public.patients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    
    -- Informations médicales
    medical_conditions JSONB DEFAULT '[]',
    medications JSONB DEFAULT '[]',
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(20),
    
    -- Préférences de transport
    mobility_requirements JSONB DEFAULT '{}',
    preferred_language VARCHAR(10) DEFAULT 'fr',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =========================================
-- 6. TABLE DES RÉSERVATIONS/COURSES
-- =========================================
CREATE TYPE ride_status AS ENUM (
    'pending',          -- En attente d'acceptation
    'accepted',         -- Acceptée par un chauffeur
    'driver_en_route',  -- Chauffeur en route vers patient
    'arrived',          -- Chauffeur arrivé chez patient
    'in_progress',      -- Course en cours
    'completed',        -- Course terminée
    'cancelled',        -- Course annulée
    'no_show'          -- Patient absent
);

CREATE TYPE priority_level AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);

CREATE TABLE IF NOT EXISTS public.rides (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    patient_id UUID REFERENCES public.patients(id),
    driver_id UUID REFERENCES public.drivers(id),
    
    -- Localisation
    pickup_location GEOGRAPHY(POINT) NOT NULL,
    pickup_address TEXT NOT NULL,
    destination_location GEOGRAPHY(POINT) NOT NULL,
    destination_address TEXT NOT NULL,
    
    -- Timing
    scheduled_time TIMESTAMP WITH TIME ZONE,
    pickup_time TIMESTAMP WITH TIME ZONE,
    arrival_time TIMESTAMP WITH TIME ZONE,
    completion_time TIMESTAMP WITH TIME ZONE,
    
    -- Détails course
    status ride_status DEFAULT 'pending',
    priority priority_level DEFAULT 'medium',
    special_requirements JSONB DEFAULT '{}',
    medical_notes TEXT,
    
    -- Tarification
    estimated_price DECIMAL(10,2),
    final_price DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'MAD',
    
    -- Évaluation
    patient_rating INTEGER CHECK (patient_rating >= 1 AND patient_rating <= 5),
    driver_rating INTEGER CHECK (driver_rating >= 1 AND driver_rating <= 5),
    patient_feedback TEXT,
    driver_feedback TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =========================================
-- 7. TABLE DES PAIEMENTS
-- =========================================
CREATE TYPE payment_status AS ENUM (
    'pending',
    'processing',
    'completed',
    'failed',
    'refunded',
    'cancelled'
);

CREATE TYPE payment_method AS ENUM (
    'cash',
    'credit_card',
    'insurance',
    'bank_transfer'
);

CREATE TABLE IF NOT EXISTS public.payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ride_id UUID REFERENCES public.rides(id),
    patient_id UUID REFERENCES public.patients(id),
    driver_id UUID REFERENCES public.drivers(id),
    
    -- Montants
    amount DECIMAL(10,2) NOT NULL,
    driver_earnings DECIMAL(10,2),
    platform_fee DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'MAD',
    
    -- Méthode et statut
    payment_method payment_method NOT NULL,
    status payment_status DEFAULT 'pending',
    
    -- Intégration externe (Stripe, etc.)
    external_payment_id VARCHAR(255),
    external_transaction_id VARCHAR(255),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE
);

-- =========================================
-- 8. INDEX POUR PERFORMANCE
-- =========================================

-- Index géospatiaux pour localisation
CREATE INDEX idx_drivers_location ON public.drivers USING GIST (current_location);
CREATE INDEX idx_rides_pickup_location ON public.rides USING GIST (pickup_location);
CREATE INDEX idx_rides_destination_location ON public.rides USING GIST (destination_location);

-- Index sur les statuts fréquemment utilisés
CREATE INDEX idx_drivers_status ON public.drivers (status);
CREATE INDEX idx_drivers_available ON public.drivers (is_available);
CREATE INDEX idx_rides_status ON public.rides (status);
CREATE INDEX idx_payments_status ON public.payments (status);

-- Index sur les relations fréquentes
CREATE INDEX idx_drivers_user_id ON public.drivers (user_id);
CREATE INDEX idx_vehicles_driver_id ON public.vehicles (driver_id);
CREATE INDEX idx_documents_driver_id ON public.driver_documents (driver_id);
CREATE INDEX idx_rides_patient_id ON public.rides (patient_id);
CREATE INDEX idx_rides_driver_id ON public.rides (driver_id);

-- Index temporels
CREATE INDEX idx_rides_created_at ON public.rides (created_at);
CREATE INDEX idx_rides_scheduled_time ON public.rides (scheduled_time);
CREATE INDEX idx_payments_created_at ON public.payments (created_at);

-- =========================================
-- 9. FONCTIONS DE MISE À JOUR AUTOMATIQUE
-- =========================================

-- Fonction pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers pour updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON public.drivers 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON public.vehicles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON public.driver_documents 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON public.patients 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rides_updated_at BEFORE UPDATE ON public.rides 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON public.payments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 10. POLITIQUES DE SÉCURITÉ RLS (Row Level Security)
-- =========================================

-- Activer RLS sur toutes les tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Politiques pour les chauffeurs (peuvent voir/modifier leurs propres données)
CREATE POLICY "Drivers can view own data" ON public.drivers
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Drivers can update own data" ON public.drivers
    FOR UPDATE USING (auth.uid() = user_id);

-- Politiques pour les véhicules
CREATE POLICY "Drivers can manage own vehicles" ON public.vehicles
    FOR ALL USING (
        driver_id IN (
            SELECT id FROM public.drivers WHERE user_id = auth.uid()
        )
    );

-- Politiques pour les documents
CREATE POLICY "Drivers can manage own documents" ON public.driver_documents
    FOR ALL USING (
        driver_id IN (
            SELECT id FROM public.drivers WHERE user_id = auth.uid()
        )
    );

-- Politiques pour les patients
CREATE POLICY "Patients can view own data" ON public.patients
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Patients can update own data" ON public.patients
    FOR UPDATE USING (auth.uid() = user_id);

-- Politiques pour les courses
CREATE POLICY "Users can view own rides" ON public.rides
    FOR SELECT USING (
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()) OR
        driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
    );

-- =========================================
-- 11. VUES UTILES
-- =========================================

-- Vue des chauffeurs avec détails complets
CREATE OR REPLACE VIEW public.drivers_full AS
SELECT 
    d.*,
    u.email,
    u.phone_number,
    u.email_verified,
    u.phone_verified,
    v.make as vehicle_make,
    v.model as vehicle_model,
    v.plate_number,
    v.vehicle_type,
    (
        SELECT COUNT(*) 
        FROM public.driver_documents dd 
        WHERE dd.driver_id = d.id AND dd.status = 'approved'
    ) as approved_documents_count,
    (
        SELECT COUNT(*) 
        FROM public.driver_documents dd 
        WHERE dd.driver_id = d.id
    ) as total_documents_count
FROM public.drivers d
LEFT JOIN public.users u ON d.user_id = u.id
LEFT JOIN public.vehicles v ON v.driver_id = d.id;

-- Vue des courses avec détails
CREATE OR REPLACE VIEW public.rides_full AS
SELECT 
    r.*,
    pd.first_name as patient_first_name,
    pd.last_name as patient_last_name,
    pu.phone_number as patient_phone,
    dd.first_name as driver_first_name,
    dd.last_name as driver_last_name,
    du.phone_number as driver_phone,
    v.make as vehicle_make,
    v.model as vehicle_model,
    v.plate_number
FROM public.rides r
LEFT JOIN public.patients pd ON r.patient_id = pd.id
LEFT JOIN public.users pu ON pd.user_id = pu.id
LEFT JOIN public.drivers dd ON r.driver_id = dd.id
LEFT JOIN public.users du ON dd.user_id = du.id
LEFT JOIN public.vehicles v ON v.driver_id = dd.id;

-- =========================================
-- COMMENTAIRES FINAUX
-- =========================================

-- Ce schéma fournit:
-- 1. Structure complète pour chauffeurs, patients, véhicules
-- 2. Système de documents avec validation
-- 3. Gestion des courses et paiements
-- 4. Géolocalisation avec PostGIS
-- 5. Sécurité avec RLS
-- 6. Performance avec index optimisés
-- 7. Audit avec timestamps automatiques

COMMENT ON SCHEMA public IS 'YALLA TBIB - Transport médical - Base de données complète';