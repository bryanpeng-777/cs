import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js'
import { isInitializeRequest } from '@modelcontextprotocol/sdk/types.js'
import { createClient, SupabaseClient } from '@supabase/supabase-js'
import express from 'express'
import { config } from 'dotenv'
import { randomUUID } from 'crypto'

import { registerConfigTools } from './tools/config-tools'
import { registerStorageTools } from './tools/storage-tools'
import { registerNotificationTools } from './tools/notification-tools'
import { registerAuditTools } from './tools/audit-tools'
import { registerPromoteTools } from './tools/promote-tools'

config()

const SUPABASE_URL = process.env.SUPABASE_URL!
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!
const PORT = parseInt(process.env.PORT || '3000')
const MCP_SECRET = process.env.MCP_SECRET

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('缺少必要环境变量：SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY')
  process.exit(1)
}

export const supabase: SupabaseClient = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } }
)

function createMcpServer() {
  const server = new McpServer({ name: 'cs-admin-mcp', version: '1.0.0' })
  registerConfigTools(server)
  registerStorageTools(server)
  registerNotificationTools(server)
  registerAuditTools(server)
  registerPromoteTools(server)
  return server
}

// session 存储
const sessions = new Map<string, { transport: StreamableHTTPServerTransport; server: McpServer }>()

const app = express()
app.use(express.json({ limit: '50mb' }))

// 健康检查（鉴权前注册）
app.get('/health', (_, res) => {
  res.json({ status: 'ok', service: 'cs-admin-mcp', version: '1.0.0' })
})

// 可选鉴权
app.use((req, res, next) => {
  if (!MCP_SECRET) return next()
  const token = req.headers['x-mcp-secret'] || req.query.secret
  if (token !== MCP_SECRET) {
    res.status(401).json({ error: 'Unauthorized' })
    return
  }
  next()
})

// POST /mcp — 创建 session 或路由到已有 session
app.post('/mcp', async (req, res) => {
  const sessionId = req.headers['mcp-session-id'] as string | undefined

  // 已有 session，转发消息
  if (sessionId && sessions.has(sessionId)) {
    const { transport } = sessions.get(sessionId)!
    await transport.handleRequest(req, res, req.body)
    return
  }

  // 新 session 必须是 initialize 请求
  if (!isInitializeRequest(req.body)) {
    res.status(400).json({
      jsonrpc: '2.0',
      error: { code: -32000, message: 'Bad Request: Server not initialized' },
      id: null,
    })
    return
  }

  // 创建新 session
  const server = createMcpServer()
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: () => randomUUID(),
    onsessioninitialized: (sid) => {
      sessions.set(sid, { transport, server })
      console.log(`[MCP] 新 session: ${sid}，当前活跃: ${sessions.size}`)
    },
  })

  transport.onclose = () => {
    const sid = transport.sessionId
    if (sid && sessions.has(sid)) {
      sessions.delete(sid)
      console.log(`[MCP] session 关闭: ${sid}，当前活跃: ${sessions.size}`)
    }
    server.close()
  }

  await server.connect(transport)
  await transport.handleRequest(req, res, req.body)
})

// GET /mcp — SSE 流（Cursor 的长连接通道）
app.get('/mcp', async (req, res) => {
  const sessionId = req.headers['mcp-session-id'] as string | undefined
  if (!sessionId || !sessions.has(sessionId)) {
    res.status(400).json({ error: 'Invalid or missing session ID' })
    return
  }
  const { transport } = sessions.get(sessionId)!
  await transport.handleRequest(req, res)
})

// DELETE /mcp — 关闭 session
app.delete('/mcp', async (req, res) => {
  const sessionId = req.headers['mcp-session-id'] as string | undefined
  if (sessionId && sessions.has(sessionId)) {
    const { transport, server } = sessions.get(sessionId)!
    sessions.delete(sessionId)
    await transport.close()
    await server.close()
  }
  res.status(200).end()
})

app.listen(PORT, '0.0.0.0', () => {
  console.log(`cs-admin-mcp 已启动，端口 ${PORT}`)
  console.log(`健康检查: http://0.0.0.0:${PORT}/health`)
  console.log(`MCP 端点: http://0.0.0.0:${PORT}/mcp`)
})
