-- ═══════════════════════════════════════════════════════════════
-- VÉRIFICATION : Course en attente existe ?
-- ═══════════════════════════════════════════════════════════════

-- 1. Voir toutes les courses en attente
SELECT 
  id, 
  patient_id,
  driver_id,
  status,
  pickup_address,
  destination_address,
  total_price,
  created_at
FROM rides
WHERE status = 'pending' AND driver_id IS NULL
ORDER BY created_at DESC;

-- 2. Si aucune course trouvée, voir TOUTES les courses récentes
SELECT 
  id, 
  patient_id,
  driver_id,
  status,
  pickup_address,
  destination_address,
  total_price,
  created_at
FROM rides
ORDER BY created_at DESC
LIMIT 10;

-- 3. Voir le nouveau patient créé
SELECT 
  u.id as user_id,
  u.phone_number,
  u.role,
  p.id as patient_id,
  p.first_name,
  p.last_name
FROM users u
LEFT JOIN patients p ON p.user_id = u.id
WHERE u.phone_number = '+212669337818';

-- 4. Voir le nouveau driver créé
SELECT 
  u.id as user_id,
  u.phone_number,
  u.role,
  d.id as driver_id,
  d.first_name,
  d.last_name,
  d.is_available
FROM users u
LEFT JOIN drivers d ON d.user_id = u.id
WHERE u.phone_number LIKE '+21266933781%'
ORDER BY u.created_at DESC;
