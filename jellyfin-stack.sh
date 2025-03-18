#!/bin/bash
set -e

# ----------------------------
# Configuration Variables
# ----------------------------
STREAMING_DIR="/srv/streaming-stack"
DOWNLOADING_DIR="/srv/downloading-stack"
MEDIA_DIRS=( "/media/movies" "/media/tvshows" "/media/anime" "/media/transmission/downloads/complete" "/media/jackett/downloads" )
TIMEZONE="Europe/Zagreb"
DOCKERUSER="dockeruser"
DOCKER_UID=1000
DOCKER_GID=2000

# List of container names per stack
streaming_containers=( jellyfin sonarr radarr bazarr jellyseerr )
downloading_containers=( jackett transmission )

# ----------------------------
# Helper Functions for Output
# ----------------------------
echo_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# ----------------------------
# Function: Install Docker
# ----------------------------
install_docker() {
    if ! command -v docker &>/dev/null; then
        echo_info "Docker is not installed on this system."
        echo "Choose Docker installation method:"
        echo "  1) Install via apt (docker.io & docker-compose)"
        echo "  2) Install via Dockeraise script"
        read -rp "Enter choice (1 or 2): " install_method

        if [[ "$install_method" == "1" ]]; then
            echo_info "Installing Docker using apt..."
            sudo apt-get update
            sudo apt-get install -y docker.io docker-compose
            sudo systemctl enable docker --now
        elif [[ "$install_method" == "2" ]]; then
            echo_info "Installing Docker using Dockeraise..."
            wget -qO- https://raw.githubusercontent.com/Zerodya/dockeraise/main/dockeraise.sh | bash
        else
            echo_error "Invalid choice. Exiting."
            exit 1
        fi
    else
        echo_info "Docker is already installed."
    fi
}

# ----------------------------
# Function: Create dockeruser
# ----------------------------
create_docker_user() {
    if id "$DOCKERUSER" &>/dev/null; then
        echo_info "User '$DOCKERUSER' already exists."
    else
        echo_info "Creating group '$DOCKERUSER' with GID $DOCKER_GID..."
        sudo groupadd -g "$DOCKER_GID" "$DOCKERUSER"
        echo_info "Creating user '$DOCKERUSER' with UID $DOCKER_UID and GID $DOCKER_GID..."
        sudo useradd "$DOCKERUSER" -u "$DOCKER_UID" -g "$DOCKER_GID" -s /bin/bash
    fi
}

# ----------------------------
# Function: Create Required Directories
# ----------------------------
create_directories() {
    # Create stack directories if they don't exist
    for dir in "$STREAMING_DIR" "$DOWNLOADING_DIR"; do
        if [ ! -d "$dir" ]; then
            echo_info "Creating directory $dir..."
            sudo mkdir -p "$dir"
        else
            echo_info "Directory $dir already exists."
        fi
    done

    # Create media directories
    for dir in "${MEDIA_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            echo_info "Creating directory $dir..."
            sudo mkdir -p "$dir"
        else
            echo_info "Directory $dir already exists."
        fi
    done

    # Set ownership on the stack directories and media folders
    echo_info "Setting ownership for $STREAMING_DIR, $DOWNLOADING_DIR and /media directories to $DOCKERUSER:$DOCKERUSER..."
    sudo chown -R "$DOCKERUSER:$DOCKERUSER" "$STREAMING_DIR" "$DOWNLOADING_DIR" /media
}

# ----------------------------
# Function: Write Docker Compose Files
# ----------------------------
create_docker_compose_files() {
    echo_info "Creating docker-compose file for streaming stack in $STREAMING_DIR..."
    sudo tee "$STREAMING_DIR/docker-compose.yml" >/dev/null <<EOF
version: "3"
services:
  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    environment:
      - PUID=${DOCKER_UID}
      - PGID=${DOCKER_GID}
      - TZ=${TIMEZONE}
    volumes:
      - ./jellyfin_config:/config
      - /media/tvshows:/data/tvshows
      - /media/movies:/data/movies
      - /media/anime:/data/anime
    ports:
      - "8096:8096"
    restart: unless-stopped

  sonarr:
    image: linuxserver/sonarr
    container_name: sonarr
    environment:
      - PUID=${DOCKER_UID}
      - PGID=${DOCKER_GID}
      - TZ=${TIMEZONE}
    volumes:
      - ./sonarr_config:/config
      - /media/anime:/anime
      - /media/tvshows:/tvshows
      - /media/transmission/downloads/complete:/downloads/complete
    ports:
      - "8989:8989"
    restart: unless-stopped

  radarr:
    image: linuxserver/radarr
    container_name: radarr
    environment:
      - PUID=${DOCKER_UID}
      - PGID=${DOCKER_GID}
      - TZ=${TIMEZONE}
    volumes:
      - ./radarr_config:/config
      - /media/transmission/downloads/complete:/downloads/complete
      - /media/movies:/movies
    ports:
      - "7878:7878"
    restart: unless-stopped

  bazarr:
    image: linuxserver/bazarr
    container_name: bazarr
    environment:
      - PUID=${DOCKER_UID}
      - PGID=${DOCKER_GID}
      - TZ=${TIMEZONE}
    volumes:
      - ./bazarr_config:/config
      - /media/movies:/movies
    ports:
      - "6767:6767"
    restart: unless-stopped

  jellyseerr:
    image: fallenbagel/jellyseerr:develop
    container_name: jellyseerr
    environment:
      - PUID=${DOCKER_UID}
      - PGID=${DOCKER_GID}
      - LOG_LEVEL=debug
      - TZ=${TIMEZONE}
    ports:
      - "5055:5055"
    volumes:
      - ./jellyseerr_config:/app/config
    restart: unless-stopped
    depends_on:
      - radarr
      - sonarr
EOF

    echo_info "Creating docker-compose file for downloading stack in $DOWNLOADING_DIR..."
    sudo tee "$DOWNLOADING_DIR/docker-compose.yml" >/dev/null <<EOF
version: "2.1"
services:
  jackett:
    image: linuxserver/jackett
    container_name: jackett
    environment:
      - PUID=${DOCKER_UID}
      - PGID=${DOCKER_GID}
      - TZ=${TIMEZONE}
      - AUTO_UPDATE=true
    volumes:
      - ./jackett:/config
      - /media/jackett/downloads:/downloads
    ports:
      - "9117:9117"
    restart: unless-stopped

  transmission:
    image: linuxserver/transmission
    container_name: transmission
    environment:
      - PUID=${DOCKER_UID}
      - PGID=${DOCKER_GID}
      - TZ=${TIMEZONE}
    volumes:
      - ./transmission:/config
      - /media/transmission/downloads:/downloads
    ports:
      - "9091:9091"
      - "51413:51413"
      - "51413:51413/udp"
    restart: unless-stopped
EOF
}

