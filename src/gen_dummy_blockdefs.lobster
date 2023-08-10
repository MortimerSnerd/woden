// Creates dummy blockdefs entries for everything under dist/images.
import core.algs

let base_dir = "dist/images"

def build_reldir(dir, n):
    if dir == base_dir:
        return n
    else:
        return substring(dir, length(base_dir)+1, -1) + "/" + n
    
def process_dir(dir: string) -> void:
    let names, sizes = scan_folder(dir, true)
    guard names and sizes
    let dirs = []
    for(names) n, i:
        if sizes[i] < 0:
            push(dirs, n)
        else:
            if ends_with(n, ".png"):
                var ent = "BLK \"{build_reldir(dir, n)}\" "
                if find_string(n, "wall") >= 0:
                    ent += "solid,opaque,"
                if find_string(dir, "item") >= 0 or find_string(dir, "player") >= 0:
                    ent += "alpha"
                print(ent)

    for(dirs) d:
        process_dir(dir + "/" + d)

process_dir(base_dir)
