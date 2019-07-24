import Router from 'vue-router'

export default ({ router }) => {
  let routes = router.options.routes.map((route) => {
    if (route.path === '/') {
      route.beforeEnter = (to, from, next) => {
        next('/zh-CN/')
      }
    }
    return route
  })

  router.options.routes = routes
  router.matcher = new Router({
    mode: 'history',
    routes
  }).matcher
}
