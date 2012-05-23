#!/usr/bin/ruby

# Simply type ./simple.rb to generate a PDF file with two slides.
# This program is mainly to make sure things can compile.

require 'rfig/Presentation'

initPresentation(
  :separateFiles => false # All slides go into one PDF file
)

############################################################
slide!('Simple demo 1',
  itemizeList(
    'Point 1',
    'Point 2',
    'Point 3',
  nil),
  pause,
  'And that\'s all for demo 1.',
nil)

############################################################
slide!('Simple demo 2',
  'Equations are easy:',
  center,
  '$\displaystyle \frac{1}{n} \sum_{i=1}^n a_i$',
  left,
  'So is drawing:',
  center,
  circle(u(1)).color(blue),
nil)

finishPresentation
