author       'Daniel Mendler'
description  'Source code highlighting engine'
dependencies 'engine/engine', 'utils/pygments'

Engine.create(:highlight, :priority => 2, :layout => true, :cacheable => true) do
  def accepts?(page); Pygments.file_format(page.name) != nil; end
  def output(context); context.app.pygmentize(context.page.content, Pygments.file_format(context.page.name)); end
end

