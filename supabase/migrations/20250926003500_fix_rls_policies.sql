-- Drop old policies first
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.drivers;

-- Create a new policy for inserting new drivers
CREATE POLICY "Anyone can insert new drivers" ON public.drivers
    FOR INSERT
    WITH CHECK (true);

-- Add policy for public insertions
ALTER TABLE public.drivers FORCE ROW LEVEL SECURITY;