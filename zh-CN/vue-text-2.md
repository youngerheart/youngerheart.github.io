---
title: vue.js技术揭秘(2)
date: 2019/10/14 21:34:11
sidebar: auto
meta:
  - name: description
    content: Vue 学习笔记。
---

# 组件化

组件化，就是把页面拆分为多个组件，组件是资源独立的，组件在系统内可复用，组件和组件之间可以嵌套。

## createComponent

`createElement` 最终会调用 `_createElement` 方法，其中有一段对 `tag` 的判断，如果是一个 string，会实例化为一个普通 VNode 节点或未知类型节点，否则通过 `createComponent` 方法创建一个组件 VNode。

传入的是一个App对象时，直接通过 createComponent 方法创建 vnode。

```
export function createComponent (
  Ctor: Class<Component> | Function | Object | void,
  data: ?VNodeData,
  context: Component,
  children: ?Array<VNode>,
  tag?: string
): VNode | Array<VNode> | void {}
```

`src/core/vdom/create-component.js` 中主要有以下三个步骤：

### 构造子类构造函数

```
const baseCtor = context.$options._base

// plain options object: turn it into a constructor
if (isObject(Ctor)) {
  Ctor = baseCtor.extend(Ctor)
}

import HelloWorld from './components/HelloWorld'

export default {
  name: 'app',
  components: {
    HelloWorld
  }
}
```

这里export了一个对象，createComponent 中就会执行到 baseCtor.extend(Ctor)，baseCtor就是 Vue，这是 `src/core/global-api/index.js` 中 initGlobalAPI 函数的逻辑：

```
Vue.options._base = Vue
```
这里定义了options，之前的 createComponent 取自 context.$options，在 `src/core/instance/init.js` 原型上的 _init 函数中有相关逻辑:


```
vm.$options = mergeOptions(
  resolveConstructorOptions(vm.constructor),
  options || {},
  vm
)
```

**`Vue.extend` 的定义**

```
Vue.extend = function (extendOptions: Object): Function {
  extendOptions = extendOptions || {}
  const Super = this
  const SuperId = Super.cid
  const cachedCtors = extendOptions._Ctor || (extendOptions._Ctor = {})
  if (cachedCtors[SuperId]) {
    return cachedCtors[SuperId]
  }

  const name = extendOptions.name || Super.options.name
  if (process.env.NODE_ENV !== 'production' && name) {
    validateComponentName(name)
  }

  const Sub = function VueComponent (options) {
    this._init(options)
  }
  Sub.prototype = Object.create(Super.prototype)
  Sub.prototype.constructor = Sub
  Sub.options = mergeOptions(
    Super.options,
    extendOptions
  )
  Sub['super'] = Super
  ...
  // cache constructor
  cachedCtors[SuperId] = Sub
  return Sub
}
```

将一个纯对象转化为一个基于 Vue 的构造器 Sub 并返回，并对其进行拓展，最后将该构造器针对其Id进行缓存避免重复构造。

### 安装组件钩子函数

Vue的vdom参考了开源库snabbdom，它的特点是在patch流程中对外暴露了各种时机的钩子函数。

```
installComponentHooks(data)
```

`src/core/vdom/create-component.js`


```
const componentVNodeHooks = {
  init (vnode: VNodeWithData, hydrating: boolean): ?boolean {}
  prepatch (oldVnode: MountedComponentVNode, vnode: MountedComponentVNode) {}
  insert (vnode: MountedComponentVNode) {}
  destroy (vnode: MountedComponentVNode) {}
}

const hooksToMerge = Object.keys(componentVNodeHooks)

function installComponentHooks (data: VNodeData) {
  const hooks = data.hook || (data.hook = {})
  for (let i = 0; i < hooksToMerge.length; i++) {
    const key = hooksToMerge[i]
    const existing = hooks[key]
    const toMerge = componentVNodeHooks[key]
    if (existing !== toMerge && !(existing && existing._merged)) {
      hooks[key] = existing ? mergeHook(toMerge, existing) : toMerge
    }
  }
}
```

`installComponentHooks` 就是将 `componentVNodeHooks` 的钩子函数合并到 data.hook 中，在 VNode 执行 patch 的过程中执行相关钩子函数，合并时如果某个时机的钩子已经存在 `data.hook` 中，那么通过 `mergeHook` 做合并。

### 实例化VNode

```
const name = Ctor.options.name || tag
const vnode = new VNode(
  `vue-component-${Ctor.cid}${name ? `-${name}` : ''}`,
  data, undefined, undefined, undefined, context,
  { Ctor, propsData, listeners, tag, children },
  asyncFactory
)
return vnode
```

通过 new VNode实例化一个 vnode 并返回。与普通元素节点的 vnode 不同，组件的 vnode 是没有 children 的。

createComponent 会返回 vnode，同样会执行 `vm._update` 方法，进而执行 `patch` 函数。

## patch

patch 的过程会调用 createElm 创建元素节点，定义在 `src/core/vdom/patch.js` 中

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
  // 这里又会出现一个 createComponent
  if (createComponent(vnode, insertedVnodeQueue, parentElm, refElm)) {
    return
  }
  // ...
}
```

### createComponent

```
function createComponent (vnode, insertedVnodeQueue, parentElm, refElm) {
  let i = vnode.data
  if (isDef(i)) {
    const isReactivated = isDef(vnode.componentInstance) && i.keepAlive
    if (isDef(i = i.hook) && isDef(i = i.init)) {
      i(vnode, false /* hydrating */)
    }
    // after calling the init hook, if the vnode is a child component
    // it should've created a child instance and mounted it. the child
    // component also has set the placeholder vnode's elm.
    // in that case we can just return the element and be done.
    if (isDef(vnode.componentInstance)) {
      initComponent(vnode, insertedVnodeQueue)
      insert(parentElm, vnode.elm, refElm)
      if (isTrue(isReactivated)) {
        reactivateComponent(vnode, insertedVnodeQueue, parentElm, refElm)
      }
      return true
    }
  }
}
```

首先对 `vnode.data` 做判断，如果 vnode 是一个 VNode，则得到 i 是钩子函数。在创建组件 VNode 时合并的钩子函数中包含 init 钩子函数。（上一章介绍过）
该函数通过 `createComponentInstanceForVnode` 创建一个 Vue 的实例，然后调用 `$mount` 方法挂载子组件。

```
export function createComponentInstanceForVnode (
  vnode: any, // we know it's MountedComponentVNode but flow doesn't
  parent: any, // activeInstance in lifecycle state
): Component {
  const options: InternalComponentOptions = {
    _isComponent: true,
    _parentVnode: vnode,
    parent
  }
  // check inline-template render functions
  const inlineTemplate = vnode.data.inlineTemplate
  if (isDef(inlineTemplate)) {
    options.render = inlineTemplate.render
    options.staticRenderFns = inlineTemplate.staticRenderFns
  }
  return new vnode.componentOptions.Ctor(options)
}
```

这里的 `new vnode.componentOptions.Ctor(options)` 相当于上节的 `new Sub(options)`
