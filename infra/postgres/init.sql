-- Creates tables for device metadata, command audit, and alerts

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Device metadata table
CREATE TABLE IF NOT EXISTS devices (
    device_id VARCHAR(255) PRIMARY KEY,
    location VARCHAR(255) NOT NULL,
    zone VARCHAR(255) NOT NULL,
    model VARCHAR(255) NOT NULL,
    firmware_version VARCHAR(50),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on zone for faster lookups
CREATE INDEX idx_devices_zone ON devices(zone);
CREATE INDEX idx_devices_status ON devices(status);

-- Command audit table
CREATE TABLE IF NOT EXISTS command_audit (
    id SERIAL PRIMARY KEY,
    command_id VARCHAR(255) UNIQUE NOT NULL,
    target_id VARCHAR(255) NOT NULL,
    command_type VARCHAR(50) NOT NULL,
    parameters JSONB,
    priority VARCHAR(20) DEFAULT 'NORMAL',
    status VARCHAR(50) DEFAULT 'PENDING',
    result JSONB,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    executed_at TIMESTAMP,
    completed_at TIMESTAMP
);

-- Create indexes for efficient queries
CREATE INDEX idx_command_audit_command_id ON command_audit(command_id);
CREATE INDEX idx_command_audit_target_id ON command_audit(target_id);
CREATE INDEX idx_command_audit_status ON command_audit(status);
CREATE INDEX idx_command_audit_created_at ON command_audit(created_at DESC);

-- Alerts table
CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    alert_id VARCHAR(255) UNIQUE NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    device_ids TEXT[] NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    metadata JSONB,
    recommended_action TEXT,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(255),
    acknowledged_at TIMESTAMP,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for alerts
CREATE INDEX idx_alerts_alert_id ON alerts(alert_id);
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_timestamp ON alerts(timestamp DESC);
CREATE INDEX idx_alerts_acknowledged ON alerts(acknowledged);
CREATE INDEX idx_alerts_resolved ON alerts(resolved);

-- Metrics aggregations table (for historical queries)
CREATE TABLE IF NOT EXISTS metrics_history (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(255) NOT NULL,
    device_id VARCHAR(255),
    timestamp TIMESTAMP NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    aggregation_window VARCHAR(20) NOT NULL, -- '1m', '5m', '15m', '1h'
    count BIGINT,
    min_value DOUBLE PRECISION,
    max_value DOUBLE PRECISION,
    avg_value DOUBLE PRECISION,
    p50_value DOUBLE PRECISION,
    p95_value DOUBLE PRECISION,
    p99_value DOUBLE PRECISION
);

-- Create indexes for metrics
CREATE INDEX idx_metrics_history_metric_name ON metrics_history(metric_name);
CREATE INDEX idx_metrics_history_timestamp ON metrics_history(timestamp DESC);
CREATE INDEX idx_metrics_history_device_id ON metrics_history(device_id);


-- Rollback log table
CREATE TABLE IF NOT EXISTS rollback_log (
    id SERIAL PRIMARY KEY,
    original_command_id VARCHAR(255) NOT NULL,
    rollback_command_id VARCHAR(255) NOT NULL,
    reason VARCHAR(500),
    status VARCHAR(50) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (original_command_id) REFERENCES command_audit(command_id)
);

CREATE INDEX idx_rollback_log_original_command ON rollback_log(original_command_id);

-- System events table for audit logging
CREATE TABLE IF NOT EXISTS system_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    event_source VARCHAR(100) NOT NULL,
    description TEXT,
    metadata JSONB,
    severity VARCHAR(20),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_system_events_timestamp ON system_events(timestamp DESC);
CREATE INDEX idx_system_events_event_type ON system_events(event_type);

-- Insert sample device data
INSERT INTO devices (device_id, location, zone, model, firmware_version) VALUES
    ('device-0001', 'Building-A-Floor-1', 'Production', 'IoT-Sensor-v2', '2.1.0'),
    ('device-0002', 'Building-A-Floor-2', 'Production', 'IoT-Sensor-v2', '2.1.0'),
    ('device-0003', 'Building-B-Floor-1', 'Testing', 'IoT-Sensor-v3', '3.0.1'),
    ('device-0004', 'Building-B-Floor-2', 'Testing', 'IoT-Sensor-v3', '3.0.1'),
    ('device-0005', 'Building-C-Floor-1', 'Development', 'IoT-Sensor-v1', '1.5.3')
ON CONFLICT (device_id) DO NOTHING;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_command_audit_updated_at BEFORE UPDATE ON command_audit
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions (adjust as needed)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO telemetry;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO telemetry;

-- Create views for common queries
CREATE OR REPLACE VIEW active_commands AS
SELECT * FROM command_audit
WHERE status IN ('PENDING', 'EXECUTING')
ORDER BY created_at DESC;

CREATE OR REPLACE VIEW recent_alerts AS
SELECT * FROM alerts
WHERE timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

CREATE OR REPLACE VIEW critical_alerts AS
SELECT * FROM alerts
WHERE severity = 'CRITICAL' AND resolved = FALSE
ORDER BY timestamp DESC;

-- Log initialization
INSERT INTO system_events (event_type, event_source, description, severity)
VALUES ('DATABASE_INIT', 'init.sql', 'Database initialized successfully', 'INFO');

-- Print success message
DO $$
BEGIN
    RAISE NOTICE 'Database initialization complete!';
    RAISE NOTICE 'Tables created: devices, command_audit, alerts, metrics_history, rollback_log, system_events';
    RAISE NOTICE 'Sample data inserted: 5 devices';
END $$;
