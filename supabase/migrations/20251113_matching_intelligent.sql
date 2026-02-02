-- Migration PHASE 2: Matching Intelligent & Attribution Automatique
-- Date: 2025-11-13
-- Description: Table ride_proposals + trigger auto-matching

-- 1. Table pour stocker les propositions de courses
CREATE TABLE IF NOT EXISTS ride_proposals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  distance_km DECIMAL(6, 2), -- Distance entre chauffeur et pickup
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  responded_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(ride_id, driver_id) -- Un chauffeur ne peut avoir qu'une proposition par course
);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_ride_proposals_ride ON ride_proposals(ride_id);
CREATE INDEX IF NOT EXISTS idx_ride_proposals_driver ON ride_proposals(driver_id);
CREATE INDEX IF NOT EXISTS idx_ride_proposals_status ON ride_proposals(status);
CREATE INDEX IF NOT EXISTS idx_ride_proposals_expires ON ride_proposals(expires_at);

-- Activer Row Level Security
ALTER TABLE ride_proposals ENABLE ROW LEVEL SECURITY;

-- Policy: Les chauffeurs voient leurs propres propositions
DROP POLICY IF EXISTS "Drivers can view own proposals" ON ride_proposals;
CREATE POLICY "Drivers can view own proposals" ON ride_proposals
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM drivers 
      WHERE drivers.id = driver_id 
      AND drivers.user_id = auth.uid()
    )
  );

-- Policy: Les chauffeurs peuvent mettre à jour leurs propres propositions
DROP POLICY IF EXISTS "Drivers can update own proposals" ON ride_proposals;
CREATE POLICY "Drivers can update own proposals" ON ride_proposals
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM drivers 
      WHERE drivers.id = driver_id 
      AND drivers.user_id = auth.uid()
    )
  );

-- Policy: Les patients peuvent voir les propositions de leurs courses
DROP POLICY IF EXISTS "Patients can view proposals for their rides" ON ride_proposals;
CREATE POLICY "Patients can view proposals for their rides" ON ride_proposals
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rides r
      JOIN patients p ON r.patient_id = p.id
      WHERE r.id = ride_id 
      AND p.user_id = auth.uid()
    )
  );

-- 2. Fonction pour expirer automatiquement les propositions
CREATE OR REPLACE FUNCTION expire_old_proposals()
RETURNS void AS $$
BEGIN
  UPDATE ride_proposals
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Fonction trigger pour appeler match-driver quand une nouvelle course est créée
-- NOTE: Cette fonction nécessite pg_net extension pour les appels HTTP
-- Pour l'instant, désactivée en attendant le déploiement de l'Edge Function
CREATE OR REPLACE FUNCTION auto_match_driver_on_new_ride()
RETURNS TRIGGER AS $$
BEGIN
  -- Seulement pour les nouvelles courses en status 'pending'
  IF NEW.status = 'pending' AND OLD IS NULL THEN
    
    -- TODO: Appeler l'Edge Function match-driver automatiquement
    -- Nécessite l'extension pg_net ou une autre méthode d'appel HTTP
    -- Pour l'instant, les propositions sont créées manuellement ou via l'app
    
    -- Log pour debugging
    RAISE NOTICE '🚀 New ride created: %, auto-matching will be triggered by Edge Function', NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Créer le trigger (désactivé pour l'instant - commenté)
-- DROP TRIGGER IF EXISTS trigger_auto_match_driver ON rides;
-- CREATE TRIGGER trigger_auto_match_driver
--   AFTER INSERT ON rides
--   FOR EACH ROW
--   EXECUTE FUNCTION auto_match_driver_on_new_ride();

-- 4. Fonction pour accepter une proposition (chauffeur)
CREATE OR REPLACE FUNCTION accept_ride_proposal(
  proposal_id UUID
)
RETURNS jsonb AS $$
DECLARE
  proposal RECORD;
  result jsonb;
BEGIN
  -- Récupérer la proposition
  SELECT * INTO proposal
  FROM ride_proposals
  WHERE id = proposal_id
    AND status = 'pending'
    AND expires_at > NOW()
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Proposal not found, already accepted, or expired'
    );
  END IF;

  -- Mettre à jour la proposition
  UPDATE ride_proposals
  SET 
    status = 'accepted',
    responded_at = NOW()
  WHERE id = proposal_id;

  -- Assigner le chauffeur à la course
  UPDATE rides
  SET 
    driver_id = proposal.driver_id,
    status = 'assigned'
  WHERE id = proposal.ride_id;

  -- Rejeter toutes les autres propositions pour cette course
  UPDATE ride_proposals
  SET 
    status = 'rejected',
    responded_at = NOW()
  WHERE ride_id = proposal.ride_id
    AND id != proposal_id
    AND status = 'pending';

  RETURN jsonb_build_object(
    'success', true,
    'rideId', proposal.ride_id,
    'driverId', proposal.driver_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Fonction pour refuser une proposition (chauffeur)
CREATE OR REPLACE FUNCTION reject_ride_proposal(
  proposal_id UUID
)
RETURNS jsonb AS $$
BEGIN
  UPDATE ride_proposals
  SET 
    status = 'rejected',
    responded_at = NOW()
  WHERE id = proposal_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Proposal not found or already responded'
    );
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Commentaires
COMMENT ON TABLE ride_proposals IS 'Propositions de courses envoyées aux chauffeurs disponibles';
COMMENT ON FUNCTION auto_match_driver_on_new_ride IS 'Trigger qui appelle match-driver automatiquement pour nouvelles courses';
COMMENT ON FUNCTION accept_ride_proposal IS 'Accepter une proposition et assigner la course au chauffeur';
COMMENT ON FUNCTION reject_ride_proposal IS 'Refuser une proposition de course';
COMMENT ON FUNCTION expire_old_proposals IS 'Marquer comme expirées les propositions dont le délai est dépassé';
