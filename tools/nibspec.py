import sys, typedstream
from typedstream.archiving import GenericArchivedObject, TypedGroup

root = typedstream.unarchive_from_file(sys.argv[1] if __name__ == '__main__' else NIB)
if __name__ != '__main__':
    pass                                 # Imported for its helpers

def flat(obj):
    out = []
    def f(v):
        if isinstance(v, TypedGroup):
            for x in v.values: f(x)
        else: out.append(v)
    for g in obj.contents: f(g)
    return out

def cname(o): return o.clazz.name.decode() if isinstance(o, GenericArchivedObject) else type(o).__name__
def chain(o):
    """[(classname, flatvalues)] from most derived to Object."""
    r = []
    while isinstance(o, GenericArchivedObject):
        r.append((cname(o), flat(o))); o = o.super_object
    return r
def part(o, cls):
    for n, v in chain(o):
        if n == cls: return v
    return None
def elems(v): return list(v.elements) if hasattr(v, 'elements') else None
def s(b): return b.decode('latin-1') if isinstance(b, bytes) else b

CELLS = ('Cell','ActionCell','ButtonCell','MenuCell','FormCell','TextFieldCell')
def rect(o):
    v = flat(o)
    if len(v) < 6 or not all(isinstance(x, float) for x in v[2:6]): return None
    return tuple(int(x) for x in v[2:6])
def subviews(o):
    for x in flat(o):
        e = elems(x)
        if e is not None and (not e or cname(e[0]) not in CELLS): return e
    return []
def cell_title(c):
    v = flat(c)
    if cname(c) == 'FormCell':          # The label is in a separate title cell
        for x in v:
            if isinstance(x, GenericArchivedObject) and cname(x) == 'Cell':
                return cell_title(x)
    return s(v[0]) if v and isinstance(v[0], bytes) else None
def key_of(c):
    v = flat(c)
    k = (v[12] >> 8) if len(v) > 12 and isinstance(v[12], int) else 0
    return chr(k) if k > 32 else ''
def cells(o):
    for x in flat(o):
        e = elems(x)
        if e and cname(e[0]) in CELLS: return e
    return []
def textof(o):
    for x in flat(o)[1:]:
        if isinstance(x, GenericArchivedObject) and cname(x) in CELLS: return cell_title(x)
    if cname(o) == 'Text':
        bs = [x for x in flat(o) if isinstance(x, bytes)]
        if bs: return '[text %d bytes]' % len(bs[0])
    return None

def desc(o):
    c = cname(o)
    w = home.get(id(o))
    return desc1(o) + (' @"%s"' % w if w else '')
def desc1(o):
    c = cname(o)
    if c == 'MenuCell': return 'MenuCell "%s"' % cell_title(o)
    if c in ('ButtonCell','FormCell','Cell','TextFieldCell'): return '%s "%s"' % (c, cell_title(o))
    if c == 'CustomObject': return 'Custom<%s>' % s(flat(o)[0])
    if c == 'WindowTemplate': return 'Window "%s"' % s(flat(o)[8])
    if c in ('Form','Matrix'):
        return '%s[%s]' % (c, ', '.join('"%s"' % cell_title(x) for x in cells(o)))
    t = textof(o)
    return '%s%s' % (c, ' "%s"' % t if t else '')

home = {}                                # id(view or cell) -> window title
def dumpview(o, ind, wtitle=None):
    home[id(o)] = wtitle
    for c in cells(o): home[id(c)] = wtitle
    c = cname(o); t = None
    print('%s%s %s' % ('  '*ind, desc(o), rect(o)))
    if c == "Text": return
    for sv in subviews(o):
        if isinstance(sv, GenericArchivedObject): dumpview(sv, ind+1, wtitle)

done = set()
def find(o, cls, acc):
    if id(o) in done: return
    if isinstance(o, GenericArchivedObject):
        done.add(id(o))
        if cname(o) == cls: acc.append(o)
        if o.super_object is not None: find(o.super_object, cls, acc)
        for v in flat(o): find(v, cls, acc)
    elif hasattr(o, 'elements'):
        for x in o.elements: find(x, cls, acc)
    elif isinstance(o, TypedGroup):
        for x in o.values: find(x, cls, acc)
def all_of(cls):
    done.clear(); acc = []; find(root, cls, acc); return acc

if __name__ == '__main__':
  print('=== MENUS ===')
  for m in all_of('MenuTemplate'):
      f = flat(m)
      sup = f[0]
      print('Menu "%s" at (%d,%d) supermenu=%s' % (s(f[3]), f[1], f[2], s(flat(sup)[3]) if sup else None))
      for c in cells(f[4]):
          k = key_of(c)
          print('    %-40s %s' % (cell_title(c), ('Cmd-'+k) if k else ''))

  print('\n=== WINDOWS ===')
  for w in all_of('WindowTemplate'):
      f = flat(w)
      print('\nWindow "%s" class=%s frame=%s style=%s backing=%s mask=%s' % (s(f[8]), s(f[10]), tuple(int(x) for x in f[0:4]), f[4], f[5], f[6]))
      dumpview(f[11], 1, s(f[8]))

  print('\n=== CONNECTIONS ===')
  for cls in ('IBOutletConnector', 'IBControlConnector'):
      for c in all_of(cls):
          f = flat(c)
          src = desc(f[0]) if f[0] is not None else 'FirstResponder'
          dst = desc(f[1]) if f[1] is not None else 'FirstResponder'
          print('%-7s %-55s -> %-40s %s' % ('outlet' if cls[2]=='O' else 'action', src, dst, s(f[2])))
