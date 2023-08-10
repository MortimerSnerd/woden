// Key/value pair
struct kvpair<K,V>:
   key: K
   value: V

// Looks up index of key value pair in an array of kvpairs.
// Returns -1 if not found.
def findkv<K, V>(pairs: [kvpair<K,V>], key: K) -> int:
   return find(pairs) kv: kv.key == key

// Finds the index of a kvpair with the given key, or calls a user provided
// function to create a new one if one is not found.
def find_or_create<K,V>(pairs: [kvpair<K,V>], key: K, createbody) -> int:
   let i = findkv(pairs, key)
   if i >= 0:
      return i
   else:
      push(pairs, kvpair<K,V>{key: key, value: createbody()})
      return length(pairs)-1
