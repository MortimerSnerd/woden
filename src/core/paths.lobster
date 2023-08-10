// simple path handling functions.

// Splits path into dir, basename pair.  Can return '' for the dir if 
// it is just a filename.
def path_split(path: string) -> string, string:
   let dpt = find_reverse(path): _ == '/'


   if dpt < 0:
      return "", path
   else:
      return substring(path, 0, dpt), substring(path, dpt+1, -1)


// Given a bare filename, splits it into base_name, extension.
// Can return '' if there's no extension.
def path_split_extension(path: string) -> string, string:
   let dpt = find_reverse(path): _ == '.'

   if dpt < 0:
      return path, ""
   else:
      return substring(path, 0, dpt), substring(path, dpt+1, -1)



