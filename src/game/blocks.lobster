// Contains info on all known block types, keeping an atlas for all block images.
// Block info is kept in an array, and is referenced by index.
// All information is parsed from a file.
import texture

import core.lexbase
import core.rects

import data.atlas
import data.binary
import data.targa

private let ATLAS_DIM=1024

// Page textures, referenced by block_info.pageno
var BLOCK_PAGES = [] :: resource<texture>

// texcoords indexed by block index.
var blk_texcoords = [] :: float4 // {tlx, tly, brx, bry}
// Atlas page number for a given block index, refers to BLOCK_PAGES textures.
var blk_page_no = [] :: int
// Flags for a given block index.
var blk_flags = [] :: int
// The image name the block image came from
var blk_img_name = [] :: string
// size of the image
var blk_img_size = [] :: int2

// flags for blk_flags
enum_flags block_flags:
    bf_solid    // can't walk on it
    bf_opaque    // blocks light
    bf_alpha     // not solid
    bf_split4    // Split floor sized tile into wall sized tiles

// Returns block index by image name.  Returns <0 if not found.
def block_index_for(img: string) -> int:
    let i = find(blk_img_name): _ == img
    return i

def is_valid_block(ix: int) -> bool:
    return ix >= 0 and ix < length(blk_page_no)

// Block information, used in the defs file in dist.
private class BLK:
    // Name of loose image, with no path.
    image: string
    flags: int
    splitno = -1

private def parse_blockdefs(s: string) -> string?, [BLK]:
    let L = lex_base{buf: s, srcname: "dist/blockdefs"}
    let rv = []

    def report(msg):
        return L.format_error("load_blockdefs", msg), [] from parse_blockdefs

    def skip_spaces():
        L.skip_while() c: c == ' ' or c == '\t'

    while L.chars_left() and L.char() != 0:
        skip_spaces()
        L.expect_word("BLK") msg:
            report(msg)
        skip_spaces()
        let img = L.expect_string() msg:
            report(msg)
        skip_spaces()

        var flags = 0
        while L.chars_left() and not L.ate_eol():
            skip_spaces()
            if L.matched_word(","):
                pass()
            elif L.matched_word("solid"):
                flags |= bf_solid
            elif L.matched_word("opaque"):
                flags |= bf_opaque
            elif L.matched_word("alpha"):
                flags |= bf_alpha
            elif L.matched_word("split4"):
                flags |= bf_split4
            else:
                report("was expecting block flags [solid|opaque|alpha|split4]*")
            skip_spaces()

        if flags.has(bf_split4):
            // Push in separate entries for the split4 blocks.
            for(4*4) n:
                push(rv, BLK{img, flags&~bf_split4, splitno: n})
        else:
            push(rv, BLK{img, flags})

    return nil, rv
            
private let blkdefs_file = "dist/blockdefs"

let blocks_tx_format = texture_format_nearest_mag | texture_format_nearest_min | texture_format_nomipmap

// Called after gl.new_window to load block definitions and images.
// Can be called more than once.  Returns nil on success, or an 
// error message otherwise.  This can modify the current shader and modelview.

