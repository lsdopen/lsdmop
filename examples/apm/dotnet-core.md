
# .NET Core App running on Kubernetes

```RUN curl -L -o ElasticApmAgent_1.18.0.zip https://github.com/elastic/apm-agent-dotnet/releases/download/v1.18.0/ElasticApmAgent_1.18.0.zip && \
unzip ElasticApmAgent_1.18.0.zip -d /ElasticApmAgent

ENV DOTNET_STARTUP_HOOKS=/ElasticApmAgent/ElasticApmAgentStartupHook.dll
```


==== General steps

The general steps in configuring profiler auto instrumentation are as follows; 
See <<instrumenting-containers-and-services>> for configuration for common deployment environments.

. Download the `elastic_apm_profiler_<version>.zip` file from the https://github.com/elastic/apm-agent-dotnet/releases[Releases] page of the .NET APM Agent GitHub repository, where `<version>` is the version number to download. You can find the file under Assets.
. Unzip the zip file into a folder on the host that is hosting the application to instrument.
. Configure the following environment variables
+
.{dot}NET Framework
[source,sh]
----
set COR_ENABLE_PROFILING = "1"
set COR_PROFILER = "{FA65FE15-F085-4681-9B20-95E04F6C03CC}"
set COR_PROFILER_PATH = "<unzipped directory>\elastic_apm_profiler.dll" <1>
set ELASTIC_APM_PROFILER_HOME = "<unzipped directory>"
set ELASTIC_APM_PROFILER_INTEGRATIONS = "<unzipped directory>\integrations.yml"
----
<1> `<unzipped directory>` is the directory to which the zip file
was unzipped in step 2.
+
.{dot}NET Core / .NET 5+ on Windows
[source,sh]
----
set CORECLR_ENABLE_PROFILING = "1"
set CORECLR_PROFILER = "{FA65FE15-F085-4681-9B20-95E04F6C03CC}"
set CORECLR_PROFILER_PATH = "<unzipped directory>\elastic_apm_profiler.dll" <1>
set ELASTIC_APM_PROFILER_HOME = "<unzipped directory>"
set ELASTIC_APM_PROFILER_INTEGRATIONS = "<unzipped directory>\integrations.yml"
----
<1> `<unzipped directory>` is the directory to which the zip file
was unzipped in step 2.
+
.{dot}NET Core / .NET 5+ on Linux
[source,sh]
----
export CORECLR_ENABLE_PROFILING=1
export CORECLR_PROFILER={FA65FE15-F085-4681-9B20-95E04F6C03CC}
export CORECLR_PROFILER_PATH="<unzipped directory>/libelastic_apm_profiler.so" <1>
export ELASTIC_APM_PROFILER_HOME="<unzipped directory>"
export ELASTIC_APM_PROFILER_INTEGRATIONS="<unzipped directory>/integrations.yml"
----

NOTE: In most cases you want to specify a server URL and a secret token to connect to an APM Server. For a profiler based setup, every agent configuration can be specified by environment variables. The specific name for an environment variable can be found on the <<configuration, general configuration>> page. E.g. you can specify the <<config-server-url,server URL>> by `ELASTIC_APM_SERVER_URL` and the <<config-secret-token, secret token>> by `ELASTIC_APM_SECRET_TOKEN`.

<1> `<unzipped directory>` is the directory to which the zip file
was unzipped in step 2.
. Start your application in a context where the set environment variables are visible.

With this setup, the .NET runtime loads Elastic's CLR profiler into the .NET process, which loads and instantiates the APM agent early 
in application startup. The profiler monitors methods of interest and injects code to instrument their execution.

=== Instrumenting containers and services

Using global environment variables causes profiler auto instrumentation to be loaded for **any** .NET process started on the
host. Often, the environment variables should be set only for specific services or containers. The following sections demonstrate how to configure common containers and services.

[float]
==== Docker containers

A build image containing the files for profiler auto instrumentation
can be used as part of a https://docs.docker.com/develop/develop-images/multistage-build/[multi-stage build]

[source,sh]
----
ARG AGENT_VERSION=1.19.0

FROM alpine:latest AS build
ARG AGENT_VERSION
WORKDIR /source

# install unzip
RUN apk update && apk add zip curl

