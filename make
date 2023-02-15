#!/usr/bin/env bash
source makesh/lib.sh
source makesh/message.sh

shopt -s extglob nullglob globstar

bin_dir="$makesh_script_dir/bin"
output_dir="$makesh_script_dir/output"

pandoc_version="3.0"
pandoc="$bin_dir/pandoc/bin/pandoc"

quarto_version="1.3.200"
quarto="env QUARTO_PANDOC=$pandoc $bin_dir/quarto/bin/quarto"

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

#:(html) Renders the project to a static website
make::html() {
  $quarto render --to html
}

#:(pdf) Renders the project to the custom PDF thesis template format
make::pdf() {
  $quarto render --to unitn-thesis-pdf
}

#:(dev) Starts a Quarto preview as PDF with the custom thesis format
make::dev() {
  $quarto preview "$makesh_script_dir" --render unitn-thesis-pdf 1>/dev/null
}

#:(all) Downloads dependencies and renders the document as PDF
make::all() {
  lib::requires bin_d2
  lib::requires bin_pandoc
  lib::requires bin_quarto
  lib::requires pdf
}

#:(clean) Removes the binaries folder and all build caches
make::clean() {
  rm -rf "$bin_dir"
  rm -rf "$output_dir"
  rm -rf .quarto
}

source makesh/runtime.sh
