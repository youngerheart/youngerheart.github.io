---
title: vue.js技术揭秘
date: 2019/07/11 21:34:11
sidebar: auto
meta:
  - name: description
    content: Vue 学习笔记。
---

## 准备工作
### flow
facebook出品的JavaScript静态类型检查工具。

JavaScript是动态语言，过于灵活会导致由类型错误引起的bug。

类型检查是在编译期尽早发现类型错误bug，又不影响代码运行。

Babel和ESlint都有对应Flow插件，小成本改动即可拥有静态类型检查能力。

#### flow的工作方式

* 类型推断: 通过变量的使用上下文来推断出变量类型并检查。
* 类型注释: 事先注释好期待的类型。

```
function split(str) {
  return str.split(' ')
}
split(11); // Error: str must be string

function add (x, y) {
  return x + y;
}
add('Hello', 11); // No error

function add (x: number, y: number): number {
  return x + y;
}
add('Hello', 11); // Error: arguments must be number

var arr: Array<number> = [1, 2, 3]
arr.push('hello') // Error: items must be number

class Bsr {
  x: string;
  y: string | number;
}

var obj: {
  a: string,
  b: number,
  c: Array<string>,
  d: Bar
} = {
  a: 'hello',
  b: 11,
  c: ['hello', 'world'],
  d: new Bar('hello', 3)
}
```

#### vue源码中的应用

配置文件为根目录的.flowconfig，库定义目录为`flow`

### 源码目录设计

```
src
├── compiler        # 编译相关 
├── core            # 核心代码 
├── platforms       # 不同平台的支持
├── server          # 服务端渲染
├── sfc             # .vue 文件解析
├── shared          # 共享代码
```

#### compiler

所有编译相关代码，将模板解析为ast语法树，优化，生成代码。
编译可以在构建时做(webpack and vue-loader)也可以在运行时做(runtime with compiler)。
编译时一项耗性能的工作，推荐离线编译。

#### core
core包含了Vue.js的核心代码，包括内置组件，全局API封装，Vue实例化，观察者，虚拟DOM，工具函数。

#### platform
Vue.js 是跨平台的MVVM框架，可以跑在web上，也可以配合weex跑在native客户端上。
这里是不同平台的入口文件。

#### server
Vue.js 2.0支持了服务器渲染，所有服务端渲染相关逻辑都在这个目录。这里是排在服务器的Node.js代码。

#### sfc
将.vue文件内容解析为一个JavaScript对象。

#### shared
可以共用的工具方法。

### Vue.js源码构建
`scripts/build.js`
```
let builds = require('./config').getAllBuilds()
if (process.argv[2]) {
  const filters = process.argv[2].split(',')
  builds = builds.filter(b => {
    return filters.some(f => b.output.file.indexOf(f) > -1 || b._name.indexOf(f) > -1)
  })
}
```
`scripts/config.js`
```
const aliases = require('./alias')
const resolve = p => {
  const base = p.split('/')[0]
  if (aliases[base]) {
    return path.resolve(aliases[base], p.slice(base.length + 1))
  } else {
    return path.resolve(__dirname, '../', p)
  }
}
function genConfig (name) {
  const opts = builds[name]
  const config = {
    input: opts.entry,
    external: opts.external,
    plugins: [
      flow(),
      alias(Object.assign({}, aliases, opts.alias))
    ].concat(opts.plugins || []),
    output: {
      file: opts.dest,
      format: opts.format,
      banner: opts.banner,
      name: opts.moduleName || 'Vue'
    },
    onwarn: (msg, warn) => {
      if (!/Circular/.test(msg)) {
        warn(msg)
      }
    }
  }
  ...
  return config
}

const builds = {
  // Runtime only (CommonJS). Used by bundlers e.g. Webpack & Browserify
  'web-runtime-cjs': {
    entry: resolve('web/entry-runtime.js'),
    dest: resolve('dist/vue.runtime.common.js'),
    format: 'cjs',
    banner
  },
  // Runtime+compiler CommonJS build (CommonJS)
  'web-full-cjs': {
    entry: resolve('web/entry-runtime-with-compiler.js'),
    dest: resolve('dist/vue.common.js'),
    format: 'cjs',
    alias: { he: './entity-decoder' },
    banner
  },
  ...
}

exports.getAllBuilds = () => Object.keys(builds).map(genConfig)
```

* Runtime + Compiler
在 Vue.js 2.0 中，最终渲染都是通过 render 函数，如果写 template 属性，则需要编译成 render 函数，那么这个编译过程会发生运行时，所以需要带有编译器的版本。

### 入口文件

`src/core/instance/index.js`
```
function Vue (options) {
  if (process.env.NODE_ENV !== 'production' &&
    !(this instanceof Vue)
  ) {
    warn('Vue is a constructor and should be called with the `new` keyword')
  }
  this._init(options)
}

initMixin(Vue)
stateMixin(Vue)
eventsMixin(Vue)
lifecycleMixin(Vue)
renderMixin(Vue)

export default Vue
```

Vue是一个用Function实现的类，只能通过new Vue去实例化它。
Vue的功能都是在Vue.prototype上扩展的方法，按功能分散在多个模块，这是class写法难以实现的，便于代码的维护和管理。

## 数据驱动
指视图由数据驱动，对视图的修改不会直接操作DOM，而是通过修改数据，使得用户的代码量大大简化。DOM变成了数据的映射，所有的逻辑都是对数据的修改而不用触碰DOM，这样的代码非常利于维护。

### new Vue 发生了什么
构造函数中限制Vue只能通过new关键字初始化，之后调用this._init方法。

