# Dockerfile for cep-engine
FROM flink:1.18-scala_2.12-java11

# Set working directory
WORKDIR /opt/flink

# Copy application JAR
COPY target/cep-engine-1.0.0.jar /opt/flink/usrlib/cep-engine.jar

# Copy Flink configuration
COPY conf/flink-conf.yaml /opt/flink/conf/

# Set environment variables
ENV FLINK_PROPERTIES="jobmanager.rpc.address: flink-jobmanager"

# Expose ports
EXPOSE 6123 8081

# Default command
CMD ["standalone-job", "--job-classname", "com.telemetry.flink.CEPEngineJob"]