# Source explicitly from your existing .zshrc or .bashrc after reviewing.
# Put optional personal overrides after this fragment in that file.
# Only set these defaults when a user has not already selected a tool.
: "${EDITOR:=vi}"
: "${VISUAL:=$EDITOR}"
: "${PAGER:=less}"
export EDITOR VISUAL PAGER

# User-installed CLI tools (including an optional local chezmoi install).
# Keep existing PATH order when the directory is already present.
if [ -d "$HOME/.local/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
  esac
fi