`src/core/instance/init.js`
```
Vue.prototype._init = function (options?: Object) {
  const vm: Component = this;
  vm._uid = uid++
  ...
  // 合并配置
  if (options && options._isComponent) {
    initInternalComponent(vm, options)
  }
  else {
    vm.$options = mergeOptions(
      resolveConstructorOptions(vm.constructor),
      options || {},
      vm
    )
  }
  vm._self = vm
  initLifecycle(vm) // 初始化生命周期
  initEvents(vm) // 初始化事件中心
  initRender(vm) // 初始化渲染
  callHook(vm, 'beforeCreate') // 触发生命周期钩子
  initInjections(vm) // resolve injections before data/props
  initState(vm) // 初始化 data/props
  initProvide(vm) // resolve provide after data/props
  callHook(vm, 'created') // 触发生命周期钩子
  if (vm.$options.el) {
    vm.$mount(vm.$options.el)
  }
}
```
检测到如果有 el 属性，则调用 vm.$mount 方法挂载 vm，挂载的目标就是把模板渲染成最终的 DOM。

### Vue实例挂载的实现

`src/platform/web/entry-runtime-with-compiler.js`

```
if (el === document.body || el === document.documentElement) warn()
if (!options.render) {
  if (template.charAt(0) === '#') template = idToTemplate(template)
  else if (template.nodeType) template = template.innerHTML
  else if (el) template = getOuterHTML(el)
  if (template) {
    const { render, staticRenderFns } = compileToFunctions(template)
    options.render = render
    options.staticRenderFns = staticRenderFns
  }
  return mount.call(this, el, hydrating)
}
```

其中的代码定义，Vue 不能挂载在 html 或者 body 之类的根节点。如果没有定义 render 函数，则会将 el 或者 template 字符串转化为 render 方法。
原型上的 $mount 在 `src/platform/web/runtime/index.js` 上定义，可以直接被 runtime only 版本的 Vue 直接使用。

```
Vue.prototype.$mount = function(
  el?: string | Element, // 挂载的元素，可以是字符串，也可以是DOM对象。
  hydrating?: boolean // 服务器渲染相关参数
): Component {
  el = el && inBrowser ? query(el) : undefined
  return mountComponent(this, el, hydrating);
}
```

`src/core/instance/lifecycle.js` 中定义了 `mountComponent` 方法。

```
vm.$el = el
if (!vm.$options.render) {
  vm.$options.render = createEmptyVNode
  if ((vm.$options.template) || vm.$options.el || el) warn('You are using the runtime-only build of Vue');
  else warn('template or render function not defined.')
}
callHook(vm, 'beforeMount')
let updateComponent
updateComponent = () => {
  vm._update(vm._render(), hydrating)
}
new Watcher(vm, updateComponent, noop, {
  before () {
    if (vm._isMounted) {
      callHook(vm, 'beforeUpdate')
    }
  }
}, true /* isRenderWatcher */)
hydrating = false
if (vm.$vnode == null) {
  vm._isMounted = true
  callHook(vm, 'mounted')
}
return vm
```

Watcher 在这里起到两个作用，一个是初始化的时候会执行回调函数，另一个是当 vm 实例中的监测的数据发生变化的时候执行回调函数。

vm.$vnode 表示 Vue 实例的父虚拟 Node，所以它为 Null 则表示当前是根 Vue 的实例。

### Vue render

_render 函数的定义位于 `src/core/instance/render.js`。

```
Vue.prototype._render = function(): VNode {
  const { render, _parentVnode } = vm.$options
  vm.$vnode = _parentVnode
  try {
    vnode = render.call(vm._renderProxy, vm.$createElement)
  } catch (e) {
    handleError(e, vm, `render`)
  }
  // set parent
  vnode.parent = _parentVnode
  return vnode
};
```
vm._render 最终是通过执行 createElement 方法并返回的是 vnode (Virtual DOM)

### Virtual DOM

真正的 DOM 元素非常庞大，如果频繁的去做 DOM 更新，会产生性能问题。

Virtual DOM 用原生 JS 对象去描述 DOM 节点，比创建 DOM 的代价小很多。Vue 中 Virtual DOM 用 VNode 的 Class 去描述，定义在 `src/core/vdom/vnode.js` 中。

VNode 只用来映射到真实 DOM 的渲染，不需要包含操作真正 DOM 的方法。其创建时通过之前提到的 createElement 方法创建的。

### createElement

`src/core/vdom/create-elemenet.js`

在处理一些参数后
```
return _createElement(context, tag, data, children, normalizationType)
```

```
export function _createElement (
  context, // VNode的上下文环境，Component 类型
  tag, // 标签，可以是一个字符串或一个 Component
  data, // Vnode 的子节点，是任意类型的，接下来要被规范为标准 VNode 数组
  normalizationType // 子节点规范的类型，类型不同规范的方法不同
  ) {
  ...
}
```

#### children 的规范化

首先要将 children 规范为 VNode 类型，根据 normalizationType 的不同，调用normalizeChildren(children) 和 simpleNormalizeChildren(children) 方法。

`src/core/vdom/helpers/normalzie-children.js`

```
// 在 render 函数是编译生成时，children 都已经是VNode类型，functional component 会返回一个数组而不是根节点，需要通过 Array.prototype.concat 将 children 数组打平，让它深度只有一层。

export function simpleNormalizeChildren (children: any) {
  for (let i = 0; i < children.length; i++) {
    if (Array.isArray(children[i])) {
      return Array.prototype.concat.apply([], children)
    }
  }
  return children
}

export function normalizeChildren (children: any): ?Array<VNode> {
  return isPrimitive(children)
    ? [createTextVNode(children)]
    : Array.isArray(children)
      ? normalizeArrayChildren(children)
      : undefined
}
```
