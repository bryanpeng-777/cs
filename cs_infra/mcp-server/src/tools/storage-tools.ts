import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { readFileSync } from 'fs'
import { basename, extname } from 'path'
import { supabase } from '../index'

const CONFIGS_BUCKET = 'configs'

export function registerStorageTools(server: McpServer) {

  // ==================== upload_image ====================
  server.tool(
    'upload_image',
    '上传图片到 Supabase Storage 并返回公开 CDN URL',
    {
      app_id: z.string().describe('App 标识，图片会存储在 configs/{app_id}/ 路径下'),
      file_path: z.string().describe('本地图片文件的绝对路径'),
      remote_name: z.string().optional().describe('存储文件名（不填则用原文件名）'),
    },
    async ({ app_id, file_path, remote_name }) => {
      // 读取本地文件
      const fileBuffer = readFileSync(file_path)
      const ext = extname(file_path).toLowerCase()
      const fileName = remote_name || basename(file_path)
      const storagePath = `${app_id}/${fileName}`

      // 根据扩展名确定 Content-Type
      const contentTypeMap: Record<string, string> = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.svg': 'image/svg+xml',
      }
      const contentType = contentTypeMap[ext] || 'application/octet-stream'

      // 上传到 Supabase Storage
      const { error } = await supabase.storage
        .from(CONFIGS_BUCKET)
        .upload(storagePath, fileBuffer, {
          contentType,
          upsert: true,
        })

      if (error) throw new Error(`上传失败: ${error.message}`)

      // 获取公开 CDN URL
      const { data } = supabase.storage
        .from(CONFIGS_BUCKET)
        .getPublicUrl(storagePath)

      const cdnUrl = data.publicUrl

      return {
        content: [{
          type: 'text',
          text: `✅ 图片上传成功\n文件: ${fileName}\n路径: ${storagePath}\nCDN URL: ${cdnUrl}\n\n可以直接用此 URL 更新配置，例如：\nupdate_config(app_id="${app_id}", config_key="home_banner_image", config_type="image_url", value={"url": "${cdnUrl}"})`,
        }],
      }
    }
  )

  // ==================== list_images ====================
  server.tool(
    'list_images',
    '列出某个 App 在 Storage 中的图片列表',
    {
      app_id: z.string(),
    },
    async ({ app_id }) => {
      const { data, error } = await supabase.storage
        .from(CONFIGS_BUCKET)
        .list(app_id, { limit: 100, sortBy: { column: 'updated_at', order: 'desc' } })

      if (error) throw new Error(error.message)

      const files = (data || []).map(f => {
        const { data: urlData } = supabase.storage
          .from(CONFIGS_BUCKET)
          .getPublicUrl(`${app_id}/${f.name}`)
        return { name: f.name, url: urlData.publicUrl, size: f.metadata?.size }
      })

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ app_id, count: files.length, files }, null, 2),
        }],
      }
    }
  )

  // ==================== delete_image ====================
  server.tool(
    'delete_image',
    '删除 Storage 中的图片',
    {
      app_id: z.string(),
      file_name: z.string().describe('文件名（不含路径前缀）'),
    },
    async ({ app_id, file_name }) => {
      const storagePath = `${app_id}/${file_name}`
      const { error } = await supabase.storage
        .from(CONFIGS_BUCKET)
        .remove([storagePath])

      if (error) throw new Error(error.message)

      return {
        content: [{
          type: 'text',
          text: `✅ 图片已删除: ${storagePath}`,
        }],
      }
    }
  )
}
