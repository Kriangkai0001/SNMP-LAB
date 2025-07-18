# SNMP-LAB

<img width="781" height="703" alt="image" src="https://github.com/user-attachments/assets/2f612188-693d-406f-8b44-a3dde96077ef" />



-----

# **Mikrotik Router Monitoring Lab with Prometheus & Grafana**

This repository provides a comprehensive guide for setting up a virtualized network to monitor a Mikrotik Router using SNMP, Prometheus, and Grafana. Learn to collect, store, and visualize network performance metrics effectively, especially for devices with limited bandwidth.

-----

## **Prerequisites**

Before starting this lab, prepare the following VM image files:

1.  **Red Hat Enterprise Linux (RHEL):**

      * Download from: [https://access.redhat.com/downloads/content/rhel](https://access.redhat.com/downloads/content/rhel)
      * *Note: Account registration might be required for trial/developer versions.*

2.  **Mikrotik RouterOS (.vmdk):**

      * Download the CHR (Cloud Hosted Router) .vmdk from: [https://mikrotik.com/download/archive](https://download.mikrotik.com/routeros/6.49.18/chr-6.49.18.vmdk.zip)
      * *Note: Select "Cloud Hosted Router (CHR)" and the .vmdk file format for your virtualization software.*

-----

## **Lab Setup: Initial VM Configuration & Repository Setup**

### **Step 1: Install Router and Red Hat VMs**

1.  **Install Mikrotik Router VM:**

      * Create a new Virtual Machine (VM) in your virtualization software (e.g., VMware Workstation/Fusion, VirtualBox).
      * Use the downloaded Mikrotik RouterOS CHR `.vmdk` file as the VM's hard disk.
      * Configure Network Adapters according to the provided diagram:
          * You should have at least 3 Network Adapters:
              * **NAT (for Internet connectivity):** To allow the Mikrotik to access external networks.
              * **LAN Segment 1 (for Monitoring Server connection):** Use a dedicated network segment like Host-only or Internal Network.
              * **LAN Segment 2, 3 (for User Test Clients):** Use separate dedicated network segments or a single one if DHCP is provided to clients by Mikrotik.
      * **Power on VM and Basic Setup:** Log in to Mikrotik (default user: `admin`, no password), configure IP Addresses for each interface as per the diagram (plan IP addresses for LAN Segment 1 for later use), and enable DHCP Server for LAN Segment 2/3 (if desired).
      * **Enable SNMP:** Crucially, enable the SNMP service on the Mikrotik Router (you'll configure the community string later).

2.  **Install Red Hat Enterprise Linux (RHEL) VM:**

      * Create a new VM for RHEL.
      * Use the downloaded RHEL ISO file.
      * Configure Network Adapters:
          * At least one Network Adapter should connect to **LAN Segment 1** of the Mikrotik Router (use the same network segment).
          * Optionally, add another Network Adapter for **NAT/Bridged** if you want the RHEL VM to have direct internet access for installation or package downloads (recommended).
      * **Complete RHEL Installation:** Choose a Minimal Install or Server with GUI based on your preference. Ensure network configuration is correct and connectivity is established.

### **Step 2: Mount ISO and Configure Local Repository on Red Hat**

1.  **Connect to RHEL VM:** Via SSH or the VM console.

2.  **Mount ISO/DVD (if needed):**

      * If you plan to use the RHEL ISO as a local package source (e.g., for installing necessary packages offline), mount it:

    <!-- end list -->

    ```bash
    sudo mkdir /mnt/cdrom
    sudo mount /dev/sr0 /mnt/cdrom  # /dev/sr0 is typically the CD-ROM/DVD drive device name
    ```

      * *Note: If your RHEL VM has direct internet access (e.g., via NAT/Bridged Adapter) and you will use Red Hat Subscription Manager to download packages, this ISO mount might not be strictly necessary for repo setup, but it's useful for offline package installation.*

3.  **Create `mountrepo.sh` script (for Repository Configuration):**

      * Open a new file using `vi`:

    <!-- end list -->

    ```bash
    vi mountrepo.sh
    ```

      * **Copy and paste the script content below** into `vi` (Press `i` for Insert Mode, paste, press `Esc`, type `:wq` and Enter to save and exit):

    <!-- end list -->

    ```bash
    #!/bin/bash

    # --- Script to configure a local YUM/DNF repository from a mounted RHEL ISO ---

    # Define mount point and repo ID
    MOUNT_POINT="/mnt/cdrom"
    REPO_ID="rhel-local-media"
    REPO_NAME="Red Hat Enterprise Linux Local Media"

    echo "Checking if ${MOUNT_POINT} is mounted..."
    if ! mountpoint -q "${MOUNT_POINT}"; then
        echo "Error: ${MOUNT_POINT} is not mounted. Please mount your RHEL ISO first. (e.g., sudo mount /dev/sr0 ${MOUNT_POINT})"
        exit 1
    fi

    echo "Creating repository configuration file..."
    sudo tee /etc/yum.repos.d/${REPO_ID}.repo > /dev/null <<EOF
    [${REPO_ID}]
    name=${REPO_NAME}
    baseurl=file://${MOUNT_POINT}/AppStream
    enabled=1
    gpgcheck=0

    [${REPO_ID}-BaseOS]
    name=${REPO_NAME} - BaseOS
    baseurl=file://${MOUNT_POINT}/BaseOS
    enabled=1
    gpgcheck=0
    EOF

    echo "Cleaning YUM/DNF cache and updating repository list..."
    sudo dnf clean all
    sudo dnf repolist

    echo "Local repository setup complete. You can now install packages from the mounted ISO."
    echo "To test: sudo dnf install httpd"
    ```

4.  **Make the script executable:**

    ```bash
    chmod +x mountrepo.sh
    ```

5.  **Run the `mountrepo.sh` script:**

    ```bash
    ./mountrepo.sh
    ```

      * This script will check if the RHEL ISO is mounted and then create the necessary `.repo` files pointing to the AppStream and BaseOS directories on your ISO, allowing `dnf` to install packages from it.

### **Step 3: Download and Prepare Grafana/Prometheus Installation Script**

1.  **Create `install_monitoring_tools.sh` script:**
      * Open a new file using `vi`:
    <!-- end list -->
    ```bash
    vi install_monitoring_tools.sh
    ```
      * **Copy and paste the script content below** into `vi` (Press `i` for Insert Mode, paste, press `Esc`, type `:wq` and Enter to save and exit):

<!-- end list -->

```bash
#!/bin/bash

# --- Script to Install Grafana, Prometheus, and SNMP Exporter on RHEL ---
# This script assumes you have a working internet connection or a configured local RHEL repository.

echo "Starting installation of monitoring tools..."

# --- 1. Install Grafana ---
echo "Installing Grafana..."
# Add Grafana repository
sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<EOF
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install Grafana
sudo dnf install -y grafana

# Start and enable Grafana service
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
echo "Grafana installed and started. Access at http://YOUR_RHEL_IP:3000"

# --- 2. Install Prometheus ---
echo "Installing Prometheus..."
# Create Prometheus user
sudo useradd --no-create-home --shell /bin/false prometheus

# Create necessary directories
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

# Download Prometheus (adjust version as needed)
PROMETHEUS_VERSION="2.51.1" # Check for latest stable version on Prometheus website
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz

tar -xvf /tmp/prometheus.tar.gz -C /tmp/
sudo cp /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
sudo cp /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
sudo cp -r /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /etc/prometheus
sudo cp -r /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus

# Set ownership
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /var/lib/prometheus

# Create prometheus.yml (basic config, will need to add snmp_exporter target later)
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Set ownership for config
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Create systemd service file for Prometheus
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=:9090
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Start and enable Prometheus service
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
echo "Prometheus installed and started. Access at http://YOUR_RHEL_IP:9090"

# --- 3. Install SNMP Exporter ---
echo "Installing SNMP Exporter..."
# Create SNMP Exporter user
sudo useradd --no-create-home --shell /bin/false snmp_exporter

# Create necessary directories
sudo mkdir /etc/snmp_exporter

# Download SNMP Exporter (adjust version as needed)
SNMP_EXPORTER_VERSION="0.25.0" # Check for latest stable version on GitHub
wget https://github.com/prometheus/snmp_exporter/releases/download/v${SNMP_EXPORTER_VERSION}/snmp_exporter-${SNMP_EXPORTER_VERSION}.linux-amd64.tar.gz -O /tmp/snmp_exporter.tar.gz

tar -xvf /tmp/snmp_exporter.tar.gz -C /tmp/
sudo cp /tmp/snmp_exporter-${SNMP_EXPORTER_VERSION}.linux-amd64/snmp_exporter /usr/local/bin/

# Set ownership
sudo chown snmp_exporter:snmp_exporter /usr/local/bin/snmp_exporter

# Create snmp.yml (initial config, needs MIBs and Mikrotik target later)
# This is a very basic example. You will need a full snmp.yml with Mikrotik OIDs.
# For a real setup, download snmp.yml from: https://github.com/prometheus/snmp_exporter/tree/main/generator
sudo tee /etc/snmp_exporter/snmp.yml > /dev/null <<EOF
modules:
  mikrotik:
    walk:
      - sysUpTime
      - ifDescr
      - ifInOctets
      - ifOutOctets
      - hrStorageUsed
      - hrStorageSize
      - hrMemorySize
    version: 2c
    retries: 3
    timeout: 5s
    community: public # IMPORTANT: CHANGE THIS TO YOUR MIKROTIK SNMP COMMUNITY STRING!
EOF

# Set ownership for config
sudo chown snmp_exporter:snmp_exporter /etc/snmp_exporter/snmp.yml

# Create systemd service file for SNMP Exporter
sudo tee /etc/systemd/system/snmp_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus SNMP Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=snmp_exporter
Group=snmp_exporter
Type=simple
ExecStart=/usr/local/bin/snmp_exporter \
    --config.file=/etc/snmp_exporter/snmp.yml \
    --web.listen-address=:9116
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Start and enable SNMP Exporter service
sudo systemctl daemon-reload
sudo systemctl enable snmp_exporter
sudo systemctl start snmp_exporter
echo "SNMP Exporter installed and started. Access at http://YOUR_RHEL_IP:9116/snmp?target=YOUR_MIKROTIK_IP&module=mikrotik"

echo "--- Installation Complete! ---"
echo "Next Steps:"
echo "1. Configure your Mikrotik Router's SNMP service (ensure community string matches snmp.yml)."
echo "2. Edit /etc/prometheus/prometheus.yml to add the snmp_exporter target for your Mikrotik."
echo "   Example target for prometheus.yml:"
echo "   - job_name: 'mikrotik_snmp'"
echo "     static_configs:"
echo "       - targets: ['YOUR_MIKROTIK_IP'] # Replace with actual Mikrotik IP"
echo "     relabel_configs:"
echo "       - source_labels: [__address__]"
echo "         target_label: __param_target"
echo "       - source_labels: [__param_target]"
C:\Users\User\Downloads\Script_install_grafana_prometheus_sh_.txt         target_label: instance"
echo "       - target_label: __address__"
echo "         replacement: localhost:9116 # SNMP Exporter address"
echo "     metrics_path: /snmp"
echo "     params:"
echo "       module: [mikrotik]"
echo "3. Restart Prometheus: sudo systemctl restart prometheus"
echo "4. Import a Mikrotik Dashboard in Grafana (e.g., ID 10972 for RouterOS). Configure the data source to Prometheus."
```

---

### **Step 4: Install Mikrotik Router from `.vmdk` Image and Configure Network Adapters**

Prior to running any scripts on your RHEL VM, ensure your Mikrotik Router VM is properly set up with the correct network configurations as per the provided diagram.

1.  **Create a New Virtual Machine for Mikrotik:**
    * Utilize your preferred virtualization software (e.g., VMware Workstation/Fusion, VirtualBox).
    * Create a new VM, selecting the downloaded **Mikrotik RouterOS CHR `.vmdk`** file as the virtual hard disk.
    * Allocate appropriate resources (RAM, CPU) for the router.

2.  **Configure Network Adapters for Mikrotik VM:**
    This is a critical step to accurately reflect the network diagram. Your Mikrotik VM will require at least **4 network adapters**.

    * **Adapter 1: NAT**
        * **Type:** Configure as a NAT network within your virtualization software.
        * **Purpose:** Provides internet access to the Mikrotik Router.

    * **Adapter 2: LAN Segment 1 (for Monitoring Server)**
        * **Type:** Set up as a dedicated internal or host-only network segment.
        * **Purpose:** This adapter will form the direct connection to your RHEL VM (Monitoring Server). Ensure this segment is isolated from your host's main network.

    * **Adapter 3: LAN Segment 2 (for User Test Client 1)**
        * **Type:** Configure as another distinct internal or host-only network segment, separate from LAN Segment 1.
        * **Purpose:** Connects to your first user test client VM.

    * **Adapter 4: LAN Segment 3 (for User Test Client 2)**
        * **Type:** Configure as a third distinct internal or host-only network segment, separate from LAN Segment 1 and LAN Segment 2.
        * **Purpose:** Connects to your second user test client VM.

3.  **Initial Mikrotik Router Configuration:**
    * Power on the Mikrotik Router VM and access its console.
    * Log in using default credentials and set a new password.
    * **Interface Identification:** Identify which virtual interface (e.g., `ether1`, `ether2`, etc.) corresponds to each of the network adapters you configured.
    * **IP Addressing & DHCP:** Configure IP addresses for each interface according to your network plan. Set up DHCP pools and DHCP servers for LAN Segment 2 and LAN Segment 3 as indicated in the diagram.
    * **NAT/Masquerade:** Configure NAT (Network Address Translation) or Masquerade rules on the interface connected to the internet (NAT adapter) to allow internal clients to access external networks.
    * **Enable SNMP Service:** Activate the SNMP service on the Mikrotik Router. You will need to define an SNMP Community String. **Remember this community string, as it will be used later for the SNMP Exporter.**

---

### **Additional Tips for Monitoring Server Setup (RHEL VM)**

These tips are crucial preparations to consider while setting up your RHEL VM, directly following the Mikrotik configuration.

* **Add an Internet-Facing Network Interface to the RHEL Monitoring Server:**
    * In addition to the network adapter connecting to Mikrotik's "LAN Segment 1", it is **highly recommended to add a second network adapter** to your RHEL VM (Monitoring Server).
    * **Type:** Configure this second adapter as `NAT` or `Bridged` (depending on your host's network setup and preference).
    * **Purpose:** This direct internet access for the RHEL VM will greatly facilitate downloading packages, system updates, and searching for information during the installation of Prometheus, Grafana, and SNMP Exporter.

* **Check Port Usage:**
    * Before and after installing services (Prometheus, Grafana, SNMP Exporter), you should verify that the ports these services use (e.g., Grafana: 3000, Prometheus: 9090, SNMP Exporter: 9116) are not already in use by other services.
    * Also, ensure that your RHEL VM's firewall (e.g., `firewalld`) is configured to allow incoming connections on these ports if you plan to access them from your host machine or other VMs.

* **Install `snmpwalk` and `snmpget`:**
    * On your RHEL VM (Monitoring Server), install the `snmpwalk` and `snmpget` utilities. These tools are invaluable for testing SNMP connectivity to your Mikrotik Router.
    * They allow you to query SNMP data directly from the Mikrotik, helping you confirm that the Mikrotik's SNMP service is enabled and that your chosen Community String is correct before configuring the SNMP Exporter.
    * You can typically install these tools by finding and installing the `net-snmp-utils` package (or similar) using your RHEL's package manager (`dnf`).

* **Study MIB OID (Management Information Base Object Identifier):**
    * To effectively pull specific metrics from your Mikrotik Router via SNMP, you need to understand the MIBs and OIDs that Mikrotik uses.
    * Mikrotik provides its own MIBs (e.g., `MIKROTIK-MIB`) which define OIDs for various data points such as CPU usage, RAM, interface traffic, wireless status, etc.
    * Studying the relevant MIBs and OIDs will allow you to precisely configure `snmp_exporter` to gather the specific data you need and build effective dashboards in Grafana. You can typically find Mikrotik MIB files on their official website.

---

