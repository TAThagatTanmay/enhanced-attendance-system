#!/bin/bash

# Render-ready installation script - Fixed for memory limits

pip install --no-cache-dir setuptools
pip install --no-cache-dir wheel
pip install --no-cache-dir Flask
pip install --no-cache-dir Flask-CORS
pip install --no-cache-dir Werkzeug
pip install --no-cache-dir gunicorn
pip install --no-cache-dir psycopg2-binary
pip install --no-cache-dir python-dotenv
pip install --no-cache-dir PyJWT
pip install --no-cache-dir python-multipart
pip install --no-cache-dir psutil

# Optional packages - may fail on free tier
pip install --no-cache-dir numpy || echo "Warning: numpy installation failed"
pip install --no-cache-dir Pillow || echo "Warning: Pillow installation failed" 
pip install --no-cache-dir opencv-python-headless || echo "Warning: opencv installation failed"

echo "Installation completed successfully!"
