# docs/api/grpc-api.md
# gRPC API Documentation

This document describes the gRPC API for the adaptive control loop, extending the REST API for lower-latency or streaming use cases.

## Service Definition
```proto
syntax = "proto3";

package telemetry.control;

option go_package = "github.com/yourorg/telemetry/proto/control";

service ControlService {
  rpc SendCommand(ControlCommand) returns (CommandResponse);
  rpc GetCommandStatus(CommandStatusRequest) returns (CommandStatus);
  rpc StreamAlerts(AlertStreamRequest) returns (stream Alert);
  // Add more endpoints as needed
}

message ControlCommand {
  string command_id = 1;
  string target_id = 2;
  string command_type = 3;
  map<string, string> parameters = 4;
  string priority = 5;
  google.protobuf.Timestamp expiry = 6;
  RollbackConfig rollback_config = 7;
  bool dry_run = 8;
}

message RollbackConfig {
  bool enabled = 1;
  int32 timeout_seconds = 2;
  map<string, string> previous_state = 3;
}

message CommandResponse {
  string command_id = 1;
  string status = 2;
}

message CommandStatusRequest {
  string command_id = 1;
}

message CommandStatus {
  string command_id = 1;
  string status = 2;
  google.protobuf.Timestamp created_at = 3;
  google.protobuf.Timestamp updated_at = 4;
  map<string, string> result = 5;
}

message AlertStreamRequest {
  string severity = 1;
  int32 limit = 2;
}

message Alert {
  string alert_id = 1;
  string alert_type = 2;
  string severity = 3;
  google.protobuf.Timestamp timestamp = 4;
  repeated string device_ids = 5;
  string title = 6;
  string description = 7;
  map<string, string> metadata = 8;
}