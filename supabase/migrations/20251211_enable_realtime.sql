-- =========================================
-- ACTIVER REALTIME SUR LES TABLES
-- Nécessaire pour que Supabase Realtime fonctionne
-- =========================================

-- Activer Realtime pour la table rides
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'rides'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.rides;
        RAISE NOTICE '✅ Realtime activé pour rides';
    ELSE
        RAISE NOTICE '✅ Realtime déjà activé pour rides';
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE '⚠️ rides déjà dans supabase_realtime';
END $$;

-- Activer Realtime pour la table driver_locations
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'driver_locations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;
        RAISE NOTICE '✅ Realtime activé pour driver_locations';
    ELSE
        RAISE NOTICE '✅ Realtime déjà activé pour driver_locations';
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE '⚠️ driver_locations déjà dans supabase_realtime';
END $$;

-- Activer Realtime pour la table chat_messages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
        RAISE NOTICE '✅ Realtime activé pour chat_messages';
    ELSE
        RAISE NOTICE '✅ Realtime déjà activé pour chat_messages';
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE '⚠️ chat_messages déjà dans supabase_realtime';
END $$;

-- Vérifier les tables dans la publication
SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