# pull down the zip file based on ${AGENT_VERSION} ARG and unzip
RUN curl -L -o elastic_apm_profiler_${AGENT_VERSION}.zip https://github.com/elastic/apm-agent-dotnet/releases/download/v${AGENT_VERSION}/elastic_apm_profiler_${AGENT_VERSION}.zip && \ 
    unzip elastic_apm_profiler_${AGENT_VERSION}.zip -d /elastic_apm_profiler_${AGENT_VERSION}
----

The files can then be copied into a subsequent stage

[source,sh]
----
COPY --from=build /elastic_apm_profiler_${AGENT_VERSION} /elastic_apm_profiler
----

Environment variables can be added to a Dockerfile to configure profiler auto instrumentation

[source,sh]
----
ENV CORECLR_ENABLE_PROFILING=1
ENV CORECLR_PROFILER={FA65FE15-F085-4681-9B20-95E04F6C03CC}
ENV CORECLR_PROFILER_PATH=/elastic_apm_profiler/libelastic_apm_profiler.so
ENV ELASTIC_APM_PROFILER_HOME=/elastic_apm_profiler
ENV ELASTIC_APM_PROFILER_INTEGRATIONS=/elastic_apm_profiler/integrations.yml

ENTRYPOINT ["dotnet", "your-application.dll"]
----

[float]
==== Windows services

Environment variables can be added to specific Windows services by
adding an entry to the Windows registry. Using PowerShell

.{dot}NET Framework service
[source,powershell]
----
$environment = [string[]]@(
  "COR_ENABLE_PROFILING=1", 
  "COR_PROFILER={FA65FE15-F085-4681-9B20-95E04F6C03CC}",
  "COR_PROFILER_PATH=<unzipped directory>\elastic_apm_profiler.dll",
  "ELASTIC_APM_PROFILER_HOME=<unzipped directory>",
  "ELASTIC_APM_PROFILER_INTEGRATIONS=<unzipped directory>\integrations.yml")

Set-ItemProperty HKLM:SYSTEM\CurrentControlSet\Services\<service-name> -Name Environment -Value $environment
----

.{dot}NET Core service
[source,powershell]
----
$environment = [string[]]@(
  "CORECLR_ENABLE_PROFILING=1", 
  "CORECLR_PROFILER={FA65FE15-F085-4681-9B20-95E04F6C03CC}",
  "CORECLR_PROFILER_PATH=<unzipped directory>\elastic_apm_profiler.dll", <1>
  "ELASTIC_APM_PROFILER_HOME=<unzipped directory>",
  "ELASTIC_APM_PROFILER_INTEGRATIONS=<unzipped directory>\integrations.yml")

Set-ItemProperty HKLM:SYSTEM\CurrentControlSet\Services\<service-name> -Name Environment -Value $environment <2>
----
<1> `<unzipped directory>` is the directory to which the zip file
was unzipped
<2> `<service-name>` is the name of the Windows service.

The service must then be restarted for the change to take effect. With PowerShell

[source,powershell]
----
Restart-Service <service-name>
----

[float]
==== Internet Information Services (IIS)

For IIS versions _before_ IIS 10, it is **not** possible to set environment variables scoped to a specific application pool, so environment variables
need to set globally.

For IIS 10 _onwards_, environment variables can be set for an application
pool using https://docs.microsoft.com/en-us/iis/get-started/getting-started-with-iis/getting-started-with-appcmdexe[AppCmd.exe]. With PowerShell

.{dot}NET Framework
[source,powershell]
----
$appcmd = "$($env:systemroot)\system32\inetsrv\AppCmd.exe"
$appPool = "<application-pool>" <1>
$profilerHomeDir = "<unzipped directory>" <2>
$environment = @{
  COR_ENABLE_PROFILING = "1"
  COR_PROFILER = "{FA65FE15-F085-4681-9B20-95E04F6C03CC}"
  COR_PROFILER_PATH = "$profilerHomeDir\elastic_apm_profiler.dll"
  ELASTIC_APM_PROFILER_HOME = "$profilerHomeDir"
  ELASTIC_APM_PROFILER_INTEGRATIONS = "$profilerHomeDir\integrations.yml"
  COMPlus_LoaderOptimization = "1" <3>
}

