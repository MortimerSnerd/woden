// 3d models via iqm, with the internals exposed for attachments to the 
// models, and skeletons. 
import core.aabb
import core.arrays
import core.matrix
import core.paths

import data.binary
import data.iqmfile
import data.meshbuilder

class anim_info:
    name: string
    first_frame: int
    num_frames: int
    frame_rate: float
    flags: int   //TODO some constants we didn't put in iqmfile?

// Data from iqm_bounds
struct model_bounds:
    bb: aabb3f
    xy_radius: float
    radius: float

// Holds global immutable data loaded from a IQM file.  Typically would
// keep just one of these per unique IQM file.
class collider_attachment
class model_data:
    meshes = [] :: resource<mesh>

    // Flat representation of the frames, where there are 3 xyzw for each joint.
    // Convenient for shader upload, and frame interpolation.
    flat_frames = [] :: [float4]

    // One per frame.
    bounds = [] :: model_bounds

    // Same frame data as flat_frames, but in a form convenient for 
    // calulations in lobster.
    frames = [] :: mat3x4
    
    // Kept only to ensure texture lifetime.
    textures = [] :: resource<texture>
    
    animations = [] :: anim_info
    colliders = [] :: collider_attachment

    // (re)populates this model_data from the given iqm file.
    // Creates the meshes, and loads the referenced textures.
    def load(model: iqm_file):
        assert model.loaded
        frames = gen_iqm_frame_transforms(model)
        flat_frames = iqm_to_uniform_array(model, frames)
        colliders = load_collider_extensions(model)

        for(model.bounds) b:
            push(bounds, model_bounds{aabb3f{b.bbmin, b.bbmax}, b.xyradius, b.radius})

        for(model.anims) a:
            push(animations, anim_info{name: model.string_for_offset(a.name), 
                                       first_frame: a.first_frame, 
                                       num_frames: a.num_frames,
                                       frame_rate: a.frame_rate, 
                                       flags: a.flags})

        // Initial geometry and mesh
        let m0ind = array_copy_sub(model.triangles, model.meshes[0].first_triangle*3,
                                   model.meshes[0].num_triangles*3)
        let m0 = gl.new_mesh_ext("PNTCWI", model.vertices.pos, 
                                 model.vertices.color, model.vertices.norm,
                                 model.vertices.texcoord, [],
                                 model.vertices.blend_indexes, 
                                 model.vertices.blend_weights, m0ind)
        meshes = [m0]
    
        // And the rest of the meshes that share vertices with m0
        for(length(model.meshes)-1) mi:
            let mesh = model.meshes[mi+1]
            let ind = array_copy_sub(model.triangles, model.meshes[mi+1].first_triangle*3,
                                     model.meshes[mi+1].num_triangles*3)
            gl.new_mesh_part(m0, model.string_for_offset(mesh.name), ind)

        textures = get_mesh_textures(model)
        for(length(model.meshes)) i:
            gl.set_mesh_texture(m0, i, 0, textures[i])

    
// Per-instance model animation state.
class model_anim_state:
    model: model_data
    anim_ix: int
    frame = 0.0

    def update(d_t: float):
        if anim_ix < length(model.animations):
            frame += d_t * model.animations[anim_ix].frame_rate

    // Sets relative frame number within the animation.
    // 0 .. anim.num_frames-1
    def set_frame(fno: int):
        frame = float(fno)

    // Interpolates frames for a real frame number, and returns a bone array
    // for the interpolation.
    def interpolate() -> [float4]:
        frame_interpolation() f0, f1, frac:
            if f0 != f1:
               let rv = vector_capacity([], length(model.flat_frames[f0]))
               for(model.flat_frames[f0]) v, i:
                  push(rv, lerp(v, model.flat_frames[f1][i], frac))
               return rv
            else:
               return model.flat_frames[f0]
        return []

    // Gets interpolated model bounds xy_radius for the current frame.
    def xy_radius() -> float:
        frame_interpolation() f0, f1, frac:
            return slerp(model.bounds[f0].xy_radius, model.bounds[f1].xy_radius, frac)

    // Calls body with f0, f1, frac for the current frame number, to 
    // allow the body to slerp between model data.
    def frame_interpolation(body):
       if anim_ix < length(model.animations):
           let anim = model.animations[anim_ix]
           let f0 = int(floor(frame)) % anim.num_frames + anim.first_frame
           let f1 = int(ceiling(frame) % anim.num_frames) + anim.first_frame
           let frac =  frame - floor(frame)    
           body(f0, f1, frac)


// Extension name we use for IQM extension fields.
let COLL_EXT_NAME = "COLLIDE1"

