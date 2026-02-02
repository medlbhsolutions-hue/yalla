-- =========================================
-- YALLA TBIB - CRÉATION TABLE RIDES UNIQUEMENT
-- Date: 12/10/2025
-- Ce script crée UNIQUEMENT la table rides
-- =========================================

-- Création des types ENUM nécessaires
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

-- =========================================
-- TABLE DES RIDES/COURSES
-- =========================================
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
-- INDEX POUR PERFORMANCE
-- =========================================

-- Index géospatiaux pour localisation
CREATE INDEX IF NOT EXISTS idx_rides_pickup_location ON public.rides USING GIST (pickup_location);
CREATE INDEX IF NOT EXISTS idx_rides_destination_location ON public.rides USING GIST (destination_location);

-- Index sur les statuts
CREATE INDEX IF NOT EXISTS idx_rides_status ON public.rides (status);

-- Index sur les relations
CREATE INDEX IF NOT EXISTS idx_rides_patient_id ON public.rides (patient_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON public.rides (driver_id);

-- Index temporels
CREATE INDEX IF NOT EXISTS idx_rides_created_at ON public.rides (created_at);
CREATE INDEX IF NOT EXISTS idx_rides_scheduled_time ON public.rides (scheduled_time);

-- =========================================
-- TRIGGER POUR UPDATED_AT
-- =========================================

-- Création de la fonction pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger pour updated_at
DROP TRIGGER IF EXISTS update_rides_updated_at ON public.rides;
CREATE TRIGGER update_rides_updated_at 
    BEFORE UPDATE ON public.rides 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- POLITIQUES RLS (Row Level Security)
-- =========================================

-- Activer RLS
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;

-- Politique: Les utilisateurs peuvent voir leurs propres courses
DROP POLICY IF EXISTS "Users can view own rides" ON public.rides;
CREATE POLICY "Users can view own rides" ON public.rides
    FOR SELECT USING (
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()) OR
        driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
    );

-- Politique: Les patients peuvent créer des courses
DROP POLICY IF EXISTS "Patients can create rides" ON public.rides;
CREATE POLICY "Patients can create rides" ON public.rides
    FOR INSERT WITH CHECK (
        patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid())
    );

-- Politique: Les chauffeurs peuvent mettre à jour le statut des courses qui leur sont assignées
DROP POLICY IF EXISTS "Drivers can update assigned rides" ON public.rides;
CREATE POLICY "Drivers can update assigned rides" ON public.rides
    FOR UPDATE USING (
        driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
    );

-- =========================================
-- VÉRIFICATION FINALE
-- =========================================

-- Afficher les tables existantes
SELECT 'Tables créées avec succès!' as message;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'rides';
