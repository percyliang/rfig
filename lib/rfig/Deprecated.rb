def centeredOverlay(*objs); overlay(*objs).pivot(0, 0) end # DEPRECTAED: use overlay(...).center

def staggeredOverlay(replace, *objs); stagger({:sticky => (not replace)}, *objs) end
