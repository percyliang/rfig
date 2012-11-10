def centeredOverlay(*objs); overlay(*objs).pivot(0, 0) end # DEPRECATED: use overlay(...).center

def staggeredOverlay(replace, *objs); stagger({:sticky => (not replace)}, *objs) end
