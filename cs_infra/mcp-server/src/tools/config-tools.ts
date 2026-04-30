import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { supabase } from '../index'

export function registerConfigTools(server: McpServer) {

  // ==================== list_configs ====================
  server.tool(
    'list_configs',
    '查询某个 App 的所有配置列表',
    {
      app_id: z.string().describe('App 标识，如 wallpaper、game-news'),
      config_type: z.enum(['image_url', 'feature_flag', 'text', 'data_table', 'notification', 'custom'])
        .optional().describe('过滤配置类型'),
      environment: z.enum(['dev', 'staging', 'prod']).default('dev').describe('环境'),
      include_inactive: z.boolean().default(false).describe('是否包含已下线的配置'),
    },
    async ({ app_id, config_type, environment, include_inactive }) => {
      let query = supabase
        .from('app_configs')
        .select('config_key, config_type, value, locale, platform, is_active, updated_at')
        .eq('app_id', app_id)
        .eq('environment', environment)
        .order('config_key')

      if (config_type) query = query.eq('config_type', config_type)
      if (!include_inactive) query = query.eq('is_active', true)

      const { data, error } = await query
      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ app_id, environment, count: data?.length, configs: data }, null, 2),
        }],
      }
    }
  )

  // ==================== get_config ====================
  server.tool(
    'get_config',
    '获取某个配置的详细信息（含历史版本数量）',
    {
      app_id: z.string(),
      config_key: z.string().describe('配置 key'),
      environment: z.enum(['dev', 'staging', 'prod']).default('dev'),
    },
    async ({ app_id, config_key, environment }) => {
      const { data, error } = await supabase
        .from('app_configs')
        .select('*')
        .eq('app_id', app_id)
        .eq('config_key', config_key)
        .eq('environment', environment)
        .single()

      if (error) throw new Error(`配置不存在: ${config_key}`)

      // 查询变更次数
      const { count } = await supabase
        .from('config_audit_log')
        .select('*', { count: 'exact', head: true })
        .eq('app_id', app_id)
        .eq('config_key', config_key)

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ ...data, change_count: count }, null, 2),
        }],
      }
    }
  )

  // ==================== update_config ====================
  server.tool(
    'update_config',
    '创建或更新一条配置（同时记录审计日志）',
    {
      app_id: z.string(),
      config_key: z.string().describe('配置唯一 key'),
      config_type: z.enum(['image_url', 'feature_flag', 'text', 'data_table', 'notification', 'custom']),
      value: z.any().describe('配置值（JSON 格式）'),
      platform: z.enum(['ios', 'android', 'all']).default('all'),
      environment: z.enum(['dev', 'staging', 'prod']).default('dev'),
      locale: z.string().default('all').describe('语言/地区，如 zh-CN、en-US、all'),
      changed_by: z.string().default('ai:cursor').describe('操作者标识，用于审计日志'),
    },
    async ({ app_id, config_key, config_type, value, platform, environment, locale, changed_by }) => {
      // 设置审计日志的操作者
      try {
        await supabase.rpc('set_config', { parameter: 'app.changed_by', value: changed_by })
      } catch (_) {}

      const { data, error } = await supabase
        .from('app_configs')
        .upsert({
          app_id,
          config_key,
          config_type,
          value,
          platform,
          environment,
          locale,
          is_active: true,
          updated_at: new Date().toISOString(),
        }, { onConflict: 'app_id,config_key,environment,locale' })
        .select()
        .single()

      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: `✅ 配置已更新\napp_id: ${app_id}\nkey: ${config_key}\nenv: ${environment}\nlocale: ${locale}\nvalue: ${JSON.stringify(value, null, 2)}`,
        }],
      }
    }
  )

  // ==================== toggle_feature_flag ====================
  server.tool(
    'toggle_feature_flag',
    '快捷开关 Feature Flag（布尔开关类配置）',
    {
      app_id: z.string(),
      flag_key: z.string().describe('Feature Flag 的 key'),
      enabled: z.boolean().describe('true = 开启，false = 关闭'),
      environment: z.enum(['dev', 'staging', 'prod']).default('dev'),
      changed_by: z.string().default('ai:cursor'),
    },
    async ({ app_id, flag_key, enabled, environment, changed_by }) => {
      try { await supabase.rpc('set_config', { parameter: 'app.changed_by', value: changed_by }) } catch (_) {}

      const { error } = await supabase
        .from('app_configs')
        .upsert({
          app_id,
          config_key: flag_key,
          config_type: 'feature_flag',
          value: { enabled },
          environment,
          locale: 'all',
          is_active: true,
          updated_at: new Date().toISOString(),
        }, { onConflict: 'app_id,config_key,environment,locale' })

      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: `✅ Feature Flag 已${enabled ? '开启' : '关闭'}\napp_id: ${app_id}\nflag: ${flag_key}\nenv: ${environment}`,
        }],
      }
    }
  )

  // ==================== delete_config ====================
  server.tool(
    'delete_config',
    '下线一条配置（软删除，设置 is_active=false）',
    {
      app_id: z.string(),
      config_key: z.string(),
      environment: z.enum(['dev', 'staging', 'prod']).default('dev'),
      changed_by: z.string().default('ai:cursor'),
    },
    async ({ app_id, config_key, environment, changed_by }) => {
      try { await supabase.rpc('set_config', { parameter: 'app.changed_by', value: changed_by }) } catch (_) {}

      const { error } = await supabase
        .from('app_configs')
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq('app_id', app_id)
        .eq('config_key', config_key)
        .eq('environment', environment)

      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: `✅ 配置已下线\napp_id: ${app_id}\nkey: ${config_key}\nenv: ${environment}`,
        }],
      }
    }
  )

  // ==================== batch_update ====================
  server.tool(
    'batch_update',
    '批量更新多条配置（原子操作，全部成功或全部失败）',
    {
      app_id: z.string(),
      environment: z.enum(['dev', 'staging', 'prod']).default('dev'),
      configs: z.array(z.object({
        config_key: z.string(),
        config_type: z.enum(['image_url', 'feature_flag', 'text', 'data_table', 'notification', 'custom']),
        value: z.any(),
        locale: z.string().default('all'),
        platform: z.enum(['ios', 'android', 'all']).default('all'),
      })).describe('要批量更新的配置列表'),
      changed_by: z.string().default('ai:cursor'),
    },
    async ({ app_id, environment, configs, changed_by }) => {
      try { await supabase.rpc('set_config', { parameter: 'app.changed_by', value: changed_by }) } catch (_) {}

      const rows = configs.map(c => ({
        app_id,
        config_key: c.config_key,
        config_type: c.config_type,
        value: c.value,
        locale: c.locale || 'all',
        platform: c.platform || 'all',
        environment,
        is_active: true,
        updated_at: new Date().toISOString(),
      }))

      const { data, error } = await supabase
        .from('app_configs')
        .upsert(rows, { onConflict: 'app_id,config_key,environment,locale' })
        .select('config_key')

      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: `✅ 批量更新完成\n共 ${data?.length || 0} 条配置已更新\n${data?.map(r => `  - ${r.config_key}`).join('\n')}`,
        }],
      }
    }
  )
}
