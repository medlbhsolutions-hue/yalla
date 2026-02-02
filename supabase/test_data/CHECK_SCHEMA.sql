-- Vérifier la structure de la table users
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- Vérifier les drivers existants
SELECT * FROM drivers LIMIT 3;

-- Vérifier les users existants
SELECT * FROM users LIMIT 3;
