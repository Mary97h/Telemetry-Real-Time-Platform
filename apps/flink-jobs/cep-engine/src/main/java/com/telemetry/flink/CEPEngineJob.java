package com.telemetry.flink;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.cep.CEP;
import org.apache.flink.cep.PatternSelectFunction;
import org.apache.flink.cep.PatternStream;
import org.apache.flink.cep.pattern.Pattern;
import org.apache.flink.cep.pattern.conditions.IterativeCondition;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.connector.kafka.source.reader.deserializer.KafkaRecordDeserializationSchema;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.flink.formats.avro.registry.confluent.ConfluentRegistryAvroDeserializationSchema;
import org.apache.flink.formats.avro.registry.confluent.ConfluentRegistryAvroSerializationSchema;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Properties;

public class CEPEngineJob {

    private static final String KAFKA_BOOTSTRAP = System.getenv("KAFKA_BOOTSTRAP_SERVERS");
    private static final String SCHEMA_REGISTRY = System.getenv("SCHEMA_REGISTRY_URL");

    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(60000);

        KafkaSource<AggregatedMetric> source = KafkaSource.<AggregatedMetric>builder()
                .setBootstrapServers(KAFKA_BOOTSTRAP)
                .setTopics("aggregated-metrics")
                .setGroupId("cep-engine")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setDeserializer(KafkaRecordDeserializationSchema.valueOnly(
                        ConfluentRegistryAvroDeserializationSchema.forSpecific(AggregatedMetric.class, SCHEMA_REGISTRY)))
                .build();

        DataStream<AggregatedMetric> stream = env.fromSource(source, WatermarkStrategy.forBoundedOutOfOrderness(Duration.ofSeconds(5))
                .withTimestampAssigner((event, timestamp) -> event.getTimestamp()), "Aggregated Source");

        Pattern<AggregatedMetric, ?> pattern = Pattern.<AggregatedMetric>begin("high")
                .where(new IterativeCondition<AggregatedMetric>() {
                    @Override
                    public boolean filter(AggregatedMetric value, Context<AggregatedMetric> ctx) throws Exception {
                        return value.getAvgMetrics().getOrDefault("latency", 0.0) > 80.0;
                    }
                })
                .followedBy("spike")
                .where(new IterativeCondition<AggregatedMetric>() {
                    @Override
                    public boolean filter(AggregatedMetric value, Context<AggregatedMetric> ctx) throws Exception {
                        return value.getAvgMetrics().getOrDefault("latency", 0.0) > 100.0;
                    }
                })
                .within(Time.seconds(10));

        PatternStream<AggregatedMetric> patternStream = CEP.pattern(stream.keyBy(m -> m.getDeviceId()), pattern);

        DataStream<Alert> alerts = patternStream.select(new PatternSelectFunction<AggregatedMetric, Alert>() {
            @Override
            public Alert select(Map<String, List<AggregatedMetric>> pattern) throws Exception {
                AggregatedMetric high = pattern.get("high").get(0);
                AggregatedMetric spike = pattern.get("spike").get(0);
                Alert alert = new Alert();
                alert.setAlertId(UUID.randomUUID().toString());
                alert.setAlertType("LATENCY_SPIKE");
                alert.setSeverity("HIGH");
                alert.setTimestamp(spike.getTimestamp());
                alert.setDeviceIds(Collections.singletonList(high.getDeviceId()));
                alert.setDescription("Latency spike detected after high value");
                return alert;
            }
        });

        Properties producerProps = new Properties();
        producerProps.setProperty("bootstrap.servers", KAFKA_BOOTSTRAP);
        FlinkKafkaProducer<Alert> kafkaSink = new FlinkKafkaProducer<>(
                "alerts",
                ConfluentRegistryAvroSerializationSchema.forSpecific(Alert.class, "alerts-value", SCHEMA_REGISTRY),
                producerProps,
                FlinkKafkaProducer.Semantic.EXACTLY_ONCE);

        alerts.addSink(kafkaSink);

        env.execute("Telemetry CEP Engine");
    }
}
