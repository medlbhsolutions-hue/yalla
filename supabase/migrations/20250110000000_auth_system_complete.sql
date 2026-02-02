-- =====================================================
-- MIGRATION: Système d'authentification complet
-- Date: 10 Janvier 2025
-- Description: Tables pour authentification dynamique
-- =====================================================

-- Table des utilisateurs (étendue)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  photo_url TEXT,
  role TEXT CHECK (role IN ('patient', 'driver', 'admin')),
  email_verified BOOLEAN DEFAULT FALSE,
  phone_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table des codes de vérification
CREATE TABLE IF NOT EXISTS verification_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  type TEXT CHECK (type IN ('email', 'sms')) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_verification_codes_user_id ON verification_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_codes_code ON verification_codes(code);

-- Fonction pour nettoyer les codes expirés
CREATE OR REPLACE FUNCTION clean_expired_codes()
RETURNS void AS $$
BEGIN
  DELETE FROM verification_codes
  WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS (Row Level Security) Policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_codes ENABLE ROW LEVEL SECURITY;

-- Policy: Les utilisateurs peuvent voir leur propre profil
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

-- Policy: Les utilisateurs peuvent mettre à jour leur propre profil
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Policy: Les admins peuvent tout voir
CREATE POLICY "Admins can view all users"
  ON users FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Policy: Les utilisateurs peuvent voir leurs codes de vérification
CREATE POLICY "Users can view own verification codes"
  ON verification_codes FOR SELECT
  USING (user_id = auth.uid());

-- Policy: Les utilisateurs peuvent insérer leurs codes
CREATE POLICY "Users can insert own verification codes"
  ON verification_codes FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Fonction pour créer un utilisateur automatiquement après inscription
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO users (id, email, first_name, last_name, phone)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'first_name',
    NEW.raw_user_meta_data->>'last_name',
    NEW.raw_user_meta_data->>'phone'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger pour créer l'utilisateur automatiquement
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Insérer un admin par défaut (à modifier avec vos vraies données)
INSERT INTO users (id, email, first_name, last_name, role, email_verified)
VALUES (
  gen_random_uuid(),
  'admin@yallatbib.com',
  'Admin',
  'Yalla Tbib',
  'admin',
  TRUE
) ON CONFLICT (email) DO NOTHING;

-- Commentaires pour documentation
COMMENT ON TABLE users IS 'Table principale des utilisateurs avec rôles';
COMMENT ON TABLE verification_codes IS 'Codes de vérification pour email et SMS';
COMMENT ON COLUMN users.role IS 'Rôle: patient, driver ou admin';
COMMENT ON COLUMN verification_codes.type IS 'Type de code: email ou sms';
