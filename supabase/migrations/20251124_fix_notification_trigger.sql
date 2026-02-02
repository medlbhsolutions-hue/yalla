-- Fix: Recréer le trigger pour notifications admin sur nouveaux documents
-- Date: 2025-11-24

-- Fonction: Récupérer l'admin principal (premier user avec role=admin)
CREATE OR REPLACE FUNCTION get_admin_user_id()
RETURNS UUID
SECURITY DEFINER -- Permet d'exécuter avec les privilèges du propriétaire
SET search_path = public
AS $$
DECLARE
  admin_id UUID;
BEGIN
  -- Chercher dans la table users (colonne id, pas user_id)
  SELECT id INTO admin_id
  FROM users
  WHERE role = 'admin'
  ORDER BY created_at ASC
  LIMIT 1;
  
  RETURN admin_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction trigger: Créer notification admin quand nouveau document pending
CREATE OR REPLACE FUNCTION notify_admin_new_document()
RETURNS TRIGGER
SECURITY DEFINER -- Permet d'exécuter avec les privilèges du propriétaire
SET search_path = public
AS $$
DECLARE
  admin_id UUID;
  driver_name TEXT;
BEGIN
  -- Récupérer l'ID admin
  admin_id := get_admin_user_id();
  
  IF admin_id IS NULL THEN
    RAISE NOTICE 'Aucun admin trouve, notification non creee';
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
    '📄 Nouveau document à valider',
    format('Le chauffeur %s a uploade un document de type %s', 
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

-- Vérification
SELECT 
  trigger_name, 
  event_manipulation, 
  event_object_table, 
  action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'trigger_notify_admin_new_document';
