-- Migration: Système de notifications pour validation documents
-- Date: 2025-11-24
-- Description: Crée table notifications + trigger automatique pour nouveaux documents

-- Table des notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL, -- 'document_pending', 'document_approved', 'document_rejected', 'new_ride', etc.
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  data JSONB, -- Données additionnelles (document_id, ride_id, etc.)
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ,
  
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Commentaires
COMMENT ON TABLE notifications IS 'Notifications pour les utilisateurs (admins, chauffeurs, patients)';
COMMENT ON COLUMN notifications.type IS 'Type de notification pour filtrage et affichage';
COMMENT ON COLUMN notifications.data IS 'Données JSON pour contexte additionnel';

-- Fonction: Récupérer l'admin principal (premier user avec role=admin)
CREATE OR REPLACE FUNCTION get_admin_user_id()
RETURNS UUID AS $$
DECLARE
  admin_id UUID;
BEGIN
  SELECT id INTO admin_id
  FROM auth.users
  WHERE raw_user_meta_data->>'role' = 'admin'
  ORDER BY created_at ASC
  LIMIT 1;
  
  RETURN admin_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction trigger: Créer notification admin quand nouveau document pending
CREATE OR REPLACE FUNCTION notify_admin_new_document()
RETURNS TRIGGER AS $$
DECLARE
  admin_id UUID;
  driver_name TEXT;
BEGIN
  -- Récupérer l'ID admin
  admin_id := get_admin_user_id();
  
  IF admin_id IS NULL THEN
    RAISE NOTICE 'Aucun admin trouvé, notification non créée';
    RETURN NEW;
  END IF;
  
  -- Récupérer le nom du chauffeur
  SELECT CONCAT(first_name, ' ', last_name) INTO driver_name
  FROM drivers
  WHERE id = NEW.driver_id;
  
  -- Créer notification pour l'admin
  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (
    admin_id,
    'document_pending',
    'Nouveau document à valider',
    format('Le chauffeur %s a uploadé un document de type %s', 
           COALESCE(driver_name, 'Inconnu'), 
           NEW.document_type),
    jsonb_build_object(
      'document_id', NEW.id,
      'driver_id', NEW.driver_id,
      'document_type', NEW.document_type,
      'file_url', NEW.file_url
    )
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Exécuter la fonction sur INSERT dans driver_documents
DROP TRIGGER IF EXISTS trigger_notify_admin_new_document ON driver_documents;
CREATE TRIGGER trigger_notify_admin_new_document
  AFTER INSERT ON driver_documents
  FOR EACH ROW
  WHEN (NEW.status = 'pending')
  EXECUTE FUNCTION notify_admin_new_document();

-- Fonction: Marquer notification comme lue
CREATE OR REPLACE FUNCTION mark_notification_read(notification_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE notifications
  SET is_read = TRUE, read_at = NOW()
  WHERE id = notification_id;
END;
$$ LANGUAGE plpgsql;

-- RLS Policies pour notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Les users peuvent voir leurs propres notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Les users peuvent mettre à jour leurs propres notifications
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Le système peut créer des notifications (via trigger)
DROP POLICY IF EXISTS "System can insert notifications" ON notifications;
CREATE POLICY "System can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);

-- Vérification
SELECT 
  table_name, 
  column_name, 
  data_type 
FROM information_schema.columns 
WHERE table_name = 'notifications'
ORDER BY ordinal_position;
