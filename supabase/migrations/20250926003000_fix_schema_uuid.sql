-- Enable required extensions
DROP EXTENSION IF EXISTS "uuid-ossp";
CREATE EXTENSION "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;

-- Drop existing policies
DROP POLICY IF EXISTS "Deny all by default" ON public.drivers;
DROP POLICY IF EXISTS "Drivers can view own profile" ON public.drivers;
DROP POLICY IF EXISTS "Drivers can update own profile" ON public.drivers;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.drivers;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.drivers;

-- Drop and recreate tables to ensure consistent schema
DROP TABLE IF EXISTS public.drivers CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;

-- Create type enums if they don't exist
DO $$ BEGIN
    CREATE TYPE driver_status AS ENUM ('pending', 'active', 'inactive', 'suspended', 'rejected');
    CREATE TYPE driver_specialization AS ENUM ('ambulance', 'handicap', 'medical', 'emergency', 'patientTransfer', 'dialysis', 'chemotherapy');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create vehicles table
CREATE TABLE public.vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    plate_number TEXT NOT NULL UNIQUE,
    color TEXT,
    year INTEGER,
    documents JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Create drivers table
CREATE TABLE public.drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE,
    first_name TEXT,
    last_name TEXT,
    phone_number TEXT UNIQUE,
    avatar TEXT,
    is_available BOOLEAN DEFAULT false,
    current_location GEOGRAPHY(POINT),
    stripe_connected_account_id TEXT UNIQUE,
    specializations driver_specialization[] DEFAULT '{}',
    is_verified BOOLEAN DEFAULT false,
    vehicle_id UUID REFERENCES vehicles(id),
    documents JSONB DEFAULT '{}',
    status driver_status DEFAULT 'pending',
    rating DECIMAL(3,2) DEFAULT 0.0,
    completed_trips INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT rating_range CHECK (rating >= 0.0 AND rating <= 5.0)
);

-- Create indexes
CREATE INDEX idx_drivers_email ON public.drivers (email);
CREATE INDEX idx_drivers_phone ON public.drivers (phone_number);
CREATE INDEX idx_drivers_location ON public.drivers USING GIST (current_location);
CREATE INDEX idx_drivers_status ON public.drivers (status);

-- Enable RLS
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Deny all by default" ON public.drivers 
    FOR ALL USING (false);

CREATE POLICY "Drivers can view own profile" ON public.drivers
    FOR SELECT USING (auth.uid()::text = id::text);

CREATE POLICY "Drivers can update own profile" ON public.drivers
    FOR UPDATE USING (auth.uid()::text = id::text)
    WITH CHECK (auth.uid()::text = id::text);

CREATE POLICY "Admins can view all profiles" ON public.drivers
    FOR SELECT USING (auth.jwt() ? 'is_admin');

CREATE POLICY "Admins can update all profiles" ON public.drivers
    FOR UPDATE USING (auth.jwt() ? 'is_admin');

-- Create trigger function for updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
DROP TRIGGER IF EXISTS update_drivers_updated_at ON public.drivers;
CREATE TRIGGER update_drivers_updated_at
    BEFORE UPDATE ON public.drivers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_vehicles_updated_at ON public.vehicles;
CREATE TRIGGER update_vehicles_updated_at
    BEFORE UPDATE ON public.vehicles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();