# React RUM Agent Example

> **Warning**
> The default React RUM Agent won't work for projects built on NextJS. Please reach out to us if this is a requirement.

Install the @elastic/apm-rum-angular package as a dependency to your application:

```
npm install @elastic/apm-rum-react --save
```

You then need to initialise the agent on the bootstrap of your React application. All agent configration options can be found here: https://www.elastic.co/guide/en/apm/agent/rum-js/5.x/configuration.html

> **Warning**
> Get your local APM server URL. If this is a SPA, then you will either need to provide a public endpoint or an endpoint in your network available to your SPA users. If you want to avoid CORS issues, you may also proxy requests via your frontends proxy. `yourapp.com/apm` -> `apm.yourorg.com`.

```
import { init as initApm } from '@elastic/apm-rum'

const apm = initApm({

  // Set required service name (allowed characters: a-z, A-Z, 0-9, -, _, and space)
  serviceName: '',

  // Set custom APM Server URL (default: http://localhost:8200)
  serverUrl: 'http://localhost:8200',

  // Set service version (required for sourcemap feature)
  serviceVersion: ''
})
```

## Instrumenting your application

To instrument the application routes, you can use ApmRoute component provided in the package. ApmRoute creates a transaction that has the path of the Route as its name and has route-change as its type.

> **Warning**
> Currently ApmRoute only supports applications using react-router library.

First you should import ApmRoute from the @elastic/apm-rum-react package:

```
import { ApmRoute } from '@elastic/apm-rum-react'
```

Then, you should replace Route components from the react-router library with ApmRoute. You can use ApmRoute in any of the routes that you would like to monitor, therefore, you don’t have to change all of your routes:

```
class App extends React.Component {
  render() {
    return (
      <div>
        <ApmRoute
          exact
          path="/"
          component={() => (
            <Redirect
              to={{
                pathname: '/home'
              }}
            />
          )}
        />
        <ApmRoute path="/home" component={HomeComponent} />
        <Route path="/about" component={AboutComponent} />
      </div>
    )
  }
}
```

> **Warning**
> ApmRoute only instruments the route if component property is provided, in other cases, e.g. using render or children properties, ApmRoute will only renders the route without instrumenting it, please instrument the individual component using withTransaction in these cases instead.

## Instrumenting individual React components

This is useful if you want to understand the transactions on a single component or are unable to use ApmRoute. First you should import withTransaction from the @elastic/apm-rum-react package:

```
import { withTransaction } from '@elastic/apm-rum-react'
```

Then, you can use withTransaction as a function to wrap your React components. `withTransaction` accepts two parameters, "transaction name" and "transaction type". If these parameters are not provided, the defaults documented in Transaction API will be used.

```
class AboutComponent extends React.Component { }
export default withTransaction('AboutComponent', 'component')(AboutComponent)
```

## Instrumenting lazy loaded routes

When the route is rendered lazily with components using React.lazy or a similar API, it is currently not possible to auto instrument the components dependencies(JavaScript bundles, API calls, etc) via ApmRoute because React suspends the underlying component until the required dependencies are available which means our transaction is not started till React starts rendering the underlying component. To instrument these lazy rendered routes and capture the spans associated with the components, you’ll need to manually instrument the code with the withTransaction API.

```
import React, { Component, Suspense, lazy } from 'react'
import { Route, Switch } from 'react-router-dom'
import { withTransaction } from '@elastic/apm-rum-react'

const Loading = () => <div>Loading</div>
const LazyRouteComponent = lazy(() => import('./lazy-component'))

function Routes() {
  return (
    <Suspense fallback={Loading()}>
      <Switch>
        <Route path="/lazy" component={LazyRouteComponent} />
      </Switch>
    </Suspense>
  )
}

// lazy-component.jsx
class LazyComponent extends Component {}
export default withTransaction('LazyComponent', 'component')(LazyComponent)
```
