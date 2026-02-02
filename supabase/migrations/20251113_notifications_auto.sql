-- Migration: Notifications automatiques pour nouvelles courses
-- Date: 2025-11-13
-- Description: Appel automatique de l'Edge Function notify-drivers après création d'une course

-- 🔔 Trigger pour notifier les chauffeurs automatiquement
-- Utilise l'extension pg_net pour appeler l'Edge Function
-- Si pg_net n'est pas disponible, appeler manuellement via le code Flutter

CREATE OR REPLACE FUNCTION notify_drivers_on_new_ride()
RETURNS TRIGGER AS $$
DECLARE
  function_url TEXT;
  payload JSONB;
BEGIN
  -- URL de l'Edge Function (à configurer avec votre vraie URL Supabase)
  function_url := 'https://aijchsvkuocbtzamyojy.supabase.co/functions/v1/notify-drivers';
  
  -- Préparer le payload
  payload := jsonb_build_object(
    'ride_id', NEW.id,
    'pickup_latitude', NEW.pickup_latitude,
    'pickup_longitude', NEW.pickup_longitude,
    'estimated_price', NEW.estimated_price,
    'priority_level', NEW.priority_level
  );
  
  -- Appeler l'Edge Function via pg_net (si disponible)
  -- NOTE: pg_net peut ne pas être disponible dans tous les plans Supabase
  -- Alternative: Appeler depuis le code Flutter après insertion
  BEGIN
    PERFORM net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('request.jwt.claims', true)::json->>'sub'
      ),
      body := payload
    );
    
    RAISE NOTICE 'Notification Edge Function appelée pour course %', NEW.id;
    
  EXCEPTION
    WHEN OTHERS THEN
      -- Si pg_net n'est pas disponible, logger l'erreur mais continuer
      RAISE WARNING 'pg_net non disponible, notifier manuellement depuis Flutter: %', SQLERRM;
  END;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Créer le trigger (COMMENTÉ par défaut, décommenter si pg_net est disponible)
-- DROP TRIGGER IF EXISTS trigger_notify_drivers_on_new_ride ON rides;
-- CREATE TRIGGER trigger_notify_drivers_on_new_ride
--   AFTER INSERT ON rides
--   FOR EACH ROW
--   WHEN (NEW.status = 'pending')
--   EXECUTE FUNCTION notify_drivers_on_new_ride();

-- Alternative: Appeler depuis Flutter après création de course
-- Exemple: await supabase.functions.invoke('notify-drivers', body: {...})

COMMENT ON FUNCTION notify_drivers_on_new_ride() IS 
'Notifie automatiquement les chauffeurs à proximité via Edge Function. 
Nécessite pg_net extension ou appel manuel depuis Flutter.';
