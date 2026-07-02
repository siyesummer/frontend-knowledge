function getSequence(arr) {
  const p = arr.slice()
  const result = [0]
  let i, j, u, v, c
  const len = arr.length
  for (i = 0; i < len; i++) {
    // i = 2；
    const arrI = arr[i] // 3
    if (arrI == 5) {
      console.log('Laile');
      
    }
    if (arrI !== 0) {
      j = result[result.length - 1] // 1
      // 5 < 3 ?
      if (arr[j] < arrI) {
        // p[1] = 0;
        p[i] = j                  // 记录前驱
        result.push(i) // [0, 1]
        continue
      }
      // 二分查找
      u = 0
      v = result.length - 1 // 1
      while (u < v) {
        c = (u + v) >> 1 // 0
        // 2 < 3 ? 
        if (arr[result[c]] < arrI) u = c + 1 // 1
        else v = c
      }
      // 3 < 5 ?
      if (arrI < arr[result[u]]) {
        //  1 > 0 ? 
        if (u > 0) p[i] = result[u - 1] // p[2] = 0
        result[u] = i // result[1] = 2
      }
    }
  }
  // 通过前驱链回溯，得到真正的 LIS（不是简单的二分结果）
  u = result.length
  v = result[u - 1]
  while (u-- > 0) {
    result[u] = v
    v = p[v]
  }
  return result
}

const arr = [0, 3, 4, 6, 5];

const result = getSequence(arr)

console.log("结果result",result);

class Season {
  season = "夏末"
}


function test1(){
  const obj = new Season()

  for (const key in obj) {
    // if (!Object.hasOwn(object, key)) continue;
    
    // const element = object[key];
    console.log("key--", key);
    
    
  }
}

test1()

for (var i = 1; i <= 5; i++) {
  setTimeout(function timer() {
    console.log(i)
  }, i * 1000)
}

function getSomething() {
    return "something";
}
async function testAsync() {
    return Promise.resolve("hello async");
}
async function test() {
    const v1 = await getSomething();
    console.log('v1',v1);
    
    const v2 = await testAsync();
    console.log(v1, v2);
}
console.log(111);

test();
console.log(222);

Function.prototype.myCall = function(ctx, ...args) {
  if (ctx === null || ctx === undefined) {
    ctx = window
  }
  const obj = Object(ctx);

  const fnKey = Symbol('call');
  
  obj[fnKey] = this;

  const result = obj[fnKey](...args);

  delete obj[fnKey];

  return result;
}

function myApply(ctx) {
  if (ctx === null || ctx === undefined) {
    ctx = window
  }
  const obj = Object(ctx);

  const fnKey = Symbol('apply');
  
  obj[fnKey] = this;

  const args = arguments[1] || [];

  const result = obj[fnKey](...args);

  delete obj[fnKey];

  return result;
}

Function.prototype.myBind = function(ctx) {
  if (ctx === null || ctx === undefined) {
    ctx = window
  }

  const originFn = this

  const args = [...arguments];
  args.shift();


  function bindFn (...params) {
    console.log('执行的时候');
    
    const result = originFn.myCall(this instanceof bindFn ? this : ctx, ...args, ...params);

    return result;
  }

  bindFn.prototype = Object.create(originFn.prototype)
  bindFn.prototype.constructor = bindFn


  return bindFn
}

function bindFn() {
  console.log('我是原始函数', this.name);
  
}

bindFn.prototype.name = "夏末"
bindFn.prototype.say = function () {
  console.log('我来啦', this.name);
}

const obj = {
  name: '四叶'
}

const toBind = bindFn.myBind(obj);
toBind.prototype.season = function() {
  console.log('绑定函数返回');
  
}

const b = new toBind();
// toBind()
// // toBind()

// b.say()

b.season()

b.hi = function() {
  console.log('自己家');
  
}

b.hi()

function deepClone(obj, hash = new WeakMap()) {
  if (obj == null || typeof obj != 'object') return obj

  if (hash.has(obj)) return hash.get(obj)

  let tmp

  if (Array.isArray(obj)) {
    tmp = []
    hash.set(obj, tmp)
    for (let i = 0; i < obj.length; i++) {
      tmp[i] = deepClone(obj[i], hash)
    }
  } else if (obj instanceof Map) {
    tmp = new Map()
    hash.set(obj, tmp)
    obj.forEach((v, k) => {
      tmp.set(deepClone(k, hash), deepClone(v, hash))
    })

  } else if (obj instanceof Set) {
    tmp = new Set()
    hash.set(obj, tmp)
     obj.forEach(v => {
      tmp.add(deepClone(v, hash))
    })
  } else {
    tmp = Object.create(Object.getPrototypeOf(obj))
    hash.set(obj, tmp)
    Object.keys(obj).forEach(key => {
      tmp[key] = deepClone(obj[key], hash)
    })
  }

  return tmp
}

const set = new Set()
set.add({
  k: "set的key"
})

const map = new Map()
map.set({
  k: 'map的key'
}, {
  v: "map的数据"
})

const cloneObj = {
  name: 'siye',
  fn: () => { console.log(989);},
  a: {
    season: '夏末',
    day: {
      hobby: "游泳"
    }
  },
  set,
  map,
}

cloneObj.COPY = cloneObj

const cloneRes = deepClone(cloneObj)

console.log('cloneObj---', cloneObj);

console.log('cloneRes---', cloneRes);

cloneObj.a.season = "四叶"

console.log('cloneObj---', cloneObj);

console.log('cloneRes---', cloneRes);


function debounce (fn, wait) {
  let timer
  return function(...args) {
    clearTimeout(timer)
    timer = setTimeout(() => {
      fn.apply(this, args)
    }, wait)
  }
}

function throttle(fn , wait = 100) {
  let lastTime = 0
  return function(...args) {
    const now = Date.now()

    if (now - lastTime >= wait) {
      lastTime = now
      fn.apply(this, args)
    }
  }
}

async function asyncPool(tasks, limit) {
  const poolList = []
  const result = []

  for (let i = 0; i < tasks.length; i++) {
    const task = tasks[i]
    const p = Promise.resolve(task()).then(v=> {
      result.push({ type: 'fulfilled', value: v})
    }, e => {
      result.push({ type: 'reject', reason: e})
    }).finally(() => {
      poolList.splice(poolList.indexOf(p), 1)
    })

    poolList.push(p)

    if (poolList.length >= limit) {
      await Promise.race(poolList)
    }
  }

  await Promise.all(poolList)

  return result

}

console.log('fn.length', asyncPool.length);


// LRU 缓存
const CACHE = new Map()
function LRUCache(key , value, limit) {
  if (arguments.length === 0) {
    return
  }

  if (arguments.length === 1) {
    if (!CACHE.has(key)) return
    const val = CACHE.get(key)
    CACHE.delete(key)
    CACHE.set(key, val)
    return val
  } else {
    if (CACHE.has(key)) {
      CACHE.delete(key)
    }

    CACHE.set(key, value)

    if (CACHE.size > limit) {
      const firstKey = CACHE.keys().next().value
      CACHE.delete(firstKey)
    }
  }
}