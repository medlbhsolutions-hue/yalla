-- =========================================
-- YALLA TBIB - Ajout colonnes de tracking pour les courses
-- Date: 08/12/2025
-- Ajoute: arrived_at, started_at pour le suivi des étapes
-- =========================================

-- Ajouter la colonne arrived_at (quand le chauffeur arrive chez le patient)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'rides' 
        AND column_name = 'arrived_at'
    ) THEN
        ALTER TABLE public.rides ADD COLUMN arrived_at TIMESTAMP WITH TIME ZONE;
        COMMENT ON COLUMN public.rides.arrived_at IS 'Timestamp quand le chauffeur arrive chez le patient';
        RAISE NOTICE '✅ Colonne arrived_at ajoutée à rides';
    ELSE
        RAISE NOTICE '⏭️ Colonne arrived_at existe déjà';
    END IF;
END $$;

-- Ajouter la colonne started_at (quand la course démarre effectivement)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'rides' 
        AND column_name = 'started_at'
    ) THEN
        ALTER TABLE public.rides ADD COLUMN started_at TIMESTAMP WITH TIME ZONE;
        COMMENT ON COLUMN public.rides.started_at IS 'Timestamp quand la course démarre (patient à bord)';
        RAISE NOTICE '✅ Colonne started_at ajoutée à rides';
    ELSE
        RAISE NOTICE '⏭️ Colonne started_at existe déjà';
    END IF;
END $$;

-- Ajouter la colonne accepted_at (quand le chauffeur accepte la course)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'rides' 
        AND column_name = 'accepted_at'
    ) THEN
        ALTER TABLE public.rides ADD COLUMN accepted_at TIMESTAMP WITH TIME ZONE;
        COMMENT ON COLUMN public.rides.accepted_at IS 'Timestamp quand le chauffeur accepte la course';
        RAISE NOTICE '✅ Colonne accepted_at ajoutée à rides';
    ELSE
        RAISE NOTICE '⏭️ Colonne accepted_at existe déjà';
    END IF;
END $$;

-- Ajouter la colonne cancelled_at (quand une course est annulée)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'rides' 
        AND column_name = 'cancelled_at'
    ) THEN
        ALTER TABLE public.rides ADD COLUMN cancelled_at TIMESTAMP WITH TIME ZONE;
        COMMENT ON COLUMN public.rides.cancelled_at IS 'Timestamp quand la course est annulée';
        RAISE NOTICE '✅ Colonne cancelled_at ajoutée à rides';
    ELSE
        RAISE NOTICE '⏭️ Colonne cancelled_at existe déjà';
    END IF;
END $$;

-- Ajouter la colonne cancellation_reason (motif d'annulation)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'rides' 
        AND column_name = 'cancellation_reason'
    ) THEN
        ALTER TABLE public.rides ADD COLUMN cancellation_reason TEXT;
        COMMENT ON COLUMN public.rides.cancellation_reason IS 'Motif de l''annulation de la course';
        RAISE NOTICE '✅ Colonne cancellation_reason ajoutée à rides';
    ELSE
        RAISE NOTICE '⏭️ Colonne cancellation_reason existe déjà';
    END IF;
END $$;

-- Créer index pour améliorer les requêtes de suivi
CREATE INDEX IF NOT EXISTS idx_rides_arrived_at ON public.rides(arrived_at) WHERE arrived_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_rides_started_at ON public.rides(started_at) WHERE started_at IS NOT NULL;

-- Rafraîchir le cache Supabase PostgREST
NOTIFY pgrst, 'reload schema';

-- =========================================
-- VÉRIFICATION
-- =========================================
-- Vérifier que les colonnes ont bien été ajoutées
DO $$ 
DECLARE
    col_count INT;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'rides' 
    AND column_name IN ('arrived_at', 'started_at', 'accepted_at', 'cancelled_at', 'cancellation_reason');
    
    RAISE NOTICE '🎯 Total colonnes de tracking: % / 5 attendues', col_count;
    
    IF col_count = 5 THEN
        RAISE NOTICE '✅ Toutes les colonnes de tracking ont été ajoutées avec succès!';
    END IF;
END $$;
