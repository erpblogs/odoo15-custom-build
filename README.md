# Build an image
docker build -t odoo-app .

# Run container with image
docker run --name odoo-mbo --network odoo-nextjs_odoo-network -p 8069:8069 -p 8071:8071 -p 8072:8072 odoo-app /usr/bin/python3 /opt/odoo/core/odooce/odoo-bin

# in this case using exites network 
odoo-nextjs_odoo-network

docker compose -f docker-compose.dev.yml up --build