// Arbitrarily large bitset.

struct bitset:
   bytes: string

   private def loc(bit_n: int) -> int, int:
      let i = bit_n / 8
      let mask = 1 << (bit_n & 7)
      return i, mask

   def set(bit_n):
      let i, mask = loc(bit_n)
      let v = read_uint8_le(bytes, i) 
      write_uint8_le(bytes, i, v | mask)

   def clear(bit_n):
      let i, mask = loc(bit_n)
      let v = read_uint8_le(bytes, i)
      write_uint8_le(bytes, i, v & ~mask)

   def has(bit_n) -> bool:
      let i, mask = loc(bit_n)
      let v = read_uint8_le(bytes, i)
      return (v & mask) != 0

   // Modifies this set to be  this | other. 
   def in_place_union(other: bitset):
      assert length(bytes) == length(other.bytes)
      for(length(bytes)) i:
         let x = read_uint8_le(bytes, i)
         let y = read_uint8_le(other.bytes, i)
         write_int8_le(bytes, i, x | y)

   // Calls body with the bit number of all set bits.
   def for_set_bits(body):
      var i = 0
      var bit_n = 0
      while i < length(bytes):
         let v = read_uint8_le(bytes, i)
         if v == 0:
            bit_n += 8
            i++
         else:
            for(8) bc:
               if (v & (1 << bc)) != 0:
                  body(bit_n)
               bit_n++
            i++


// Makes a new cleared bitset.
def mk_bitset(n_bits: int) -> bitset:
   return bitset{bytes: ensure_size("", (n_bits + 7) / 8, 0)}
