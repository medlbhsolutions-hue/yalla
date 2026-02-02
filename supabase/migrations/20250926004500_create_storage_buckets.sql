-- Create storage buckets for driver documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('driver-documents', 'driver-documents', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/jpg', 'application/pdf']::text[]),
  ('driver-avatars', 'driver-avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/jpg']::text[])
ON CONFLICT (id) DO NOTHING;

-- Create storage policies for driver documents
CREATE POLICY "Users can upload their own documents" ON storage.objects
    FOR INSERT 
    WITH CHECK (bucket_id = 'driver-documents');

CREATE POLICY "Users can view their own documents" ON storage.objects
    FOR SELECT 
    USING (bucket_id = 'driver-documents');

CREATE POLICY "Users can update their own documents" ON storage.objects
    FOR UPDATE 
    USING (bucket_id = 'driver-documents');

CREATE POLICY "Users can delete their own documents" ON storage.objects
    FOR DELETE 
    USING (bucket_id = 'driver-documents');

-- Create storage policies for driver avatars (public)
CREATE POLICY "Anyone can view avatars" ON storage.objects
    FOR SELECT 
    USING (bucket_id = 'driver-avatars');

CREATE POLICY "Users can upload avatars" ON storage.objects
    FOR INSERT 
    WITH CHECK (bucket_id = 'driver-avatars');

CREATE POLICY "Users can update avatars" ON storage.objects
    FOR UPDATE 
    USING (bucket_id = 'driver-avatars');

CREATE POLICY "Users can delete avatars" ON storage.objects
    FOR DELETE 
    USING (bucket_id = 'driver-avatars');