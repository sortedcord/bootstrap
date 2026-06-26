#!/usr/bin/env bash
# GitHub API helper functions for Bootstrap installers

# Usage: github_get_latest_release <owner/repo>
# Prints the tag_name of the latest release.

# Installers still use this function instead of just directly invoking download_asset function:
# - Asset names often contain the version
# - Installers may compare the latest tag from github against the locally installed version before doing any work.
# - We need concrete version string so we can pass it to the reigster_tool function.
github_get_latest_release() {
    local repo="$1"
    local tag
    tag=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name // empty')
    echo "$tag"
}

# Usage: github_get_download_url <owner/repo> <tag> <regex_pattern>
# Finds the asset matching the regex pattern in the specified release tag and prints its download URL.
github_get_download_url() {
    local repo="$1"
    local tag="$2"
    local pattern="$3"
    
    # If the tag is exactly 'latest', fetch the latest release asset list
    local endpoint
    if [ "$tag" = "latest" ]; then
        endpoint="https://api.github.com/repos/$repo/releases/latest"
    else
        endpoint="https://api.github.com/repos/$repo/releases/tags/$tag"
    fi
    
    local url
    url=$(curl -fsSL "$endpoint" | jq -r --arg regex "$pattern" '.assets[] | select(.name | test($regex; "i")) | .browser_download_url' | head -n1)
    echo "$url"
}

# Usage: github_download_asset <owner/repo> <tag> <regex_pattern> <dest_file>
# Resolves the URL for the matching asset and downloads it to dest_file.
github_download_asset() {
    local repo="$1"
    local tag="$2"
    local pattern="$3"
    local dest="$4"
    
    local url
    url=$(github_get_download_url "$repo" "$tag" "$pattern")
    
    if [ -z "$url" ]; then
        log_error "Could not find asset matching regex '$pattern' for $repo@$tag"
        return 1
    fi
    
    log_info "Downloading $url ..."
    download_file "$url" "$dest"
}

export -f github_get_latest_release github_get_download_url github_download_asset
