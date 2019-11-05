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
