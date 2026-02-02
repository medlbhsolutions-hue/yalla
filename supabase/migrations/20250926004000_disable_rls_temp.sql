-- Temporarily disable RLS for development and testing
ALTER TABLE public.drivers DISABLE ROW LEVEL SECURITY;

-- Or alternatively, create a more permissive policy
-- DROP POLICY IF EXISTS "Anyone can insert new drivers" ON public.drivers;
-- CREATE POLICY "Allow all operations for development" ON public.drivers FOR ALL USING (true) WITH CHECK (true);