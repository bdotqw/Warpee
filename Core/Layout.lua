local addonName, ns = ...

local Layout = {}
ns.Layout = Layout

function Layout.Metrics(region, size, gap)
  local px = ns.PixelUnit(region)
  local s = math.max(px, math.floor((tonumber(size) or 0) / px + 0.5) * px)
  local g = math.max(0, math.floor((tonumber(gap) or 0) / px + 0.5) * px)
  return s, g, s + g, px
end

function Layout.Width(size, cols, gap)
  return (cols - 1) * (size + gap) + size
end

function Layout.Step(size, gap)
  return (tonumber(size) or 0) + (tonumber(gap) or 0)
end

function Layout.Cell(index, cols)
  cols = tonumber(cols) or 1
  if cols < 1 then cols = 1 end
  local i = (tonumber(index) or 0) - 1
  return i % cols, math.floor(i / cols)
end

function Layout.Point(index, cols, left, top, step)
  local col, row = Layout.Cell(index, cols)
  return (left or 0) + col * (step or 0), (top or 0) + row * (step or 0)
end

function Layout.GridHeight(rows, step, size)
  return ((tonumber(rows) or 0) - 1) * (step or 0) + (size or 0)
end

function Layout.WindowWidth(pad, cols, step, gap)
  return (pad or 0) * 2 + (cols or 0) * (step or 0) - (gap or 0)
end

ns.GridMetrics = Layout.Metrics
ns.GridWidth = Layout.Width
