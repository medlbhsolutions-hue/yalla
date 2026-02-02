-- =========================================
-- VÉRIFICATION DU CHAUFFEUR 0669337852
-- =========================================

-- 1. Trouver l'utilisateur
SELECT 
    id as user_id,
    email,
    phone_number,
    created_at
FROM auth.users
WHERE phone_number LIKE '%669337852%' OR email LIKE '%669337852%';

-- 2. Trouver le profil chauffeur
SELECT 
    d.id as driver_id,
    d.user_id,
    d.first_name,
    d.last_name,
    d.status,
    d.is_available,
    d.is_verified,
    u.email,
    u.phone_number
FROM public.drivers d
JOIN public.users u ON d.user_id = u.id
WHERE u.phone_number LIKE '%669337852%' OR u.email LIKE '%669337852%';

-- 3. Vérifier les documents du chauffeur
SELECT 
    dd.id,
    dd.driver_id,
    dd.document_type,
    dd.status,
    dd.file_url,
    dd.uploaded_at,
    dd.validated_at,
    dd.admin_notes,
    d.first_name,
    d.last_name
FROM public.driver_documents dd
JOIN public.drivers d ON dd.driver_id = d.id
JOIN public.users u ON d.user_id = u.id
WHERE u.phone_number LIKE '%669337852%' OR u.email LIKE '%669337852%'
ORDER BY dd.document_type;

-- 4. Résumé complet
SELECT 
    'User ID: ' || u.id as info
FROM public.users u
WHERE u.phone_number LIKE '%669337852%' OR u.email LIKE '%669337852%'
UNION ALL
SELECT 
    'Driver ID: ' || d.id
FROM public.drivers d
JOIN public.users u ON d.user_id = u.id
WHERE u.phone_number LIKE '%669337852%' OR u.email LIKE '%669337852%'
UNION ALL
SELECT 
    'Email: ' || u.email
FROM public.users u
WHERE u.phone_number LIKE '%669337852%' OR u.email LIKE '%669337852%'
UNION ALL
SELECT 
    'Documents: ' || COUNT(*)::text
FROM public.driver_documents dd
JOIN public.drivers d ON dd.driver_id = d.id
JOIN public.users u ON d.user_id = u.id
WHERE u.phone_number LIKE '%669337852%' OR u.email LIKE '%669337852%';
