// Helper for reading/writing binary data from a string. 
// Keeps up with offsets so we don't have to deal directly
// the the multiple return values of the read_*_le functions.
// 
// All operations are little endian, unless otherwise stated.

class binary_editor:
   data: string = ""
   offset: int = 0

   def read_vertex2f() -> float2:
      let nx = read_float32()
      let ny = read_float32()
      return float2{nx, ny}

   def read_vertex2short() -> int2:
      let nx = read_short()
      let ny = read_short()
      return int2{nx, ny}

   def read_vertex3short() -> int3:
      let nx = read_short()
      let ny = read_short()
      let nz = read_short()
      return int3{nx, ny, nz}

   def read_vertex2i() -> int2:
      let nx = read_int32()
      let ny = read_int32()
      return int2{nx, ny}

   def read_vertex3i() -> int3:
      let nx = read_int32()
      let ny = read_int32()
      let nz = read_int32()
      return int3{nx, ny, nz}

   def read_vertex3f() -> float3:
      let nx = read_float32()
      let ny = read_float32()
      let nz = read_float32()
      return float3{nx, ny, nz}

   // Reads a string field that has a fixed size, up to the 
   // first null, or the entire field if there is no null.
   def read_string(slen) -> string:
      var null_ix = offset + slen
      for(slen) i:
         if data[i+offset] == 0:
            null_ix = offset + i
            break
      let rv = substring(data, offset, null_ix - offset)
      offset += slen
      return rv

   private def find_nullix():
      var null_ix = offset
      while null_ix < length(data):
         if data[null_ix] == 0:
            return null_ix
         null_ix++
      return null_ix
 
   // Reads a null terminated string, no field size.
   def read_string0() -> string:
      let null_ix = find_nullix()
      let rv = substring(data, offset, null_ix - offset)
      offset += (null_ix - offset) + 1
      return rv
       
   def read_bytes(n: int) -> string:
      let rv = substring(data, offset, n)
      offset += n
      return rv

   // Assumes there is enough bytes left in the stream for this.  Caller should verify.
   def read_short() -> int:
      let nm, off0 = read_int16_le(data, offset)
      offset = off0
      return nm

   def read_ushort() -> int:
      let nm, off0 = read_uint16_le(data, offset)
      offset = off0
      return nm

   // Assumes there is enough bytes left in the stream for this.  Caller should verify.
   def read_int32() -> int:
      let nm, off0 = read_int32_le(data, offset)
      offset = off0
      return nm

   def read_int64() -> int:
      let nm, off0 = read_int64_le(data, offset)
      offset = off0
      return nm

   // Assumes there is enough bytes left in the stream for this.  Caller should verify.
   def read_uint32() -> int:
      let nm, off0 = read_uint32_le(data, offset)
      offset = off0
      return nm

   def read_vertex4ui32() -> int4:
      let x = read_uint32()
      let y = read_uint32()
      let z = read_uint32()
      let w = read_uint32()
      return int4{x, y, z, w}

   def read_vertex3ui() -> int3:
      let x = read_uint32()
      let y = read_uint32()
      let z = read_uint32()
      return int3{x, y, z}
   
   def read_vertex4f() -> float4:
      let x = read_float32()
      let y = read_float32()
      let z = read_float32()
      let w = read_float32()
      return float4{x, y, z, w}

   def read_float32() -> float:
      let f, off = read_float32_le(data, offset)
      offset = off
      return f

   def read_byte() -> int:
      var v = 0
      v, offset = read_uint8_le(data, offset)
      return v

   // Writes an array, by writing out the array length, and then callin
   // body(item) for each item so body can write out its contents.
   def write_array(arr, body):
      write_int32(length(arr))
      for(arr) it:
         body(it)

   // Reads an array written by write_array by calling body for each of the
   // items of the saved array.  Body should return the deserialized item.
   def read_array(body):
      let len = read_int32()
      assert len >= 0
      return map(len): body()

   // Writes the string bytes, does no null termination.
   def write_string(s: string):
      data, offset = write_substring(data, offset, s, 0)

   // Writes the string bytes, terminates with a null.
   def write_string0(s: string):
      data, offset = write_substring(data, offset, s, 1)

   def write_bool(b: bool):
       write_byte(if b: 1 else: 0)
    
   def read_bool() -> bool:
       let v = read_byte()
       return v != 0

   def read_rle_bytes(size_hint = 128) -> string:
      var rv = ensure_size("", size_hint, 0)
      var act_len = 0
      var count = read_byte()

      while count != 0:
         if count & 0x80:
            let repeat = read_byte()
            count = count&0x7F
            for(count) i:
               rv = write_int8_le(rv, i+act_len, repeat)
         else:
            for(count) i:
               rv = write_int8_le(rv, i+act_len, read_byte())

         act_len += count
         count = read_byte()

      return substring(rv, 0, act_len)

   def write_rle_bytes(s: string, start = 0, len = -1):
      // Simple scheme, lifted from targa.  Two types of 
      // packets, RLE and RAW. A RLE packet has a count with
      // the high bit set, and is followed by a single byte to 
      // repeat.  A RAW packet has a count with a cleared high 
      // bit, and is followed by that many bytes to copy.
      // section is terminated by a 0 count RAW packet.
      if len < 0:
         len = length(s)

      assert start + len <= length(s)
      var i = start
      var endi = i + len
      var raw_start = i

      def output_raw():
         var left = i - raw_start
         while left > 0:
            let take = min(left, 127)
            write_byte(take)
            for(take):
               write_byte(s[raw_start++])
            left -= take
         

      while i < endi:
         // Scan ahead for run of characters matching current character.
         let c = s[i]
         var j = i+1
         while j < endi and s[j] == c:
            j++
         var run = j - i
         if run > 1:
            output_raw()
            while run > 0:
               let take = min(run, 127)
               write_byte(0x80|take)
               write_byte(c)
               run -= take
            i = j
            raw_start = i
         else:
            // no run, just another byte that will output in a raw packet.
            i++

      output_raw()
      write_byte(0)

   def write_byte(b: int):
      data = ensure_size(data, offset + 1, 0)
      data, offset = write_int8_le(data, offset, b & 0xFF)

   def write_int64(i: int):
      data, offset = write_int64_le(data, offset, i)
      
   def write_int32(i: int):
      data, offset = write_int32_le(data, offset, i)

   def write_uint32(i: int):
      data, offset = write_int32_le(data, offset, i)

   def write_uint16(i: int):
      data, offset = write_int16_le(data, offset, i)

   def write_int16(i: int):
      data, offset = write_int16_le(data, offset, i)

   def write_vertex3f(v: float3):
      data, offset = write_float32_le(data, offset, v.x)
      data, offset = write_float32_le(data, offset, v.y)
      data, offset = write_float32_le(data, offset, v.z)

   def write_vertex2f(v: float2):
      data, offset = write_float32_le(data, offset, v.x)
      data, offset = write_float32_le(data, offset, v.y)

   def write_vertex2i(v: int2):
      data, offset = write_int32_le(data, offset, v.x)
      data, offset = write_int32_le(data, offset, v.y)

   def write_vertex3i(v: int3):
      data, offset = write_int32_le(data, offset, v.x)
      data, offset = write_int32_le(data, offset, v.y)
      data, offset = write_int32_le(data, offset, v.z)

   def write_vertex4f(v: float4):
      data, offset = write_float32_le(data, offset, v.x)
      data, offset = write_float32_le(data, offset, v.y)
      data, offset = write_float32_le(data, offset, v.z)
      data, offset = write_float32_le(data, offset, v.w)

   def write_float32(f: float):
      data, offset = write_float32_le(data, offset, f)
