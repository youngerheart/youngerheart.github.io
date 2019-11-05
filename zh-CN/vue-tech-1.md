---
title: vue.js技术揭秘(1)
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

class Bar {
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
编译是一项耗性能的工作，推荐离线编译。

#### core
core包含了Vue.js的核心代码，包括内置组件，全局API封装，Vue实例化，观察者，虚拟DOM，工具函数。

#### platform
Vue.js 是跨平台的MVVM框架，可以跑在web上，也可以配合weex跑在native客户端上。
这里是不同平台的入口文件。

#### server
Vue.js 2.0支持了服务器渲染，所有服务端渲染相关逻辑都在这个目录。这里是跑在服务器的Node.js代码。

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
Vue.prototype.$mount = function ( ...
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
      callHook(vm, 'beforeUpdate')  // 触发生命周期钩子
    }
  }
}, true /* isRenderWatcher */)
hydrating = false
if (vm.$vnode == null) {
  vm._isMounted = true
  callHook(vm, 'mounted')  // 触发生命周期钩子
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

VNode 只用来映射到真实 DOM 的渲染，不需要包含操作真正 DOM 的方法。其创建是通过之前提到的 createElement 方法创建的。

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

在 render 函数是编译生成时，children 都已经是VNode类型，functional component 会返回一个数组而不是根节点，需要通过 Array.prototype.concat 将 children 数组打平，让它深度只有一层。

```

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

normalizeChildren 方法的调用场景有 2 种:
* render 函数是用户手写的，当 children 只有一个节点的时候，Vue.js 从接口层面允许用户把 children 写成基础类型用来创建单个简单的文本节点，这种情况会调用 createTextVNode 创建一个文本节点的 VNode。
* 编译 slot、v-for 的时候会产生嵌套数组的情况，会调用 normalizeArrayChildren 方法。

```
function normalizeArrayChildren (children: any, nestedIndex?: string): Array<VNode> {
  const res = []
  let i, c, lastIndex, last
  for (i = 0; i < children.length; i++) {
    c = children[i]
    if (isUndef(c) || typeof c === 'boolean') continue
    lastIndex = res.length - 1
    last = res[lastIndex]
    //  slot、v-for
    if (Array.isArray(c)) {
      if (c.length > 0) {
        c = normalizeArrayChildren(c, `${nestedIndex || ''}_${i}`)
        // merge adjacent text nodes
        if (isTextNode(c[0]) && isTextNode(last)) {
          res[lastIndex] = createTextVNode(last.text + (c[0]: any).text)
          c.shift()
        }
        res.push.apply(res, c)
      }
    } else if (isPrimitive(c)) { // 基本数据类型
      if (isTextNode(last)) {
        // merge adjacent text nodes
        // this is necessary for SSR hydration because text nodes are
        // essentially merged when rendered to HTML strings
        res[lastIndex] = createTextVNode(last.text + c)
      } else if (c !== '') {
        // convert primitive to vnode
        res.push(createTextVNode(c))
      }
    } else {
      if (isTextNode(c) && isTextNode(last)) {
        // merge adjacent text nodes
        res[lastIndex] = createTextVNode(last.text + c.text)
      } else {
        // default key for nested array children (likely generated by v-for)
        if (isTrue(children._isVList) &&
          isDef(c.tag) &&
          isUndef(c.key) &&
          isDef(nestedIndex)) {
          c.key = `__vlist${nestedIndex}_${i}__`
        }
        res.push(c)
      }
    }
  }
  return res
}
```

经过对 children 的规范化，children 变成了一个类型为 VNode 的 Array。

#### VNode 的创建

`createElement` 函数中，规范了 children 后将会去创建一个 VNode 实例。

`['普通 VNode', '组件 VNode', '未知类型 VNode']`

当tag是一个 string，判断是否是一个内置节点，如果是则创建一个普通 VNode。否则如果是已注册的组件名则创建一个组件 VNode，否则创建一个未知类型的VNode。

```
let vnode, ns
if (typeof tag === 'string') {
  let Ctor
  ns = (context.$vnode && context.$vnode.ns) || config.getTagNamespace(tag)
  if (config.isReservedTag(tag)) {
    // platform built-in elements
    vnode = new VNode(
      config.parsePlatformTagName(tag), data, children,
      undefined, undefined, context
    )
  } else if (isDef(Ctor = resolveAsset(context.$options, 'components', tag))) {
    // component
    vnode = createComponent(Ctor, data, context, children, tag)
  } else {
    // unknown or unlisted namespaced elements
    // check at runtime because it may get assigned a namespace when its
    // parent normalizes children
    vnode = new VNode(
      tag, data, children,
      undefined, undefined, context
    )
  }
} else {
  // direct component options / constructor
  vnode = createComponent(tag, data, context, children)
}
```

每个 VNode 有 children，children 每个元素也是一个 VNode，这样就形成了一个 VNode Tree，它很好的描述了 DOM Tree。

### update

Vue 的 `_update` 是实例的一个私有方法，在首次渲染与数据更新时被调用，作用是把 VNode 渲染为 DOM，定义在 `src/core/instance/lifecycle.js` 中。

```
Vue.prototype._update = function (vnode: VNode, hydrating?: boolean) {
  const vm: Component = this
  const prevEl = vm.$el
  const prevVnode = vm._vnode
  const prevActiveInstance = activeInstance
  activeInstance = vm
  vm._vnode = vnode
  // Vue.prototype.__patch__ is injected in entry points
  // based on the rendering backend used.
  if (!prevVnode) {
    // initial render
    vm.$el = vm.__patch__(vm.$el, vnode, hydrating, false /* removeOnly */)
  } else {
    // updates
    vm.$el = vm.__patch__(prevVnode, vnode)
  }
  activeInstance = prevActiveInstance
  // update __vue__ reference
  if (prevEl) {
    prevEl.__vue__ = null
  }
  if (vm.$el) {
    vm.$el.__vue__ = vm
  }
  // if parent is an HOC, update its $el as well
  if (vm.$vnode && vm.$parent && vm.$vnode === vm.$parent._vnode) {
    vm.$parent.$el = vm.$el
  }
  // updated hook is called by the scheduler to ensure that children are
  // updated in a parent's updated hook.
}
```

`_update` 的核心就是调用 `vm.__patch__` 方法，这个方法实际上在不同的平台，比如 web 和 weex 上的定义是不一样的，在 web 平台中定义在 src/platforms/web/runtime/index.js

```
Vue.prototype.__patch__ = inBrowser ? patch : noop
```

patch 方法的定义位于 src/platforms/web/runtime/patch.js

```
import * as nodeOps from 'web/runtime/node-ops'
import { createPatchFunction } from 'core/vdom/patch'
import baseModules from 'core/vdom/modules/index'
import platformModules from 'web/runtime/modules/index'

// the directive module should be applied last, after all
// built-in modules have been applied.
const modules = platformModules.concat(baseModules)

export const patch: Function = createPatchFunction({ nodeOps, modules })
```

createPatchFunction 定义于 `src/core/vdom/patch.js`

在该方法中定义了一系列辅助方法，最终返回了一个 `patch` 方法。patch 是平台相关的，在 web 与 weex 把虚拟 DOM 映射到 平台 DOM 的方法不同。

对应之前的例子：

```
var app = new Vue({
  el: '#app',
  render: function (createElement) {
    return createElement('div', {
      attrs: {
        id: 'app'
      },
    }, this.message)
  },
  data: {
    message: 'Hello Vue!'
  }
})
```
``
// initial render
vm.$el = vm.__patch__(vm.$el, vnode, hydrating, false /* removeOnly */)
``

执行 patch 时传入的 `vm.$el` 是 id 为 app 的 DOM 对象，赋值于之前的 mountComponent 函数。`vnode`对应调用 `render` 函数的返回值，其余两个参数为false。

```
const isRealElement = isDef(oldVnode.nodeType)
if (!isRealElement && sameVnode(oldVnode, vnode)) {
  // patch existing root node
  patchVnode(oldVnode, vnode, insertedVnodeQueue, removeOnly)
} else {
  if (isRealElement) {
    // mounting to a real element
    // check if this is server-rendered content and if we can perform
    // a successful hydration.
    if (oldVnode.nodeType === 1 && oldVnode.hasAttribute(SSR_ATTR)) {
      oldVnode.removeAttribute(SSR_ATTR)
      hydrating = true
    }
    if (isTrue(hydrating)) {
      if (hydrate(oldVnode, vnode, insertedVnodeQueue)) {
        invokeInsertHook(vnode, insertedVnodeQueue, true)
        return oldVnode
      } else if (process.env.NODE_ENV !== 'production') {
        warn(...)
      }
    }      
    // either not server-rendered, or hydration failed.
    // create an empty node and replace it
    oldVnode = emptyNodeAt(oldVnode)
  }

  // replacing existing element
  const oldElm = oldVnode.elm
  const parentElm = nodeOps.parentNode(oldElm)

  // create new node
  createElm(
    vnode,
    insertedVnodeQueue,
    // extremely rare edge case: do not insert if old element is in a
    // leaving transition. Only happens when combining transition +
    // keep-alive + HOCs. (#4590)
    oldElm._leaveCb ? null : parentElm,
    nodeOps.nextSibling(oldElm)
  )
}
```

传入的 oldVnode 为真实 DOM，通过 emptyNodeAt 方法把 oldVNode 转换为 VNode 对象，再调用 createElm 方法。

createElm: 通过虚拟节点创建真实DOM并插入到父节点。

```
function createElm (
  vnode,
  insertedVnodeQueue,
  parentElm,
  refElm,
  nested,
  ownerArray,
  index
) {
  if (isDef(vnode.elm) && isDef(ownerArray)) {
    vnode = ownerArray[index] = cloneVNode(vnode)
  }

  vnode.isRootInsert = !nested // for transition enter check
  // 尝试创建子组件
  if (createComponent(vnode, insertedVnodeQueue, parentElm, refElm)) {
    return
  }

  const data = vnode.data
  const children = vnode.children
  const tag = vnode.tag
  // 如果vnode包含tag，先在非生产环境下检验是否是合法标签，再调用平台DOM去创建一个占位元素
  if (isDef(tag)) {
    if (process.env.NODE_ENV !== 'production') {
      if (data && data.pre) {
        creatingElmInVPre++
      }
      if (isUnknownElement(vnode, creatingElmInVPre)) {
        warn(...)
      }
    }

    vnode.elm = vnode.ns
      ? nodeOps.createElementNS(vnode.ns, tag)
      : nodeOps.createElement(tag, vnode)
    setScope(vnode)

    // 创建子元素，遍历子虚拟节点，递归调用createElm
    /* istanbul ignore if */
    if (__WEEX__) {
      // ...
    } else {
      createChildren(vnode, children, insertedVnodeQueue)
      if (isDef(data)) {
        // 执行create钩子并把 vnode push 到 insertedVnodeQueue
        invokeCreateHooks(vnode, insertedVnodeQueue)
      }
      // 调用insert方法把DOM插入到父节点。子元素优先调用insert，因此整个vnode树节点的插入顺序是先子后父。
      insert(parentElm, vnode.elm, refElm)
    }

    if (process.env.NODE_ENV !== 'production' && data && data.pre) {
      creatingElmInVPre--
    }
  } else if (isTrue(vnode.isComment)) {
    vnode.elm = nodeOps.createComment(vnode.text)
    insert(parentElm, vnode.elm, refElm)
  } else {
    vnode.elm = nodeOps.createTextNode(vnode.text)
    insert(parentElm, vnode.elm, refElm)
  }
}
```

```
function createChildren (vnode, children, insertedVnodeQueue) {
  if (Array.isArray(children)) {
    if (process.env.NODE_ENV !== 'production') {
      checkDuplicateKeys(children)
    }
    for (let i = 0; i < children.length; ++i) {
      createElm(children[i], insertedVnodeQueue, vnode.elm, null, true, children, i)
    }
  } else if (isPrimitive(vnode.text)) {
    nodeOps.appendChild(vnode.elm, nodeOps.createTextNode(String(vnode.text)))
  }
}
```

```
function invokeCreateHooks (vnode, insertedVnodeQueue) {
  for (let i = 0; i < cbs.create.length; ++i) {
    cbs.create[i](emptyNode, vnode)
  }
  i = vnode.data.hook // Reuse variable
  if (isDef(i)) {
    if (isDef(i.create)) i.create(emptyNode, vnode)
    if (isDef(i.insert)) insertedVnodeQueue.push(vnode)
  }
}
```

```
function insert (parent, elm, ref) {
  if (isDef(parent)) {
    if (isDef(ref)) {
      if (ref.parentNode === parent) {
        nodeOps.insertBefore(parent, elm, ref)
      }
    } else {
      nodeOps.appendChild(parent, elm)
    }
  }
}
```

### 总结

Vue的渲染过程: new->init->$mount->complie(如果写template)->render->vnode->patch->DOM
