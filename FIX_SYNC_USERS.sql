-- 🔧 RECRÉER LE TRIGGER CORRECTEMENT
-- Date : 14 octobre 2025
-- Synchroniser auth.users → public.users SANS créer de profil patient automatique

-- ==========================================
-- ÉTAPE 0 : Vérifier la structure de public.users
-- ==========================================

-- Voir les colonnes de la table public.users
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'users'
ORDER BY ordinal_position;

-- 📋 Notez les colonnes disponibles avant de continuer

-- ==========================================
-- ÉTAPE 1 : Créer la fonction corrigée
-- ==========================================

CREATE OR REPLACE FUNCTION public.handle_new_user_sync()
RETURNS TRIGGER AS $$
BEGIN
  -- Insérer l'utilisateur dans public.users (synchronisation)
  INSERT INTO public.users (
    id, 
    email, 
    phone_number, 
    created_at, 
    updated_at,
    email_verified,
    phone_verified,
    is_active
  )
  VALUES (
    NEW.id,
    NEW.email,
    NEW.phone,
    NEW.created_at,
    NEW.updated_at,
    COALESCE(NEW.email_confirmed_at IS NOT NULL, false),
    COALESCE(NEW.phone_confirmed_at IS NOT NULL, false),
    true
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone_number = EXCLUDED.phone_number,
    updated_at = EXCLUDED.updated_at,
    email_verified = EXCLUDED.email_verified,
    phone_verified = EXCLUDED.phone_verified,
    last_login = NOW();
  
  -- ✅ PAS de création automatique de profil patient !
  -- Flutter décide quel profil créer (patient OU driver)
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- ÉTAPE 2 : Créer le trigger
-- ==========================================

DROP TRIGGER IF EXISTS on_auth_user_created_sync ON auth.users;

CREATE TRIGGER on_auth_user_created_sync
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user_sync();

-- ✅ Résultat attendu : "CREATE TRIGGER"

-- ==========================================
-- ÉTAPE 3 : Vérification
-- ==========================================

SELECT 
    tgname AS trigger_name,
    proname AS function_name,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'auth.users'::regclass
  AND tgname = 'on_auth_user_created_sync';

-- ✅ Doit afficher le trigger avec la fonction handle_new_user_sync

-- ==========================================
-- ÉTAPE 4 : Synchroniser les utilisateurs existants
-- ==========================================

-- Copier tous les utilisateurs de auth.users vers public.users
INSERT INTO public.users (
  id, 
  email, 
  phone_number, 
  created_at, 
  updated_at,
  email_verified,
  phone_verified,
  is_active
)
SELECT 
    id, 
    email, 
    phone,
    created_at, 
    updated_at,
    COALESCE(email_confirmed_at IS NOT NULL, false),
    COALESCE(phone_confirmed_at IS NOT NULL, false),
    true
FROM auth.users
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone_number = EXCLUDED.phone_number,
    updated_at = EXCLUDED.updated_at,
    email_verified = EXCLUDED.email_verified,
    phone_verified = EXCLUDED.phone_verified;

-- ✅ Résultat : "INSERT X" où X = nombre d'utilisateurs synchronisés

-- ==========================================
-- ÉTAPE 5 : Vérification finale
-- ==========================================

-- Comparer auth.users et public.users
SELECT 
    'auth.users' AS source,
    COUNT(*) AS total
FROM auth.users
UNION ALL
SELECT 
    'public.users' AS source,
    COUNT(*) AS total
FROM public.users;

-- ✅ Les deux nombres doivent être identiques

-- ==========================================
-- ÉTAPE 6 : Test de création d'utilisateur
-- ==========================================

-- Vérifier l'utilisateur 0669337846 qui a échoué
SELECT 
    au.id,
    au.email AS auth_email,
    pu.email AS public_email,
    CASE 
        WHEN pu.id IS NULL THEN '❌ Pas dans public.users'
        ELSE '✅ Synchronisé'
    END AS status
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE au.email = 'u669337846@t.co';

-- ✅ Doit afficher "✅ Synchronisé" après l'ÉTAPE 4

/*
🎯 EXPLICATION :

Le problème était que nous avons supprimé le trigger qui synchronise auth.users → public.users.

Les tables drivers et patients ont des foreign keys vers public.users (pas auth.users).

Donc quand un utilisateur se connecte :
1. ✅ Il est créé dans auth.users (par Supabase Auth)
2. ❌ Mais PAS dans public.users (trigger supprimé)
3. ❌ Donc impossible de créer driver ou patient (foreign key échoue)

SOLUTION :
1. Recréer le trigger de synchronisation
2. MAIS sans la création automatique de profil patient
3. Laisser Flutter décider quel profil créer

✅ APRÈS CE SCRIPT :
- Les nouveaux utilisateurs seront automatiquement synchronisés dans public.users
- PAS de profil patient créé automatiquement
- Flutter contrôle la création des profils (patient OU driver)
*/
