package com.telemetry.avro;
import org.apache.avro.specific.SpecificRecordBase;
import org.apache.avro.specific.SpecificRecord;
import java.util.Map;

public class AggregatedMetric extends SpecificRecordBase implements SpecificRecord {
  private String device_id;
  private long timestamp;
  private long window_start;
  private long window_end;
  private Map<String, Double> avg_metrics;
  private Map<String, Double> min_metrics;
  private Map<String, Double> max_metrics;
  private long count;
 

    // Getters/setters
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

    public long getWindowStart() {
        return window_start;
    }

    public void setWindowStart(long window_start) {
        this.window_start = window_start;
    }

    public long getWindowEnd() {
        return window_end;
    }

    public void setWindowEnd(long window_end) {
        this.window_end = window_end;
    }

    public Map<String, Double> getAvgMetrics() {
        return avg_metrics;
    }

    public void setAvgMetrics(Map<String, Double> avg_metrics) {
        this.avg_metrics = avg_metrics;
    }

    public Map<String, Double> getMinMetrics() {
        return min_metrics;
    }

    public void setMinMetrics(Map<String, Double> min_metrics) {
        this.min_metrics = min_metrics;
    }

    public Map<String, Double> getMaxMetrics() {
        return max_metrics;
    }

    public void setMaxMetrics(Map<String, Double> max_metrics) {
        this.max_metrics = max_metrics;
    }

    public long getCount() {
        return count;
    }

    public void setCount(long count) {
        this.count = count;
    }
    
}