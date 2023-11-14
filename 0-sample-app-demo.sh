mvn clean install -DskipTests=true
java -Dspring.profiles.active=h2 -jar target/spring-petclinic-3.1.0-SNAPSHOT.jar