$environment.Keys | ForEach-Object {
  & $appcmd set config -section:system.applicationHost/applicationPools /+"[name='$appPool'].environmentVariables.[name='$_',value='$($environment[$_])']"  
}
----
<1> `<application-pool>` is the name of the Application Pool your application uses. For example, `IIS APPPOOL\DefaultAppPool`
<2> `<unzipped directory>` is the full path to the directory in which the zip file
was unzipped
<3> Forces assemblies **not** to be loaded domain-neutral. There is currently a limitation
where Profiler auto-instrumentation cannot instrument assemblies when they are loaded
domain-neutral. This limitation is expected to be removed in future, but for now, can be worked
around by setting this environment variable. See the https://docs.microsoft.com/en-us/dotnet/framework/app-domains/application-domains#the-complus_loaderoptimization-environment-variable[Microsoft documentation for further details].

.{dot}NET Core
[source,powershell]
----
$appcmd = "$($env:systemroot)\system32\inetsrv\AppCmd.exe"
$appPool = "<application-pool>" <1>
$profilerHomeDir = "<unzipped directory>" <2>
$environment = @{
  CORECLR_ENABLE_PROFILING = "1"
  CORECLR_PROFILER = "{FA65FE15-F085-4681-9B20-95E04F6C03CC}"
  CORECLR_PROFILER_PATH = "$profilerHomeDir\elastic_apm_profiler.dll"
  ELASTIC_APM_PROFILER_HOME = "$profilerHomeDir"
  ELASTIC_APM_PROFILER_INTEGRATIONS = "$profilerHomeDir\integrations.yml"
}

$environment.Keys | ForEach-Object {
  & $appcmd set config -section:system.applicationHost/applicationPools /+"[name='$appPool'].environmentVariables.[name='$_',value='$($environment[$_])']"  
}
----
<1> `<application-pool>` is the name of the Application Pool your application uses. For example, `IIS APPPOOL\DefaultAppPool`
<2> `<unzipped directory>` is the full path to the directory in which the zip file
was unzipped

[IMPORTANT]
--
Ensure that the location of the `<unzipped directory>` is accessible and executable to the https://docs.microsoft.com/en-us/iis/manage/configuring-security/application-pool-identities[Identity
account under which the Application Pool runs].
--

Once environment variables have been set, stop and start IIS so that applications hosted in
IIS will see the new environment variables

[source,sh]
----
net stop /y was
net start w3svc
----

[float]
==== systemd / systemctl

Environment variables can be added to specific services run with systemd
by creating an environment.env file containing the following

[source,sh]
----
CORECLR_ENABLE_PROFILING=1
CORECLR_PROFILER={FA65FE15-F085-4681-9B20-95E04F6C03CC}
CORECLR_PROFILER_PATH=/<unzipped directory>/libelastic_apm_profiler.so <1>
ELASTIC_APM_PROFILER_HOME=/<unzipped directory>
ELASTIC_APM_PROFILER_INTEGRATIONS=/<unzipped directory>/integrations.yml
----
<1> `<unzipped directory>` is the directory to which the zip file
was unzipped

Then adding an https://www.freedesktop.org/software/systemd/man/systemd.service.html#Command%20lines[`EnvironmentFile`] entry to the service's configuration file
that references the path to the environment.env file

[source,sh]
----
[Service]
EnvironmentFile=/path/to/environment.env
ExecStart=<command> <1>
----
<1> the command that starts your service

After adding the `EnvironmentFile` entry, restart the service

[source,sh]
----
systemctl reload-or-restart <service>
----

[float]
[[profiler-configuration]]
=== Profiler environment variables

The profiler auto instrumentation has its own set of environment variables to manage
the instrumentation. These are used in addition to <<configuration, agent configuration>> 
through environment variables.


`ELASTIC_APM_PROFILER_HOME`::

The home directory of the profiler auto instrumentation. The home directory typically 
contains 

* platform specific profiler assemblies
* a directory for each compatible target framework, where each directory contains
supporting managed assemblies for auto instrumentation.
* an integrations.yml file that determines which methods to target for
auto instrumentation

`ELASTIC_APM_PROFILER_INTEGRATIONS` _(optional)_::

The path to the integrations.yml file that determines which methods to target for
auto instrumentation. If not specified, the profiler will assume an
integrations.yml exists in the home directory specified by `ELASTIC_APM_PROFILER_HOME`
environment variable.

`ELASTIC_APM_PROFILER_EXCLUDE_INTEGRATIONS` _(optional)_::

A semi-colon separated list of integrations to exclude from auto-instrumentation.
Valid values are those defined in the `Integration name` column in the integrations
table above.

