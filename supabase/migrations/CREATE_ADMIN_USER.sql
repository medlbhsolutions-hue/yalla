-- ============================================
-- CRÉER COMPTE ADMIN POUR YALLA TBIB
-- ============================================
-- Date: 14 Novembre 2025
-- Email: admin@yallatbib.com
-- Mot de passe: Admin2025!

-- IMPORTANT: Ce script crée un utilisateur admin complet
-- avec authentification Supabase et profil dans la table users

-- ============================================
-- ÉTAPE 1: Créer l'utilisateur dans auth.users
-- ============================================

DO $$
DECLARE
  admin_user_id UUID;
  existing_auth_user_id UUID;
  existing_public_user_id UUID;
BEGIN
  -- Vérifier si l'email existe dans public.users
  SELECT id INTO existing_public_user_id
  FROM public.users
  WHERE email = 'admin@yallatbib.com'
  LIMIT 1;

  -- Vérifier si l'email existe dans auth.users
  SELECT id INTO existing_auth_user_id
  FROM auth.users
  WHERE email = 'admin@yallatbib.com'
  LIMIT 1;

  -- Déterminer l'ID à utiliser
  IF existing_public_user_id IS NOT NULL THEN
    -- Utiliser l'ID existant de public.users
    admin_user_id := existing_public_user_id;
    RAISE NOTICE 'Utilisation ID existant: %', admin_user_id;
  ELSIF existing_auth_user_id IS NOT NULL THEN
    -- Utiliser l'ID existant de auth.users
    admin_user_id := existing_auth_user_id;
    RAISE NOTICE 'Utilisation ID auth: %', admin_user_id;
  ELSE
    -- Générer un nouveau UUID
    admin_user_id := gen_random_uuid();
    RAISE NOTICE 'Nouveau UUID généré: %', admin_user_id;
  END IF;

  -- Créer ou mettre à jour dans auth.users
  IF existing_auth_user_id IS NULL THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      aud,
      role
    )
    VALUES (
      admin_user_id,
      '00000000-0000-0000-0000-000000000000',
      'admin@yallatbib.com',
      crypt('Admin2025!', gen_salt('bf')),
      NOW(),
      NOW(),
      NOW(),
      'authenticated',
      'authenticated'
    );
    RAISE NOTICE '✅ Compte auth.users créé';
  ELSE
    -- Mettre à jour le mot de passe si nécessaire
    UPDATE auth.users
    SET encrypted_password = crypt('Admin2025!', gen_salt('bf')),
        email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = existing_auth_user_id;
    RAISE NOTICE '✅ Compte auth.users mis à jour';
  END IF;

  -- Créer ou mettre à jour dans public.users
  IF existing_public_user_id IS NULL THEN
    INSERT INTO public.users (
      id,
      email,
      phone_number,
      is_active,
      email_verified,
      created_at
    )
    VALUES (
      admin_user_id,
      'admin@yallatbib.com',
      '+212600000000',
      true,
      true,
      NOW()
    );
    RAISE NOTICE '✅ Compte public.users créé';
  ELSE
    UPDATE public.users 
    SET is_active = true,
        email_verified = true,
        phone_number = COALESCE(phone_number, '+212600000000'),
        updated_at = NOW()
    WHERE id = existing_public_user_id;
    RAISE NOTICE '✅ Compte public.users mis à jour';
  END IF;

  RAISE NOTICE '====================================';
  RAISE NOTICE '✅ Configuration admin terminée!';
  RAISE NOTICE 'Email: admin@yallatbib.com';
  RAISE NOTICE 'Mot de passe: Admin2025!';
  RAISE NOTICE 'UUID: %', admin_user_id;
  RAISE NOTICE '====================================';
END $$;

-- ============================================
-- VÉRIFICATION
-- ============================================

-- Vérifier que l'admin existe
SELECT 
  u.id,
  u.email,
  u.phone_number,
  u.is_active,
  u.email_verified,
  u.created_at
FROM public.users u
WHERE u.email = 'admin@yallatbib.com';

-- ============================================
-- NOTES
-- ============================================
-- Email: admin@yallatbib.com
-- Mot de passe: Admin2025!
-- 
-- Pour changer le mot de passe plus tard:
-- UPDATE auth.users 
-- SET encrypted_password = crypt('NouveauMotDePasse', gen_salt('bf'))
-- WHERE email = 'admin@yallatbib.com';
