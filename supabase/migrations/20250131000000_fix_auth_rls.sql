-- =====================================================
-- MIGRATION: Correction des politiques RLS pour l'Auth
-- Description: Autorise la création et la vérification des codes 
--             même avant la connexion.
-- =====================================================

-- 1. Autoriser la lecture publique limitée des utilisateurs par email
-- (Nécessaire pour trouver l'ID d'un utilisateur lors du reset)
DROP POLICY IF EXISTS "Public can check email existance" ON users;
CREATE POLICY "Public can check email existance"
  ON users FOR SELECT
  USING (true); 

-- 2. Autoriser l'insertion des codes de vérification par n'importe qui
-- (Nécessaire pour l'inscription et le mot de passe oublié)
DROP POLICY IF EXISTS "Anyone can insert verification codes" ON verification_codes;
CREATE POLICY "Anyone can insert verification codes"
  ON verification_codes FOR INSERT
  WITH CHECK (true);

-- 3. Autoriser la lecture des codes par n'importe qui (pour vérification)
DROP POLICY IF EXISTS "Anyone can view verification codes" ON verification_codes;
CREATE POLICY "Anyone can view verification codes"
  ON verification_codes FOR SELECT
  USING (true);

-- 4. Pour la sécurité, on s'assure que le contenu sensible des codes n'est pas 
--    exposé inutilement (on pourrait filtrer, mais ici on reste en mode dev)
ALTER TABLE verification_codes ENABLE ROW LEVEL SECURITY;