`ELASTIC_APM_PROFILER_EXCLUDE_PROCESSES` _(optional)_::

A semi-colon separated list of process names to exclude from auto-instrumentation.
For example, `dotnet.exe;powershell.exe`. Can be used in scenarios where profiler
environment variables have a global scope that would end up auto-instrumenting
applications that should not be.

`ELASTIC_APM_PROFILER_EXCLUDE_SERVICE_NAMES` _(optional)_::

A semi-colon separated list of APM service names to exclude from auto-instrumentation.
Values defined are checked against the value of <<config-service-name,`ELASTIC_APM_SERVICE_NAME`>>
environment variable.

`ELASTIC_APM_PROFILER_LOG` _(optional)_::

The log level at which the profiler should log. Valid values are

* trace
* debug
* info
* warn
* error
* none

The default value is `warn`. More verbose log levels like `trace` and `debug` can
affect the runtime performance of profiler auto instrumentation, so are recommended
_only_ for diagnostics purposes.

`ELASTIC_APM_PROFILER_LOG_DIR` _(optional)_::

The directory in which to write profiler log files. If unset, defaults to

* `%PROGRAMDATA%\elastic\apm-agent-dotnet\logs` on Windows
* `/var/log/elastic/apm-agent-dotnet` on Linux

If the default directory cannot be written to for some reason, the profiler
will try to write log files to a `logs` directory in the home directory specified 
by `ELASTIC_APM_PROFILER_HOME` environment variable.

`ELASTIC_APM_PROFILER_LOG_TARGETS` _(optional)_::

A semi-colon separated list of targets for profiler logs. Valid values are

* file
* stdout

The default value is `file`, which logs to the directory specified by
`ELASTIC_APM_PROFILER_LOG_DIR` environment variable.



====================================================================



:nuget: https://www.nuget.org/packages
:dot: .

[[setup-dotnet-net-core]]
=== .NET Core

[float]
==== Quick start

On .NET Core, the agent can be registered on the `IHostBuilder`. This applies to both ASP.NET Core and to other .NET Core applications that depend on `IHostBuilder`, like https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services[background tasks]. In this case, you need to reference the {nuget}/Elastic.Apm.NetCoreAll[`Elastic.Apm.NetCoreAll`] package.


[source,csharp]
----
using Elastic.Apm.NetCoreAll;

namespace MyApplication
{
  public class Program
  {
    public static IHostBuilder CreateHostBuilder(string[] args) =>
        Host.CreateDefaultBuilder(args)
            .ConfigureWebHostDefaults(webBuilder => { webBuilder.UseStartup<Startup>(); })
            .UseAllElasticApm();

    public static void Main(string[] args) => CreateHostBuilder(args).Build().Run();
  }
}
----

With the `UseAllElasticApm()`, the agent with all its components is turned on. On ASP.NET Core, it'll automatically capture incoming requests, database calls through supported technologies, outgoing HTTP requests, and so on.

[float]
==== Manual instrumentation

The `UseAllElasticApm` will add an `ITracer` to the Dependency Injection system, which can be used in your code to manually instrument your application, using the <<public-api>> 

[source,csharp]
----
using Elastic.Apm.Api;

namespace WebApplication.Controllers
{
    public class HomeController : Controller
    {
        private readonly ITracer _tracer;

        //ITracer injected through Dependency Injection
        public HomeController(ITracer tracer) => _tracer = tracer;

        public IActionResult Index()
        {
            //use ITracer
            var span = _tracer.CurrentTransaction?.StartSpan("MySampleSpan", "Sample");
            try
            {
                //your code here
            }
            catch (Exception e)
            {
                span?.CaptureException(e);
                throw;
            }
            finally
            {
                span?.End();
            }
            return View();
        }
    }
}
----

Similarly to this ASP.NET Core controller, you can use the same approach with `IHostedService` implementations.

[float]
==== Instrumentation modules

The `Elastic.Apm.NetCoreAll` package references every agent component that can be automatically configured. This is usually not a problem, but if you want to keep dependencies minimal, you can instead reference the `Elastic.Apm.Extensions.Hosting` package and use the `UseElasticApm` method, instead of `UseAllElasticApm`. With this setup you can control what the agent will listen for.

