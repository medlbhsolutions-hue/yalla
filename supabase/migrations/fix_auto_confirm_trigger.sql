-- =========================================
-- FIX TRIGGER AUTO-CONFIRMATION
-- Le trigger BEFORE INSERT ne peut pas modifier email_confirmed_at
-- Il faut utiliser un trigger AFTER INSERT avec UPDATE
-- =========================================

-- Supprimer l'ancien trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.auto_confirm_user();

-- Créer une nouvelle fonction qui UPDATE après insertion
CREATE OR REPLACE FUNCTION public.auto_confirm_user_after()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-confirmer l'email APRÈS la création
  UPDATE auth.users
  SET email_confirmed_at = NOW()
  WHERE id = NEW.id
  AND email_confirmed_at IS NULL;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Créer le trigger AFTER INSERT
CREATE TRIGGER on_auth_user_created_after
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_user_after();

-- Confirmer tous les utilisateurs existants non confirmés
UPDATE auth.users 
SET email_confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

-- Vérification
SELECT 
    COUNT(*) as total_users,
    COUNT(email_confirmed_at) as users_confirmed,
    COUNT(*) FILTER (WHERE email_confirmed_at IS NULL) as users_not_confirmed
FROM auth.users;

-- Message final
SELECT '✅ Trigger AFTER INSERT créé. Tous les nouveaux utilisateurs seront auto-confirmés.' as message;
