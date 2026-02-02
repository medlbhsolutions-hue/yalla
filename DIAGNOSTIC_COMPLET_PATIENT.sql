-- 🔍 DIAGNOSTIC COMPLET : Pourquoi tous les nouveaux utilisateurs deviennent patients ?
-- Date : 14 octobre 2025
-- À exécuter dans Supabase SQL Editor

-- ==========================================
-- ÉTAPE 1 : Vérifier qu'il n'y a AUCUN trigger actif
-- ==========================================

SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    tgenabled AS status,
    proname AS function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'auth.users'::regclass;

-- ✅ Résultat attendu : Aucune ligne OU triggers désactivés
-- ⚠️ Si vous voyez un trigger actif → C'EST LE PROBLÈME

-- ==========================================
-- ÉTAPE 2 : Vérifier toutes les fonctions qui créent des patients
-- ==========================================

SELECT 
    proname AS function_name,
    prosrc AS function_code
FROM pg_proc
WHERE prosrc ILIKE '%INSERT INTO patients%'
   OR prosrc ILIKE '%INSERT INTO public.patients%';

-- ⚠️ Si vous voyez des fonctions suspectes → NOTEZ LEURS NOMS

-- ==========================================
-- ÉTAPE 3 : Vérifier le profil de 0669337841
-- ==========================================

SELECT 
    u.phone,
    u.email,
    u.id AS user_id,
    TO_CHAR(u.created_at, 'YYYY-MM-DD HH24:MI:SS') AS date_creation,
    p.id AS patient_id,
    TO_CHAR(p.created_at, 'YYYY-MM-DD HH24:MI:SS') AS patient_cree_le,
    d.id AS driver_id,
    TO_CHAR(d.created_at, 'YYYY-MM-DD HH24:MI:SS') AS driver_cree_le,
    CASE 
        WHEN p.id IS NULL AND d.id IS NOT NULL THEN '✅ Chauffeur uniquement (PARFAIT)'
        WHEN p.id IS NOT NULL AND d.id IS NULL THEN '👤 Patient uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN '⚠️ Double rôle (PROBLÈME)'
        ELSE '❌ Aucun profil'
    END AS status
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.phone = '+212669337841'
   OR u.email LIKE '%669337841%';

-- ⚠️ Si patient_id n'est PAS NULL → Le profil patient a été créé automatiquement
-- 📊 Comparez patient_cree_le et date_creation : si créés en même temps → TRIGGER actif

-- ==========================================
-- ÉTAPE 4 : Vérifier TOUS les nouveaux utilisateurs (7 derniers jours)
-- ==========================================

SELECT 
    u.phone,
    u.email,
    TO_CHAR(u.created_at, 'YYYY-MM-DD HH24:MI:SS') AS inscription,
    TO_CHAR(p.created_at, 'YYYY-MM-DD HH24:MI:SS') AS patient_cree,
    TO_CHAR(d.created_at, 'YYYY-MM-DD HH24:MI:SS') AS driver_cree,
    CASE 
        WHEN p.id IS NULL AND d.id IS NOT NULL THEN '✅ Chauffeur uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NULL THEN '👤 Patient uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN '⚠️ Double rôle'
        ELSE '❌ Aucun profil'
    END AS status,
    -- Calculer le délai entre création user et création patient (en secondes)
    EXTRACT(EPOCH FROM (p.created_at - u.created_at)) AS delai_patient_sec
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.created_at > NOW() - INTERVAL '7 days'
ORDER BY u.created_at DESC
LIMIT 30;

-- 📊 ANALYSE DU RÉSULTAT :
-- 1. Si delai_patient_sec < 5 secondes → Profil patient créé AUTOMATIQUEMENT (trigger ou fonction)
-- 2. Si delai_patient_sec > 10 secondes → Profil patient créé MANUELLEMENT (par l'app)
-- 3. Si status = "⚠️ Double rôle" → PROBLÈME

-- ==========================================
-- ÉTAPE 5 : Chercher les policies qui pourraient créer des patients
-- ==========================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd AS command,
    qual AS using_expression,
    with_check AS with_check_expression
FROM pg_policies
WHERE tablename = 'patients';

-- 📊 Vérifiez si une policy INSERT permet la création automatique

-- ==========================================
-- ÉTAPE 6 : Lister TOUS les triggers sur TOUTES les tables
-- ==========================================

SELECT 
    t.tgname AS trigger_name,
    c.relname AS table_name,
    p.proname AS function_name,
    CASE t.tgenabled::text
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE '⚠️ ' || t.tgenabled::text
    END AS status
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE c.relname IN ('users', 'patients', 'drivers')
   OR p.proname ILIKE '%patient%';

-- ⚠️ Cherchez des triggers actifs qui contiennent "patient" dans leur nom

-- ==========================================
-- RECOMMANDATIONS SELON LES RÉSULTATS
-- ==========================================

/*
🔍 DIAGNOSTIC :

1️⃣ Si ÉTAPE 1 montre un trigger actif :
   → Le trigger n'a PAS été supprimé correctement
   → Solution : Ré-exécuter EXECUTE_FIX_TRIGGER.sql

2️⃣ Si ÉTAPE 3 montre patient_id != NULL pour 0669337841 :
   → Un profil patient a été créé automatiquement
   → Vérifier delai_patient_sec dans ÉTAPE 4

3️⃣ Si delai_patient_sec < 5 secondes :
   → Création AUTOMATIQUE (trigger ou fonction)
   → Chercher le coupable dans ÉTAPE 2 et ÉTAPE 6

4️⃣ Si TOUS les utilisateurs ont status "👤 Patient uniquement" :
   → Le trigger est TOUJOURS actif
   → OU une fonction dans l'app crée automatiquement le patient

5️⃣ Si aucun trigger n'est trouvé mais les patients sont créés :
   → Vérifier le code Flutter (ensurePatientProfile, createPatientProfile)
   → Vérifier les policies Supabase (ÉTAPE 5)

📋 ACTIONS À PRENDRE :

- [ ] Exécuter toutes les étapes ci-dessus
- [ ] Noter les résultats anormaux
- [ ] Partager les résultats avec moi

🎯 OBJECTIF : Trouver QUI/QUOI crée automatiquement le profil patient !
*/
