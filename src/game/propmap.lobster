// Classes for storing properties associated with a cell position.
import core.aabb
import data.binary
import game.defs

// Property values are chunked by cell areas.  This is the base
// class that contains common functionality.
// Contains some overrideable methods for known subclasses to avoid
// "is" tests.
private class propmap_chunk:
    bounds: aabb2i

    def is_set(cc: int2) -> bool:
        fatal("promap_chunk: unimplemented is_set")
        return false

    def set(cc: int2):
        fatal("promap_chunk: unimplemented set")
        pass()

    def clear(cc: int2):
        fatal("promap_chunk: unimplemented clear")
        pass()

    def set_byte(cc: int2, v: int):
        fatal("propmap_chunk: unimplemented set_byte")

    def get_byte(cc: int2) -> int:
        fatal("propmap_chunk: unimplemented get_byte")
        return 0

    def adj_byte(cc: int2, dv: int):
        fatal("propmap_chunk: unimplemented adj_byte")
        return

    def serialize(D: binary_editor):
        D.write_string("pmc0")
        serialize_bb2i(D, bounds)

    def deserialize(D: binary_editor) -> string?:
        let hd = D.read_string(4)
        guard hd == "pmc0":
            return "propmap_chunk.deserialize: bad magic @ {D.offset}"
        bounds = deserialize_bb2i(D) 
        return nil

// Base of property maps that has common functions.
// NB definitely some shared logic with how chunks are managed with the grid_layer
//    code, but unsure if it's enough to be worth pulling out.
class propmap_base:
    chunks: [propmap_chunk]
    chunk_dims: int2

    // Union of bounds of all of the chunks.  Updated as chunks are
    // added and removed.
    bounds: aabb2i

    def serialize(D: binary_editor):
        D.write_string("pmb0")
        D.write_vertex2i(chunk_dims)
        D.write_array(chunks) c:
            c.serialize(D)
        serialize_bb2i(D, bounds)

    def deserialize(D: binary_editor) -> string?:
        let magic = D.read_string(4)
        guard magic == "pmb0":
            return "promap_base.deserialize: bad magic @ {D.offset}"
        chunk_dims = D.read_vertex2i()
        chunks = D.read_array():
            let c = new_chunk(aabb2i{int2_0, -int2_1})
            let err = c.deserialize(D)
            if err:
                return err
            else:
                c    
        bounds = deserialize_bb2i(D)
        return nil

    // Override: to create the correct chunk type
    def new_chunk(bb: aabb2i) -> propmap_chunk:
        return propmap_chunk{bb}


    def find_existing_chunk(cc: int2) -> propmap_chunk?:
        let i = find(chunks): _.bounds.contains(cc)
        if i >= 0:
            return chunks[i]
        return nil

    // Unconditionally creates a new chunk for the given location.
    def new_chunk_containing(cc: int2) -> propmap_chunk:
        // quantitize chunk positions, never want overlapping chunks
        let tl = (cc / chunk_dims) * chunk_dims
        let ch = new_chunk(aabb2i{tl, tl+chunk_dims-1})
        bounds = bounds.union(ch.bounds)
        push(chunks, ch)
        return ch
    
    // Returns the chunk for the given grid coordinate, creating one
    // if none exists.
    def chunk_for(cc: int2) -> propmap_chunk:
        if bounds.contains(cc):
            let ch = find_existing_chunk(cc)
            if ch:
                return ch

        return new_chunk_containing(cc)

//
// Map from cell coordinate to a bit.

class propmap_bit_chunk: propmap_chunk
    data: string

    def serialize(D: binary_editor):
        D.write_string("pbc0")
        super serialize(D)
        write_rle_bytes(D, data)

    def deserialize(D: binary_editor) -> string?:
        let magic = D.read_string(4)
        guard magic == "pbc0":
            return "propmap_bit_chunk.deserialize: bad magic @ {D.offset}"
        let err = super deserialize(D)
        if err: 
            return err
        data = D.read_rle_bytes(bounds.area)
        return nil

    // Returns index and mask for the bit for the given coordinate.
    // It assumes p is in bounds, undefined if it is not.
    def index_and_mask(cc: int2) -> int, int:
        let pi = cc.x + cc.y*bounds.width
        let ix = pi / 8
        let mask = 1 << (pi % 8) 
        return ix, mask

    // Returns non-zero if the bit for the given coordinate is set.
    // Does not bounds check.
    def is_set(cc: int2) -> bool:
        let ix, mask = index_and_mask(cc)
        return data[ix]&mask != 0

    def set(cc: int2):
        let ix, mask = index_and_mask(cc)
        write_int8_le(data, ix, data[ix] | mask)

    def clear(cc: int2):
        let ix, mask = index_and_mask(cc)
        write_int8_le(data, ix, data[ix] & ~mask)


constructor propmap_bit_chunk(bb: aabb2i, default_value: bool):
    let b = if default_value: 0xff else: 0x00
    return propmap_bit_chunk{
        bounds: bb,
        data: ensure_size("", 1+bb.area/8, b)
    }
    
