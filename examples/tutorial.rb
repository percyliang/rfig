#!/usr/bin/ruby

# rfig tutorial
# Percy Liang
# 08/24/07

require 'rfig/Presentation' # version 1.1

l = Latex.new # A handy variable to write latex in Ruby (see below)
initPresentation(
  # Each slide is initially written to a separate PDF
  # (to make incremental changes faster).
  # At the end, write everything to this path.
  :aggregateOutPath => 'tutorial.pdf',
  #:recentOutPath => 'debug.pdf',
  :latexHeader => [
    '\newcommand\half{\frac{1}{2}}',            # Can either write LaTeX...
    l.newCommand('quarter', l.f('frac', 1, 4)), # or use Ruby
  ]
)

############################################################
slide!('',
  center,
  vspace,
  rtable('rfig 1.1 tutorial (incomplete)').center.scale(1.3).bold.color(darkblue),
  _('programming figures/slides in Ruby').color(darkblue),
  cr,
  'Percy Liang',
nil) { |slide| slide.label('title').signature(4).showSlideNum(false) }

############################################################
slide!('Title of the slide goes here',
  'We can start writing text...',
  'Each string starts a new line.',
  center,
  'Let\'s make this centered',
  'Still centered',
  left, 'Back to left justified',
  right, 'Right justified',
  'All text is treated as \LaTeX, so math is easy to do: $\frac{1}{2} - \pi$',
  autowrap(
    'By default, text does not autowrap.',
    'If it is put into an autowrap function',
    'we can make it wrap up to a certain width (10 inches)',
    'and obey a certain orientation (flushfull).').width(u(10)).flushfull,
nil) { |slide| slide.label('text').signature(5) }

############################################################
slide!('Animation',
  'Each slide can produce many PDF pages.',
  'First I appear', pause,
  'I appear on the next slide', pause,
  'and so on...',
nil) { |slide| slide.label('anim').signature(2) }

############################################################
slide!('Animation 2',
  'Another way to animate is to specify the \red{levels}',
  'at which objects appear:',
  _('level 2').level(2),
  _('level 3').level(3),
  _('level 0').level(0),
  _('level 1').level(1),
nil) { |slide| slide.label('anim2').signature(2) }

############################################################
slide!('Transformations',
  'Normal size',
  _('Smaller').scale(0.8),
  _('Rotated').rotate(90),
  _('Slanted').slant(0.2),
  _('The color can be changed').color(blue),
  _('Many transformations can be strung together').xscale(0.7).rotate(10).color(red),
nil) { |slide| slide.label('trans').signature(2) }

############################################################
slide!('Lists',
  itemizeList(
    'Itemized lists are easy to make',
    ['We can also create hierarchical lists:',
      'Sub bullet 1',
      'Sub bullet 2',
    nil],
  nil),
  enumerateList(
    'Now we can number the points',
    'See the numbers increase',
  nil),
nil) { |slide| slide.label('list').signature(1) }

############################################################
slide!('Tables',
  scale(0.7), # Let's make everything on this slide smaller so it'll fit
  'So far, we have just dumped content in a sequential manner.',
  'We would like to format our slides somehow.',
  'There are two ways of doing that: using tables and overlays.',
  cr, # This is a carriage return
  'Here is a basic table:',
  center,
  table(
    ['first row, first column', 'second column'],
    ['second row now', 'last one'],
  nil).border(1),
  left,
  'We can justify the table and remove the border:',
  center,
  table(
    ['aaa', 'd', 'e'],
    ['b', 'ccc', 'fff'],
  nil).cjustify('lcr'), # cjustify stands for column justify
  left,
  'If we want tables with just one row or one column,',
  'we can use the following shorthand:',
  rtable('row 1', 'row 2'),
  ctable('column 1', 'column 2'),
nil) { |slide| slide.label('table').signature(7) }

############################################################
slide!('Overlays',
  'Using overlays, we can place things on top of each other.',
  'The pivot specifies the relative positions',
  'that should be used to align the objects in the overlay.',
  overlay('0 = 1', hedge.color(red).thickness(2)).pivot(0, 0),
  staggeredOverlay(true, # True means that old objects disappear
    'the elements', 'in this', 'overlay should be centered',
  nil).pivot(0, 0), # (x, y)
  cr, pause,
  staggeredOverlay(true,
    'whereas the ones', 'here', 'should be right justified',
  nil).pivot(1, 0), # (x, y): -1 = left, 0 = center, +1 = right
  centeredOverlay(hedge, vedge),
nil) { |slide| slide.label('overlay').signature(8) }

