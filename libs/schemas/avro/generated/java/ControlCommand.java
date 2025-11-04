package com.telemetry.avro;

import org.apache.avro.specific.SpecificRecordBase;
import org.apache.avro.specific.SpecificRecord;
import java.util.Map;

public class ControlCommand extends SpecificRecordBase implements SpecificRecord {
  private String command_id;
  private String target_id;
  private CommandType command_type;
  private Map<String, String> parameters;
  private long timestamp;
  private Long expiry;
  private Priority priority;
  private RollbackConfig rollback_config;
  private boolean dry_run;

  public String getCommandId() {
    return command_id;
  }

  public void setCommandId(String command_id) {
    this.command_id = command_id;
  }

  public String getTargetId() {
    return target_id;
  }

  public void setTargetId(String target_id) {
    this.target_id = target_id;
  }

  public CommandType getCommandType() {
    return command_type;
  }

  public void setCommandType(CommandType command_type) {
    this.command_type = command_type;
  }

  public Map<String, String> getParameters() {
    return parameters;
  }

  public void setParameters(Map<String, String> parameters) {
    this.parameters = parameters;
  }

  public long getTimestamp() {
    return timestamp;
  }

  public void setTimestamp(long timestamp) {
    this.timestamp = timestamp;
  }

  public Long getExpiry() {
    return expiry;
  }

  public void setExpiry(Long expiry) {
    this.expiry = expiry;
  }

  public Priority getPriority() {
    return priority;
  }

  public void setPriority(Priority priority) {
    this.priority = priority;
  }

  public RollbackConfig getRollbackConfig() {
    return rollback_config;
  }

  public void setRollbackConfig(RollbackConfig rollback_config) {
    this.rollback_config = rollback_config;
  }

  public boolean isDryRun() {
    return dry_run;
  }

  public void setDryRun(boolean dry_run) {
    this.dry_run = dry_run;
  }
}