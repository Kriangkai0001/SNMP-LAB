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