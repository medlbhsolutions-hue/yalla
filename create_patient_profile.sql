-- ✅ PROFIL PATIENT CRÉÉ AVEC SUCCÈS !
-- UUID: 383bed51-60f1-4566-928f-468a7ad22eec

-- Vérification que le profil existe bien
SELECT 
    p.id as patient_id,
    p.user_id,
    p.first_name,
    p.last_name,
    u.email,
    u.phone_number,
    p.created_at
FROM public.patients p
JOIN public.users u ON p.user_id = u.id
WHERE p.user_id = '383bed51-60f1-4566-928f-468a7ad22eec';
