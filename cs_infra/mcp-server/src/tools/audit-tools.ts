import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { supabase } from '../index'

export function registerAuditTools(server: McpServer) {

  // ==================== view_audit_log ====================
  server.tool(
    'view_audit_log',
    '查看配置变更历史记录',
    {
      app_id: z.string(),
      config_key: z.string().optional().describe('不填则查看所有配置的变更记录'),
      environment: z.enum(['dev', 'staging', 'prod']).default('dev'),
      limit: z.number().default(20).describe('返回条数'),
    },
    async ({ app_id, config_key, environment, limit }) => {
      let query = supabase
        .from('config_audit_log')
        .select('id, config_key, old_value, new_value, changed_by, change_type, created_at')
        .eq('app_id', app_id)
        .eq('environment', environment)
        .order('created_at', { ascending: false })
        .limit(limit)

      if (config_key) {
        query = query.eq('config_key', config_key)
      }

      const { data, error } = await query
      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ app_id, environment, count: data?.length, logs: data }, null, 2),
        }],
      }
    }
  )

  // ==================== rollback_config ====================
  server.tool(
    'rollback_config',
    '将配置回滚到某个历史版本',
    {
      app_id: z.string(),
      config_key: z.string(),
      to_audit_id: z.string().uuid().describe('目标审计日志 ID（从 view_audit_log 获取）'),
      environment: z.enum(['dev', 'staging', 'prod']).default('dev'),
      changed_by: z.string().default('ai:cursor'),
    },
    async ({ app_id, config_key, to_audit_id, environment, changed_by }) => {
      // 查找目标审计记录
      const { data: auditRecord, error: auditError } = await supabase
        .from('config_audit_log')
        .select('old_value, new_value, created_at, change_type')
        .eq('id', to_audit_id)
        .single()

      if (auditError) throw new Error(`审计记录不存在: ${to_audit_id}`)

      // 回滚目标值：使用该记录的 old_value（即变更前的值）
      const rollbackValue = auditRecord.old_value
      if (rollbackValue === null) {
        throw new Error('无法回滚：该记录是最初创建的版本，没有更早的值')
      }

      // 设置审计操作者
      try {
        await supabase.rpc('set_config', { parameter: 'app.changed_by', value: `${changed_by}:rollback` })
      } catch (_) {}

      // 写回目标值（change_type 会被 trigger 记录为 'rollback'）
      // 注意：我们需要修改 trigger，或者在这里手动插入审计记录
      const { error: updateError } = await supabase
        .from('app_configs')
        .update({
          value: rollbackValue,
          is_active: true,
          updated_at: new Date().toISOString(),
        })
        .eq('app_id', app_id)
        .eq('config_key', config_key)
        .eq('environment', environment)

      if (updateError) throw new Error(updateError.message)

      // 手动插入 rollback 类型的审计记录
      await supabase.from('config_audit_log').insert({
        app_id,
        config_key,
        environment,
        old_value: null,
        new_value: rollbackValue,
        changed_by: `${changed_by}:rollback`,
        change_type: 'rollback',
      })

      return {
        content: [{
          type: 'text',
          text: `✅ 配置已回滚\napp_id: ${app_id}\nkey: ${config_key}\n回滚到时间点: ${auditRecord.created_at}\n回滚值: ${JSON.stringify(rollbackValue, null, 2)}`,
        }],
      }
    }
  )

  // ==================== register_app ====================
  server.tool(
    'register_app',
    '注册一个新 App 到基础架构（初始化 config_sync_versions 记录）',
    {
      app_id: z.string().describe('新 App 的唯一标识，建议用小写字母和连字符，如 wallpaper、game-news'),
    },
    async ({ app_id }) => {
      const { error } = await supabase
        .from('config_sync_versions')
        .upsert([
          { app_id, environment: 'dev', version: 0 },
          { app_id, environment: 'prod', version: 0 },
        ], { onConflict: 'app_id,environment' })

      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: `✅ App 注册成功\napp_id: ${app_id}\n\n接下来：\n1. 在 Flutter 项目中 CsClient.initialize(appId: "${app_id}", ...)\n2. 提供 assets/default_configs.json 默认配置\n3. 用 update_config 初始化配置数据`,
        }],
      }
    }
  )
}
