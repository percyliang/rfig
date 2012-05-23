#!/usr/bin/ruby

# This is an example of how to draw figures.
# Note that PDF files are generated only when the signature changes.

require 'rfig/FigureSet'

initFigureSet

printObj(
  :obj => _('hello').color(blue).signature(1),
  :outPrefix => 'hello')

printObj(
  :obj => circle(u(2)).color(red).fill.signature(1),
  :outPrefix => 'circle')

finishFigureSet
