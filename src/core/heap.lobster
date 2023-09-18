// Functions for treating an array as a binary heap.

// Treating arrays as binary heaps.
private def lchild(i: int) -> int:
   return 2*i + 1

private def rchild(i: int) -> int:
   return 2*i + 2

private def parent(i:int) -> int:
   assert i != 0
   return (i-1)/2 // Assume: division floored.

def heap_swap<T>(arr: [T], ai: int, bi: int):
   let t = arr[ai]
   arr[ai] = arr[bi]
   arr[bi] = t

def heap_bubble_up<T>(arr: [T], i: int, cmpfn):
   var pos = i

   while pos > 0 and not cmpfn(arr[parent(pos)], arr[pos]):
      heap_swap(arr, parent(pos), pos)
      pos = parent(pos)

def heap_bubble_down<T>(arr: [T], i: int, cmpfn):
   var pos = i
   var inplace = false

   while not inplace and pos < length(arr)-1:
      let li = lchild(pos)
      let ri = li + 1
      let li_exists = li < length(arr)
      let ri_exists = ri < length(arr)

      if (not li_exists or cmpfn(arr[pos], arr[li])) and (not ri_exists or cmpfn(arr[pos], arr[ri])):
         inplace = true
      else:
         if li_exists and ri_exists:
            if cmpfn(arr[li], arr[ri]):
               heap_swap(arr, pos, li)
               pos = li
            else:
               heap_swap(arr, pos, ri)
               pos = ri
         else:
            // One child is not present.
            if li_exists:
               heap_swap(arr, pos, li)
               pos = li
            else:
               heap_swap(arr, pos, ri)
               pos = ri

// Treats `arr` like a binary heap, and adds
// item to the proper place in the tree.  
// cmpfn can be <= for a min heap, or >= for a max
// heap.  
def heap_add<T>(arr: [T], item: T, cmpfn):
   let i = length(arr)
   push(arr, item)
   heap_bubble_up(arr, i, cmpfn)

def heap_pop<T>(arr: [T], cmpfn) -> T:
   let rv = arr[0]

   if length(arr) == 0:
      pop(arr)
   else:
      arr[0] = arr[length(arr)-1]
      pop(arr)
      heap_bubble_down(arr, 0, cmpfn)

   return rv

