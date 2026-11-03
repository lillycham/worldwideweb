"""Write out the RTF text stored in Text objects of a NeXT nib.

Usage: nibrtf.py data.nib out.rtf   (writes the first one found)
"""
import sys, typedstream
from typedstream.archiving import GenericArchivedObject, TypedGroup

root = typedstream.unarchive_from_file(sys.argv[1])
seen = set()
def walk(v):
    if id(v) in seen: return None
    seen.add(id(v))
    if hasattr(v, 'elements') and isinstance(v.elements, (bytes, bytearray)):
        v = v.elements                  # A char array, such as [1161c]
    if isinstance(v, (bytes, bytearray)):
        return bytes(v) if bytes(v).startswith(b'{\\rtf') else None
    kids = []
    if isinstance(v, GenericArchivedObject): kids = [v.super_object] + list(v.contents)
    elif isinstance(v, TypedGroup): kids = list(v.values)
    elif hasattr(v, 'elements'): kids = list(v.elements)
    elif hasattr(v, 'contents'): kids = list(v.contents)
    elif hasattr(v, 'value'): kids = [v.value]
    for k in kids:
        r = walk(k)
        if r: return r
    return None
rtf = walk(root)
if not rtf: sys.exit('no RTF found')
open(sys.argv[2], 'wb').write(rtf)
print(len(rtf), 'bytes')
