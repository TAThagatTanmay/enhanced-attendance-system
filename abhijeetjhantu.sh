
set -e  # Exit on error

echo "=== Render Free Tier Installation Script ==="
echo "Fixing KeyError: '__version__' issue..."
pip cache purge 2>/dev/null || true
pip install --upgrade pip
echo "Step 1: Installing base packages..."
pip install --no-cache-dir --upgrade numpy
pip install --no-cache-dir --upgrade setuptools
pip install --no-cache-dir --upgrade wheel
echo "Step 2: Installing utility packages..."
pip install --no-cache-dir python-dotenv
pip install --no-cache-dir PyJWT
pip install --no-cache-dir python-multipart
pip install --no-cache-dir psutil
echo "Step 3: Installing OpenCV (headless)..."
pip install --no-cache-dir opencv-python-headless
echo "Step 4: Installing database connector..."
pip install --no-cache-dir psycopg2-binary
echo "Step 5: Attempting face recognition installation..."
if pip install --no-cache-dir --only-binary=all dlib; then
    echo "dlib installed successfully"
    pip install --no-cache-dir --only-binary=all face-recognition
    echo "face-recognition installed successfully"
else
    echo "WARNING: dlib installation failed - face recognition will be disabled"
fi
pip cache purge 2>/dev/null || true
echo "=== Installation completed ==="
pip list | grep -E "(dlib|face|opencv|numpy)" || echo "Some face recognition packages may be missing"
