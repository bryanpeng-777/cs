import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { supabase } from '../index'

const PUSH_FUNCTION_URL = `${process.env.SUPABASE_URL}/functions/v1/push-notification`

export function registerNotificationTools(server: McpServer) {

  // ==================== send_notification ====================
  server.tool(
    'send_notification',
    '向 App 用户发送推送通知',
    {
      app_id: z.string(),
      title: z.string().describe('通知标题'),
      body: z.string().describe('通知内容'),
      data: z.record(z.string(), z.string()).optional().describe('自定义数据（key-value）'),
      target_device_ids: z.array(z.string()).optional().describe('定向推送的设备 ID 列表；不填则群发所有设备'),
    },
    async ({ app_id, title, body, data, target_device_ids }) => {
      const response = await fetch(PUSH_FUNCTION_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          app_id,
          title,
          body,
          data,
          type: 'notification',
          target_device_ids,
        }),
      })

      const result = await response.json()
      if (!response.ok) throw new Error(JSON.stringify(result))

      return {
        content: [{
          type: 'text',
          text: `✅ 推送通知已发送\napp_id: ${app_id}\n标题: ${title}\n内容: ${body}\n发送设备数: ${result.sent}/${result.total_devices}`,
        }],
      }
    }
  )

  // ==================== trigger_config_sync ====================
  server.tool(
    'trigger_config_sync',
    '发送 silent push 通知，让所有后台 App 主动拉取最新配置',
    {
      app_id: z.string(),
      target_device_ids: z.array(z.string()).optional(),
    },
    async ({ app_id, target_device_ids }) => {
      const response = await fetch(PUSH_FUNCTION_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          app_id,
          type: 'config_sync',
          target_device_ids,
        }),
      })

      const result = await response.json()
      if (!response.ok) throw new Error(JSON.stringify(result))

      return {
        content: [{
          type: 'text',
          text: `✅ 配置同步信号已发送\napp_id: ${app_id}\n通知设备数: ${result.sent}`,
        }],
      }
    }
  )

  // ==================== list_devices ====================
  server.tool(
    'list_devices',
    '查询某个 App 的注册设备列表',
    {
      app_id: z.string(),
      platform: z.enum(['ios', 'android', 'all']).default('all'),
      limit: z.number().default(50),
    },
    async ({ app_id, platform, limit }) => {
      let query = supabase
        .from('devices')
        .select('device_id, platform, app_version, locale, updated_at')
        .eq('app_id', app_id)
        .order('updated_at', { ascending: false })
        .limit(limit)

      if (platform !== 'all') {
        query = query.eq('platform', platform)
      }

      const { data, error } = await query
      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ app_id, count: data?.length, devices: data }, null, 2),
        }],
      }
    }
  )
}
