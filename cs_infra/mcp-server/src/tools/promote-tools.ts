import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { supabase } from '../index'

export function registerPromoteTools(server: McpServer) {

  // ==================== promote_to_prod ====================
  server.tool(
    'promote_to_prod',
    '将 dev 环境的配置发布到 prod 环境（支持全量或指定 key）',
    {
      app_id: z.string().describe('App 标识'),
      config_keys: z.array(z.string()).optional().describe('指定要发布的 key 列表；不填则发布 dev 全部配置'),
      changed_by: z.string().default('ai:cursor').describe('操作者标识'),
    },
    async ({ app_id, config_keys, changed_by }) => {
      // 拉取 dev 配置
      let query = supabase
        .from('app_configs')
        .select('config_key, config_type, value, platform, locale')
        .eq('app_id', app_id)
        .eq('environment', 'dev')
        .eq('is_active', true)

      if (config_keys && config_keys.length > 0) {
        query = query.in('config_key', config_keys)
      }

      const { data: devConfigs, error: fetchError } = await query
      if (fetchError) throw new Error(`拉取 dev 配置失败: ${fetchError.message}`)
      if (!devConfigs || devConfigs.length === 0) {
        return { content: [{ type: 'text', text: '⚠️ dev 环境没有找到可发布的配置' }] }
      }

      // 设置审计操作者
      try {
        await supabase.rpc('set_config', { parameter: 'app.changed_by', value: `${changed_by}:promote` })
      } catch (_) {}

      // 批量写入 prod
      const prodRows = devConfigs.map((c: any) => ({
        app_id,
        config_key: c.config_key,
        config_type: c.config_type,
        value: c.value,
        platform: c.platform,
        locale: c.locale,
        environment: 'prod',
        is_active: true,
        updated_at: new Date().toISOString(),
      }))

      const { data, error: upsertError } = await supabase
        .from('app_configs')
        .upsert(prodRows, { onConflict: 'app_id,config_key,environment,locale' })
        .select('config_key')

      if (upsertError) throw new Error(`写入 prod 失败: ${upsertError.message}`)

      const keys = data?.map((r: any) => `  ✅ ${r.config_key}`).join('\n')
      return {
        content: [{
          type: 'text',
          text: `🚀 发布成功！共 ${data?.length || 0} 条配置从 dev → prod\n\n${keys}`,
        }],
      }
    }
  )

  // ==================== diff_envs ====================
  server.tool(
    'diff_envs',
    '对比 dev 和 prod 环境的配置差异，发布前用于确认变更内容',
    {
      app_id: z.string(),
    },
    async ({ app_id }) => {
      const [devRes, prodRes] = await Promise.all([
        supabase.from('app_configs').select('config_key, value, updated_at').eq('app_id', app_id).eq('environment', 'dev').eq('is_active', true),
        supabase.from('app_configs').select('config_key, value, updated_at').eq('app_id', app_id).eq('environment', 'prod').eq('is_active', true),
      ])

      if (devRes.error) throw new Error(devRes.error.message)
      if (prodRes.error) throw new Error(prodRes.error.message)

      const devMap = Object.fromEntries((devRes.data || []).map((r: any) => [r.config_key, r]))
      const prodMap = Object.fromEntries((prodRes.data || []).map((r: any) => [r.config_key, r]))

      const allKeys = new Set([...Object.keys(devMap), ...Object.keys(prodMap)])
      const diffs: string[] = []
      const same: string[] = []
      const devOnly: string[] = []
      const prodOnly: string[] = []

      for (const key of allKeys) {
        if (!prodMap[key]) {
          devOnly.push(key)
        } else if (!devMap[key]) {
          prodOnly.push(key)
        } else if (JSON.stringify(devMap[key].value) !== JSON.stringify(prodMap[key].value)) {
          diffs.push(`  🔄 ${key}\n     dev:  ${JSON.stringify(devMap[key].value)}\n     prod: ${JSON.stringify(prodMap[key].value)}`)
        } else {
          same.push(key)
        }
      }

      const lines = [`📊 ${app_id} dev vs prod 差异报告\n`]
      if (diffs.length > 0) lines.push(`【值不同 - ${diffs.length} 条】\n${diffs.join('\n')}`)
      if (devOnly.length > 0) lines.push(`【仅在 dev - ${devOnly.length} 条，未发布】\n${devOnly.map(k => `  🆕 ${k}`).join('\n')}`)
      if (prodOnly.length > 0) lines.push(`【仅在 prod - ${prodOnly.length} 条】\n${prodOnly.map(k => `  ⚠️ ${k}`).join('\n')}`)
      if (same.length > 0) lines.push(`【一致 - ${same.length} 条】\n${same.map(k => `  ✓ ${k}`).join('\n')}`)

      return { content: [{ type: 'text', text: lines.join('\n\n') }] }
    }
  )
}
