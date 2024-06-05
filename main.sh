#!/bin/bash

# Define the path to the Varnish configuration file
VARNISH_CONFIG_FILE="$1"

if [ -z "$VARNISH_CONFIG_FILE" ]; then
  echo "Usage: $0 <path_to_varnish_config_file>"
  exit 1
fi

if [ ! -f "$VARNISH_CONFIG_FILE" ]; then
  echo "Error: Configuration file '$VARNISH_CONFIG_FILE' not found!"
  exit 1
fi

# Function to provide detailed feedback on each configuration parameter
analyze_config() {
    local config_line="$1"
    
    case "$config_line" in
        *"vcl 4.0"*)
            echo "Configuration: Using Varnish Configuration Language version 4.0."
            echo "Note: Ensure compatibility with Varnish modules and backends."
            ;;
        *"backend"*"{")
            backend_name=$(echo "$config_line" | awk '{print $2}')
            echo "Configuration: Found backend definition named '$backend_name'."
            ;;
        *"host ="*)
            host=$(echo "$config_line" | awk -F\" '{print $2}')
            echo "Configuration: Backend server hostname is '$host'."
            echo "Recommendation: Verify that the hostname resolves correctly and is reachable."
            ;;
        *"port ="*)
            port=$(echo "$config_line" | awk '{print $3}' | tr -d ';')
            echo "Configuration: Backend server port is '$port'."
            echo "Recommendation: Ensure the backend service is listening on port $port."
            ;;
        *"acl"*"{")
            acl_name=$(echo "$config_line" | awk '{print $2}')
            echo "Configuration: Found Access Control List (ACL) named '$acl_name'."
            echo "Recommendation: Verify ACL entries to ensure correct access control."
            ;;
        *"include"*";")
            include_file=$(echo "$config_line" | awk -F\" '{print $2}')
            echo "Configuration: Including additional VCL file '$include_file'."
            echo "Recommendation: Check the included file for correctness and potential conflicts."
            ;;
        *"sub"*"{")
            subroutine_name=$(echo "$config_line" | awk '{print $2}')
            echo "Configuration: Found subroutine '$subroutine_name'."
            echo "Note: Analyze the logic within this subroutine for performance impact."
            ;;
        *"return (synth("*")
            synth_code=$(echo "$config_line" | awk -F'[(|)]' '{print $2}')
            echo "Configuration: Returning a synthetic response with status code '$synth_code'."
            echo "Recommendation: Ensure synthetic responses are used appropriately to handle errors."
            ;;
        *"set req.http."*)
            header=$(echo "$config_line" | awk -F' ' '{print $3}')
            value=$(echo "$config_line" | awk -F' = ' '{print $2}' | tr -d ';')
            echo "Configuration: Setting request HTTP header '$header' to '$value'."
            echo "Recommendation: Ensure headers are set correctly to avoid request manipulation issues."
            ;;
        *"set beresp.ttl ="*)
            ttl=$(echo "$config_line" | awk -F' = ' '{print $2}' | tr -d ';')
            echo "Configuration: Setting backend response Time-To-Live (TTL) to '$ttl'."
            echo "Performance Note: TTL balances content freshness with backend load."
            echo "Recommendation: Adjust TTL based on content volatility and caching strategy."
            ;;
        *"set beresp.grace ="*)
            grace=$(echo "$config_line" | awk -F' = ' '{print $2}' | tr -d ';')
            echo "Configuration: Setting backend response grace period to '$grace'."
            echo "Performance Note: Grace period allows serving slightly stale content during backend issues."
            echo "Recommendation: Use grace periods to improve user experience during backend disruptions."
            ;;
        *)
            # If the line doesn't match any known directive, print it as-is with a warning
            echo "Unrecognized line: $config_line"
            echo "Warning: This line could not be analyzed and may require manual review."
            ;;
    esac
}

# Function to check HTTP headers and provide recommendations
check_http_headers() {
    local headers=$(varnishadm -T 127.0.0.1:6082 -S /etc/varnish/secret vcl.list | grep 'active' | awk '{print $4}')
    
    if [[ -n "$headers" ]]; then
        echo "Checking HTTP headers set in the active VCL:"
        for header in $headers; do
            echo "Header: $header"
            case "$header" in
                "X-Forwarded-For")
                    echo "Recommendation: Ensure the X-Forwarded-For header is set correctly to track the client's IP address."
                    ;;
                "Cache-Control")
                    echo "Recommendation: Use the Cache-Control header to manage caching directives."
                    ;;
                "Authorization")
                    echo "Recommendation: Be cautious with the Authorization header, ensure it doesn't cache sensitive data."
                    ;;
                *)
                    echo "Recommendation: Review the header '$header' for appropriate use."
                    ;;
            esac
        done
    else
        echo "No HTTP headers set in the active VCL."
    fi
}

# Read the Varnish configuration file line by line
echo "Analyzing Varnish Configuration File: $VARNISH_CONFIG_FILE"
while IFS= read -r line; do
    analyze_config "$line"
done < "$VARNISH_CONFIG_FILE"

# Check and provide recommendations on HTTP headers
check_http_headers
