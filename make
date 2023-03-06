#!/usr/bin/env bash
source makesh/lib.sh
source makesh/message.sh

shopt -s extglob nullglob globstar

bin_dir="$makesh_script_dir/bin"
output_dir="$makesh_script_dir/output"
book_dir="$makesh_script_dir/book"
slides_dir="$makesh_script_dir/slides"

pandoc_version="3.0"
pandoc="$bin_dir/pandoc/bin/pandoc"

quarto_version="1.3.231"
quarto="$bin_dir/quarto/bin/quarto"

d2="$bin_dir/d2/bin/d2"

#:(bindir) Creates `$bin_dir` (`./bin/`) if not already present
make::bindir() {
  lib::check_dir "$bin_dir"
  mkdir -p "$bin_dir"
}

#:(bin_d2) Downloads the latest D2 version using the official installer
make::bin_d2() {
  lib::requires bindir
  lib::check_file "$d2"

  local installer="$bin_dir/d2-installer.sh"
  curl -fsSL "https://d2lang.com/install.sh" >"$installer" \
    || msg::die "Failed to download D2 installer"
  msg::msg "Downloaded D2 installer to: ./%s" "${installer#"$makesh_script_dir/"}"
  chmod +x "$installer"
  "$installer" --prefix "$bin_dir/d2" --method standalone
}

#:(bin_pandoc) Downloads Pandoc version `$quarto_version` but only if the
#:(bin_pandoc) current installation is a lower version
make::bin_pandoc() {
  lib::requires bindir
  lib::check_file "$pandoc"

  msg::msg "Downloading Pandoc v$pandoc_version"
  wget -qO "$bin_dir"/pandoc.tar.gz \
    "https://github.com/jgm/pandoc/releases/download/${pandoc_version}/pandoc-${pandoc_version}-linux-amd64.tar.gz"

  msg::msg "Extracting Pandoc"
  pushd "$bin_dir" >/dev/null
  tar xzf pandoc.tar.gz
  rm pandoc.tar.gz
  mv "pandoc-${pandoc_version}" pandoc
  popd >/dev/null
}

#:(bin_quarto) Downloads Quarto version `$quarto_version` but only if the
#:(bin_quarto) current installation is a lower version
make::bin_quarto() {
  lib::requires bindir
  local _version
  if _version=$(cat "$bin_dir/quarto/share/version"); then
    [[ ! "$_version" < "$quarto_version" ]] && ((!makesh_force)) \
      && lib::return "Already on latest Quarto version"
  fi

  msg::msg "Downloading Quarto v$quarto_version"
  wget -qO "$bin_dir"/quarto.tar.gz \
    "https://github.com/quarto-dev/quarto-cli/releases/download/v${quarto_version}/quarto-${quarto_version}-linux-amd64.tar.gz"

  msg::msg "Extracting Quarto"
  pushd "$bin_dir" >/dev/null
  rm -rf quarto >/dev/null
  tar xzf quarto.tar.gz
  rm quarto.tar.gz
  mv "quarto-${quarto_version}" quarto
  popd >/dev/null

  msg::msg "Installing Quarto tools"
  $quarto install --no-prompt tinytex
  msg::msg2 "If compilation fails because TeX packages are the wrong version, run"
  msg::plain "rm -rf ~/.TinyTeX"
}

# Utility function to cd into a directory and render that project with Quarto
# $1 : the format to render to
# $2 : the directory containing the project (_quarto.yml)
_render() {
  pushd "$2" || msg::die "Cannot read directory %s" "$2"
  $quarto render --to "$1"
  popd
}

#:(book_html) Renders the thesis book to a static website
make::book_html() {
  _render "html" "$book_dir"
}

#:(book_pdf) Renders the thesis book to the custom PDF template format
make::book_pdf() {
  _render "unitn-thesis-pdf" "$book_dir"
}

#:(book_dev) Starts a Quarto preview of the book as PDF
#:(book_dev) with the custom thesis format
make::book_dev() {
  $quarto preview "$book_dir" --render unitn-thesis-pdf 1>/dev/null
}

#:(slides) Renders the slides to RevealJS
make::slides() {
  _render "unitn-thesis-revealjs" "$slides_dir"
}

#:(slides_dev) Starts a Quarto preview of the slides as RevealJS
make::slides_dev() {
  $quarto preview "$slides_dir" --render unitn-thesis-revealjs 1>/dev/null
}

#:(all) Downloads dependencies and renders the document as PDF
make::all() {
  lib::requires bin_d2
  lib::requires bin_pandoc
  lib::requires bin_quarto

  lib::requires book_pdf

  lib::requires slides
}

#:(clean) Removes the binaries folder and all build caches
make::clean() {
  rm -rf "$bin_dir"
  rm -rf "$output_dir"
  rm -rf ./**/.quarto
}

source makesh/runtime.sh
