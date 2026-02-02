-- ============================================
-- SOLUTION SIMPLE: CRÉER ADMIN VIA SUPABASE UI
-- ============================================
-- 
-- ÉTAPES À SUIVRE:
-- 
-- 1. Aller sur: https://supabase.com/dashboard/project/aijchsvkuocbtzamyojy/auth/users
-- 
-- 2. Cliquer sur "Add user" ou "Invite user"
-- 
-- 3. Remplir le formulaire:
--    - Email: admin@yallatbib.com
--    - Password: Admin2025!
--    - Auto Confirm Email: YES (cocher la case)
-- 
-- 4. Cliquer sur "Create user" ou "Send invitation"
-- 
-- 5. Une fois créé, exécuter ce script SQL ci-dessous:

-- Trouver l'UUID du compte admin créé
SELECT id, email FROM auth.users WHERE email = 'admin@yallatbib.com';

-- Vérifier si un profil existe déjà dans public.users
SELECT id, email FROM public.users WHERE email = 'admin@yallatbib.com';

-- Si aucun profil n'existe, créer le profil (remplacer YOUR_UUID_HERE par l'UUID trouvé ci-dessus)
-- INSERT INTO public.users (id, email, phone_number, is_active, email_verified, created_at)
-- VALUES ('YOUR_UUID_HERE', 'admin@yallatbib.com', '+212600000000', true, true, NOW());

-- ============================================
-- OU SOLUTION ALTERNATIVE: MISE À JOUR EMAIL
-- ============================================

-- Si un compte existe déjà avec cet email dans public.users mais pas dans auth.users:
-- 1. Trouver l'ID dans public.users:
SELECT id, email FROM public.users WHERE email = 'admin@yallatbib.com';

-- 2. Créer le compte auth.users avec le même ID (remplacer YOUR_UUID_HERE):
-- Note: Il est plus sûr de le faire via l'interface Supabase UI

-- ============================================
-- VÉRIFICATION FINALE
-- ============================================

-- Vérifier que tout est en place:
SELECT 
  'auth.users' as table_name,
  id,
  email,
  email_confirmed_at IS NOT NULL as email_confirmed
FROM auth.users 
WHERE email = 'admin@yallatbib.com'

UNION ALL

SELECT 
  'public.users' as table_name,
  id,
  email,
  email_verified
FROM public.users 
WHERE email = 'admin@yallatbib.com';
