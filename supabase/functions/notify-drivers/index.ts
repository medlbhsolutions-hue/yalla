import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  ride_id: string
  pickup_latitude: number
  pickup_longitude: number
  estimated_price: number
  priority_level: string
}

// Fonction pour obtenir un access token OAuth2 depuis le service account
async function getAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
  
  const jwtHeader = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const now = Math.floor(Date.now() / 1000)
  const jwtClaimSet = btoa(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  }))
  
  const signatureInput = `${jwtHeader}.${jwtClaimSet}`
  
  // Importer la clé privée
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pemContents = serviceAccount.private_key
    .replace(pemHeader, '')
    .replace(pemFooter, '')
    .replace(/\s/g, '')
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
  
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signatureInput)
  )
  
  const jwtSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
  
  const jwt = `${signatureInput}.${jwtSignature}`
  
  // Échanger le JWT contre un access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  })
  
  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

serve(async (req) => {
  // Gérer CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    // Récupérer les données de la requête
    const payload: NotificationPayload = await req.json()
    console.log('📨 Notification pour course:', payload.ride_id)
    
    // 1. Trouver les chauffeurs à proximité (rayon 10 km)
    const { data: nearbyDrivers, error: driversError } = await supabase
      .rpc('find_nearby_drivers', {
        pickup_lat: payload.pickup_latitude,
        pickup_lng: payload.pickup_longitude,
        radius_km: 10
      })
    
    if (driversError) {
      console.error('❌ Erreur recherche chauffeurs:', driversError)
      throw driversError
    }
    
    if (!nearbyDrivers || nearbyDrivers.length === 0) {
      console.log('⚠️ Aucun chauffeur à proximité')
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Aucun chauffeur disponible à proximité',
          drivers_notified: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log(`✅ ${nearbyDrivers.length} chauffeurs trouvés`)
    
    // 2. Récupérer les FCM tokens des chauffeurs depuis users.fcm_token
    const driverIds = nearbyDrivers.map((d: any) => d.driver_id)  // Utilise driver_id, pas id !
    console.log(`🔍 DEBUG: driverIds extraits:`, JSON.stringify(driverIds))
    
    const { data: drivers, error: tokensError } = await supabase
      .from('drivers')
      .select('id, user_id, users!inner(fcm_token)')
      .in('id', driverIds)
    
    if (tokensError) {
      console.error('❌ Erreur récupération tokens:', tokensError)
      throw tokensError
    }
    
    // Extraire les tokens non-null avec user_id
    console.log(`🔍 DEBUG: drivers récupérés:`, JSON.stringify(drivers))
    const fcmTokens = drivers
      ?.filter((d: any) => d.users?.fcm_token)
      .map((d: any) => { 
        console.log(`🔍 DEBUG: Mapping driver ${d.id}, user_id=${d.user_id}`)
        return {
          driver_id: d.id, 
          user_id: d.user_id, 
          fcm_token: d.users.fcm_token 
        }
      }) || []
    
    console.log(`🔍 DEBUG: fcmTokens final:`, JSON.stringify(fcmTokens))
    
    if (!fcmTokens || fcmTokens.length === 0) {
      console.log('⚠️ Aucun token FCM trouvé')
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Aucun token FCM disponible',
          drivers_notified: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log(`📱 ${fcmTokens.length} tokens FCM trouvés`)
    
    // 3. Envoyer les notifications FCM (API V1)
    const accessToken = await getAccessToken()
    const projectId = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!).project_id
    
    const notificationPromises = fcmTokens.map(async (tokenData: any) => {
      const driver = nearbyDrivers.find((d: any) => d.driver_id === tokenData.driver_id)  // Utilise driver_id !
      
      const message = {
        message: {
          token: tokenData.fcm_token,
          notification: {
            title: payload.priority_level === 'urgent' 
              ? '🚨 COURSE URGENTE !' 
              : '🚕 Nouvelle course disponible',
            body: `À ${driver?.distance_km?.toFixed(1) || '?'} km de vous - ${payload.estimated_price} MAD`
          },
          data: {
            ride_id: payload.ride_id,
            distance_km: driver?.distance_km?.toString() || '0',
            estimated_price: payload.estimated_price.toString(),
            priority_level: payload.priority_level,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'available_rides'
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channel_id: 'ride_notifications'
            }
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1
              }
            }
          }
        }
      }
      
      try {
        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify(message)
          }
        )
        
        const fcmResult = await fcmResponse.json()
        
        if (fcmResponse.ok) {
          console.log(`✅ Notification envoyée au chauffeur ${tokenData.driver_id}`)
          return { success: true, driver_id: tokenData.driver_id, user_id: tokenData.user_id }
        } else {
          console.error(`❌ Échec notification chauffeur ${tokenData.driver_id}:`, fcmResult)
          return { success: false, driver_id: tokenData.driver_id, user_id: tokenData.user_id, error: fcmResult }
        }
      } catch (error) {
        console.error(`❌ Erreur FCM pour chauffeur ${tokenData.driver_id}:`, error)
        return { success: false, driver_id: tokenData.driver_id, user_id: tokenData.user_id, error }
      }
    })
    
    const results = await Promise.all(notificationPromises)
    const successCount = results.filter(r => r.success).length
    
    console.log(`🎯 ${successCount}/${results.length} notifications envoyées`)
    
    // 4. Enregistrer les notifications dans la base
    const notificationRecords = results
      .filter(r => r.success)
      .map(r => ({
        user_id: r.user_id,  // Utilise user_id pour la table notifications
        type: 'new_ride',
        title: payload.priority_level === 'urgent' ? 'Course urgente' : 'Nouvelle course',
        body: `Course à ${payload.estimated_price} MAD disponible`,
        data: { ride_id: payload.ride_id },
        is_read: false
      }))
    
    if (notificationRecords.length > 0) {
      await supabase
        .from('notifications')
        .insert(notificationRecords)
    }
    
    return new Response(
      JSON.stringify({ 
        success: true,
        drivers_found: nearbyDrivers.length,
        drivers_notified: successCount,
        ride_id: payload.ride_id
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
    
  } catch (error) {
    console.error('❌ Erreur:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
