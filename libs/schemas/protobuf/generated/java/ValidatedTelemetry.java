package com.telemetry.avro;

import org.apache.avro.specific.SpecificRecordBase;
import org.apache.avro.specific.SpecificRecord;

public class ValidatedTelemetry extends SpecificRecordBase implements SpecificRecord {
  private String event_id;
  private String device_id;
  private long timestamp;
  private String sensor_type;
  private double value;
  private String unit;
  private DeviceMetadata device_metadata;
  private long processed_timestamp;
  private Double anomaly_score;
  private double quality_score;
  private boolean valid;
  // Getters/setters
}