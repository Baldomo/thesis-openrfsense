local system = require "pandoc.system"
local with_temporary_directory = system.with_temporary_directory
local with_working_directory = system.with_working_directory

-- The default format is SVG i.e. vector graphics:
-- local filetype = "svg"
local mimetypes = {
  png = "image/png",
  svg = "image/svg+xml"
}

---Parsed metadata options. Will always be overridden by block-local attributes
local options = {
  output = "svg",
  layout = nil,
  path = os.getenv("D2") or "d2",
  pad = nil,
  sketch = false,
  theme = nil,
}

-- Check for output formats that potentially cannot use SVG
-- vector graphics. In these cases, we use a different format
-- such as PNG:
if FORMAT == "docx" then
  options.output = "png"
elseif FORMAT == "pptx" then
  options.output = "png"
elseif FORMAT == "rtf" then
  options.output = "png"
end

---Renders a D2 code block contents to a specfic output format
---@param code string
---@param ext string
---@param args table<string>
---@return string
local function render(code, ext, args)
  if ext == "svg" then
    table.insert(args, "-")
    return pandoc.pipe(options.path, args, code)
  end

  if ext == "png" then
    error("PNG rendering is not yet working")

    return with_temporary_directory("d2image", function (tmpdir)
      return with_working_directory(tmpdir, function ()
        local file_template = "%s/image.%s"
        local d2file = file_template:format(tmpdir, "d2")
        local outfile = file_template:format(tmpdir, "png")

        -- Write the D2 code to file
        local f = io.open(d2file, "w")
        if not f then
          error("could not write d2 code to file " .. d2file)
        end
        f:write(code)
        f:close()

        -- Run D2
        table.insert(args, d2file)
        table.insert(args, outfile)
        quarto.log.output(options.path, ":", args)
        pandoc.pipe(options.path, args, "")

        -- Try to open and read the image
        local img_data
        local r = io.open(outfile, "rb")
        if r then
          img_data = r:read("*all")
          r:close()
        else
          quarto.log.warning("could not read image from " .. outfile)
        end

        return img_data
      end)
    end)
  end

  error(string.format("Conversion to %s not implemented", ext))
end

---Parses extension configuration
function Meta(meta)
  if not meta["d2"] then
    return meta
  end

  options.output = meta.d2.output and pandoc.utils.stringify(meta.d2.output) or options.output
  options.layout = meta.d2.layout and pandoc.utils.stringify(meta.d2.layout) or options.layout
  options.path = pandoc.utils.stringify(meta.d2.path)
  options.pad = meta.d2.pad and pandoc.utils.stringify(meta.d2.pad) or options.pad
  options.sketch = meta.d2.sketch or options.sketch
  options.theme = meta.d2.layout and pandoc.utils.stringify(meta.d2.theme) or options.theme
end

---Parses a code block and renders its contents to a `pandoc.Figure` containing
---the output from the D2 renderer
function CodeBlock(block)
  if block.classes[1] ~= "d2" then
    return block
  end

  local args = {}
  if block.attributes["output"] then
    options.output = block.attributes["output"]
  end
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

  local success, img = pcall(render, block.text, options.output, args)
  if not (success and img) then
    quarto.log.error(img or "no image data has been returned")
    error "Image conversion failed, aborting"
    return block
  end

  -- Create figure name by hashing the image content
  local filename = pandoc.sha1(img) .. "." .. options.output
  -- Store the data in the media bag
  pandoc.mediabag.insert(filename, mimetypes[options.output], img)

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
    return pandoc.Div{ pandoc.Figure(pandoc.Plain{img_obj}, caption, fig_attr) }
  end
end

return {
  { Meta = Meta },
  { CodeBlock = CodeBlock },
}
