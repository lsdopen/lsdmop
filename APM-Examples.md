
# Monitor Spring Boot Application Performance with Elastic APM Java Agent




## Spring Boot Application

The Java application which will be monitored is a Spring Boot 2 application. Using Spring Boot we’re going to create a simple REST api for users that are stored in a MYSQL database, the api will provide simple CRUD operations for users data.

Besides the REST api, the application will have some scheduled backgrounds tasks. These tasks do not have any functionalities, they are built only to show how we can monitor background tasks using APM agent pulbic API.

REST endpoints

- GET `/api/v1/users/{userId}` \- Returns an user with a specific ID or 404 if no user was found
- POST `/api/v1/users` \- Creates a new user. Request body sample: `{"name":"Cosmin Seceleanu","email":"test@email.com"}`
- DELETE `/api/v1/users/{userId}` \- Deletes an user with a specific userid or returns 404 if user does not exists

## Deploy services

1.  `git clone [https://github.com/cosminseceleanu/tutorials.git](https://github.com/cosminseceleanu/tutorials.git)`
2.  `cd tutorials/elastic-apm-java`
3.  `mvn package` \- build Spring Boot jar file
4.  Build and start containers using `docker-compose -f docker/docker-compose.yml up -d`
5.  Checking containers status using `docker-compose -f docker/docker-compose.yml ps` and you should have 5 containers: Elasticsearch, MySQL, Kibana, APM server and the java service

Docker services

If APM Server service doesn’t start, it’s because it uses Elasticsearch and Elasticsearch take some time to start. To solve this, just restart some containers using this command: `docker-compose -f docker/docker-compose.yml restart apm user-microservice` .

### Spring Boot Service Dockerfile

```
FROM openjdk:8-jdkEXPOSE 8080RUN mkdir -p /opt/appWORKDIR /opt/appARG JAR_PATHCOPY $JAR_PATH /opt/appRUN wget -O apm-agent.jar https://search.maven.org/remotecontent?filepath=co/elastic/apm/elastic-apm-agent/1.2.0/elastic-apm-agent-1.2.0.jarCMD java -javaagent:/opt/app/apm-agent.jar $JVM_OPTIONS -jar $JAR_NAME
```

## Monitor Application

What will we monitor?

1.  Time for incoming http requests
2.  Throughput
3.  Time for MySQL queries
4.  Using APM agent public api we will monitor time for some custom code and a background task

To have some metrics we need to call our REST service, we can do this using the `curl` command. If you want to execute a large number of request you can use this tools:

- [Apache Bench](https://httpd.apache.org/docs/2.4/programs/ab.html)
- [Apache JMeter](https://jmeter.apache.org/)

For the next metrics that I will show you I am going to execute the following curl commands:

- curl -X POST [http://localhost:8080/api/v1/users](http://localhost:8080/api/v1/users) -H “Content-Type: application/json” -d ‘{“name”:”Cosmin Seceleanu”,”email”:”[cosmin.seceleanu@email.com](mailto:cosmin.seceleanu@email.com)”}’
- curl -X POST [http://localhost:8080/api/v1/users](http://localhost:8080/api/v1/users) -H “Content-Type: application/json” -d ‘{“name”:”Foo Bar”,”email”:”[foo@bar.com](mailto:foo@bar.com)”}’
- curl -X GET [http://localhost:8080/api/v1/users/1](http://localhost:8080/api/v1/users/1)
- curl -X GET [http://localhost:8080/api/v1/users/2](http://localhost:8080/api/v1/users/2)
- curl -X DELETE [http://localhost:8080/api/v1/users/2](http://localhost:8080/api/v1/users/2)
- curl -X GET [http://localhost:8080/api/v1/users/1](http://localhost:8080/api/v1/users/1)
- curl -X GET [http://localhost:8080/api/v1/users/1](http://localhost:8080/api/v1/users/1)
- curl -X GET [http://localhost:8080/api/v1/users/2](http://localhost:8080/api/v1/users/2)

After you execute some HTTP requests, you can use Kibana by accessing [http://localhost:5601](http://localhost:5601/) and under the APM tab, you should see a list of services(agents) with some summary performance metrics.


```
package com.cosmin.tutorials.apm.service;import co.elastic.apm.api.CaptureSpan;import com.cosmin.tutorials.apm.database.User;import com.cosmin.tutorials.apm.database.UserRepository;import org.slf4j.Logger;import org.slf4j.LoggerFactory;import org.springframework.beans.factory.annotation.Autowired;import org.springframework.stereotype.Service;import java.util.Optional;import java.util.Random;@Servicepublic class UserService {    private final static Logger logger = LoggerFactory.getLogger(UserService.class);    private UserRepository userRepository;    @Autowired    public UserService(UserRepository userRepository) {        this.userRepository = userRepository;    }    public User save(User user) {        sleep();        return userRepository.save(user);    }    public Optional<User> get(Integer id) {        sleep();        return userRepository.findById(id);    }    public void delete(Integer id) {        sleep();        userRepository.deleteById(id);    }    @CaptureSpan("otherOperations")    private void sleep() {        try {            Random random = new Random();            int milis = random.nextInt(100 - 20 + 1) + 20;            logger.info(String.format("Sleep ---> %s ms", milis));            Thread.sleep(milis);        } catch (Exception e) {           logger.error(e.getMessage(), e);        }    }}
```

The performance metrics about tasks are generated using agent public Api, but this time we need to generate the transaction by using the annotation `@CaptureTransaction` as you can see in the bellow Java code:

```
package com.cosmin.tutorials.apm.tasks;import co.elastic.apm.api.CaptureSpan;import co.elastic.apm.api.CaptureTransaction;import com.cosmin.tutorials.apm.database.UserRepository;import org.slf4j.Logger;import org.slf4j.LoggerFactory;import org.springframework.beans.factory.annotation.Autowired;import org.springframework.scheduling.annotation.Scheduled;import org.springframework.stereotype.Service;import java.util.Random;@Servicepublic class PrintUsersTask {    private final static Logger logger = LoggerFactory.getLogger(PrintUsersTask.class);    private UserRepository userRepository;    @Autowired    public PrintUsersTask(UserRepository userRepository) {        this.userRepository = userRepository;    }    @Scheduled(fixedDelayString = "5000")    public void execute() {        logger.info("run scheduled test");        doExecute();    }    @CaptureTransaction(type = "Task", value = "PrintUsers")    private void doExecute() {        userRepository.findAll().forEach(user-> logger.debug(user.getEmail()));        sleep();    }    @CaptureSpan("someCustomOperation")    private void sleep() {        try {            Random random = new Random();            int milis = random.nextInt(120 - 20 + 1) + 20;            Thread.sleep(milis);        } catch (Exception e) {            logger.error(e.getMessage(), e);        }    }}
```



# .NET Core App running on Kubernetes

```RUN curl -L -o ElasticApmAgent_1.18.0.zip https://github.com/elastic/apm-agent-dotnet/releases/download/v1.18.0/ElasticApmAgent_1.18.0.zip && \
unzip ElasticApmAgent_1.18.0.zip -d /ElasticApmAgent

ENV DOTNET_STARTUP_HOOKS=/ElasticApmAgent/ElasticApmAgentStartupHook.dll



```
