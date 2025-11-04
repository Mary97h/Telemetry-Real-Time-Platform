#!/bin/bash
# Schema compilation script for Avro and Protobuf

set -e

echo "Compiling Avro schemas..."

# Create output directories
mkdir -p avro/generated/java
mkdir -p avro/generated/python
mkdir -p protobuf/generated/java
mkdir -p protobuf/generated/python
mkdir -p protobuf/generated/go

# Compile Avro schemas to Java
echo "Generating Java classes from Avro schemas..."
for schema in avro/*.avsc; do
    java -jar /opt/avro-tools.jar compile schema "$schema" avro/generated/java/
done

# Compile Avro schemas to Python (using avro-python3)
echo "Generating Python classes from Avro schemas..."
python3 -m avro.codegen avro/*.avsc avro/generated/python/

# Compile Protobuf schemas
echo "Generating code from Protobuf schemas..."
if [ -d "protobuf" ]; then
    # Java
    protoc --java_out=protobuf/generated/java/ protobuf/*.proto
    
    # Python
    python -m grpc_tools.protoc -I protobuf/ \
        --python_out=protobuf/generated/python/ \
        --grpc_python_out=protobuf/generated/python/ \
        protobuf/*.proto
    
    # Go
    protoc --go_out=protobuf/generated/go/ \
        --go-grpc_out=protobuf/generated/go/ \
        protobuf/*.proto
fi

echo "Schema compilation complete!"
echo "Java classes: avro/generated/java/"
echo "Python modules: avro/generated/python/"