The following example only turns on outgoing HTTP monitoring (so, for instance, database or Elasticsearch calls won't be automatically captured):

[source,csharp]
----
public static IHostBuilder CreateHostBuilder(string[] args) =>
    Host.CreateDefaultBuilder(args)
        .ConfigureWebHostDefaults(webBuilder => { webBuilder.UseStartup<Startup>(); })
        .UseElasticApm(new HttpDiagnosticsSubscriber());
----


[float]
[[zero-code-change-setup]]
==== Zero code change setup on .NET Core and .NET 5+ (added[1.7])

If you can't or don't want to reference NuGet packages in your application, you can use the startup hook feature to inject the agent during startup, if your application runs on .NET Core 3.0 or .NET 5 or newer.

To configure startup hooks

. Download the `ElasticApmAgent_<version>.zip` file from the https://github.com/elastic/apm-agent-dotnet/releases[Releases] page of the .NET APM Agent GitHub repository. You can find the file under Assets.
. Unzip the zip file into a folder.
. Set the `DOTNET_STARTUP_HOOKS` environment variable to point to the `ElasticApmAgentStartupHook.dll` file in the unzipped folder
+
[source,sh]
----
set DOTNET_STARTUP_HOOKS=<path-to-agent>\ElasticApmAgentStartupHook.dll <1>
----
<1> `<path-to-agent>` is the unzipped directory from step 2.

. Start your .NET Core application in a context where the `DOTNET_STARTUP_HOOKS` environment variable is visible.

With this setup the agent will be injected into the application during startup and it will start every auto instrumentation feature. On ASP.NET Core (including gRPC), incoming requests will be automatically captured. 

[NOTE]
--
Agent configuration can be controlled through environment variables with the startup hook feature.
--




ifdef::env-github[]
NOTE: For the best reading experience,
please view this documentation at https://www.elastic.co/guide/en/apm/agent/dotnet[elastic.co]
endif::[]

[[log-correlation]]
== Log correlation

The Elastic APM .NET agent provides integrations for popular logging frameworks, which take care of
injecting trace ID fields into your application's log records. Currently supported logging frameworks are:

- <<serilog>>
- <<nlog>>

If your favorite logging framework is not already supported, there are two other options:

* Open a feature request, or contribute code, for additional support, as described in https://github.com/elastic/apm-agent-dotnet/blob/main/CONTRIBUTING.md[CONTRIBUTING.md].
* Manually inject trace IDs into log records, as described in <<log-correlation-manual>>.

Regardless of how you integrate APM with logging, you can use {filebeat-ref}[Filebeat] to
send your logs to Elasticsearch, in order to correlate your traces and logs and link from
APM to the {observability-guide}/monitor-logs.html[Logs app].

[[serilog]]
=== Serilog

We offer a https://github.com/serilog/serilog/wiki/Enrichment[Serilog Enricher] that adds the trace id to every log line that is created during an active trace.

The enricher lives in the https://www.nuget.org/packages/Elastic.Apm.SerilogEnricher[Elastic.Apm.SerilogEnricher] NuGet package.

You can enable it when you configure your Serilog logger:

[source,csharp]
----
var logger = new LoggerConfiguration()
   .Enrich.WithElasticApmCorrelationInfo()
   .WriteTo.Console(outputTemplate: "[{ElasticApmTraceId} {ElasticApmTransactionId} {Message:lj} {NewLine}{Exception}")
   .CreateLogger();
----

In the code snippet above `.Enrich.WithElasticApmCorrelationInfo()` enables the enricher, which will set 2 properties for log lines that are created during a transaction:

- ElasticApmTransactionId
- ElasticApmTraceId

As you can see, in the `outputTemplate` of the Console sink these two properties are printed. Of course they can be used with any other sink.

If you want to send your logs directly to Elasticsearch you can use the https://www.nuget.org/packages/Serilog.Sinks.Elasticsearch[Serilog.Sinks.ElasticSearch] package. Furthermore, you can pass the `EcsTextFormatter` from the   https://www.nuget.org/packages/Elastic.CommonSchema.Serilog[Elastic.CommonSchema.Serilog] package to the Elasticsearch sink, which formats all your logs according to Elastic Common Schema (ECS) and it makes sure that the trace id ends up in the correct field.

Once you added the two packages mentioned above, you can configure your logger like this:

[source,csharp]
----
Log.Logger = new LoggerConfiguration()
.Enrich.WithElasticApmCorrelationInfo()
.WriteTo.Elasticsearch(new ElasticsearchSinkOptions(new Uri("http://localhost:9200"))
{
  CustomFormatter = new EcsTextFormatter()
})
.CreateLogger();
----

With this setup the application will send all the logs automatically to Elasticsearch and you will be able to jump from traces to logs and from logs to traces.


[[nlog]]
=== NLog

For NLog, we offer two https://github.com/NLog/NLog/wiki/Layout-Renderers[LayoutRenderers] that inject the current trace and transaction id into logs.

In order to use them, you need to add the https://www.nuget.org/packages/Elastic.Apm.NLog[Elastic.Apm.NLog] NuGet package to your application and load it in the `<extensions>` section of your NLog config file:

[source,xml]
----
<nlog>
<extensions>
   <add assembly="Elastic.Apm.NLog"/>
</extensions>
<targets>
<target type="file" name="logfile" fileName="myfile.txt">
    <layout type="jsonlayout">
        <attribute name="traceid" layout="${ElasticApmTraceId}" />
        <attribute name="transactionid" layout="${ElasticApmTransactionId}" />
    </layout>
</target>
</targets>
<rules>
    <logger name="*" minLevel="Trace" writeTo="logfile" />
</rules>
</nlog>
----

As you can see in the sample file above, you can reference the current transaction id with `${ElasticApmTransactionId}` and the trace id with `${ElasticApmTraceId}`.

[[log-correlation-manual]]
=== Manual log correlation

If the agent-provided logging integrations are not suitable or not available for your
application, then you can use the agent's <<public-api, API>> to inject trace IDs manually.
There are two main approaches you can take, depending on whether you are using structured
or unstructured logging.

[float]
[[log-correlation-manual-structured]]
==== Manual log correlation (structured)

For correlating structured logs with traces, the following fields should be added to your logs:

 - `trace.id`
 - `transaction.id`

Given a transaction object, you can obtain its trace id by using the `Transaction.TraceId` property and its transaction id by using the `Transaction.Id` property.

You can also use the <<api-current-transaction, Elastic.Apm.Agent.Tracer.CurrentTransaction>> property anywhere in the code to access the currently active transaction.

[source,csharp]
----
public (string traceId, string transactionId) GetTraceIds()
{
	if (!Agent.IsConfigured) return default;
	if (Agent.Tracer.CurrentTransaction == null) return default;
	return (Agent.Tracer.CurrentTransaction.TraceId, Agent.Tracer.CurrentTransaction.Id);
}
----

In case the agent is configured and there is an active transaction, the `traceId` and `transactionId` will always return the current trace and transaction ids that you can manually add to your logs. Make sure you store those in the fields `trace.id` and `transaction.id` when you send them to Elasticsearch.

[float]
[[log-correlation-manual-unstructured]]
==== Manual log correlation (unstructured)

For correlating unstructured logs (e.g. basic printf-style logging, like
`Console.WriteLine`), you will need to include the trace ids in your log message, and then
extract them using Filebeat.

If you already have a transaction object, then you can use the
`TraceId` and `Id` properties. Both are of type `string`, so you can simply add them to the log.

[source,csharp]
----
var currentTransaction = //Get Current transaction, e.g.: Agent.Tracer.CurrentTransaction;

Console.WriteLine($"ERROR [trace.id={currentTransaction.TraceId} transaction.id={currentTransaction.Id}] an error occurred");
----


This would print a log message along the lines of:

----
    ERROR [trace.id=cd04f33b9c0c35ae8abe77e799f126b7 transaction.id=cd04f33b9c0c35ae] an error occurred
----

For log correlation to work, the trace ids must be extracted from the log message and
stored in separate fields in the Elasticsearch document. This can be achieved by
{filebeat-ref}/configuring-ingest-node.html[parsing the data by using ingest node], in particular
by using {ref}/grok-processor.html[the grok processor].

[source,json]
----
{
  "description": "...",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": [%{LOGLEVEL:log.level} \\[trace.id=%{TRACE_ID:trace.id}(?: transaction.id=%{SPAN_ID:transaction.id})?\\] %{GREEDYDATA:message}"],
        "pattern_definitions": {
          "TRACE_ID": "[0-9A-Fa-f]{32}",
          "SPAN_ID": "[0-9A-Fa-f]{16}"
        }
      }
    }
  ]
}
----
