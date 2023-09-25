[Unit]
Description=Live Patching Service
Wants=network-online.target
After=network-online.target

[Service]
Restart=always
RestartSec=1800s
ExecStart=/opt/azure/containers/ubuntu-live-patching.sh

[Install]
WantedBy=multi-user.target
