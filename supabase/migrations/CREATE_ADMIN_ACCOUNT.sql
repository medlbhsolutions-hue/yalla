-- Créer un compte admin pour tester
-- Date: 2025-11-24

-- Étape 1: Créer l'utilisateur dans auth.users (via Dashboard Supabase)
-- Va dans Authentication → Users → Add user
-- Email: admin@yallatbib.ma
-- Password: Admin123!
-- Ou utilise le SQL ci-dessous si tu as les permissions

-- Étape 2: Une fois le user créé, mettre à jour son rôle dans la table users
-- Remplace 'VOTRE_USER_ID' par l'ID réel du user créé

-- Option A: Si tu connais l'email
UPDATE users 
SET role = 'admin' 
WHERE email = 'admin@yallatbib.ma';

-- Option B: Si tu connais l'ID
-- UPDATE users 
-- SET role = 'admin' 
-- WHERE id = 'VOTRE_USER_ID';

-- Vérification
SELECT id, email, role, created_at 
FROM users 
WHERE role = 'admin';
