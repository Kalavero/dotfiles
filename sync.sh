#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_SUBAGENT_MODEL="haiku"
OPENCODE_SUBAGENT_MODEL="openai/gpt-5.6-terra"
CODEX_SUBAGENT_MODEL="gpt-5.6-terra"
TARGET_HOME="${HOME:?HOME must be set}"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./sync.sh [--target-home PATH] [--dry-run]

Options:
  --target-home PATH  Publish and stow into PATH instead of the current home.
  --dry-run           Report changes without modifying the target home.
  -h, --help          Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-home)
      [ "$#" -ge 2 ] || { echo "sync.sh: --target-home requires a path" >&2; exit 2; }
      TARGET_HOME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "sync.sh: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$TARGET_HOME" in
  /*) ;;
  *)
    echo "sync.sh: target home must be an absolute path: $TARGET_HOME" >&2
    exit 2
    ;;
esac

[ -d "$TARGET_HOME" ] || {
  echo "sync.sh: target home does not exist: $TARGET_HOME" >&2
  exit 2
}

echo "==> Syncing Kalavero Dotfiles"
echo ""

link_if_needed() {
  local source="$DOTFILES_DIR/$1"
  local target="$TARGET_HOME/$2"
  local backup

  if [ -L "$target" ]; then
    [ "$(readlink "$target")" = "$source" ] && return 0
    if ! symlink_points_into_repo "$target"; then
      echo "  Preserving user-managed symlink: ~/$2" >&2
      return 0
    fi
    # Repository-owned link pointing at a stale path: refresh it in place.
    if [ "$DRY_RUN" = true ]; then
      echo "  Would relink repository-owned ~/$2"
    else
      rm "$target"
      mkdir -p "$(dirname "$target")"
      ln -s "$source" "$target"
    fi
    return 0
  fi

  if [ ! -e "$target" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  Would link ~/$2"
    else
      mkdir -p "$(dirname "$target")"
      ln -s "$source" "$target"
    fi
    return 0
  fi

  backup="$(next_backup_path "$target")"
  if [ "$DRY_RUN" = true ]; then
    echo "  Would back up conflicting ~/$2 -> $(basename "$backup")"
    echo "  Would link ~/$2"
  else
    echo "  Backing up existing ~/$2 -> $(basename "$backup")"
    mv "$target" "$backup"
    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
  fi
}

next_backup_path() {
  local target="$1"
  local timestamp
  local candidate
  local counter=1

  timestamp="$(date +%Y%m%d%H%M%S)"
  candidate="$target.backup.$timestamp"
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="$target.backup.$timestamp.$counter"
    counter=$((counter + 1))
  done
  printf '%s\n' "$candidate"
}

symlink_points_into_repo() {
  local link="$1"
  local destination
  local candidate
  local resolved_dir

  [ -L "$link" ] || return 1
  destination="$(readlink "$link")"
  case "$destination" in
    /*) candidate="$destination" ;;
    *) candidate="$(dirname "$link")/$destination" ;;
  esac

  resolved_dir="$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P)" || return 1
  case "$resolved_dir/$(basename "$candidate")" in
    "$DOTFILES_DIR"/*) return 0 ;;
    *) return 1 ;;
  esac
}

remove_old_symlink() {
  local target="$TARGET_HOME/$1"

  if [ -L "$target" ] && symlink_points_into_repo "$target"; then
    if [ "$DRY_RUN" = true ]; then
      echo "  Would remove repository-owned old symlink: ~/$1"
      return 0
    fi
    echo "  Removing old symlink: ~/$1"
    rm "$target"
  elif [ -L "$target" ]; then
    echo "  Preserving user-managed symlink: ~/$1" >&2
  fi
}

backup_if_conflict() {
  local target="$TARGET_HOME/$1"
  local backup
  local physical_home
  local physical_repo
  local physical_parent

  if [ -L "$target" ] && symlink_points_into_repo "$target"; then
    return 0
  fi
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    return 0
  fi
  # A target reached through a symlinked directory (a tree stow folded into
  # the repository, or a user-managed directory link) is not a plain file
  # conflict; backing it up would move files outside the target home. Leave
  # it for stow to merge or report.
  physical_home="$(cd "$TARGET_HOME" && pwd -P)"
  physical_repo="$(cd "$DOTFILES_DIR" && pwd -P)"
  physical_parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || return 0
  case "$physical_parent" in
    "$physical_home" | "$physical_home"/*) ;;
    *) return 0 ;;
  esac
  case "$physical_parent" in
    "$physical_repo" | "$physical_repo"/*) return 0 ;;
  esac
  # A directory stow already manages (unfolded, with links into the repo) is
  # not a conflict; stow merges into it on the next run.
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    local entry
    for entry in "$target"/*; do
      if [ -L "$entry" ] && symlink_points_into_repo "$entry"; then
        return 0
      fi
    done
  fi

  backup="$(next_backup_path "$target")"
  if [ "$DRY_RUN" = true ]; then
    echo "  Would back up conflicting ~/$1 -> $(basename "$backup")"
  else
    echo "  Backing up existing ~/$1 -> $(basename "$backup")"
    mv "$target" "$backup"
  fi
}

# Back up real target files that would make stow abort mid-install. Symlinks
# into the repository restow cleanly, so only non-symlink conflicts move.
# .stow-local-ignore patterns are not parsed here; the current ignores only
# cover herdr runtime state that never ships in the package.
backup_package_conflicts() {
  local pkg="$1"
  local file

  while IFS= read -r file; do
    backup_if_conflict "${file#"$DOTFILES_DIR/$pkg"/}"
  done < <(find "$DOTFILES_DIR/$pkg" -type f ! -name .stow-local-ignore)
}

publish_skill_links() {
  local source_dir="$DOTFILES_DIR/$1"
  local target_dir="$TARGET_HOME/$2"
  local source
  local target
  local destination
  local virtual_empty=false

  if [ -L "$target_dir" ]; then
    if [ "$(readlink "$target_dir")" = "$source_dir" ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "  Would replace legacy skills root symlink: ~/$2"
        virtual_empty=true
      else
        echo "  Replacing legacy skills root symlink: ~/$2"
        rm "$target_dir"
        mkdir -p "$target_dir"
      fi
    else
      echo "  Preserving user-managed skills root symlink: ~/$2" >&2
      return 0
    fi
  elif [ -e "$target_dir" ] && [ ! -d "$target_dir" ]; then
    echo "  Preserving user-managed skills path: ~/$2" >&2
    return 0
  elif [ ! -d "$target_dir" ]; then
    if [ "$DRY_RUN" = true ]; then
      virtual_empty=true
    else
      mkdir -p "$target_dir"
    fi
  fi

  if [ "$virtual_empty" = false ]; then
    for target in "$target_dir"/*; do
      [ -L "$target" ] || continue
      destination="$(readlink "$target")"
      case "$destination" in
        "$source_dir"/*)
          source="$source_dir/$(basename "$target")"
          if [ "$destination" != "$source" ] || [ ! -d "$source" ] || [ ! -f "$source/SKILL.md" ]; then
            if [ "$DRY_RUN" = true ]; then
              echo "  Would remove stale Kalavero skill link: $target"
            else
              echo "  Removing stale Kalavero skill link: $target"
              rm "$target"
            fi
          fi
          ;;
      esac
    done
  fi

  for source in "$source_dir"/*; do
    [ -d "$source" ] || continue
    [ -f "$source/SKILL.md" ] || continue
    target="$target_dir/$(basename "$source")"

    if [ "$virtual_empty" = false ] && [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      continue
    fi

    if [ "$virtual_empty" = false ] && { [ -e "$target" ] || [ -L "$target" ]; }; then
      echo "  Preserving user-managed skill: $target" >&2
      continue
    fi

    if [ "$DRY_RUN" = true ]; then
      echo "  Would link Kalavero skill: $target"
    else
      ln -s "$source" "$target"
    fi
  done
}

remove_published_skill_links() {
  local source_dir="$DOTFILES_DIR/$1"
  local target_dir="$TARGET_HOME/$2"
  local target
  local destination

  if [ -L "$target_dir" ]; then
    if [ "$(readlink "$target_dir")" = "$source_dir" ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "  Would remove legacy repository-owned skills root: ~/$2"
      else
        echo "  Removing legacy repository-owned skills root: ~/$2"
        rm "$target_dir"
      fi
    else
      echo "  Preserving user-managed skills root symlink: ~/$2" >&2
    fi
    return 0
  fi

  [ -d "$target_dir" ] || return 0
  for target in "$target_dir"/*; do
    [ -L "$target" ] || continue
    destination="$(readlink "$target")"
    case "$destination" in
      "$source_dir"/*)
        if [ "$DRY_RUN" = true ]; then
          echo "  Would remove legacy Kalavero skill link: $target"
        else
          echo "  Removing legacy Kalavero skill link: $target"
          rm "$target"
        fi
        ;;
    esac
  done
}

generate_agents() {
  local format="$1"
  local source_dir="$DOTFILES_DIR/plugins/kalavero/agents"
  local target_dir
  local model

  case "$format" in
    claude)
      target_dir="$TARGET_HOME/.claude/agents"
      model="$CLAUDE_SUBAGENT_MODEL"
      ;;
    opencode)
      target_dir="$TARGET_HOME/.config/opencode/agents"
      model="$OPENCODE_SUBAGENT_MODEL"
      ;;
    *)
      echo "sync.sh: unsupported agent format: $format" >&2
      return 2
      ;;
  esac

  if [ -L "$target_dir" ]; then
    if [ "$(readlink "$target_dir")" = "$source_dir" ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "  Would replace legacy $format agents symlink"
        return 0
      fi
      rm "$target_dir"
    else
      echo "  Skipping $format agents: $target_dir is a user-managed symlink" >&2
      return 0
    fi
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "  Would generate $format agents in $target_dir"
    return 0
  fi

  node "$DOTFILES_DIR/script/render-agents.mjs" "$format" "$source_dir" "$target_dir" "$model"
}

configure_opencode_subagent_model() {
  local target="$TARGET_HOME/.config/opencode/plugins/kalavero-subagent-model.ts"
  local marker="Generated by sync.sh"

  if [ -e "$target" ] || [ -L "$target" ]; then
    if ! grep -q "$marker" "$target"; then
      echo "  Skipping OpenCode subagent defaults: $target is user-managed" >&2
      return 0
    fi
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "  Would configure OpenCode subagent defaults"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  cat >"$target" <<EOF
// $marker. Explicit agent model settings take precedence.
export default async function () {
  return {
    config: (config) => {
      config.agent ??= {}

      for (const name of ["general", "explore", "scout"]) {
        config.agent[name] ??= {}
        config.agent[name].model ??= "$OPENCODE_SUBAGENT_MODEL"
      }
    },
  }
}
EOF
}

configure_codex_subagent_model() {
  local target="$TARGET_HOME/.codex/config.toml"
  local candidate="$target.kalavero.$$"

  if [ -L "$target" ]; then
    echo "  Skipping Codex subagent default: $target is a user-managed symlink" >&2
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "  Would configure Codex subagent defaults"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  if ! node "$DOTFILES_DIR/script/configure-codex.mjs" "$target" "$candidate" "$CODEX_SUBAGENT_MODEL"; then
    rm -f "$candidate"
    return 1
  fi

  [ -e "$candidate" ] || return 0
  # mv would replace an existing config with default-umask permissions;
  # carry over the target's mode first (BSD stat, portable on macOS).
  if [ -e "$target" ]; then
    chmod "$(stat -f '%Lp' "$target")" "$candidate"
  fi
  mv "$candidate" "$target"
}

echo "==> Checking for old symlinks..."
remove_old_symlink ".zshrc"
remove_old_symlink ".zshenv"
remove_old_symlink ".aliases"
remove_old_symlink ".tmux.conf"
remove_old_symlink ".gitconfig"
remove_old_symlink ".gitignore"
remove_old_symlink ".zsh"
remove_old_symlink ".vim"
remove_old_symlink ".vimrc"

echo "==> Backing up conflicting configs..."
backup_if_conflict ".config/ghostty"
backup_if_conflict ".config/herdr"

echo "==> Linking shared AI workflow assets..."
link_if_needed "plugins/kalavero/commands" ".claude/commands"
publish_skill_links "plugins/kalavero/skills" ".claude/skills"
generate_agents claude

link_if_needed "plugins/kalavero/commands" ".agents/commands"
publish_skill_links "plugins/kalavero/skills" ".agents/skills"
link_if_needed "plugins/kalavero/agents" ".agents/agents"

link_if_needed "plugins/kalavero/commands" ".config/opencode/commands"
publish_skill_links "plugins/kalavero/skills" ".config/opencode/skills"
generate_agents opencode

link_if_needed "plugins/kalavero/commands" ".pi/agent/prompts"
publish_skill_links "plugins/kalavero/skills" ".pi/agent/skills"

link_if_needed "home/AGENTS.md" ".claude/CLAUDE.md"
link_if_needed "home/AGENTS.md" ".config/opencode/AGENTS.md"
link_if_needed "home/AGENTS.md" ".codex/AGENTS.md"
link_if_needed "home/AGENTS.md" ".pi/agent/AGENTS.md"
link_if_needed "plugins/kalavero/commands" ".codex/commands"
remove_published_skill_links "plugins/kalavero/skills" ".codex/skills"
link_if_needed "plugins/kalavero/agents" ".codex/agents"

echo "==> Configuring lower-cost subagent models..."
configure_opencode_subagent_model
configure_codex_subagent_model

echo "==> Stowing packages..."
while IFS= read -r pkg || [ -n "$pkg" ]; do
  [ -n "$pkg" ] || continue
  if [ -d "$DOTFILES_DIR/$pkg" ]; then
    backup_package_conflicts "$pkg"
    stow_args=(-v -d "$DOTFILES_DIR" -t "$TARGET_HOME")
    # herdr writes runtime state into ~/.config/herdr; folding would turn that
    # directory into a symlink into the repository, bypassing .stow-local-ignore.
    [ "$pkg" = herdr ] && stow_args+=(--no-folding)
    if [ "$DRY_RUN" = true ]; then
      echo "  Would stow $pkg..."
      stow --simulate "${stow_args[@]}" "$pkg"
    else
      echo "  Stowing $pkg..."
      stow "${stow_args[@]}" "$pkg"
    fi
  fi
done < "$DOTFILES_DIR/stow-packages.txt"
