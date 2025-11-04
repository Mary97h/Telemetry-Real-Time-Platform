package com.telemetry.avro;

import org.apache.avro.specific.SpecificRecordBase;
import org.apache.avro.specific.SpecificRecord;

public class EnrichedEvent extends SpecificRecordBase implements SpecificRecord {
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

  public String getEventId() {
    return event_id;
  }

  public void setEventId(String event_id) {
    this.event_id = event_id;
  }

  public String getDeviceId() {
    return device_id;
  }

  public void setDeviceId(String device_id) {
    this.device_id = device_id;
  }

  public long getTimestamp() {
    return timestamp;
  }

  public void setTimestamp(long timestamp) {
    this.timestamp = timestamp;
  }

  public String getSensorType() {
    return sensor_type;
  }

  public void setSensorType(String sensor_type) {
    this.sensor_type = sensor_type;
  }

  public double getValue() {
    return value;
  }

  public void setValue(double value) {
    this.value = value;
  }

  public String getUnit() {
    return unit;
  }

  public void setUnit(String unit) {
    this.unit = unit;
  }

  public DeviceMetadata getDeviceMetadata() {
    return device_metadata;
  }

  public void setDeviceMetadata(DeviceMetadata device_metadata) {
    this.device_metadata = device_metadata;
  }

  public long getProcessedTimestamp() {
    return processed_timestamp;
  }

  public void setProcessedTimestamp(long processed_timestamp) {
    this.processed_timestamp = processed_timestamp;
  }

  public Double getAnomalyScore() {
    return anomaly_score;
  }

  public void setAnomalyScore(Double anomaly_score) {
    this.anomaly_score = anomaly_score;
  }

  public double getQualityScore() {
    return quality_score;
  }

  public void setQualityScore(double quality_score) {
    this.quality_score = quality_score;
  }
}