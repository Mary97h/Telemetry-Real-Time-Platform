-- Initialize Telemetry Platform Database
-- Control plane tables for reference state and control actions

-- Device registry table
CREATE TABLE IF NOT EXISTS devices (
    device_id VARCHAR(255) PRIMARY KEY,
    device_type VARCHAR(100) NOT NULL,
    location VARCHAR(255),
    firmware_version VARCHAR(50),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_devices_type ON devices(device_type);
CREATE INDEX idx_devices_location ON devices(location);

-- Aggregated metrics table
CREATE TABLE IF NOT EXISTS aggregated_metrics (
    id BIGSERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DOUBLE PRECISION NOT NULL,
    aggregation_type VARCHAR(50) NOT NULL,
    window_start TIMESTAMP NOT NULL,
    window_end TIMESTAMP NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_agg_device_time ON aggregated_metrics(device_id, timestamp DESC);
CREATE INDEX idx_agg_metric_time ON aggregated_metrics(metric_name, timestamp DESC);
CREATE INDEX idx_agg_window ON aggregated_metrics(window_start, window_end);

-- Control actions table
CREATE TABLE IF NOT EXISTS control_actions (
    id BIGSERIAL PRIMARY KEY,
    action_type VARCHAR(100) NOT NULL,
    target_component VARCHAR(255) NOT NULL,
    parameters JSONB,
    status VARCHAR(50) DEFAULT 'pending',
    triggered_by VARCHAR(255),
    executed_at TIMESTAMP,
    completed_at TIMESTAMP,
    result JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_control_status ON control_actions(status, created_at DESC);
CREATE INDEX idx_control_target ON control_actions(target_component, created_at DESC);

-- Anomaly events table
CREATE TABLE IF NOT EXISTS anomaly_events (
    id BIGSERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    anomaly_type VARCHAR(100) NOT NULL,
    severity VARCHAR(50) NOT NULL,
    description TEXT,
    confidence_score DOUBLE PRECISION,
    metadata JSONB,
    detected_at TIMESTAMP NOT NULL,
    acknowledged BOOLEAN DEFAULT false,
    acknowledged_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_anomaly_device_time ON anomaly_events(device_id, detected_at DESC);
CREATE INDEX idx_anomaly_severity ON anomaly_events(severity, detected_at DESC);
CREATE INDEX idx_anomaly_ack ON anomaly_events(acknowledged, detected_at DESC);

-- Configuration table
CREATE TABLE IF NOT EXISTS configuration (
    key VARCHAR(255) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default configurations
INSERT INTO configuration (key, value, description) VALUES
    ('control_loop_enabled', 'true', 'Enable adaptive control loop'),
    ('autoscaling_thresholds', '{"cpu_upper": 0.7, "cpu_lower": 0.3, "memory_upper": 0.8}', 'Autoscaling thresholds'),
    ('alert_thresholds', '{"error_rate": 0.05, "latency_p99": 1000, "throughput_min": 100}', 'Alert threshold configuration'),
    ('checkpoint_interval_ms', '60000', 'Flink checkpoint interval'),
    ('retention_policy', '{"raw_days": 7, "aggregated_days": 30, "archive_days": 365}', 'Data retention policy')
ON CONFLICT (key) DO NOTHING;

-- Sample seed data for testing
INSERT INTO devices (device_id, device_type, location, firmware_version, metadata) VALUES
    ('device-001', 'sensor', 'datacenter-1', 'v1.2.3', '{"zone": "A", "rack": 15}'),
    ('device-002', 'sensor', 'datacenter-1', 'v1.2.3', '{"zone": "B", "rack": 22}'),
    ('device-003', 'actuator', 'datacenter-2', 'v2.0.1', '{"zone": "C", "rack": 8}'),
    ('device-004', 'sensor', 'datacenter-2', 'v1.2.4', '{"zone": "D", "rack": 31}'),
    ('device-005', 'gateway', 'edge-location-1', 'v3.1.0', '{"region": "us-west"}')
ON CONFLICT (device_id) DO NOTHING;

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for devices table
CREATE TRIGGER update_devices_modtime
    BEFORE UPDATE ON devices
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

-- Create views for monitoring
CREATE OR REPLACE VIEW recent_anomalies AS
SELECT
    a.device_id,
    d.device_type,
    d.location,
    a.anomaly_type,
    a.severity,
    a.confidence_score,
    a.detected_at
FROM anomaly_events a
JOIN devices d ON a.device_id = d.device_id
WHERE a.detected_at > NOW() - INTERVAL '24 hours'
ORDER BY a.detected_at DESC;

CREATE OR REPLACE VIEW control_action_summary AS
SELECT
    action_type,
    target_component,
    status,
    COUNT(*) as action_count,
    AVG(EXTRACT(EPOCH FROM (completed_at - created_at))) as avg_duration_seconds,
    MAX(created_at) as last_action_time
FROM control_actions
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY action_type, target_component, status
ORDER BY last_action_time DESC;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin;

-- Log initialization
DO $$
BEGIN
    RAISE NOTICE 'Telemetry Platform database initialized successfully';
END $$;
