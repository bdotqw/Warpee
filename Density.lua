local addonName, ns = ...

local STEPS = {
  { max = 29,
    pad = 8, header = 61, footer = 27, div = 20, hb = 24, row1y = 3, searchH = 20, headerBand = 30,
    bagPad = 10, bagGap = 5, labelH = 12, labelGap = 3,
    pocketPad = 10, pocketBand = 22, pocketNudge = 20, pocketGap = 7, arrow = 10, moveH = 14,
    pickSize = 32, pickGap = 7, pickPad = 10, pickMinW = 150,
    pickerPad = 6, pickerRow = 25, pickerHdr = 20, pickerHead = 29, pickerMinW = 235, pickerRows = 8,
    font = 14 },
  { max = 43,
    pad = 10, header = 66, footer = 28, div = 22, hb = 26, row1y = 4, searchH = 22, headerBand = 32,
    bagPad = 12, bagGap = 6, labelH = 13, labelGap = 4,
    pocketPad = 12, pocketBand = 26, pocketNudge = 24, pocketGap = 8, arrow = 11, moveH = 16,
    pickSize = 36, pickGap = 8, pickPad = 12, pickMinW = 176,
    pickerPad = 8, pickerRow = 27, pickerHdr = 22, pickerHead = 32, pickerMinW = 265, pickerRows = 10,
    font = 15 },
  { max = 56,
    pad = 12, header = 71, footer = 29, div = 24, hb = 28, row1y = 5, searchH = 24, headerBand = 34,
    bagPad = 14, bagGap = 7, labelH = 14, labelGap = 5,
    pocketPad = 14, pocketBand = 30, pocketNudge = 28, pocketGap = 9, arrow = 12, moveH = 18,
    pickSize = 40, pickGap = 9, pickPad = 14, pickMinW = 200,
    pickerPad = 10, pickerRow = 30, pickerHdr = 24, pickerHead = 36, pickerMinW = 300, pickerRows = 14,
    font = 16 },
}

local cache = {}

local function pick(size)
  for i = 1, #STEPS do
    if size <= STEPS[i].max then return STEPS[i] end
  end
  return STEPS[#STEPS]
end

function ns.Density(size)
  if size == nil then size = ns.Bags and ns.Bags.iconSize end
  size = math.floor((tonumber(size) or 37) + 0.5)
  local hit = cache[size]
  if not hit then
    hit = pick(size)
    cache[size] = hit
  end
  return hit
end
