package com.telemetry.flink;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.FlatMapFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.jdbc.JdbcConnectionOptions;
import org.apache.flink.connector.jdbc.JdbcExecutionOptions;
import org.apache.flink.connector.jdbc.JdbcSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.connector.kafka.source.reader.deserializer.KafkaRecordDeserializationSchema;
import org.apache.flink.streaming.api.datastream.AsyncDataStream;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.async.AsyncFunction;
import org.apache.flink.streaming.api.functions.async.ResultFuture;
import org.apache.flink.streaming.api.functions.async.RichAsyncFunction;
import org.apache.flink.streaming.api.functions.ProcessFunction;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.flink.util.Collector;
import org.apache.avro.specific.SpecificRecord;
import org.apache.flink.formats.avro.AvroDeserializationSchema;
import org.apache.flink.formats.avro.registry.confluent.ConfluentRegistryAvroDeserializationSchema;
import io.confluent.kafka.schemaregistry.client.SchemaRegistryClient;
import io.confluent.kafka.schemaregistry.client.rest.exceptions.RestClientException;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Duration;
import java.util.Collections;
import java.util.Properties;
import java.util.concurrent.TimeUnit;

public class StreamProcessorJob {

    private static final String KAFKA_BOOTSTRAP = System.getenv("KAFKA_BOOTSTRAP_SERVERS");
    private static final String SCHEMA_REGISTRY = System.getenv("SCHEMA_REGISTRY_URL");
    private static final String POSTGRES_URL = "jdbc:postgresql://" + System.getenv("POSTGRES_HOST") + ":" + System.getenv("POSTGRES_PORT") + "/telemetry_db";
    private static final String REDIS_HOST = System.getenv("REDIS_HOST");
    private static final int REDIS_PORT = Integer.parseInt(System.getenv("REDIS_PORT"));
    private static final String S3_BUCKET = System.getenv("S3_BUCKET");
    private static final String S3_ENDPOINT = System.getenv("S3_ENDPOINT");

    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(60000);

        KafkaSource<Telemetry> source = KafkaSource.<Telemetry>builder()
                .setBootstrapServers(KAFKA_BOOTSTRAP)
                .setTopics("ingest-telemetry")
                .setGroupId("stream-processor")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setDeserializer(KafkaRecordDeserializationSchema.valueOnly(
                        ConfluentRegistryAvroDeserializationSchema.forSpecific(Telemetry.class, SCHEMA_REGISTRY)))
                .build();

        DataStream<Telemetry> telemetryStream = env.fromSource(source, WatermarkStrategy.forBoundedOutOfOrderness(Duration.ofSeconds(5))
                .withTimestampAssigner((event, timestamp) -> event.getTimestamp()), "Telemetry Source");

        DataStream<EnrichedTelemetry> enrichedStream = AsyncDataStream.unorderedWait(
                telemetryStream,
                new RedisEnrichFunction(),
                5000, TimeUnit.MILLISECONDS, 100);

        DataStream<ValidatedTelemetry> validatedStream = enrichedStream.process(new ValidationProcessFunction());

        Properties producerProps = new Properties();
        producerProps.setProperty("bootstrap.servers", KAFKA_BOOTSTRAP);
        FlinkKafkaProducer<ValidatedTelemetry> kafkaSink = new FlinkKafkaProducer<>(
                "processed-metrics",
                ConfluentRegistryAvroSerializationSchema.forSpecific(ValidatedTelemetry.class, "processed-metrics-value", SCHEMA_REGISTRY),
                producerProps,
                FlinkKafkaProducer.Semantic.EXACTLY_ONCE);

        validatedStream.addSink(kafkaSink);

        env.execute("Telemetry Stream Processor");
    }

    public static class RedisEnrichFunction extends RichAsyncFunction<Telemetry, EnrichedTelemetry> {
        private transient JedisPool jedisPool;

        @Override
        public void open(Configuration parameters) throws Exception {
            JedisPoolConfig poolConfig = new JedisPoolConfig();
            poolConfig.setMaxTotal(128);
            jedisPool = new JedisPool(poolConfig, REDIS_HOST, REDIS_PORT);
        }

        @Override
        public void asyncInvoke(Telemetry input, ResultFuture<EnrichedTelemetry> resultFuture) throws Exception {
            try (Jedis jedis = jedisPool.getResource()) {
                String features = jedis.get("features:" + input.getDeviceId());
                EnrichedTelemetry enriched = new EnrichedTelemetry(input);
                if (features != null) {
                    enriched.setFeatures(Json.parse(features));
                }
                resultFuture.complete(Collections.singleton(enriched));
            } catch (Exception e) {
                resultFuture.completeExceptionally(e);
            }
        }

        @Override
        public void close() throws Exception {
            if (jedisPool != null) {
                jedisPool.close();
            }
        }
    }

    public static class ValidationProcessFunction extends ProcessFunction<EnrichedTelemetry, ValidatedTelemetry> {
        @Override
        public void processElement(EnrichedTelemetry value, Context ctx, Collector<ValidatedTelemetry> out) throws Exception {
            boolean valid = true;
            for (Map.Entry<String, Double> metric : value.getMetrics().entrySet()) {
                if (metric.getValue() < 0 || metric.getValue() > 1000) {
                    valid = false;
                    break;
                }
            }
            ValidatedTelemetry validated = new ValidatedTelemetry(value);
            validated.setValid(valid);
            out.collect(validated);
        }
    }
}
