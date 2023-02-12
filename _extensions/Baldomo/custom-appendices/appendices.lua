-- https://github.com/shafayetShafee/include-code-files/blob/main/_extensions/include-code-files/include-code-files.lua
-- https://github.com/pandoc-ext/abstract-section/blob/main/_extensions/abstract-section/abstract-section.lua
-- https://github.com/pandoc/lua-filters

local latexAdded = false
function Header(el)
  if el.level ~= 1 then
    return el
  end

  if FORMAT:match("latex") then
    if el.classes[1] == "custom-appendices" and not latexAdded then
      latexAdded = true
      return pandoc.Para(
        pandoc.RawInline("latex", "\\appendix")
      )
    end
    return nil
  end

  if FORMAT:match("epub") then
    el.attr.attributes["epub:type"] = "appendix"
  end

  return el
end

return {
  { Header = Header },
}
