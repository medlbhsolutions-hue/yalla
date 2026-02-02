-- 🔍 DEBUG COMPLET : Vérifier tous les profils créés récemment
-- Date : 14 octobre 2025

-- Voir TOUS les chauffeurs créés aujourd'hui avec leurs profils patients
SELECT 
    u.phone,
    u.email,
    u.created_at AS user_created,
    -- Profil Patient
    p.id AS patient_id,
    p.created_at AS patient_created,
    EXTRACT(EPOCH FROM (p.created_at - u.created_at)) / 60 AS patient_minutes_after_user,
    -- Profil Chauffeur  
    d.id AS driver_id,
    d.created_at AS driver_created,
    EXTRACT(EPOCH FROM (d.created_at - u.created_at)) / 60 AS driver_minutes_after_user,
    -- Comparaison
    CASE 
        WHEN p.id IS NULL AND d.id IS NOT NULL THEN '✅ Chauffeur uniquement (BON)'
        WHEN p.id IS NOT NULL AND d.id IS NULL THEN '👤 Patient uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN '⚠️ DOUBLE RÔLE (PROBLÈME)'
        ELSE '❌ Aucun profil'
    END AS status,
    CASE
        WHEN p.created_at > d.created_at THEN '⚠️ Patient créé APRÈS driver'
        WHEN d.created_at > p.created_at THEN '⚠️ Driver créé APRÈS patient'
        ELSE 'OK'
    END AS order_check
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.created_at > NOW() - INTERVAL '1 day'  -- Dernières 24h
ORDER BY u.created_at DESC
LIMIT 10;

-- Vérifier spécifiquement 0669337823
SELECT 
    u.phone,
    u.id AS user_id,
    u.created_at AS user_created,
    -- Patient
    p.id AS patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    p.created_at AS patient_created,
    TO_CHAR(p.created_at, 'YYYY-MM-DD HH24:MI:SS') AS patient_created_formatted,
    -- Driver
    d.id AS driver_id,
    d.first_name || ' ' || d.last_name AS driver_name,
    d.created_at AS driver_created,
    TO_CHAR(d.created_at, 'YYYY-MM-DD HH24:MI:SS') AS driver_created_formatted,
    -- Délai entre les créations
    CASE 
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN
            EXTRACT(EPOCH FROM (p.created_at - d.created_at))::INT || ' secondes'
        ELSE 'N/A'
    END AS time_diff_patient_after_driver
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.phone IN ('+212669337823', '+212669337822', '+212669337821')
ORDER BY u.created_at DESC;
