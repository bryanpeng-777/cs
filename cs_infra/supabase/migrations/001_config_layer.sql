-- =============================================================
-- Migration 001: 配置层 (Config Layer)
-- public schema 下的所有配置相关表
-- 用途：AI/运营下发配置给所有客户端，广播性质
-- =============================================================

-- ==================== 通用配置下发表 ====================
CREATE TABLE IF NOT EXISTS app_configs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id      TEXT NOT NULL,
  config_key  TEXT NOT NULL,
  config_type TEXT NOT NULL CHECK (config_type IN (
    'image_url', 'feature_flag', 'text', 'data_table', 'notification', 'custom'
  )),
  value       JSONB NOT NULL,
  platform    TEXT NOT NULL DEFAULT 'all' CHECK (platform IN ('ios', 'android', 'all')),
  environment TEXT NOT NULL DEFAULT 'prod' CHECK (environment IN ('dev', 'staging', 'prod')),
  locale      TEXT NOT NULL DEFAULT 'all',   -- 'all' | 'zh-CN' | 'en-US' | 'ja-JP' 等
  min_version TEXT,
  max_version TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_app_config_key UNIQUE (app_id, config_key, environment, locale)
);

CREATE INDEX IF NOT EXISTS idx_configs_app_active
  ON app_configs (app_id, is_active, environment, locale);

CREATE INDEX IF NOT EXISTS idx_configs_updated
  ON app_configs (app_id, updated_at);

-- updated_at 自动更新
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_configs_updated_at
  BEFORE UPDATE ON app_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ==================== 增量同步版本表 ====================
CREATE TABLE IF NOT EXISTS config_sync_versions (
  app_id      TEXT NOT NULL,
  environment TEXT NOT NULL DEFAULT 'prod',
  version     BIGINT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (app_id, environment)
);

-- app_configs 新增或更新时自动递增版本号
CREATE OR REPLACE FUNCTION bump_sync_version()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO config_sync_versions (app_id, environment, version, updated_at)
  VALUES (NEW.app_id, NEW.environment, 1, now())
  ON CONFLICT (app_id, environment)
  DO UPDATE SET
    version    = config_sync_versions.version + 1,
    updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bump_sync_version
  AFTER INSERT OR UPDATE ON app_configs
  FOR EACH ROW EXECUTE FUNCTION bump_sync_version();

-- ==================== 设备注册表 ====================
CREATE TABLE IF NOT EXISTS devices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id      TEXT NOT NULL,
  device_id   TEXT NOT NULL,
  fcm_token   TEXT,
  platform    TEXT CHECK (platform IN ('ios', 'android')),
  app_version TEXT,
  locale      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_app_device UNIQUE (app_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_devices_app ON devices (app_id);
CREATE INDEX IF NOT EXISTS idx_devices_fcm  ON devices (fcm_token) WHERE fcm_token IS NOT NULL;

CREATE TRIGGER trg_devices_updated_at
  BEFORE UPDATE ON devices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ==================== 配置变更审计日志 ====================
CREATE TABLE IF NOT EXISTS config_audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id      TEXT NOT NULL,
  config_key  TEXT NOT NULL,
  environment TEXT NOT NULL DEFAULT 'prod',
  old_value   JSONB,
  new_value   JSONB NOT NULL,
  changed_by  TEXT NOT NULL DEFAULT 'system',
  change_type TEXT NOT NULL CHECK (change_type IN ('create', 'update', 'delete', 'rollback')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_app_key
  ON config_audit_log (app_id, config_key, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_created
  ON config_audit_log (created_at DESC);

-- 自动记录配置变更到审计日志
CREATE OR REPLACE FUNCTION audit_config_change()
RETURNS TRIGGER AS $$
DECLARE
  actor TEXT;
BEGIN
  -- 优先使用 session 变量（MCP Server 设置），回退到 'system'
  actor := COALESCE(current_setting('app.changed_by', true), 'system');

  IF TG_OP = 'INSERT' THEN
    INSERT INTO config_audit_log
      (app_id, config_key, environment, new_value, changed_by, change_type)
    VALUES
      (NEW.app_id, NEW.config_key, NEW.environment, NEW.value, actor, 'create');

  ELSIF TG_OP = 'UPDATE' THEN
    -- 只有 value 或 is_active 变化时才记录
    IF OLD.value IS DISTINCT FROM NEW.value OR OLD.is_active IS DISTINCT FROM NEW.is_active THEN
      INSERT INTO config_audit_log
        (app_id, config_key, environment, old_value, new_value, changed_by, change_type)
      VALUES (
        NEW.app_id,
        NEW.config_key,
        NEW.environment,
        OLD.value,
        NEW.value,
        actor,
        CASE WHEN NOT NEW.is_active THEN 'delete' ELSE 'update' END
      );
    END IF;

  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_config
  AFTER INSERT OR UPDATE ON app_configs
  FOR EACH ROW EXECUTE FUNCTION audit_config_change();

-- ==================== RLS 策略 ====================
ALTER TABLE app_configs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE config_sync_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices           ENABLE ROW LEVEL SECURITY;
ALTER TABLE config_audit_log  ENABLE ROW LEVEL SECURITY;

-- app_configs：所有人可读激活的配置，只有 service_role 可写
CREATE POLICY "public_read_active_configs" ON app_configs
  FOR SELECT USING (is_active = true);

CREATE POLICY "service_role_full_access_configs" ON app_configs
  FOR ALL USING (auth.role() = 'service_role');

-- config_sync_versions：所有人可读（客户端需要检查版本号）
CREATE POLICY "public_read_sync_versions" ON config_sync_versions
  FOR SELECT USING (true);

CREATE POLICY "service_role_full_access_versions" ON config_sync_versions
  FOR ALL USING (auth.role() = 'service_role');

-- devices：设备可以注册和更新自己的记录
CREATE POLICY "device_upsert_self" ON devices
  FOR ALL USING (true);

-- config_audit_log：只有 service_role 可读（敏感操作记录）
CREATE POLICY "service_role_read_audit" ON config_audit_log
  FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "service_role_insert_audit" ON config_audit_log
  FOR INSERT WITH CHECK (true);

-- ==================== 初始化 cs-demo App ====================
INSERT INTO config_sync_versions (app_id, environment, version)
VALUES
  ('cs-demo', 'dev',  0),
  ('cs-demo', 'prod', 0)
ON CONFLICT DO NOTHING;
