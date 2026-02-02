-- Migration: Ajouter colonnes bancaires pour profil chauffeur complet
-- Date: 2025-11-24
-- Description: Ajoute les champs de compte bancaire pour recevoir les paiements

-- Ajouter les colonnes bancaires à la table drivers
ALTER TABLE drivers 
  ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100),
  ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(50),
  ADD COLUMN IF NOT EXISTS bank_iban VARCHAR(50),
  ADD COLUMN IF NOT EXISTS bank_swift VARCHAR(20);

-- Ajouter des commentaires pour documentation
COMMENT ON COLUMN drivers.bank_name IS 'Nom de la banque du chauffeur';
COMMENT ON COLUMN drivers.bank_account_number IS 'Numéro de compte bancaire';
COMMENT ON COLUMN drivers.bank_iban IS 'IBAN international (optionnel)';
COMMENT ON COLUMN drivers.bank_swift IS 'Code SWIFT/BIC (optionnel)';

-- Vérification
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'drivers' 
  AND column_name IN ('bank_name', 'bank_account_number', 'bank_iban', 'bank_swift')
ORDER BY column_name;
