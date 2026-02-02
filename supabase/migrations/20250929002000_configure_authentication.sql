-- Enable l'authentification basique par email/mot de passe
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

-- Configuration de base pour l'authentification
UPDATE auth.config 
SET config_data = jsonb_set(
  config_data::jsonb, 
  '{auth.email}', 
  '{
    "enable": true,
    "enable_confirm": false,
    "min_password_length": 6,
    "double_confirm_changes": false,
    "enable_signup": true
  }'::jsonb
);

-- Politique permettant la création de nouveaux utilisateurs
DROP POLICY IF EXISTS "Allow signups" ON auth.users;
CREATE POLICY "Allow signups" ON auth.users
  FOR INSERT WITH CHECK (true);

-- Politique permettant aux utilisateurs de voir leur propre profil
DROP POLICY IF EXISTS "Users can view their own profile" ON auth.users;
CREATE POLICY "Users can view their own profile" ON auth.users
  FOR SELECT USING (auth.uid() = id);

-- Fonction de déclenchement pour gérer les nouveaux utilisateurs
CREATE OR REPLACE FUNCTION public.handle_new_patient()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.patients (user_id, name, created_at)
  VALUES (NEW.id, NEW.email, NOW())
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger pour créer un profil patient lors de l'inscription
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_patient();

-- S'assurer que la table patients existe
CREATE TABLE IF NOT EXISTS public.patients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Politiques pour la table patients
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Patients can view own data" ON public.patients;
CREATE POLICY "Patients can view own data" ON public.patients
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Patients can update own data" ON public.patients;
CREATE POLICY "Patients can update own data" ON public.patients
  FOR UPDATE USING (auth.uid() = user_id);

-- Configuration des types de rôles
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email LIKE '%@admin.%') THEN
    INSERT INTO auth.users (email, encrypted_password, raw_app_meta_data)
    VALUES 
    ('admin@admin.yallatabib.com', 
     crypt('adminpassword', gen_salt('bf')), 
     '{"role":"admin"}'::jsonb);
  END IF;
END $$;