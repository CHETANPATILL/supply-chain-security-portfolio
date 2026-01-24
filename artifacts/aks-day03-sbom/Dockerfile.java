FROM maven:3.8-openjdk-11-slim AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:resolve

FROM eclipse-temurin:11-jre
WORKDIR /app
COPY --from=build /root/.m2/repository /root/.m2/repository
CMD ["java", "-version"]
