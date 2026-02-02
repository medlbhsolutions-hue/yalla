-- =========================================
-- AUTO-CONFIRMER TOUS LES UTILISATEURS
-- Pour désactiver la confirmation d'email pendant le développement
-- =========================================

-- Confirmer automatiquement tous les utilisateurs non confirmés
UPDATE auth.users 
SET email_confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

-- Vérifier les utilisateurs confirmés
SELECT 
    email, 
    email_confirmed_at,
    created_at,
    CASE 
        WHEN email_confirmed_at IS NOT NULL THEN '✅ Confirmé'
        ELSE '❌ Non confirmé'
    END as statut
FROM auth.users 
ORDER BY created_at DESC
LIMIT 10;

-- Message de confirmation
SELECT 
    COUNT(*) as total_users,
    COUNT(email_confirmed_at) as users_confirmed,
    COUNT(*) - COUNT(email_confirmed_at) as users_not_confirmed
FROM auth.users;
