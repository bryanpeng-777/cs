import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FCM_URL = 'https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send'

interface PushPayload {
  app_id: string
  title?: string
  body?: string
  data?: Record<string, string>
  type?: 'notification' | 'config_sync'  // config_sync = silent push
  target_device_ids?: string[]            // 定向推送；为空则群发
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, content-type',
      },
    })
  }

  try {
    const payload: PushPayload = await req.json()
    const { app_id, title, body, data, type = 'notification', target_device_ids } = payload

    // 获取 FCM access token
    const fcmToken = await getFcmAccessToken()

    // 获取目标设备的 FCM tokens
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    let query = supabase
      .from('devices')
      .select('fcm_token')
      .eq('app_id', app_id)
      .not('fcm_token', 'is', null)

    if (target_device_ids && target_device_ids.length > 0) {
      query = query.in('device_id', target_device_ids)
    }

    const { data: devices, error } = await query

    if (error) throw error
    if (!devices || devices.length === 0) {
      return new Response(JSON.stringify({ sent: 0, message: '无目标设备' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const tokens = devices.map((d: any) => d.fcm_token).filter(Boolean)

    // 构建 FCM 消息
    const isConfigSync = type === 'config_sync'
    let sentCount = 0

    // FCM 每次最多 500 个 token，批量发送
    const batchSize = 500
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize)

      const fcmPayload = {
        message: {
          tokens: batch,
          data: {
            type,
            app_id,
            ...data,
          },
          // silent push 不显示通知栏
          ...(isConfigSync
            ? { android: { priority: 'normal' }, apns: { headers: { 'apns-priority': '5' } } }
            : {
                notification: {
                  title: title || '',
                  body: body || '',
                },
              }),
        },
      }

      const projectId = Deno.env.get('FCM_PROJECT_ID')!
      const url = FCM_URL.replace('{PROJECT_ID}', projectId)

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${fcmToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(fcmPayload),
      })

      if (!response.ok) {
        const errorText = await response.text()
        console.error('FCM 发送失败:', errorText)
      } else {
        sentCount += batch.length
      }
    }

    return new Response(
      JSON.stringify({ sent: sentCount, total_devices: tokens.length }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('推送通知错误:', error)
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})

/** 获取 FCM OAuth2 access token（使用 Service Account） */
async function getFcmAccessToken(): Promise<string> {
  const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!
  const serviceAccount = JSON.parse(serviceAccountJson)

  // 构建 JWT
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  }

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const signingInput = `${encode(header)}.${encode(claim)}`

  // 使用私钥签名
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(signingInput)
  )

  const jwt = `${signingInput}.${arrayBufferToBase64Url(signature)}`

  // 换取 access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const binary = atob(base64)
  const buffer = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) buffer[i] = binary.charCodeAt(i)
  return buffer.buffer
}

function arrayBufferToBase64Url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}
