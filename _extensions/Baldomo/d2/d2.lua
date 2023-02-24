-- The default format is SVG i.e. vector graphics:
local filetype = "svg"
local mimetype = "image/svg+xml"

-- Check for output formats that potentially cannot use SVG
-- vector graphics. In these cases, we use a different format
-- such as PNG:
if FORMAT == "docx" then
  filetype = "png"
  mimetype = "image/png"
elseif FORMAT == "pptx" then
  filetype = "png"
  mimetype = "image/png"
elseif FORMAT == "rtf" then
  filetype = "png"
  mimetype = "image/png"
end

---Parsed metadata options. Will always be overridden by block-local attributes
local options = {
  layout = nil,
  path = os.getenv("D2") or "d2",
  pad = nil,
  sketch = false,
  theme = nil,
}

---Renders a D2 code block contents to a specfic output format
---@param code string
---@param ext string
---@param args table<string>
---@return string
local function render(code, ext, args)
  if ext ~= "svg" and ext ~= "png" then
    error(string.format("Conversion to %s not implemented", ext))
  end

  table.insert(args, "-")
  quarto.log.output(args)
  return pandoc.pipe(options.path, args, code)
end

---Parses extension configuration
function Meta(meta)
  if not meta["d2"] then
    return meta
  end

  options.path = pandoc.utils.stringify(meta.d2.path)
  options.layout = meta.d2.layout and pandoc.utils.stringify(meta.d2.layout) or nil
  options.pad = meta.d2.pad and pandoc.utils.stringify(meta.d2.pad) or nil
  options.sketch = meta.d2.sketch or false
  options.theme = meta.d2.layout and pandoc.utils.stringify(meta.d2.theme) or nil
end

---Parses a code block and renders its contents to a `pandoc.Figure` containing
---the output from the D2 renderer
function CodeBlock(block)
  if block.classes[1] ~= "d2" then
    return block
  end

  local args = {}
  if block.attributes["layout"] or options.layout then
    table.insert(args, "-l")
    table.insert(args, block.attributes["layout"] or options.layout)
  end
  if block.attributes["theme"] or options.theme then
    table.insert(args, "-t")
    table.insert(args, block.attributes["theme"] or options.theme)
  end
  if block.attributes["pad"] or options.pad then
    table.insert(args, "--pad")
    table.insert(args, block.attributes["pad"] or options.pad)
  end
  if block.attributes["sketch"] or options.sketch then
    table.insert(args, "-s")
  end

  local success, img = pcall(render, block.text, filetype, args)
  if not (success and img) then
    quarto.log.error(img or "no image data has been returned")
    error "Image conversion failed, aborting"
  end

  -- Create figure name by hashing the image content
  local filename = pandoc.sha1(img) .. "." .. filetype
  -- Store the data in the media bag
  pandoc.mediabag.insert(filename, mimetype, img)

  -- If the user defines a caption, read it as Markdown
  local caption = block.attributes["fig-cap"]
    and pandoc.read(block.attributes["fig-cap"]).blocks
    or pandoc.Blocks{}
  local alt = pandoc.utils.blocks_to_inlines(caption)

  if PANDOC_VERSION < 3 then
    -- A non-empty caption means that this image is a figure. We have to
    -- set the image title to "fig-" for Quarto to treat it as such
    local title = #caption > 0 and "fig-" or ""

    -- Transfer identifier and other relevant attributes from the code
    -- block to the image. The `name` is kept as an attribute.
    -- This allows a figure block starting with:
    --
    --     {#fig-example .d2 fig-cap="Image created by **d2**."}
    --
    -- to be referenced as @fig-example outside of the figure when used
    -- with `pandoc-crossref`
    local img_attr = {
      id = block.identifier,
      name = block.attributes.name,
      width = block.attributes.width,
      height = block.attributes.height
    }

    -- Create a new image for the document's structure. Attach the user's
    -- caption. Also use a hack (fig-) to enforce pandoc to create a
    -- figure i.e. attach a caption to the image
    local img_obj = pandoc.Image(alt, filename, title, img_attr)

    -- Finally, put the image inside an empty paragraph. By returning the
    -- resulting paragraph object, the source code block gets replaced by
    -- the image
    return pandoc.Para{ img_obj }
  else
    local fig_attr = {
      id = block.identifier,
      name = block.attributes.name,
    }
    local img_attr = {
      width = block.attributes.width,
      height = block.attributes.height,
    }
    local img_obj = pandoc.Image(alt, filename, "", img_attr)

    -- Create a figure that contains just this image
    return pandoc.Figure(pandoc.Plain{img_obj}, caption, fig_attr)
  end
end

return {
  { Meta = Meta },
  { CodeBlock = CodeBlock },
}
