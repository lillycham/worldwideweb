"""Write the long static texts of a NeXT nib's panels to a property list.

Usage: nibtexts.py data.nib out.plist

The result maps each window title to a list of its longer text fields
(more than 60 characters), in the order they appear in the window.
"""
import sys, plistlib, runpy
spec = runpy.run_path(__file__.replace('nibtexts.py', 'nibspec.py'),
                      run_name='nibtexts')          # Reuse its helpers
out = {}
for w in spec['all_of']('WindowTemplate'):
    f = spec['flat'](w)
    title = spec['s'](f[8])
    texts = []
    def visit(o):
        if spec['cname'](o) == 'TextField':
            t = spec['textof'](o)
            if t and len(t) > 60: texts.append(t)
        for sv in spec['subviews'](o):
            if isinstance(sv, spec['GenericArchivedObject']): visit(sv)
    visit(f[11])
    if texts: out[title] = texts
with open(sys.argv[2], 'wb') as fp: plistlib.dump(out, fp)
print({k: [len(t) for t in v] for k, v in out.items()})
