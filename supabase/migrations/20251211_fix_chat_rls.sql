-- =========================================
-- CORRECTION RLS CHAT_MESSAGES
-- Problème: patient_id/driver_id dans rides = IDs de profils, pas user_id
-- Solution: Joindre avec tables patients/drivers pour vérifier user_id
-- =========================================

-- Supprimer les anciennes politiques
DROP POLICY IF EXISTS "Users can view chat messages of their rides" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can send chat messages in their rides" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can mark messages as read" ON public.chat_messages;

-- Nouvelle politique SELECT: Voir les messages de ses courses
CREATE POLICY "Users can view chat messages of their rides" ON public.chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.rides r
            LEFT JOIN public.patients p ON r.patient_id = p.id
            LEFT JOIN public.drivers d ON r.driver_id = d.id
            WHERE r.id = ride_id
            AND (p.user_id = auth.uid() OR d.user_id = auth.uid())
        )
    );

-- Nouvelle politique INSERT: Envoyer des messages dans ses courses
CREATE POLICY "Users can send chat messages in their rides" ON public.chat_messages
    FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.rides r
            LEFT JOIN public.patients p ON r.patient_id = p.id
            LEFT JOIN public.drivers d ON r.driver_id = d.id
            WHERE r.id = ride_id
            AND (p.user_id = auth.uid() OR d.user_id = auth.uid())
        )
    );

-- Nouvelle politique UPDATE: Marquer comme lu les messages reçus
CREATE POLICY "Users can mark messages as read" ON public.chat_messages
    FOR UPDATE USING (
        sender_id != auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.rides r
            LEFT JOIN public.patients p ON r.patient_id = p.id
            LEFT JOIN public.drivers d ON r.driver_id = d.id
            WHERE r.id = ride_id
            AND (p.user_id = auth.uid() OR d.user_id = auth.uid())
        )
    );

-- Vérification
DO $$ 
BEGIN
    RAISE NOTICE '✅ Politiques RLS chat_messages corrigées!';
END $$;

-- Rafraîchir le cache
NOTIFY pgrst, 'reload schema';
