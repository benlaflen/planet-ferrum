local function rescale(node, factor)
  if type(node) ~= "table" then return end
  if node.filename or node.filenames or node.stripes then
    node.scale = (node.scale or 1) * factor
    if node.shift then node.shift = { node.shift[1] * factor, node.shift[2] * factor } end
  end
  for _, child in pairs(node) do rescale(child, factor) end
end

return rescale