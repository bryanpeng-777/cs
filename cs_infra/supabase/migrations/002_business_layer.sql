-- =============================================================
-- Migration 002: 业务数据层 (Business Layer)
-- business schema 下的用户私有数据表
-- 用途：存储各业务 App 的用户数据，每个用户只能访问自己的数据
-- =============================================================

-- ==================== 创建 business schema ====================
CREATE SCHEMA IF NOT EXISTS business;

-- ==================== 用户基础表（由基础架构统一提供）====================
-- 绑定 Supabase Auth 的用户 ID（auth.users.id）
CREATE TABLE IF NOT EXISTS business.users (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  app_id       TEXT NOT NULL,
  display_name TEXT,
  avatar_url   TEXT,
  metadata     JSONB DEFAULT '{}',   -- 各业务可扩展的额外字段
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_biz_users_app ON business.users (app_id);

CREATE TRIGGER trg_biz_users_updated_at
  BEFORE UPDATE ON business.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE business.users ENABLE ROW LEVEL SECURITY;

-- 用户只能读写自己的记录
CREATE POLICY "user_read_own" ON business.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "user_insert_own" ON business.users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "user_update_own" ON business.users
  FOR UPDATE USING (auth.uid() = id);

-- service_role 可以查询所有用户（管理用途）
CREATE POLICY "service_role_full_access_users" ON business.users
  FOR ALL USING (auth.role() = 'service_role');

-- 新用户首次登录时自动创建 business.users 记录
-- （需要在 CsClient.initialize 时由 SDK 调用 upsert 完成）

-- ==================== 新业务建表模板说明 ====================
-- 每个新业务在此文件后追加，或新建 003_[app_name]_tables.sql
-- 模板格式：
--
-- CREATE TABLE IF NOT EXISTS business.[app_name]_[entity] (
--   id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--   user_id    UUID NOT NULL REFERENCES business.users(id) ON DELETE CASCADE,
--   -- 业务自定义字段...
--   created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
--   updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
-- );
--
-- ALTER TABLE business.[app_name]_[entity] ENABLE ROW LEVEL SECURITY;
--
-- CREATE POLICY "user_own_data" ON business.[app_name]_[entity]
--   FOR ALL USING (auth.uid() = user_id);

-- ==================== cs-demo App 的示例业务表 ====================
-- 用于 Demo App 验证业务数据层能力

CREATE TABLE IF NOT EXISTS business.demo_favorites (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES business.users(id) ON DELETE CASCADE,
  item_id      TEXT NOT NULL,
  item_type    TEXT NOT NULL DEFAULT 'wallpaper',
  metadata     JSONB DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_demo_user_item UNIQUE (user_id, item_id, item_type)
);

CREATE INDEX IF NOT EXISTS idx_demo_fav_user
  ON business.demo_favorites (user_id, created_at DESC);

ALTER TABLE business.demo_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_own_favorites" ON business.demo_favorites
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "service_role_full_access_favorites" ON business.demo_favorites
  FOR ALL USING (auth.role() = 'service_role');