############################################################
slide!(ctable('Formatting the', _('slide').color(green)),
  'We can also change properties of the slide.',
  'Compare this slide',
  'with the others to see what has changed.',
nil) { |slide| slide.label('formatSlide').signature(3).
  titleSpacing(u(0)).
  lineSpacing(u(0.1)).
  leftMargin(u(0)).
  titleHeight(u(0.5)).
  bgColor(dodgerblue).
  footnote('footnote').
  border(5).borderColor(black)
}

############################################################
slide!('Graphics',
  scale(0.8),
  'We can integrate figures into our slides fairly easily.',
  ctable('Here is a circle:', circle(u(1)).color(blue).fill),
  ctable('We can draw an arrow:', leftarrow),
  'We can go low-level and specify absolute positions:',
  overlay(
    circle(u(0.5)), # A circle centered at the origin
    circle(u(0.5)).shift(upair(0, 1)), # A circle that has been shifted to (0, 1)
    circle(u(0.5)).shift(upair(2, 0)), # A circle that has been shifted to (2, 0)
    circle(u(0.5)).shift(upair(2, 1)), # A circle that has been shifted to (2, 1)
    rectllur(upair(0, 0), upair(2, 1)), # A rectangle
  nil),
  'However, it\'s much cleaner and modular to use tables when possible:',
  table(
    [circle(u(0.5)), circle(u(0.5))],
    [circle(u(0.5)), circle(u(0.5))],
  nil).rmargin(u(0.5)).cmargin(u(1)),
nil) { |slide| slide.label('graphics').signature(7) }

############################################################
slide!('Imported graphics',
  'One can import jpeg and pdf files:',
  center,
  image('worldmap.jpeg').scale(0.3),
  cr,
  image('plot.pdf'),
nil) { |slide| slide.label('import').signature(8) }

############################################################
slide!('Flexible relative positioning of objects',
  autowrap('We can specify the positions of some objects with respect to others.'),
  cr,
  autowrap('A useful primitive to have is to connect two objects with a line:'),
  overlay(
    a = circle(u(0.2), u(0.5)), # Create an ellipse
    b = circle(u(1.2), u(0.5)).shift(upair(5, 1)), # Create another ellipse
    arrow(tcenter(a), tcenter(b)).dashed, # Connect their centers with an edge
  nil),
  cr,
  'We can also circle objects:',
  ctable(
    enrect(:obj => 'box'), encircle(:obj => 'ellipse'),
  nil),
nil) { |slide| slide.label('flexible').signature(9) }

############################################################
# Below this point are more advanced examples,
# which are not explained.

############################################################
slide!('Tables example',
  'A more complicated example of using lots of features:',
  center,
  rtable(
    table([1, 2], [3, 4]).ospace.bgColor(darkgreen).opaque.border(2).borderColor(red).rotate(90),
    ctable(1, _(2).level(1), _(3).color(blue), 4),
  nil).border,
  color(blue),
  table([1, _(2).scale(0.5)], [_(3).dimLevel(1), _(4).rotate(90)]).scale(2),
nil) { |slide| slide.signature(4) }

############################################################
slide!('Overlays',
  overlay(
    'hello',
    _('hello').slant(2),
    _('hello').scale(2),
    _('hello').rotate(90),
    pause,
    color(blue),
    arrow(upair(0, 0), upair(1, 1)),
    path(upair(0, 0), upair(1, 0), upair(1, 1)).type(:arrow).curved,
    ctable(1, 2, 3, 4),
    ctable(1, 2, 3, 4).border.rotate(180),
    ctable(1, 2, 3, _(4).rotate(-90).color(green)).shift(upair(-2, 0)),
    shift(upair(2, 0)), 'a', 'b',
  nil),
  pause,
  centeredOverlay(
    'hello',
    pause,
    'bye',
    pause,
    _('bye').shift(upair(1, 0)),
   nil),
   pause,
   'done',
nil)

############################################################
slide!('Encircling things',
  redEncircle(:obj => _('redEncircle new object').useRawBounds, :isNewObj => true),
  a = _('existing object'),
  pause,
  redEncircle(:obj => a),
  encircle(:obj => 'encircle this new object'),
  enrect(:obj => 'enrect this new object'),
nil)

