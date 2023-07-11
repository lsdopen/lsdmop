# Angular RUM Agent Example

Install the @elastic/apm-rum-angular package as a dependency to your application:

```
npm install @elastic/apm-rum-angular --save
```

## Instrumenting your application

The Angular integration packages exposes the ApmModule and ApmService which uses Angular’s dependency injection pattern and will start subscribing to Angular Router Events once the service is initialized.

> **Note**
> ApmService must be initialized from either the application module or application component since the RUM agent has to start capturing all the resources and API calls as soon as possible.

> **Warning**
> Get your local APM server URL. If this is a SPA, then you will either need to provide a public endpoint or an endpoint in your network available to your SPA users. If you want to avoid CORS issues, you may also proxy requests via your frontends proxy. `yourapp.com/apm` -> `apm.yourorg.com`.

All agent configration options can be found here: https://www.elastic.co/guide/en/apm/agent/rum-js/5.x/configuration.html

```
import { NgModule } from '@angular/core'
import { BrowserModule } from '@angular/platform-browser'
import { Routes, RouterModule } from '@angular/router'
import { ApmModule, ApmService } from '@elastic/apm-rum-angular'

const routes: Routes = [
  { path: 'contact', component: ContactListComponent },
  { path: 'contact/:id', component: ContactDetailComponent }
]

@NgModule({
  imports: [ApmModule, BrowserModule, RouterModule.forRoot(routes)],
  declarations: [AppComponent, ContactListComponent, ContactDetailComponent],
  providers: [ApmService],
  bootstrap: [AppComponent]
})
export class AppModule {
  constructor(service: ApmService) {
    // Agent API is exposed through this apm instance
    const apm = service.init({
      serviceName: 'angular-app',
      serverUrl: '<apm server url>'
    })

    apm.setUserContext({
      'username': 'foo',
      'id': 'bar'
    })
  }
}
```

Once the service is initialized, both page load and Single page application navigation events will be captured as transactions with the path of the route as its name and page-load or route-change as type.

## Capturing errors in Angular applications

By default, when an error is thrown inside the Angular application, the default error handler prints the error messages to the console without rethrowing them as browser events.

ApmErrorHandler provides a centralized error handling which captures and reports the errors to be shown in the APM UI and also logs them to the browser console.

```
import { ErrorHandler } from '@angular/core'
import { ApmErrorHandler } from '@elastic/apm-rum-angular'

@NgModule({
  providers: [
    {
      provide: ErrorHandler,
      useClass: ApmErrorHandler
    }
  ]
})
class AppModule {}
```
