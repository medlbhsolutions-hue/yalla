-- Mise à jour des politiques d'authentification pour les tests
-- Date: 2025-09-29

-- Créer la table patients si elle n'existe pas déjà
CREATE TABLE IF NOT EXISTS public.patients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Créer un index pour améliorer les performances
CREATE INDEX IF NOT EXISTS patients_user_id_idx ON public.patients(user_id);

-- Désactiver temporairement RLS pour les tests
ALTER TABLE public.patients DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers DISABLE ROW LEVEL SECURITY;

-- Politique permissive pour les tests
DROP POLICY IF EXISTS "Allow all operations for testing" ON public.patients;
DROP POLICY IF EXISTS "Allow all operations for testing" ON public.drivers;

CREATE POLICY "Allow all operations for testing" ON public.patients 
FOR ALL USING (true) 
WITH CHECK (true);

CREATE POLICY "Allow all operations for testing" ON public.drivers 
FOR ALL USING (true) 
WITH CHECK (true);

-- Activer RLS mais avec des politiques permissives pour les tests
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

-- Permettre l'inscription sans email vérifié pour les tests
UPDATE auth.config 
SET config_data = jsonb_set(
  config_data::jsonb, 
  '{auth.email.enable_confirm}', 
  'false'::jsonb
);