package com.telemetry.common;

import org.apache.avro.generic.GenericRecord;
import java.util.Map;

public class EventUtils {
  public static long extractTimestamp(GenericRecord record) {
    return (long) record.get("timestamp");
  }

  public static Map<String, Double> getMetrics(GenericRecord record) {
    return (Map<String, Double>) record.get("metrics");
  }

  // Other utility methods for event handling
}