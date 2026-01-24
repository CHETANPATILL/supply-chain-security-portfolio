FROM maven:3.8-openjdk-11 as build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline

FROM adoptopenjdk/openjdk11:jdk-11.0.11_9-alpine-slim
WORKDIR /app
COPY --from=build /root/.m2 /root/.m2
CMD ["java", "-version"]
