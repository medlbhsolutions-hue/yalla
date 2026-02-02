-- 🔥 SOLUTION FINALE : Supprimer le trigger qui crée automatiquement un profil patient
-- Date : 14 octobre 2025
-- Problème : Le trigger "on_auth_user_created" crée un profil patient pour TOUS les nouveaux utilisateurs
-- Effet : Les chauffeurs obtiennent automatiquement un profil patient → double rôle

-- ==========================================
-- ÉTAPE 1 : Supprimer le trigger problématique
-- ==========================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DROP FUNCTION IF EXISTS public.handle_new_patient();

-- ==========================================
-- ÉTAPE 2 : Vérification
-- ==========================================

-- Vérifier qu'il n'y a plus de trigger sur auth.users
SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    proname AS function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'auth.users'::regclass
AND tgname NOT LIKE 'pg_%';

-- Résultat attendu : Aucune ligne (ou seulement des triggers système)

-- ==========================================
-- ÉTAPE 3 : Nettoyer les profils patients créés automatiquement
-- ==========================================

-- Supprimer les profils patients des chauffeurs uniquement (double rôle)
DELETE FROM patients 
WHERE user_id IN (
  SELECT p.user_id 
  FROM patients p
  INNER JOIN drivers d ON p.user_id = d.user_id
  -- Ne supprimer que si le patient n'a pas de courses
  WHERE NOT EXISTS (
    SELECT 1 FROM rides WHERE patient_id = p.id
  )
);

-- Message attendu : DELETE X (où X = nombre de profils patients supprimés)

-- ==========================================
-- ÉTAPE 4 : Vérification finale
-- ==========================================

-- Voir tous les utilisateurs avec leurs rôles
SELECT 
    u.phone,
    u.email,
    CASE 
        WHEN p.id IS NULL AND d.id IS NOT NULL THEN '✅ Chauffeur uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NULL THEN '👤 Patient uniquement'
        WHEN p.id IS NOT NULL AND d.id IS NOT NULL THEN '⚠️ Double rôle'
        ELSE '❌ Aucun profil'
    END AS status,
    p.id AS patient_id,
    d.id AS driver_id
FROM auth.users u
LEFT JOIN patients p ON u.id = p.user_id
LEFT JOIN drivers d ON u.id = d.user_id
WHERE u.created_at > NOW() - INTERVAL '7 days'
ORDER BY u.created_at DESC
LIMIT 20;

-- ==========================================
-- INFORMATIONS IMPORTANTES
-- ==========================================

/*
✅ APRÈS EXÉCUTION DE CE SCRIPT :

1. Les nouveaux utilisateurs n'auront PLUS de profil patient créé automatiquement
2. Seul le code Flutter décide quel profil créer (via FirstTimeRoleSelectionScreen)
3. Les chauffeurs auront uniquement un profil chauffeur
4. Les patients auront uniquement un profil patient

🧪 TESTER :

1. Créer un nouveau compte chauffeur (ex: 0669337824)
2. Choisir "Chauffeur" dans l'écran de sélection
3. Se déconnecter puis se reconnecter
4. ✅ Redirection automatique vers DriverDashboard (pas d'écran de sélection)

⚠️ IMPORTANT :

Si vous voulez recréer le trigger plus tard (pas recommandé), utilisez :

CREATE OR REPLACE FUNCTION public.handle_new_patient()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.patients (user_id, first_name, last_name, created_at)
  VALUES (NEW.id, 'Nouveau', 'Patient', NOW())
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_patient();

Mais ce n'est PAS recommandé car cela recréera le problème du double rôle.
*/
```