// Edge Function: match-driver
// Description: Matche automatiquement une course avec les meilleurs chauffeurs disponibles
// Déclenché par: Trigger database quand nouvelle course créée

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface MatchDriverRequest {
  rideId: string
  pickupLat: number
  pickupLng: number
  maxDistance?: number // km
  maxDriversToNotify?: number
}

interface NearbyDriver {
  driver_id: string
  driver_name: string
  driver_phone: string
  vehicle_type: string
  rating: number
  distance_km: number
  lat: number
  lng: number
  last_update: string
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { rideId, pickupLat, pickupLng, maxDistance = 10, maxDriversToNotify = 3 } = 
      await req.json() as MatchDriverRequest

    console.log(`🔍 Matching drivers for ride ${rideId}`)
    console.log(`📍 Pickup: ${pickupLat}, ${pickupLng}`)
    console.log(`📏 Max distance: ${maxDistance}km, Max drivers: ${maxDriversToNotify}`)

    // 1. Trouver les chauffeurs à proximité avec find_nearby_drivers
    const { data: nearbyDrivers, error: driversError } = await supabase
      .rpc('find_nearby_drivers', {
        pickup_lat: pickupLat,
        pickup_lng: pickupLng,
        radius_km: maxDistance
      })

    if (driversError) {
      console.error('❌ Error finding nearby drivers:', driversError)
      throw driversError
    }

    if (!nearbyDrivers || nearbyDrivers.length === 0) {
      console.log('⚠️ No drivers found nearby')
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'No drivers available nearby',
          driversNotified: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Found ${nearbyDrivers.length} nearby drivers`)

    // 2. Sélectionner les meilleurs chauffeurs (rating + proximité)
    // Déjà trié par distance dans la fonction SQL
    const selectedDrivers = (nearbyDrivers as NearbyDriver[])
      .slice(0, maxDriversToNotify)

    console.log(`📋 Selected ${selectedDrivers.length} drivers to notify`)

    // 3. Créer des notifications pour chaque chauffeur sélectionné
    const notificationPromises = selectedDrivers.map(async (driver) => {
      // Récupérer l'user_id du driver
      const { data: driverData, error: driverError } = await supabase
        .from('drivers')
        .select('user_id')
        .eq('id', driver.driver_id)
        .single()

      if (driverError || !driverData) {
        console.error(`❌ Error getting user_id for driver ${driver.driver_id}:`, driverError)
        return null
      }

      // Créer une proposition de course
      const { error: proposalError } = await supabase
        .from('ride_proposals')
        .insert({
          ride_id: rideId,
          driver_id: driver.driver_id,
          status: 'pending',
          distance_km: driver.distance_km,
          expires_at: new Date(Date.now() + 60 * 1000).toISOString() // 60 secondes
        })

      if (proposalError) {
        console.error(`❌ Error creating proposal for driver ${driver.driver_id}:`, proposalError)
        return null
      }

      // Envoyer notification push via send-notification
      try {
        const notifResponse = await supabase.functions.invoke('send-notification', {
          body: {
            userId: driverData.user_id,
            title: '🚗 Nouvelle Course Disponible',
            body: `Course à ${driver.distance_km.toFixed(1)}km de vous. Tap pour accepter!`,
            type: 'ride_proposal',
            data: {
              rideId,
              driverId: driver.driver_id,
              distance: driver.distance_km,
              expiresIn: 60
            }
          }
        })

        if (notifResponse.error) {
          console.error(`❌ Error sending notification to driver ${driver.driver_id}:`, notifResponse.error)
          return null
        }

        console.log(`✅ Notification sent to driver ${driver.driver_name} (${driver.distance_km.toFixed(1)}km)`)
        return driver
      } catch (notifError) {
        console.error(`❌ Failed to invoke send-notification:`, notifError)
        return null
      }
    })

    const results = await Promise.all(notificationPromises)
    const successCount = results.filter(r => r !== null).length

    console.log(`🎉 Successfully notified ${successCount}/${selectedDrivers.length} drivers`)

    return new Response(
      JSON.stringify({
        success: true,
        driversNotified: successCount,
        drivers: results.filter(r => r !== null).map(d => ({
          id: d!.driver_id,
          name: d!.driver_name,
          distance: d!.distance_km
        }))
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error in match-driver:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
