-- =========================================
-- SOLUTION COMPLETE - AUTO-CONFIRMATION EMAIL
-- Exécutez ce script ENTIER dans Supabase SQL Editor
-- =========================================

-- ÉTAPE 1: Confirmer TOUS les utilisateurs existants
UPDATE auth.users 
SET email_confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

-- ÉTAPE 2: Créer la fonction d'auto-confirmation
CREATE OR REPLACE FUNCTION public.auto_confirm_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-confirmer l'email dès la création
  NEW.email_confirmed_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ÉTAPE 3: Créer le trigger pour les nouveaux utilisateurs
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_user();

-- ÉTAPE 4: Vérification
SELECT 
    COUNT(*) as total_users,
    COUNT(email_confirmed_at) as users_confirmed,
    COUNT(*) - COUNT(email_confirmed_at) as users_not_confirmed
FROM auth.users;

-- ÉTAPE 5: Afficher les derniers utilisateurs
SELECT 
    email,
    CASE 
        WHEN email_confirmed_at IS NOT NULL THEN '✅ Confirmé'
        ELSE '❌ Non confirmé'
    END as statut,
    created_at
FROM auth.users 
ORDER BY created_at DESC
LIMIT 10;

-- Message final
SELECT '🎉 TERMINÉ ! Tous les utilisateurs sont confirmés et les nouveaux le seront automatiquement.' as message;
