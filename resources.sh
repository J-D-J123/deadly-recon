#!/bin/bash

# resources.sh: Installation script for all the resource 
# dependencies required by the Deadly Reconnaissance Package 

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════╗"
echo "║  Deadly Reconnaissance Package Installer       ║"
echo "║  resources.sh                                  ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
            print_status "Detected: Debian/Ubuntu Linux"
        elif [ -f /etc/redhat-release ]; then
            OS="redhat"
            print_status "Detected: RedHat/CentOS/Fedora Linux"
        else
            OS="linux"
            print_status "Detected: Generic Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        print_status "Detected: macOS"
    else
        print_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
}

# Install newer Go version
install_go_binary() {
    print_status "Checking Go version..."
    
    # Check if Go is installed and version
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        MAJOR=$(echo $GO_VERSION | cut -d. -f1)
        MINOR=$(echo $GO_VERSION | cut -d. -f2)
        
        if [ "$MAJOR" -ge 1 ] && [ "$MINOR" -ge 21 ]; then
            print_success "Go version $GO_VERSION is sufficient"
            return
        else
            print_warning "Go version $GO_VERSION is too old, installing newer version..."
        fi
    fi
    
    print_status "Installing Go 1.23.5 (latest stable)..."
    
    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        GO_ARCH="amd64"
    elif [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
        GO_ARCH="arm64"
    else
        print_error "Unsupported architecture: $ARCH"
        exit 1
    fi
    
    # Download and install Go
    cd /tmp
    wget https://go.dev/dl/go1.23.5.linux-${GO_ARCH}.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.23.5.linux-${GO_ARCH}.tar.gz
    rm go1.23.5.linux-${GO_ARCH}.tar.gz
    
    # Update PATH for current session
    export PATH=$PATH:/usr/local/go/bin
    
    print_success "Go 1.23.5 installed"
}

# Install system dependencies
install_system_deps() {
    print_status "Installing system dependencies..."
    
    if [ "$OS" == "debian" ]; then
        sudo apt-get update
        sudo apt-get install -y \
            git \
            nmap \
            python3 \
            python3-pip \
            wget \
            curl \
            build-essential \
            libssl-dev \
            libffi-dev \
            python3-dev
            
    elif [ "$OS" == "redhat" ]; then
        sudo yum install -y \
            git \
            nmap \
            python3 \
            python3-pip \
            wget \
            curl \
            gcc \
            openssl-devel \
            libffi-devel \
            python3-devel
            
    elif [ "$OS" == "macos" ]; then
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            print_status "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        brew install git go nmap python3 wget
    fi
    
    print_success "System dependencies installed"
}

# Setup Go environment
setup_go() {
    print_status "Setting up Go environment..."
    
    # Add Go to PATH if not already there
    if ! grep -q "/usr/local/go/bin" ~/.bashrc 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi
    
    if ! grep -q "GOPATH" ~/.bashrc 2>/dev/null; then
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
    fi
    
    if [ -f ~/.zshrc ]; then
        if ! grep -q "/usr/local/go/bin" ~/.zshrc 2>/dev/null; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
        fi
        if ! grep -q "GOPATH" ~/.zshrc 2>/dev/null; then
            echo 'export GOPATH=$HOME/go' >> ~/.zshrc
            echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
        fi
    fi
    
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
    
    mkdir -p $HOME/go/{bin,src,pkg}
    print_success "Go environment configured"
}

# Install Go-based tools
install_go_tools() {
    print_status "Installing Go-based security tools..."
    
    # Subfinder - use specific working version
    print_status "Installing subfinder..."
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@v2.6.6
    
    # Assetfinder
    print_status "Installing assetfinder..."
    go install github.com/tomnomnom/assetfinder@latest
    
    # Amass - use specific working version
    print_status "Installing amass..."
    go install -v github.com/owasp-amass/amass/v4/...@v4.2.0
    
    # Nuclei - use specific working version
    print_status "Installing nuclei..."
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@v3.2.9
    
    # Httpx (bonus - for checking live hosts)
    print_status "Installing httpx..."
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@v1.6.4
    
    print_success "Go tools installed"
}

# Install EyeWitness
install_eyewitness() {
    print_status "Installing EyeWitness..."
    
    cd ~
    
    if [ -d "EyeWitness" ]; then
        print_warning "EyeWitness directory already exists, updating..."
        cd EyeWitness
        git pull
    else
        git clone https://github.com/RedSiege/EyeWitness.git
        cd EyeWitness
    fi
    
    cd Python/setup
    
    if [ "$OS" == "macos" ]; then
        print_status "Installing Python dependencies for EyeWitness..."
        pip3 install -r requirements.txt
    else
        sudo ./setup.sh
    fi
    
    cd ~
    print_success "EyeWitness installed"
}

# Create symbolic links for easy access
create_symlinks() {
    print_status "Creating symbolic links..."
    
    # Create bin directory if it doesn't exist
    mkdir -p ~/.local/bin
    
    # Add to PATH if not already there
    if ! grep -q ".local/bin" ~/.bashrc 2>/dev/null; then
        echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
    fi
    
    if [ -f ~/.zshrc ] && ! grep -q ".local/bin" ~/.zshrc 2>/dev/null; then
        echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.zshrc
    fi
    
    # Create symlink for EyeWitness
    if [ -f ~/EyeWitness/Python/EyeWitness.py ]; then
        ln -sf ~/EyeWitness/Python/EyeWitness.py ~/.local/bin/eyewitness
        chmod +x ~/.local/bin/eyewitness
    fi
    
    print_success "Symbolic links created"
}

# Verify installations
verify_tools() {
    print_status "Verifying tool installations..."
    
    local tools=("subfinder" "assetfinder" "amass" "nuclei" "nmap" "httpx")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if command -v $tool &> /dev/null; then
            print_success "$tool: $(which $tool)"
        else
            print_error "$tool: NOT FOUND"
            missing+=($tool)
        fi
    done
    
    # Check EyeWitness
    if [ -f ~/EyeWitness/Python/EyeWitness.py ] || command -v eyewitness &> /dev/null; then
        print_success "eyewitness: Installed"
    else
        print_error "eyewitness: NOT FOUND"
        missing+=(eyewitness)
    fi
    
    if [ ${#missing[@]} -eq 0 ]; then
        echo ""
        print_success "All tools installed successfully!"
        echo ""
        print_status "You may need to restart your terminal or run:"
        echo "  source ~/.bashrc"
        echo ""
    else
        echo ""
        print_warning "Some tools failed to install: ${missing[*]}"
        print_status "Try running this script again or install them manually"
    fi
}

# Main installation function
main() {
    detect_os
    echo ""
    
    print_warning "This script will install security reconnaissance tools"
    print_warning "Some commands require sudo privileges"
    echo -n "Continue? (y/n): "
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_error "Installation cancelled"
        exit 0
    fi
    
    echo ""
    install_system_deps
    echo ""
    install_go_binary
    echo ""
    setup_go
    echo ""
    install_go_tools
    echo ""
    install_eyewitness
    echo ""
    create_symlinks
    echo ""
    verify_tools
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Installation Complete!                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    print_status "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.bashrc"
    echo "  2. Run the recon script: ./recon_script.sh example.com"
    echo ""
}

# Run main function
main
