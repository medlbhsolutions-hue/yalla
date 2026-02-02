-- Migration pour ajouter la table notifications
-- Date: 2025-11-10
-- Description: Table pour stocker les notifications push et in-app

-- Créer la table notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL, -- 'new_ride_request', 'ride_accepted', 'driver_arrived', 'ride_started', 'ride_completed', 'ride_cancelled', 'payment_received', 'rating_received', 'system'
  data JSONB DEFAULT '{}'::jsonb,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  read_at TIMESTAMP WITH TIME ZONE
);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- Ajouter la colonne fcm_token dans une table séparée pour les tokens FCM
-- On ne peut pas modifier auth.users directement
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);

-- Ajouter les colonnes rating dans la table drivers si elles n'existent pas
ALTER TABLE drivers
ADD COLUMN IF NOT EXISTS rating DECIMAL(2,1) DEFAULT 5.0,
ADD COLUMN IF NOT EXISTS total_ratings INTEGER DEFAULT 0;

-- Ajouter les colonnes rating dans la table patients si elles n'existent pas
ALTER TABLE patients
ADD COLUMN IF NOT EXISTS rating DECIMAL(2,1) DEFAULT 5.0,
ADD COLUMN IF NOT EXISTS total_ratings INTEGER DEFAULT 0;

-- Ajouter les colonnes de commentaires dans la table rides si elles n'existent pas
ALTER TABLE rides
ADD COLUMN IF NOT EXISTS driver_comment TEXT,
ADD COLUMN IF NOT EXISTS patient_comment TEXT,
ADD COLUMN IF NOT EXISTS rated_at TIMESTAMP WITH TIME ZONE;

-- Activer Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Les utilisateurs ne peuvent voir que leurs propres notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Permettre l'insertion de notifications (pour le système)
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON notifications;
CREATE POLICY "Enable insert for authenticated users" ON notifications
  FOR INSERT
  WITH CHECK (true);

-- Policy: Les utilisateurs peuvent mettre à jour leurs propres notifications (marquer comme lu)
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Function pour compter les notifications non lues
CREATE OR REPLACE FUNCTION get_unread_notifications_count(target_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM notifications
    WHERE user_id = target_user_id AND is_read = FALSE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour marquer toutes les notifications comme lues
CREATE OR REPLACE FUNCTION mark_all_notifications_as_read(target_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE notifications
  SET is_read = TRUE, read_at = NOW()
  WHERE user_id = target_user_id AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger pour mettre à jour read_at automatiquement
CREATE OR REPLACE FUNCTION update_notification_read_at()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_read = TRUE AND OLD.is_read = FALSE THEN
    NEW.read_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_notification_read_at ON notifications;
CREATE TRIGGER trigger_update_notification_read_at
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_notification_read_at();

-- Commentaires sur la table
COMMENT ON TABLE notifications IS 'Stocke toutes les notifications push et in-app pour les utilisateurs';
COMMENT ON COLUMN notifications.type IS 'Type de notification: new_ride_request, ride_accepted, driver_arrived, ride_started, ride_completed, ride_cancelled, payment_received, rating_received, system';
COMMENT ON COLUMN notifications.data IS 'Données supplémentaires au format JSON (ride_id, etc.)';