############################################################
slide!('Lists',
  scale(1.2),
  itemizeList(
    'one',
    pause,
    'two',
    [
      'two dot one',
      scale(1.5),
      pause,
      a = _('two dot two'),
    nil],
    'three',
    pause,
    'four',
  nil).rotate(10).slant(0.1).postProcessor { |writer,obj|
    obj.postPause
    obj.postAdd(writer, redEncircle(:obj => _('hello')))
    obj.postAdd(writer, redEncircle(:obj => a))
  }.listStyleFunc($enumerateListStyle),
nil)

############################################################
slide!('Drawing pictures and post-processing',
  'here',
  rotate(90),
  pause,
  'eh',
  pause,
  'foo',
  ctable(_('hello').label('a'), 'bye').postProcessor { |writer,obj|
    a = obj.findPicNode('a')
    p1 = a.getPoint(-1, 0)
    p2 = a.getPoint(+1, 0)
    obj.postAdd(writer, edge(p1, p2).color(red).thickness(2))
    obj.postAdd(writer, _('origin'))

    b = obj.postAdd(writer, _('moved right').shift(upair(3, 0)))

    obj.postAdd(writer, centeredOverlay(pause, circle(u(1)).color(red)).shift(b.getPoint(0, 0)))

    obj.postAdd(writer, _('shown early').shift(upair(4, 4)).level(1))
    obj.postAdd(writer, _('shown late').label('b').shift(upair(4, 4)))

    obj.postAddArrows(writer, ['a', 'b'])
  },
nil)

############################################################
slide!('Pause levels and variables',
  'A plain table:',
  table([1, pause, 2, 3], [4, 5, 6]),
  pause,
  let(:l, tstartlevel),
  'A table with a border:',
  table([1, 2, 3], [4, 5, 6]).border(2),
  pause,
  'An overlay:',
  overlay(
    _('one').nlevels,
    pause,
    _('two').nlevels,
    pause,
    _('three'),
  nil),
  pause,
  _('This is shown when the bordered table is').level(:l),
  'This is shown afterwards',
nil)

############################################################
slide!('More pause levels',
  'Press any key to begin...',
  pause,
  scale(0.5), rotate(45),
  'We will show one column at a time',
  plet(:lBegin, tstartlevel),
  table(
    # Important: need to make setting the level persistent
    # (affect the entire hierarchy of styles), because pause is
    [plevel(:lBegin), 'a', pause, 'b', pause, 'c', pause, 'd'],
    [plevel(:lBegin), 'a', pause, 'b', pause, 'c', pause, 'd'],
    [plevel(:lBegin), 'a', pause, 'b', pause, 'c', pause, 'd'],
  nil),
  pause,
  'At the end',
nil)

############################################################
slide!('More pause levels',
  root = rtable(
    'begin...',
    pause,
    plet(:l, tstartlevel),
    table(['a', pause, 'b'], ['c', 'd']),
    'after in overlay',
    level(:l),
    ctable('reset level', pause, 'reset level 2'),
  nil),
  'after out of overlay: printed after three pauses total',
nil)

############################################################
slide!('Referencing positions objects without postAdd',
  overlay(
    root = table([a=_('a'), b=_('b').label('b')], [c=_('c').label('c'), d=_('d')]),
    edge(tcenter(a), tcenter(d)).color(green).nlevels(1), # Can use objects
    pause,
    edge(tcenter(root, 'b'), tcenter(root, 'c')).color(red), # Or use paths
  nil),
  overlay(
    root = rtable(a=_('this is a test').useRawBounds.yscale(2), circ=circle(u(4))),
    arrow(tpoint(-1, -1, a), tcenter(circ)).begindir('down').enddir('down').curved.arrowSize(10),
    shift(upair(5, 0)),
    circ2 = circle(u(2)).xscale(0.5),
    circ3 = circle(u(1)).xscale(0.5),
    #edge(tcenter(circ), tcenter(circ2)).arrow.curved.begindir('up'),
    clippedpath(circ, circ2).ignoreSpatialStyles.arrow.curved.begindir('up'),
  nil),
nil)

############################################################
slide!('Level strings',
  L(0, 'a', 'b', L(2, 'c', L(1, 'd')), 'e'),
  pause,
  'A next example in math:',
  L(0, '$\frac{', L(1, 'x+y'), '}{', L(2, 'z+w'), '}$'),
nil)

