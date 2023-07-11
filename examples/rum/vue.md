# Vue RUM Agent Example

Install the @elastic/apm-rum-angular package as a dependency to your application:

```
npm install @elastic/apm-rum-vue --save
```

## Using APM Plugin

```
app.use(ApmVuePlugin, options)
```

All agent configration options can be found here: https://www.elastic.co/guide/en/apm/agent/rum-js/5.x/configuration.html

### Options

- `config` (required) - RUM agent configuration options.
- `router` (optional) - Instance of Vue Router. If provided, will start capturing both page load and SPA navigation events as transactions with path of the route as its name.
- `captureErrors` (optional) - If enabled, will install a global Vue error handler to capture render errors inside the components. Defaults to true. The plugin captures the component name, lifecycle hook and file name (if it’s available) as part of the error context.

## Instrumenting your Vue application

The package exposes ApmVuePlugin which is a Vue Plugin and can be installed in your application using Vue.use method.

```
import { createApp, defineComponent, h } from 'vue'
import { createRouter, createWebHashHistory } from 'vue-router'
import { ApmVuePlugin } from '@elastic/apm-rum-vue'
import App from './App.vue'

const Home = defineComponent({
  render: () => h("div", {}, "home")
})

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', component: Home }
  ]
})

createApp(App)
  .use(router)
  .use(ApmVuePlugin, {
    router,
    config: {
      serviceName: 'app-name',
      // agent configuration
    }
  })
  // app specific code
  .mount('#app')
```

## Accessing agent instance inside components

Instance of the agent can be accessed inside all the components using this.$apm

```
<template>
  <div>Component timings as span</div>
</template>

<script>
export default {
  data() {
    return {
      span: null
    }
  },
  created() {
    this.span = this.$apm.startSpan('create-mount-duration', 'custom')
  },
  mounted() {
    this.span && this.span.end()
  }
}
</script>
```

ApmVuePlugin expects the router option to be an instance of VueRouter since it uses the navigation guards functionality.

Once the plugin is initialized, both page load and SPA navigation events will be captured as transactions with the path of the route as its name and page-load or route-change as type.