def load_blockdefs() -> string?:
    let ld_err = read_blockdefs("{blkdefs_file}.bin")
    if not ld_err:
        // Read the binary version, all done.
        return nil

    print("load_blockdefs: failed loading binary version, re-building: {ld_err}")

    let dcontents = read_file(blkdefs_file)
    if not dcontents:
        return "load_blockdefs: Could not open file {blkdefs_file}"

    let err, blks = parse_blockdefs(dcontents)
    if err:
        return "load_blockdefs: error loading defs file: " + err

    let txs = []
    let athand = []
    let bld = mk_atlas_builder(int2{ATLAS_DIM,ATLAS_DIM})

    // Do texture loading and atlas placement first
    for(blks) b:
        //TODO reloading the same texture repeatedly for splitno defs here
        let file = "dist/images/{b.image}"
        let tx = gl.load_texture(file, blocks_tx_format)
        if not tx:
            return "load_blockdefs: could not load {file}"

        var dims = gl.texture_size(tx)
        if b.splitno >= 0:
            dims = dims / 4

        let aerr, handle = bld.add(dims)
        if aerr:
            return "load_blockdefs: atlas failure: {aerr}"
        push(athand, handle)
        push(txs, tx)
    bld.place_images()

    blk_texcoords = []
    blk_page_no = []
    blk_flags = []
    blk_img_name = []
    blk_img_size = []

    // Populate the atlas images with our texture collection.
    BLOCK_PAGES = map(bld.num_pages()): 
                     gl.create_blank_texture(int3{ATLAS_DIM, ATLAS_DIM, 1}, blocks_tx_format)

    // NB: doing this with render_to_texture is ugly, but maybe not as ugly
    //     as doing manual blits in a big string of image data.
    gl.set_shader("textured")
    for(bld.num_pages) pg:
        render_to_texture(BLOCK_PAGES[pg], int2{ATLAS_DIM, ATLAS_DIM}, false, nil, 
                          blocks_tx_format):
            gl.ortho()
            gl.color(color_white)
            for(length(txs)) i:
                let rpage, trect = bld.rect_for(athand[i])
                if pg == rpage:
                    gl.set_primitive_texture(0, txs[i])
                    var tc_tl = float2_0
                    var tc_sz = float2_1
                    if blks[i].splitno >= 0:
                        // figure out texture coords from number 
                        // column 
                        let row = float(blks[i].splitno / 4)
                        let col = float(blks[i].splitno % 4)
                        tc_tl = float2_1*float2{col,row}*0.25
                        tc_sz = float2_1*0.25

                    //TODO extrude border around items
                    gl.translate(float(trect.top_left)):
                        gl.rect_tc_col(float(trect.extent), tc_tl, tc_sz, [])
                    

    // Finally, fill out arrays.
    let fdim = float(ATLAS_DIM)
    let hapx = 0.0/fdim
    for(blks) b, i:
        let pg, trect = bld.rect_for(athand[i])
        if b.splitno >= 0:
            push(blk_img_name, b.image + "|{b.splitno}")
            push(blk_img_size, gl.texture_size(txs[i]) / 4)
        else:
            push(blk_img_name, b.image)
            push(blk_img_size, gl.texture_size(txs[i]))
        push(blk_page_no, pg)

        let tlx = float(trect.top_left.x)/fdim + hapx
        let tly = float(trect.top_left.y)/fdim + hapx
        let brx = float(trect.bottom_right.x)/fdim - hapx
        let bry = float(trect.bottom_right.y)/fdim - hapx
        // NB -1 on y coords for flipped texture
        push(blk_texcoords, float4{tlx, 1.0-tly, brx, 1.0 - bry})
                                
        push(blk_flags, b.flags)
            

    let sv_err = save_blockdefs("{blkdefs_file}.bin")
    if sv_err:
        print("load_blockdefs: failed to save rebuilt blockdefs")

    return nil

private def read_blockdefs(fname: string) -> string?:
    let contents = read_file(fname)
    guard contents:
        return "read_blockdefs: could not load {fname}"

    let D = binary_editor{data: contents, offset: 0}
    let ver = D.read_string(4)
    guard ver == "blk0":
        return "read_blockdefs: bad magic"

    let npages = D.read_int32()
    guard npages > 0:
        return "read_blockdefs: bad page count {npages}"

    BLOCK_PAGES = []
    for(npages) p:
        let afname = "dist/atlas{p}.tga"
        let tx = gl.load_texture(afname, blocks_tx_format)
        guard tx:
            return "read_blockdefs: could not load texture {afname}"
        push(BLOCK_PAGES, tx)

    blk_texcoords = D.read_array():
        D.read_vertex4f()

    blk_page_no = D.read_array():
        D.read_byte()

    blk_flags = D.read_array():
        D.read_int64()

    blk_img_name = D.read_array():
        D.read_string0()

    blk_img_size = D.read_array():
        D.read_vertex2i()    

    guard D.read_string(4) == "eblk":
        return "read_blockdefs: bad end tag"

    return nil

private def save_blockdefs(fname: string) -> string?:
    // Save out page images first, as that's the most likely failure.
    for(BLOCK_PAGES) tx, pg_no:
        let pxdat = gl.read_texture(tx)
        guard pxdat:
            return "save_blockdefs: failed reading texture for page {pg_no}"

        let targ = binary_editor{data: ensure_size("", TARGA_HEADER_SIZE + ATLAS_DIM*ATLAS_DIM*4, 0)}
        write_targa_header(targ, targa_opts{width: ATLAS_DIM, height: ATLAS_DIM, bpp: 32, 
                                            bottom_to_top: true})
        write_pixels_from_texture(targ, pxdat, true)
        if not write_file("dist/atlas{pg_no}.tga", targ.data):
            return "save_blockdefs: failed writing file for page {pg_no}"

    // Now for the actual defs.
    let D = binary_editor{}

    D.write_string("blk0")  // version 0
    D.write_int32(length(BLOCK_PAGES))

    D.write_array(blk_texcoords) tc:
        D.write_vertex4f(tc)

    D.write_array(blk_page_no) p:
        D.write_byte(p)

    D.write_array(blk_flags) f:
        D.write_int64(f)

    D.write_array(blk_img_name) n:
        D.write_string0(n)

    D.write_array(blk_img_size) s:
        D.write_vertex2i(s)

    D.write_string("eblk")

    if write_file(fname, substring(D.data, 0, D.offset)):
        return nil
    else:
        return "save_blockdefs: could not write file {fname}"

