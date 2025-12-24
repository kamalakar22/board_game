# =========================
# Stage 1: Build
# =========================
FROM maven:3.9.9-eclipse-temurin-11 AS builder

WORKDIR /build

# Copy ALL project files
COPY . .

# Build application (NO sonar here)
RUN mvn clean install 

# =========================
# Stage 2: Runtime
# =========================
FROM eclipse-temurin:11-jre

ENV APP_HOME=/usr/src/app
WORKDIR $APP_HOME

# Copy only the built JAR from builder stage
COPY --from=builder /build/target/*.jar app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
