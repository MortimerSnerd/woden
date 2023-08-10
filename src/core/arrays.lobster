// Array themed helper functions.
//TODO move functions to treat arrays as heaps from algs to here.

def array_copy_sub(arr, first, num):
   let rv = []
   var i = first
   for(num):
      push(rv, arr[i])
      i++

   return rv
