# =========================
# Stage 1: Build
# =========================
FROM maven:3.9.9-eclipse-temurin-11 AS builder

WORKDIR /build

# Copy entire Jenkins context
COPY . .

# Find where pom.xml actually is (debug-safe)
RUN find . -name pom.xml

# Move into the directory that contains pom.xml
WORKDIR /build/workspace/*

# Verify
RUN ls -l && test -f pom.xml

# Build
RUN mvn clean install -DskipTests

# =========================
# Stage 2: Runtime
# =========================
FROM eclipse-temurin:11-jre

WORKDIR /usr/src/app

COPY --from=builder /build/workspace/*/target/*.jar app.jar

EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
