# =========================
# Runtime Image ONLY
# =========================
FROM eclipse-temurin:17-jre

WORKDIR /usr/src/app

# Copy the jar built by Jenkins
COPY target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