# ----------------------------
# Function: Install the Entire Stack
# ----------------------------
install_stack() {
    echo_info "Starting installation of the media stack..."
    install_docker
    create_docker_user
    create_directories
    create_docker_compose_files

    echo "Do you want to start the Docker containers now? (y/n)"
    read -rp "> " start_choice
    if [[ "$start_choice" =~ ^[Yy]$ ]]; then
        echo_info "Starting containers in streaming stack..."
        (cd "$STREAMING_DIR" && sudo docker-compose up -d)
        echo_info "Starting containers in downloading stack..."
        (cd "$DOWNLOADING_DIR" && sudo docker-compose up -d)
        echo_info "Listing running containers:"
        sudo docker ps
    else
        echo_info "Installation complete. You can later start the containers by navigating to the respective directories and running 'docker-compose up -d'."
    fi
}

# ----------------------------
# Function: Determine if the Stack Is Installed
# ----------------------------
is_installed() {
    if [ -f "$STREAMING_DIR/docker-compose.yml" ] && [ -f "$DOWNLOADING_DIR/docker-compose.yml" ]; then
        return 0
    else
        return 1
    fi
}

# ----------------------------
# Function: Map Container to Its Stack Directory
# ----------------------------
get_stack_dir_for_container() {
    local container="$1"
    if [[ " ${streaming_containers[*]} " == *" $container "* ]]; then
        echo "$STREAMING_DIR"
    elif [[ " ${downloading_containers[*]} " == *" $container "* ]]; then
        echo "$DOWNLOADING_DIR"
    else
        echo ""
    fi
}

# ----------------------------
# Function: Manage (Start/Stop/Restart) a Container
# ----------------------------
manage_container() {
    local action="$1"
    read -rp "Enter container name: " container
    dir=$(get_stack_dir_for_container "$container")
    if [ -z "$dir" ]; then
        echo_error "Container '$container' is not part of the managed stack."
        return
    fi
    echo_info "Running '$action' on container '$container'..."
    (cd "$dir" && sudo docker-compose $action "$container")
}

# ----------------------------
# Function: Show Container Info
# ----------------------------
show_container_info() {
    read -rp "Enter container name: " container
    if ! sudo docker ps --format '{{.Names}}' | grep -wq "$container"; then
        echo_error "Container '$container' is not running."
        return
    fi
    echo_info "Port mappings for container '$container':"
    sudo docker port "$container"
}

# ----------------------------
# Function: Uninstall the Stack
# ----------------------------
uninstall_stack() {
    echo "WARNING: This will stop and remove all containers and delete the stack directories."
    read -rp "Are you sure you want to proceed? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo_info "Stopping and removing containers for streaming stack..."
        if ! (cd "$STREAMING_DIR" && sudo docker-compose down --timeout 120); then
            echo_error "docker-compose down failed for streaming stack, attempting force removal..."
            for container in "${streaming_containers[@]}"; do
                sudo docker rm -f "$container" || true
            done
        fi

        echo_info "Stopping and removing containers for downloading stack..."
        if ! (cd "$DOWNLOADING_DIR" && sudo docker-compose down --timeout 120); then
            echo_error "docker-compose down failed for downloading stack, attempting force removal..."
            for container in "${downloading_containers[@]}"; do
                sudo docker rm -f "$container" || true
            done
        fi

        echo_info "Removing directories $STREAMING_DIR and $DOWNLOADING_DIR..."
        sudo rm -rf "$STREAMING_DIR" "$DOWNLOADING_DIR"
        echo_info "Media stack uninstalled."
        exit 0
    else
        echo_info "Uninstallation cancelled."
    fi
}

# ----------------------------
# Management Menu
# ----------------------------
management_menu() {
    while true; do
        echo ""
        echo "----------------------"
        echo "Media Stack Management Menu"
        echo "----------------------"
        echo "1) Start a container"
        echo "2) Stop a container"
        echo "3) Restart a container"
        echo "4) Show container IP/port mapping"
        echo "5) Uninstall the media stack"
        echo "6) Exit"
        read -rp "Choose an option [1-6]: " choice
        case "$choice" in
            1)
                manage_container "up -d"
                ;;
            2)
                manage_container "stop"
                ;;
            3)
                manage_container "restart"
                ;;
            4)
                show_container_info
                ;;
            5)
                uninstall_stack
                ;;
            6)
                echo_info "Exiting management menu."
                exit 0
                ;;
            *)
                echo_error "Invalid option, please choose between 1 and 6."
                ;;
        esac
    done
}

# ----------------------------
# Main Execution Flow
# ----------------------------
if is_installed; then
    echo_info "Media stack installation detected."
    management_menu
else
    install_stack
fi