// Data representation for a capsule that is attached to a joint
// in a model.  The positions are for the model in the default pose, 
// and can be can be pre-multiplied with the frame joint translations.
// ie: point * transform, not transform * point.
class collider_attachment:
    name = ""
    joint  = -1
    // start to start+extent goes from tip to tip of the capsule.
    // Not from centers of the capping sphere like c_capsule does it.
    start  = float3_0
    extent = float3_0
    radius = 0.0
    mesh   = nil :: resource<mesh>

    // Write binary rep.  This is used when saving this as a IQM extension.
    def write(model: iqm_file, D: binary_editor):
        let no = model.add_string(name)
        D.write_uint32(no)
        D.write_uint32(joint)
        D.write_vertex3f(start)
        D.write_vertex3f(extent)
        D.write_float32(radius)

    // Reads the binary rep written by write()
    def read(model: iqm_file, D: binary_editor):
        let no = D.read_uint32()
        name = model.string_for_offset(no)
        joint = D.read_uint32()
        start = D.read_vertex3f()
        extent = D.read_vertex3f()
        radius = D.read_float32()

    def rotate_around_start(axis: float3, d_ang: float):
        let q = mk_quat(axis, d_ang)
        extent = q.normalize_q().transform(extent)

    def rotate_around_center(axis: float3, d_ang: float):
        let q = mk_quat(axis, d_ang)
        let c = start + extent*0.5
        let s_p = q.transform(start - c) + c
        let e_p = q.transform(start+extent - c) + c
        start = s_p
        extent = e_p - s_p
         
    def translate(v: float3):
        start += v

    def change_length_by(d: float):
        let ev = normalize(extent)
        let nlen = d + magnitude(extent)
        if nlen >= 2.0*radius:
            extent = ev*nlen
        mesh = nil

    def change_radius_by(d: float):
        let evmag = magnitude(extent)
        let new_r = radius + d

        if new_r > 1.0e-4:
            if evmag < 2.0*new_r:
                change_length_by(2.0*new_r - evmag)
            radius = new_r
            mesh = nil

    def slide_by(d: float):
        start += extent*d

    // Instantiates a capsule mesh, and renders it in the collider
    def debug_render_mesh(bone_trans: mat3x4):
        if not mesh:
            let mb = mesh_builder{}
            let ht = magnitude(extent)
            build_capsule_indexed(mb, float3_0, radius, ht)
            mesh = mb.make_mesh_indexed("PNC")    
        if mesh:
            let p0 = bone_trans.pre_mult(xyzw(start, 1.0))
            let p1 = bone_trans.pre_mult(xyzw(start+extent, 1.0))
            let t_extent = p1 - p0
            gl.translate(p1):
                if (t_extent.x != 0.0 or t_extent.y != 0.0):
                    let qr = mk_quat_from_vectors(t_extent, float3_z)
                    let axis, ang = qr.decompose()
                    gl.rotate(axis, sincos(ang)):
                        gl.render_mesh(mesh)
                else:
                    gl.render_mesh(mesh)
            //gl.line(p0, p1, 0.1)

// Looks for collider extensions in the iqm_file, and if found, loads and
// returns them.
def load_collider_extensions(model: iqm_file) -> [collider_attachment]:
    let ext_name = model.string_to_offset(COLL_EXT_NAME)
    let ci = find(model.extensions): _.name == ext_name
    if ci < 0:
        return []

    let rv = []
    let D = binary_editor{data: model.extensions[ci].data}
    let n_coll = D.read_uint32()
    for(n_coll):
        let cc = collider_attachment{}
        cc.read(model, D)
        push(rv, cc) 

    return rv

// Given a list of collider attachments, adds them as a extension to the given
// iqm file.
def save_collider_extensions(model: iqm_file, cs: [collider_attachment]):
    let cname = model.add_string(COLL_EXT_NAME)
    model.extensions = filter(model.extensions): _.name != cname
    if length(cs) > 0:
        let ext = iqm_extension{name: cname}
        let D = binary_editor{data: ext.data}
        D.write_uint32(length(cs))
        for(cs) cc:
            cc.write(model, D)
        ext.data = substring(D.data, 0, D.offset)
        ext.num_data = D.offset
        push(model.extensions, ext)

// Helper for loader to pick a texture from mesh or mesh material names.
private def get_mesh_textures(model: iqm_file) -> [resource<texture>]:
    let rv = []
    def pathed(s):
        var nm = s
        if nm != "" and nm[length(nm)-1] == '/':
            nm = substring(nm, 0, length(nm)-1)
        var p = "dist/{nm}"
        let _bn, ext = path_split_extension(nm)
        if ext == "":
            p += ".png"
        return p

    def gett(m):
        //TODO should use load_tx from texture module, but need a way to 
        //     use it where we know if it failed, or where we can pass a 
        //     list of names to try.
        if m.material != 0:
            let p_m = pathed(model.string_for_offset(m.material))
            let m_t = gl.load_texture(p_m)
            if m_t:
                return m_t
        if m.name != 0:
            let p_n = pathed(model.string_for_offset(m.name))
            let n_t = gl.load_texture(p_n)
            if n_t:
                return n_t

        let backup = pathed("NONESUCH")
        let b_t = gl.load_texture(backup)
        if b_t:
            return b_t

        fatal("Could not load even backup texture {backup}")
        return from program

    for(model.meshes) m:
        push(rv, gett(m))

    return rv

