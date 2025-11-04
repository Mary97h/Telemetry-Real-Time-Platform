package com.telemetry.flink;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.AggregateFunction;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.connector.kafka.source.reader.deserializer.KafkaRecordDeserializationSchema;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.assigners.TumblingEventTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaProducer;
import org.apache.flink.formats.avro.registry.confluent.ConfluentRegistryAvroDeserializationSchema;
import org.apache.flink.formats.avro.registry.confluent.ConfluentRegistryAvroSerializationSchema;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

public class AggregatorJob {

    private static final String KAFKA_BOOTSTRAP = System.getenv("KAFKA_BOOTSTRAP_SERVERS");
    private static final String SCHEMA_REGISTRY = System.getenv("SCHEMA_REGISTRY_URL");

    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(60000);

        KafkaSource<ValidatedTelemetry> source = KafkaSource.<ValidatedTelemetry>builder()
                .setBootstrapServers(KAFKA_BOOTSTRAP)
                .setTopics("processed-metrics")
                .setGroupId("aggregator")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setDeserializer(KafkaRecordDeserializationSchema.valueOnly(
                        ConfluentRegistryAvroDeserializationSchema.forSpecific(ValidatedTelemetry.class, SCHEMA_REGISTRY)))
                .build();

        DataStream<ValidatedTelemetry> stream = env.fromSource(source, WatermarkStrategy.forBoundedOutOfOrderness(Duration.ofSeconds(5))
                .withTimestampAssigner((event, timestamp) -> event.getTimestamp()), "Processed Source");

        DataStream<AggregatedMetric> aggregated = stream
                .keyBy(t -> t.getDeviceId())
                .window(TumblingEventTimeWindows.of(Time.seconds(5)))
                .aggregate(new MetricAggregator());

        Properties producerProps = new Properties();
        producerProps.setProperty("bootstrap.servers", KAFKA_BOOTSTRAP);
        FlinkKafkaProducer<AggregatedMetric> kafkaSink = new FlinkKafkaProducer<>(
                "aggregated-metrics",
                ConfluentRegistryAvroSerializationSchema.forSpecific(AggregatedMetric.class, "aggregated-metrics-value", SCHEMA_REGISTRY),
                producerProps,
                FlinkKafkaProducer.Semantic.EXACTLY_ONCE);

        aggregated.addSink(kafkaSink);

        env.execute("Telemetry Aggregator");
    }

    public static class MetricAggregator implements AggregateFunction<ValidatedTelemetry, Map<String, Double[]>, AggregatedMetric> {
        @Override
        public Map<String, Double[]> createAccumulator() {
            return new HashMap<>();
        }

        @Override
        public Map<String, Double[]> add(ValidatedTelemetry value, Map<String, Double[]> accumulator) {
            for (Map.Entry<String, Double> entry : value.getMetrics().entrySet()) {
                Double[] stats = accumulator.getOrDefault(entry.getKey(), new Double[]{0.0, 0.0});
                stats[0] += entry.getValue();
                stats[1] += 1;
                accumulator.put(entry.getKey(), stats);
            }
            return accumulator;
        }

        @Override
        public AggregatedMetric getResult(Map<String, Double[]> accumulator) {
            AggregatedMetric agg = new AggregatedMetric();
            Map<String, Double> avgs = new HashMap<>();
            for (Map.Entry<String, Double[]> entry : accumulator.entrySet()) {
                avgs.put(entry.getKey(), entry.getValue()[0] / entry.getValue()[1]);
            }
            agg.setAvgMetrics(avgs);
            return agg;
        }

        @Override
        public Map<String, Double[]> merge(Map<String, Double[]> a, Map<String, Double[]> b) {
            return a;
        }
    }
}
