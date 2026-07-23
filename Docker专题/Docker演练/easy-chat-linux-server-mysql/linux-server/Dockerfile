ARG JAVA_IMAGE=eclipse-temurin:21-jre
FROM ${JAVA_IMAGE}

WORKDIR /app

COPY linux-server-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8081

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
