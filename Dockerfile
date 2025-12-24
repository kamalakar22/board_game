# =========================
# Stage 1: Build
# =========================
FROM maven:3.9.9-eclipse-temurin-11 AS builder

WORKDIR /build

# Copy everything from Jenkins context
COPY . .

# Move into actual Jenkins workspace (IMPORTANT)
WORKDIR /build/workspace

# Optional: show files for debug (can remove later)
RUN ls -l

# Build
RUN mvn clean install -DskipTests

# =========================
# Stage 2: Runtime
# =========================
FROM eclipse-temurin:11-jre

ENV APP_HOME=/usr/src/app
WORKDIR $APP_HOME

COPY --from=builder /build/workspace/target/*.jar app.jar

EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
