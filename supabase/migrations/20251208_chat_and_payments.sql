-- =========================================
-- YALLA TBIB - Tables Chat et Paiements
-- Date: 08/12/2025
-- Fonctionnalités: Chat temps réel + Paiements
-- =========================================

-- =========================================
-- TABLE: chat_messages
-- Messages en temps réel entre Patient et Chauffeur
-- =========================================

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_chat_messages_ride_id ON public.chat_messages(ride_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON public.chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at DESC);

-- Commentaires
COMMENT ON TABLE public.chat_messages IS 'Messages de chat entre patient et chauffeur pour une course';
COMMENT ON COLUMN public.chat_messages.ride_id IS 'ID de la course associée';
COMMENT ON COLUMN public.chat_messages.sender_id IS 'ID de l''utilisateur qui envoie le message';
COMMENT ON COLUMN public.chat_messages.message IS 'Contenu du message';
COMMENT ON COLUMN public.chat_messages.is_read IS 'Si le message a été lu par le destinataire';

-- RLS (Row Level Security)
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Supprimer les politiques existantes si elles existent
DROP POLICY IF EXISTS "Users can view chat messages of their rides" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can send chat messages in their rides" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can mark messages as read" ON public.chat_messages;

-- Politique: Utilisateurs peuvent voir les messages de leurs courses
CREATE POLICY "Users can view chat messages of their rides" ON public.chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.rides r
            WHERE r.id = ride_id
            AND (r.patient_id = auth.uid() OR r.driver_id = auth.uid())
        )
    );

-- Politique: Utilisateurs peuvent envoyer des messages dans leurs courses
CREATE POLICY "Users can send chat messages in their rides" ON public.chat_messages
    FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.rides r
            WHERE r.id = ride_id
            AND (r.patient_id = auth.uid() OR r.driver_id = auth.uid())
        )
    );

-- Politique: Utilisateurs peuvent marquer comme lu les messages reçus
CREATE POLICY "Users can mark messages as read" ON public.chat_messages
    FOR UPDATE USING (
        sender_id != auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.rides r
            WHERE r.id = ride_id
            AND (r.patient_id = auth.uid() OR r.driver_id = auth.uid())
        )
    );

-- =========================================
-- TABLE: payments
-- Historique des paiements
-- =========================================

-- Créer la table si elle n'existe pas
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
    patient_id UUID REFERENCES auth.users(id),
    driver_id UUID REFERENCES auth.users(id),
    amount DECIMAL(10, 2),
    payment_method VARCHAR(20) DEFAULT 'cash',
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ajouter les colonnes manquantes si elles n'existent pas
DO $$ 
BEGIN
    -- amount_cents
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'payments' AND column_name = 'amount_cents') THEN
        ALTER TABLE public.payments ADD COLUMN amount_cents INTEGER;
        RAISE NOTICE '✅ Colonne amount_cents ajoutée';
    END IF;
    
    -- amount_mad
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'payments' AND column_name = 'amount_mad') THEN
        ALTER TABLE public.payments ADD COLUMN amount_mad DECIMAL(10, 2);
        RAISE NOTICE '✅ Colonne amount_mad ajoutée';
    END IF;
    
    -- stripe_session_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'payments' AND column_name = 'stripe_session_id') THEN
        ALTER TABLE public.payments ADD COLUMN stripe_session_id TEXT;
        RAISE NOTICE '✅ Colonne stripe_session_id ajoutée';
    END IF;
    
    -- stripe_payment_intent_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'payments' AND column_name = 'stripe_payment_intent_id') THEN
        ALTER TABLE public.payments ADD COLUMN stripe_payment_intent_id TEXT;
        RAISE NOTICE '✅ Colonne stripe_payment_intent_id ajoutée';
    END IF;
END $$;

-- Index
CREATE INDEX IF NOT EXISTS idx_payments_ride_id ON public.payments(ride_id);
CREATE INDEX IF NOT EXISTS idx_payments_patient_id ON public.payments(patient_id);
CREATE INDEX IF NOT EXISTS idx_payments_driver_id ON public.payments(driver_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON public.payments(created_at DESC);

-- Commentaires
COMMENT ON TABLE public.payments IS 'Historique des paiements pour les courses';
COMMENT ON COLUMN public.payments.amount_cents IS 'Montant en centimes (pour Stripe)';
COMMENT ON COLUMN public.payments.amount_mad IS 'Montant en MAD';
COMMENT ON COLUMN public.payments.payment_method IS 'Méthode: card (carte) ou cash (espèces)';
COMMENT ON COLUMN public.payments.status IS 'Statut: pending, completed, failed, refunded';

-- RLS
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Supprimer les politiques existantes si elles existent
DROP POLICY IF EXISTS "Users can view their payments" ON public.payments;
DROP POLICY IF EXISTS "Authenticated users can insert payments" ON public.payments;
DROP POLICY IF EXISTS "Authenticated users can update payments" ON public.payments;

-- Politique: Utilisateurs peuvent voir leurs paiements
CREATE POLICY "Users can view their payments" ON public.payments
    FOR SELECT USING (
        patient_id = auth.uid() OR driver_id = auth.uid()
    );

-- Politique: Seul le système peut créer des paiements
CREATE POLICY "Authenticated users can insert payments" ON public.payments
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Politique: Mise à jour par le système
CREATE POLICY "Authenticated users can update payments" ON public.payments
    FOR UPDATE USING (auth.role() = 'authenticated');

-- =========================================
-- TABLE: user_fcm_tokens (si pas existante)
-- Tokens FCM pour les notifications push
-- =========================================

CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type VARCHAR(20), -- 'android', 'ios', 'web'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON public.user_fcm_tokens(user_id);

-- RLS
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can manage their FCM tokens" ON public.user_fcm_tokens
    FOR ALL USING (user_id = auth.uid());

-- =========================================
-- FONCTION: Compter messages non lus
-- =========================================

CREATE OR REPLACE FUNCTION get_unread_messages_count(p_user_id UUID, p_ride_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM public.chat_messages
        WHERE ride_id = p_ride_id
        AND sender_id != p_user_id
        AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =========================================
-- TRIGGER: Mise à jour updated_at
-- =========================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour chat_messages
DROP TRIGGER IF EXISTS update_chat_messages_updated_at ON public.chat_messages;
CREATE TRIGGER update_chat_messages_updated_at
    BEFORE UPDATE ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger pour payments
DROP TRIGGER IF EXISTS update_payments_updated_at ON public.payments;
CREATE TRIGGER update_payments_updated_at
    BEFORE UPDATE ON public.payments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- REALTIME: Activer pour le chat
-- =========================================

-- Activer Realtime sur chat_messages (ignorer si déjà activé)
DO $$ 
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE 'Table chat_messages déjà dans supabase_realtime';
END $$;

-- Rafraîchir le cache PostgREST
NOTIFY pgrst, 'reload schema';

-- =========================================
-- VÉRIFICATION
-- =========================================

DO $$ 
DECLARE
    tables_count INT;
BEGIN
    SELECT COUNT(*) INTO tables_count
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN ('chat_messages', 'payments', 'user_fcm_tokens');
    
    RAISE NOTICE '🎯 Tables créées: % / 3 attendues', tables_count;
    
    IF tables_count = 3 THEN
        RAISE NOTICE '✅ Toutes les tables Chat/Paiements ont été créées!';
    END IF;
END $$;
