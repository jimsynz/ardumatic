#!/bin/bash
# Gazebo Diagnostics Script
# Provides feedback about what's happening in the simulation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

check_gazebo_running() {
    log "Checking if Gazebo is running..."
    
    if pgrep -f "gz sim" > /dev/null; then
        success "Gazebo process found"
        ps aux | grep "gz sim" | grep -v grep
    else
        error "No Gazebo process found"
        return 1
    fi
}

check_model_loading() {
    log "Checking model loading status..."
    
    # Check if we can query Gazebo
    if command -v gz >/dev/null 2>&1; then
        log "Querying Gazebo for loaded models..."
        
        # List all models in the simulation
        if gz model --list 2>/dev/null; then
            success "Successfully queried Gazebo models"
        else
            warning "Could not query Gazebo models (simulation may not be ready)"
        fi
        
        # Check specific model
        log "Checking for hexapod model..."
        if gz model --list 2>/dev/null | grep -q "demo_hexapod"; then
            success "Hexapod model found in simulation"
            
            # Get model pose
            log "Getting hexapod pose..."
            gz model --model demo_hexapod --pose 2>/dev/null || warning "Could not get model pose"
            
            # List model links
            log "Listing hexapod links..."
            gz model --model demo_hexapod --link 2>/dev/null || warning "Could not list model links"
            
        else
            error "Hexapod model not found in simulation"
        fi
    else
        error "gz command not found"
    fi
}

check_world_file() {
    log "Checking world file..."
    
    local world_file="worlds/flat_terrain.sdf"
    if [ -f "$world_file" ]; then
        success "World file exists: $world_file"
        
        # Check if hexapod is included
        if grep -q "demo_hexapod" "$world_file"; then
            success "Hexapod model referenced in world file"
        else
            error "Hexapod model not referenced in world file"
        fi
        
        # Check model path
        if grep -q "model://hexapod" "$world_file"; then
            success "Hexapod model URI found in world file"
        else
            error "Hexapod model URI not found in world file"
        fi
    else
        error "World file not found: $world_file"
    fi
}

check_model_files() {
    log "Checking model files..."
    
    local model_dir="models/hexapod"
    if [ -d "$model_dir" ]; then
        success "Model directory exists: $model_dir"
        
        if [ -f "$model_dir/model.config" ]; then
            success "model.config exists"
            log "model.config contents:"
            head -10 "$model_dir/model.config"
        else
            error "model.config missing"
        fi
        
        if [ -f "$model_dir/model.sdf" ]; then
            success "model.sdf exists"
            log "model.sdf size: $(wc -l < "$model_dir/model.sdf") lines"
            
            # Check for syntax errors
            log "Checking SDF syntax..."
            if command -v xmllint >/dev/null 2>&1; then
                if xmllint --noout "$model_dir/model.sdf" 2>/dev/null; then
                    success "SDF syntax is valid"
                else
                    error "SDF syntax errors found"
                    xmllint --noout "$model_dir/model.sdf"
                fi
            else
                warning "xmllint not available, cannot check SDF syntax"
            fi
        else
            error "model.sdf missing"
        fi
    else
        error "Model directory not found: $model_dir"
    fi
}

check_gazebo_resource_path() {
    log "Checking Gazebo resource path..."
    
    if [ -n "$GZ_SIM_RESOURCE_PATH" ]; then
        success "GZ_SIM_RESOURCE_PATH is set"
        log "Resource paths:"
        echo "$GZ_SIM_RESOURCE_PATH" | tr ':' '\n' | while read -r path; do
            if [ -d "$path" ]; then
                log "  ✓ $path (exists)"
            else
                log "  ✗ $path (missing)"
            fi
        done
        
        # Check if our models directory is in the path
        local models_path="$(pwd)/models"
        if echo "$GZ_SIM_RESOURCE_PATH" | grep -q "$models_path"; then
            success "Our models directory is in resource path"
        else
            error "Our models directory NOT in resource path"
            log "Expected: $models_path"
        fi
    else
        error "GZ_SIM_RESOURCE_PATH not set"
    fi
}

capture_gazebo_logs() {
    log "Capturing recent Gazebo logs..."
    
    # Look for common log locations
    local log_locations=(
        "/tmp/gazebo_server.log"
        "/tmp/gazebo_gui.log" 
        "/tmp/gazebo.log"
        "$HOME/.gz/logs"
        "/var/log/gazebo"
    )
    
    for log_path in "${log_locations[@]}"; do
        if [ -f "$log_path" ]; then
            log "Found log: $log_path"
            log "Last 20 lines:"
            tail -20 "$log_path" 2>/dev/null || warning "Could not read log file"
            echo "---"
        elif [ -d "$log_path" ]; then
            log "Found log directory: $log_path"
            ls -la "$log_path" 2>/dev/null || warning "Could not list log directory"
        fi
    done
}

create_simple_test_model() {
    log "Creating simple test model for verification..."
    
    mkdir -p "models/test_simple"
    
    cat > "models/test_simple/model.config" << 'EOF'
<?xml version="1.0"?>
<model>
  <name>test_simple</name>
  <version>1.0</version>
  <sdf version="1.6">model.sdf</sdf>
  <description>Simple test model</description>
</model>
EOF

    cat > "models/test_simple/model.sdf" << 'EOF'
<?xml version="1.0" ?>
<sdf version="1.6">
  <model name="test_simple">
    <link name="test_link">
      <pose>0 0 0.5 0 0 0</pose>
      <visual name="test_visual">
        <geometry>
          <box>
            <size>0.2 0.2 0.2</size>
          </box>
        </geometry>
        <material>
          <ambient>1 0 1 1</ambient>
          <diffuse>1 0 1 1</diffuse>
        </material>
      </visual>
    </link>
  </model>
</sdf>
EOF

    success "Created simple test model (purple box)"
}

main() {
    echo "Gazebo Diagnostics Report"
    echo "========================"
    
    check_gazebo_running
    echo ""
    
    check_gazebo_resource_path
    echo ""
    
    check_model_files
    echo ""
    
    check_world_file
    echo ""
    
    check_model_loading
    echo ""
    
    capture_gazebo_logs
    echo ""
    
    create_simple_test_model
    echo ""
    
    log "Diagnostics complete!"
    log "If models aren't visible, try:"
    log "1. Check the Gazebo GUI camera position"
    log "2. Look for error messages in the logs above"
    log "3. Verify the simple test model appears as a purple box"
}

main "$@"