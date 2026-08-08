FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

ENV HOME=/root
ENV LANG=en_US.UTF-8

# Core tools
RUN apk add --no-cache \
  git curl stow zsh tmux neovim ripgrep fd \
  build-base cmake unzip nodejs npm

# Install starship
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# Copy dotfiles into container
COPY . /root/kalavero_dotfiles

WORKDIR /root/kalavero_dotfiles

# Stow all packages from the same registry used by sync.sh
RUN while IFS= read -r package || [ -n "$package" ]; do \
      [ -n "$package" ] || continue; \
      stow -v -t /root "$package"; \
    done < stow-packages.txt

# Install TPM
RUN git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm

# Create undo dir for Neovim
RUN mkdir -p /root/.config/nvim/undodir

CMD ["zsh"]
