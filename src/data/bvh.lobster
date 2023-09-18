// Parsing support for BVH motion capture files.
import core.lexbase
import core.matrix

enum anim_channels:
    Xposition, Yposition, Zposition, 
    Xrotation, Yrotation, Zrotation

let anim_channel_names = map(6): string(anim_channels(_))

class bvh_joint:
    parent = -1
    children = [] :: int
    channels = [] :: anim_channels
    n_channels = 0
    name = ""
    offset = float3_0
    end_site = float3_0  // set if the joint has no children, to get a joint length
    frame_offset = 0  // calculated offset of the joint from beginning of frame data

    def base_transform() -> mat4x4:
        return mat4x4_translation(offset)

    // Endpoint offset used when drawing as a bone.
    def endpoint_offset(joints: [bvh_joint]) -> float3:
        if length(children):
            return joints[children[0]].offset
        else:
            return end_site

class bvh_file:
    joints = [] :: bvh_joint
    n_frames = 0
    frame_time = 0.0
    channels_per_frame = 0
    // same ordering as in the file, for every frame there are channels_per_frame
    // floats grouped together. 
    motion_data = [] :: float

    // Pass frame < 0 to get base transform.
    def joint_transform(jix: int, frame: int) -> mat4x4:
        assert(frame < n_frames)
        let j = joints[jix]
        var i = frame * channels_per_frame + j.frame_offset
        var m = j.base_transform()
        if frame >= 0:
            for(j.channels) ch:
                let d = motion_data[i]
                i++
                switch ch:
                    case Xposition:
                        m.col3 += float4_x*d
                    case Yposition:
                        m.col3 += float4_y*d
                    case Zposition: 
                        m.col3 += float4_z*d
                    //TODO there may be a hidden problem that makes me use -d
                    //   for the rotation transforms.
                    case Xrotation:
                        let r = rotation_4x4(float3_x, -d)
                        m = m * r
                    case Yrotation:
                        let r = rotation_4x4(float3_y, -d)
                        m = m * r
                    case Zrotation:
                        let r = rotation_4x4(float3_z, -d)
                        m = m * r
        return m

    def interpolated_transform(jix: int, frame: float) -> mat4x4:
        let f0 = floor(frame) % n_frames
        let f1 = ceiling(frame) % n_frames
        if f0 == f1:
            return joint_transform(jix, f0)
        else:
            let m0 = joint_transform(jix, f0)
            let m1 = joint_transform(jix, f1)
            let fac = float(f1) - frame
            return mat4x4{lerp(m0.col0, m1.col0, fac), 
                          lerp(m0.col1, m1.col1, fac),
                          lerp(m0.col2, m1.col2, fac),
                          lerp(m0.col3, m1.col3, fac)}
         
    def draw_debug_skeleton(frame: float, thickness = 0.1): 
        def draw_hier(jix, m) -> void:
            let jm = m * interpolated_transform(jix, frame)
            //let jm = m * joint_transform(jix, floor(frame))
            let jp = xyz(jm * float4_w)
            let np = xyz(jm * vec4(joints[jix].endpoint_offset(joints), 1.0))
            gl.line(jp, np, thickness)
            for(joints[jix].children) chix:
                draw_hier(chix, jm)

        draw_hier(0, mat4x4_identity())
        

def parse_bvh_file(fname: string) -> string?, bvh_file:
    let rv = bvh_file{}

    let bytes = read_file(fname)
    if bytes:
        let err = parse_bvh_data(rv, fname, bytes)
        return err, rv
    else:
        return "parse_bvh_file: could not open file {fname}", rv

def parse_bvh_data(file: bvh_file, fname: string, bytes: string) -> string?:
    let L = lex_base{buf: bytes, srcname: fname}    
    
    def report(msg):
        return L.format_error("parse_bvh_data", msg) from parse_bvh_data

    def word():
        L.skip_ws()
        if L.at_eof():
            report("expecting word, but got EOF")
        else: 
            let start = L.p
            let c = L.cur_char()
            if is_alpha_ascii(c):
                L.p++
                L.skip_while(): _ == '_' or is_num_ascii(_) or is_alpha_ascii(_)
                let end = L.p
                L.skip_ws()
                return substring(L.buf, start, end - start)
            else:
                report("expecting word, but got \'{unicode_to_string([c])}\'")
        return ""

    def keyword(k):
        L.ignore_ws():
            L.expect_word(k): report(_)

    def skip_space():
        // space, not newlines.
        L.skip_while(): _ == ' ' or _ == '\t'

    def parse_offset():
        skip_space()
        let x = L.expect_float(): report(_)
        skip_space()
        let y = L.expect_float(): report(_)
        skip_space()
        let z = L.expect_float(): report(_)
        skip_space()
        return float3{x, y, z}

    def parse_joint(parent) -> int:
        let rv = bvh_joint{parent: parent}
        let my_ix = length(file.joints)
        push(file.joints, rv)

        if parent == -1:
            keyword "ROOT"

        rv.name = word()
        L.expect('{'): report(_)
        L.skip_ws()
        while L.chars_left() and L.char() != '}':
            if L.matched_word("OFFSET"):
                rv.offset = parse_offset()
            elif L.matched_word("CHANNELS"):
                skip_space()
                rv.n_channels = L.expect_int(): report(_)
                for(rv.n_channels):
                    skip_space()
                    let w = word()
                    let i = find(anim_channel_names): w == _
                    
                    if i >= 0:
                        push(rv.channels, anim_channels(i))
                    else:
                        report("unknown channel name {w}")
            elif L.matched_word("JOINT"):
                let child = parse_joint(my_ix)
                push(rv.children, child)
            elif L.matched_word("End"):
                keyword "Site"
                L.ignore_ws(): L.expect('{'): report(_)
                keyword "OFFSET"
                rv.end_site = parse_offset()
                L.ignore_ws(): L.expect('}'): report(_)
            else:
                let w = word()
                report("Unknown joint keyword {w}")
            L.skip_ws()
        L.expect('}'): report(_)
        return my_ix

    keyword "HIERARCHY"
    parse_joint(-1)
    file.channels_per_frame = fold(map(file.joints) j: length(j.channels), 0) a, b: a + b
    var foff = 0
    for(file.joints) j:
       j.frame_offset = foff
       foff += length(j.channels) 

    keyword "MOTION"
    keyword "Frames:"
    file.n_frames = L.expect_int(): report(_)
    L.skip_ws()
    keyword "Frame Time:"
    file.frame_time = L.expect_float(): report(_)
    L.skip_ws()

    for(file.n_frames):
        for(file.channels_per_frame):
            skip_space()
            push(file.motion_data, L.expect_float(): report(_))
        skip_space()
        if not L.ate_eol():
            report("expected EOL at frame boundary of motion data channels_per_frame={file.channels_per_frame}")
   
    print("FILUS {file}")
    print("names = {map(file.joints): _.name}")
    return nil

