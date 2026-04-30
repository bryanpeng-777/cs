-- =============================================================
-- Migration 模板：新业务接入时复制此文件
-- 文件命名：003_[app_name]_tables.sql
-- 执行前替换所有 [app_name] 为实际的 appId
-- =============================================================

-- Step 1: 注册新 App（必须执行）
INSERT INTO config_sync_versions (app_id, environment, version)
VALUES
  ('[app_name]', 'dev',  0),
  ('[app_name]', 'prod', 0)
ON CONFLICT DO NOTHING;

-- Step 2: 建业务表（按需，无用户数据可跳过）
-- 示例：用户收藏表
CREATE TABLE IF NOT EXISTS business.[app_name]_favorites (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES business.users(id) ON DELETE CASCADE,
  item_id      TEXT NOT NULL,
  metadata     JSONB DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_[app_name]_user_item UNIQUE (user_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_[app_name]_fav_user
  ON business.[app_name]_favorites (user_id, created_at DESC);

ALTER TABLE business.[app_name]_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_own_[app_name]_favorites" ON business.[app_name]_favorites
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "service_role_[app_name]_favorites" ON business.[app_name]_favorites
  FOR ALL USING (auth.role() = 'service_role');

-- Step 3: 根据业务需要继续添加更多表...