class propmap_bits: propmap_base
    // What to return for unset areas.  Do not want queries creating
    // a bunch of "empty" chunks.
    default_value: bool

    def new_chunk(bb: aabb2i) -> propmap_chunk:
        return propmap_bit_chunk(bb, default_value)

    def serialize(D: binary_editor):
        D.write_string("bit0")
        super serialize(D)
        D.write_byte(if default_value: 1 else: 0)

    def deserialize(D: binary_editor) -> string?:
        let magic = D.read_string(4)
        guard magic == "bit0":
            return "propmap_bits.deserialize: bad magic @ {D.offset}"
        let err = super deserialize(D)
        if err:
            return err
        default_value = if D.read_byte() != 0: true else: false
        return nil

    def is_set(cc: int2) -> bool:
        guard cc.x >= 0 and cc.y >= 0:
            return default_value
        let ch = find_existing_chunk(cc)
        guard ch:
            return default_value
        return ch.is_set(cc)
            
    def set(cc:int2):
        guard cc.x >= 0 and cc.y >= 0
        let ch = find_existing_chunk(cc)
        if ch:
            ch.set(cc)
        else:
            // only create a new chunk if the default_value requires it
            if not default_value:
                let chn = new_chunk_containing(cc)
                chn.set(cc)

    def clear(cc:int2):
        guard cc.x >= 0 and cc.y >= 0
        let ch = find_existing_chunk(cc)
        if ch:
            ch.clear(cc)
        else:
            // only create a new chunk if the default_value requires it
            if default_value:
                let chn = new_chunk_containing(cc)
                chn.clear(cc)

    // Clears the map to all coordiantes returning "val".
    def clear(val: bool):
        default_value = val
        chunks = []
        bounds = aabb2i{int2_0,-int2_1}

constructor propmap_bits(chunk_dims: int2, defval: bool) -> propmap_bits:
    return propmap_bits{
       chunk_dims: chunk_dims, 
       default_value: defval, 
       chunks: [], 
       bounds: aabb2i{int2_0, -int2_1}}

// Mapping from a cell coordinate to a byte value.
class propmap_byte_chunk: propmap_chunk
    data: string

    def serialize(D: binary_editor):
        D.write_string("byc0")
        super serialize(D)
        D.write_rle_bytes(data)

    def deserialize(D: binary_editor) -> string?:
        let magic = D.read_string(4)
        guard magic == "byc0":
            return "propmap_byte_chunk.deserialize: bad magic @ {D.offset}"
        let err = super deserialize(D)
        if err:
            return err
        data = D.read_rle_bytes(bounds.area)
        return nil

    // Returns index of the given coordinate.  Assumes the coordinates are
    // in bounds.
    def index(cc: int2) -> int:
        return cc.x + cc.y*bounds.width

    def get_byte(cc: int2) -> int:
        return data[index(cc)]

    def set_byte(cc: int2, v: int):
        write_int8_le(data, index(cc), v)

    def adj_byte(cc: int2, dv: int):
        let i = index(cc)
        let v = data[i]
        write_int8_le(data, i, clamp(v+dv, 0, 255))

constructor propmap_byte_chunk(bb: aabb2i, default_value: int):
    return propmap_byte_chunk{bounds: bb, 
                              data: ensure_size("", bb.area, default_value)}
 
class propmap_bytes: propmap_base
    default_value: int  // 0-255

    def new_chunk(bb: aabb2i) -> propmap_chunk:
        return propmap_byte_chunk(bb, default_value)

    def serialize(D: binary_editor):
        D.write_string("pby0")
        super serialize(D)
        D.write_byte(default_value)

    def deserialize(D: binary_editor) -> string?:
        let magic = D.read_string(4)
        guard magic == "pby0":
            return "propmap_bytes.deserialize: bad magic @ {D.offset}"
        let err = super deserialize(D)
        if err:
            return err
        default_value = D.read_byte()
        return nil

    def get_byte(cc: int2) -> int:
        guard cc.x >= 0 and cc.y >= 0:
            return default_value
        let ch = find_existing_chunk(cc)
        if ch:
            return ch.get_byte(cc)
        else:
            return default_value

    def set_byte(cc: int2, v: int):
        guard cc.x >= 0 and cc.y >= 0
        let ch = find_existing_chunk(cc)
        if ch:
            ch.set_byte(cc, v)
        elif v != default_value:
            let chn = new_chunk_containing(cc)
            chn.set_byte(cc, v)

    // Adds dv to the value at cc.  Result gets saturated to 0,255.
    def adj_byte(cc: int2, dv: int):
        guard cc.x >= 0 and cc.y >= 0
        let ch = find_existing_chunk(cc)
        if ch:
            ch.adj_byte(cc, dv)
        else:
            let chn = new_chunk_containing(cc)
            chn.adj_byte(cc, dv)

    def clear(defval: int):
        default_value = defval
        chunks = []
    
constructor propmap_bytes(chunk_dims: int2, defval: int):
    return propmap_bytes{
        chunk_dims: chunk_dims, 
        default_value: defval, 
        chunks: [],
        bounds: aabb2i{int2_0, -int2_1}}
