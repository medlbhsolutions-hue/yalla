// Edge Function pour envoyer des notifications push via Firebase Cloud Messaging API V1
// Deploy: supabase functions deploy send-notification
// Requires: FIREBASE_SERVICE_ACCOUNT secret (JSON du compte de service Firebase)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

interface NotificationPayload {
  userId: string;
  title: string;
  body: string;
  type: string;
  data?: Record<string, any>;
}

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
}

// Cache pour le token OAuth2
let cachedAccessToken: string | null = null;
let tokenExpiry: number = 0;

/**
 * Génère un JWT signé pour obtenir un access token OAuth2
 */
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  
  // Réutiliser le token en cache s'il est encore valide (avec 5 min de marge)
  if (cachedAccessToken && tokenExpiry > now + 300) {
    return cachedAccessToken;
  }

  // Créer le JWT
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: getNumericDate(0),
    exp: getNumericDate(3600), // 1 heure
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  // Importer la clé privée
  const pemContents = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");
  
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  // Signer le JWT
  const jwt = await create(header, payload, cryptoKey);

  // Échanger le JWT contre un access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  
  if (!tokenResponse.ok) {
    throw new Error(`OAuth2 error: ${JSON.stringify(tokenData)}`);
  }

  cachedAccessToken = tokenData.access_token;
  tokenExpiry = now + tokenData.expires_in;
  
  return cachedAccessToken!;
}

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Vérifier la configuration
    if (!FIREBASE_SERVICE_ACCOUNT) {
      console.error("❌ FIREBASE_SERVICE_ACCOUNT non configuré");
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: "Firebase service account not configured" 
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Parser le payload
    const payload: NotificationPayload = await req.json();
    const { userId, title, body, type, data } = payload;

    console.log(`📤 Envoi notification à user: ${userId}`);

    // 2. Parser le compte de service
    const serviceAccount: ServiceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    const projectId = serviceAccount.project_id;

    // 3. Créer client Supabase
    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_KEY!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 4. Récupérer le FCM token de l'utilisateur
    const { data: tokenData, error: tokenError } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token")
      .eq("user_id", userId)
      .single();

    if (tokenError || !tokenData?.fcm_token) {
      console.log("⚠️ FCM token non trouvé, sauvegarde notification locale uniquement");
      
      // Sauvegarder quand même la notification en base
      await supabase.from("notifications").insert({
        user_id: userId,
        title: title,
        body: body,
        type: type,
        data: data || {},
        is_read: false,
      });

      return new Response(
        JSON.stringify({ 
          success: true, 
          push_sent: false,
          message: "Notification saved locally (no FCM token)" 
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const fcmToken = tokenData.fcm_token;
    console.log(`✅ FCM Token trouvé: ${fcmToken.substring(0, 20)}...`);

    // 5. Obtenir le token OAuth2
    const accessToken = await getAccessToken(serviceAccount);

    // 6. Construire le message FCM V1
    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: type,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          ...Object.fromEntries(
            Object.entries(data || {}).map(([k, v]) => [k, String(v)])
          ),
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        webpush: {
          notification: {
            icon: "/icons/icon-192x192.png",
          },
        },
      },
    };

    // 7. Envoyer via Firebase Cloud Messaging API V1
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify(message),
      }
    );

    const fcmResult = await fcmResponse.json();

    // 8. Enregistrer dans la table notifications (pour l'historique in-app)
    await supabase.from("notifications").insert({
      user_id: userId,
      title: title,
      body: body,
      type: type,
      data: data || {},
      is_read: false,
    });

    if (fcmResponse.ok) {
      console.log("✅ Notification push envoyée avec succès:", fcmResult.name);
      return new Response(
        JSON.stringify({ 
          success: true,
          push_sent: true,
          message_id: fcmResult.name 
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } else {
      console.error("❌ Erreur FCM:", fcmResult);
      return new Response(
        JSON.stringify({ 
          success: true,
          push_sent: false,
          error: fcmResult.error?.message || "FCM error",
          details: fcmResult
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (error) {
    console.error("❌ Erreur fonction:", error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});
