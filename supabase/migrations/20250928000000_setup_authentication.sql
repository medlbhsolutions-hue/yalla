-- Migration pour configurer l'authentification et lier les chauffeurs aux users
-- Date: 2025-09-28

-- Modifier la table drivers pour lier aux comptes utilisateurs
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Créer un index pour améliorer les performances
CREATE INDEX IF NOT EXISTS drivers_user_id_idx ON public.drivers(user_id);

-- Fonction pour créer automatiquement un profil chauffeur après inscription
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Optionnel: Créer automatiquement un enregistrement dans drivers
  -- (pour l'instant on va le faire manuellement via l'inscription)
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger pour appeler la fonction après création d'un nouvel utilisateur
-- (désactivé pour l'instant, on va gérer manuellement)
-- CREATE OR REPLACE TRIGGER on_auth_user_created
--   AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Mettre à jour les politiques RLS pour utiliser l'authentification
DROP POLICY IF EXISTS "Drivers can view their own data" ON public.drivers;
DROP POLICY IF EXISTS "Drivers can update their own data" ON public.drivers;
DROP POLICY IF EXISTS "Anyone can insert drivers" ON public.drivers;

-- Nouvelle politique : Les utilisateurs peuvent voir leurs propres données
CREATE POLICY "Drivers can view their own data" ON public.drivers
  FOR SELECT USING (auth.uid() = user_id);

-- Nouvelle politique : Les utilisateurs peuvent modifier leurs propres données
CREATE POLICY "Drivers can update their own data" ON public.drivers
  FOR UPDATE USING (auth.uid() = user_id);

-- Nouvelle politique : Les utilisateurs authentifiés peuvent créer leur profil
CREATE POLICY "Authenticated users can create driver profile" ON public.drivers
  FOR INSERT WITH CHECK (auth.uid() = user_id AND auth.role() = 'authenticated');

-- Politique pour que les admins puissent tout voir (optionnel)
CREATE POLICY "Admins can view all drivers" ON public.drivers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users 
      WHERE auth.users.id = auth.uid() 
      AND (auth.users.raw_app_meta_data->>'role' = 'admin'
           OR auth.users.email LIKE '%@admin.%')
    )
  );

-- S'assurer que RLS est activé
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;