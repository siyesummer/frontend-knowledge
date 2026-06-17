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


