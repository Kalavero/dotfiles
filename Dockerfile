FROM alpine:edge

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

# Stow all packages
RUN stow -v -t /root zsh aliases starship git neovim tmux bin

# Install TPM
RUN git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm

# Create undo dir for Neovim
RUN mkdir -p /root/.config/nvim/undodir

CMD ["zsh"]
