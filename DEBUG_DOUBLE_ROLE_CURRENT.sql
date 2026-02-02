-- 🔍 DEBUG : Vérifier l'état actuel des profils pour 0669337821
-- Date : 14 octobre 2025

-- Vérification complète de l'utilisateur
SELECT 
    u.id AS user_id,
    u.phone,
    u.email,
    u.created_at AS user_created_at,
    -- Profil Patient
    p.id AS patient_id,
    p.first_name AS patient_first_name,
    p.last_name AS patient_last_name,
    p.created_at AS patient_created_at,
    -- Profil Chauffeur
    d.id AS driver_id,
    d.first_name AS driver_first_name,
    d.last_name AS driver_last_name,
    d.created_at AS driver_created_at,
    -- Statut
    CASE 
        WHEN p.id IS NULL AND d.id IS NOT NULL THEN '✅ Chauffeur uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NULL THEN '👤 Patient uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN '⚠️ DOUBLE RÔLE (PROBLÈME)'
        ELSE '❌ Aucun profil'
    END AS status
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.phone = '+212669337821'
ORDER BY u.created_at DESC;

-- Si le résultat montre DOUBLE RÔLE, exécuter cette requête pour voir quand le profil patient a été créé :
SELECT 
    id,
    user_id,
    first_name,
    last_name,
    created_at,
    EXTRACT(EPOCH FROM (NOW() - created_at)) / 60 AS minutes_ago
FROM patients
WHERE user_id = (SELECT id FROM auth.users WHERE phone = '+212669337821')
ORDER BY created_at DESC;
