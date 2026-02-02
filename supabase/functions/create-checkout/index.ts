import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import Stripe from "npm:stripe@12.13.0"

serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Access-Control-Allow-Credentials": "true",
  }

  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    })
  }

  try {
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") || "", {
      apiVersion: "2023-10-16",
    })

    const { amount, success_url, cancel_url, ride_id, patient_id, driver_id } = await req.json()
    
    if (!amount || amount <= 0) {
      throw new Error("Le montant est requis et doit être supérieur à 0")
    }

    if (!success_url || !cancel_url) {
      throw new Error("Les URLs de redirection success_url et cancel_url sont requises")
    }

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: "mad", // Dirham Marocain
            product_data: { 
              name: "Course médicale Yalla L'Tbib",
              description: ride_id ? `Course #${ride_id.substring(0, 8)}` : undefined,
            },
            unit_amount: amount,
          },
          quantity: 1,
        },
      ],
      mode: "payment",
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: {
        ride_id: ride_id || "",
        patient_id: patient_id || "",
        driver_id: driver_id || "",
      },
    })

    return new Response(
      JSON.stringify({ url: session.url }), 
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error) {
    const err = error as Error
    return new Response(
      JSON.stringify({ error: err.message }), 
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    )
  }
})