############################################################
slide!('Zooming',
  ctable('a', _('b').label('b'), 'c').postProcessor { |writer,obj|
    obj.postPause
    zoom(:writer => writer, :rootObj => obj,
      :smallPicNode => obj.findPicNode('b'),
      :bigObj => rtable('The letter {\bf B}', pause, 'very nice').scale(2),
      :bigMargin => u(0.3),
      :offset => upair(3, -4))
    obj.postAdd(writer, encircle(:obj => obj.findPicNode('b').obj))
  },
  pause,
  'more stuff here',
nil)

############################################################
data = DataTable.new(:cellName => 'accuracy',
  :rowName => 'method', :colName => 'dataset size',
  :rowLabels => ['EM', 'variational'],
  :colLabels => [10, 100, 1000, '10000'],
  :contents => [[89, 90], [92, 94], [95, 98], [88, 99]].transpose)
slide!('Tables and graphs',
  center,
  latexTable(data).scale(0.6),
  pause,
  centeredOverlay(
    barGraph(data).scale(0.8).postProcessor { |writer,obj|
      obj.postPause
      obj.postAdd(writer, redEncircle(:obj => obj.findPicNode('bar(1,1)').obj))
    }.nlevels(2),
    pause,
   lineGraph(data).scale(0.8).yrange(70, 100).legendPosition(+1, -1).
      xtickStyle(:short).xrange(0).xlength(u(7)).xtickIncrValue(1).
      xroundPlaces(0).useRowPairs([nil, 0], [nil, 1]).postProcessor { |writer,obj|
     obj.postPause
     p = obj.getPoint(0, 0, 'pt(1,1)')
     obj.postAdd(writer,
       overlay(rtable('Interesting', downarrow).ospace.center).pivot(0, -1).shift(p))
   },
  nil),
nil)

############################################################
slide!('Changing bounds (on text)',
  ignore(
    a = 'begin',
    def b; _('$\frac{2}{3+\underbrace{\sqrt{4}}_\text{this is actually just $2$}}$') end,
    c = 'middle',
    def d; _('g'); end,
    e = 'end',
  nil),
  ctable(
    rtable('Normal formatting:', a, b, c, d, e),
    rtable('Using raw bounds:', a, b.useRawBounds, c, d.useRawBounds, e),
    rtable('Using standard height:', a, b.stdHeight, c, d.stdHeight.scale(2), e),
  nil).scale(0.8),
  overlay('a', b, d.scale(2)),
  autowrap(6, 0.5,
    'Raw bounds put g higher because it does not have the ascender.',
    'Using the standard height makes everything take as much vertical space as an a.'),
nil)

slide!('',
  # Doesn't work: should put c on same level as a and b
  staggeredOverlay(true,
    'a', 'b', ctable('c', circle(u(4))).center.cNumGhosts(0, 1),
  nil).pivot(-1, +1),
nil)

slide!('',
  hedge(u(4)),
  autowrap('this should autowrap at 4 inches').width(u(4)),
  autowrap('if scaled by 0.5, autowrapping happens at 2').width(u(4)).scale(0.5),
nil)

def f
  overlay.postProcessor { |writer,rootObj|
    rootObj.postAdd(writer, _('a').scale(2))
  }
end

slide!('',
  # Scaling is unexpected
  #f, overlay(f).scale(2),
  staggeredOverlay(true, 'a', 'b', 'c'),
  pause,
  'd',

# barGraph(DataTable.new(:colLabels => ['a', 'b'], :contents => [[3, 4]])).xtickLabelScale(1).scale(0.5),
# # Doesn't do the right thing
# barGraph(DataTable.new(:colLabels => ['a', 'b'], :contents => [[3, 4]])).xtickLabelScale(2).scale(0.5),
# overlay(barGraph(DataTable.new(:colLabels => ['a', 'b'], :contents => [[3, 4]])).xtickLabelScale(2)).scale(0.5),

#  barGraph(DataTable.new(:colLabels => ['a', 'b'], :contents => [[3, 4]])),
#  scale(0.5),
#  barGraph(DataTable.new(:colLabels => ['a', 'b'], :contents => [[3, 4]])),
#  barGraph(DataTable.new(:colLabels => ['a', 'b'], :contents => [[3, 4]])).xtickLabelScale(2),

#  ctable(_('a').scale(2), 'b'),
#  ctable(_('a').scale(2), 'b').scale(2),
#  ctable(_('a').Scale(2), 'b').scale(2),
#  scale(2),
#  ctable(_('a').scale(2), 'b'),
#  ctable(_('a').scale(2), 'b').scale(2),
nil)

finishPresentation
