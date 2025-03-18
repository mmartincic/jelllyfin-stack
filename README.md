Media Stack Setup & Management Script
=====================================

This Bash script automates the installation, configuration, and management of a self-hosted media stack using Docker on Ubuntu 22.04 running in an LXC container on Proxmox. The media stack includes:

*   **Jellyfin** – Media server
    
*   **Sonarr** – TV Shows (and Anime) management
    
*   **Radarr** – Movies management
    
*   **Bazarr** – Subtitle management
    
*   **Jellyseerr** – Media request management
    
*   **Jackett** – Torrent indexer interface
    
*   **Transmission** – Torrent client
    

Features
--------

*   **Automatic Docker Installation:**Checks if Docker is installed and prompts you to choose between installing via apt (docker.io & docker-compose) or using the Dockeraise script.
    
*   **User & Directory Setup:**Creates a dedicated user (dockeruser with UID 1000 and custom GID 2000) and ensures all required directories exist with proper permissions.
    
*   **Docker Compose Files:**Automatically generates Docker Compose configuration files for both the streaming and downloading stacks, setting the timezone to Europe/Zagreb and leaving port mappings unchanged.
    
*   **Container Management:**If the media stack is already installed, the script displays a management menu to:
    
    *   Start, stop, or restart individual containers.
        
    *   Show the IP/port mappings for a container.
        
    *   Uninstall the entire media stack (stopping and removing all containers and directories).
        

Requirements
------------

*   Ubuntu 22.04 (in an LXC container on Proxmox)
    
*   Sudo privileges
    
*   Basic knowledge of Linux, Docker, and Docker Compose
    

Installation & Usage
--------------------

1.  Save the script as media\_stack.sh.
    
2.  bashCopyEditchmod +x media\_stack.sh
    
3.  bashCopyEditsudo ./media\_stack.sh
    
4.  **Installation Mode:**
    
    *   If the media stack is not installed, the script will:
        
        *   Check and install Docker (with a choice between apt or Dockeraise).
            
        *   Create the required user and directories.
            
        *   Generate the Docker Compose files for both stacks.
            
        *   Optionally start the containers after installation.
            
5.  If the stack is already installed, the script presents a menu with the following options:
    
    1.  **Start a Container:**Start a specific container by entering its name.
        
    2.  **Stop a Container:**Stop a specific container by entering its name.
        
    3.  **Restart a Container:**Restart a specific container by entering its name.
        
    4.  **Show Container IP/Port Mapping:**Display the IP and port mappings for a running container.
        
    5.  **Uninstall the Media Stack:**Stop all containers, remove them, and delete the installation directories.
        
    6.  **Exit:**Exit the management menu.
        

Directory Structure
-------------------

*   **Stack Directories:**
    
    *   Streaming Stack: /srv/streaming-stack
        
    *   Downloading Stack: /srv/downloading-stack
        
*   **Media Directories:**
    
    *   Movies: /media/movies
        
    *   TV Shows: /media/tvshows
        
    *   Anime: /media/anime
        
    *   Transmission Downloads: /media/transmission/downloads/complete
        
    *   Jackett Downloads: /media/jackett/downloads
        

Customization
-------------

*   **Timezone:**The timezone is set to Europe/Zagreb by default. You can change the TIMEZONE variable in the script if needed.
    
*   **User Settings:**The script creates dockeruser with UID 1000 and GID 2000. Modify the DOCKER\_UID and DOCKER\_GID variables as required.
    
*   **Port Mappings:**The default port mappings are maintained as described in the script. Adjust them in the Docker Compose sections if necessary.
    

Troubleshooting
---------------

*   **Timeout Issues:**The script now uses an extended timeout (120 seconds) for stopping containers during uninstallation and forcefully removes containers if necessary.
    
*   **Docker Issues:**Ensure Docker is properly installed and running. Consult the Docker documentation for additional help.
    

License
-------

This script is provided for educational and personal use. Modify and distribute it as needed.

Disclaimer
----------

This script is provided "as is" without any warranties. Use it at your own risk. The author is not responsible for any damage or data loss caused by running this script.