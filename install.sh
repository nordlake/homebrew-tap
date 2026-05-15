#!/bin/sh
set -eu

REPO="nordlake/homebrew-tap"
BINARY="vasa"

main() {
  OS=$(detect_os)
  ARCH=$(detect_arch)
  VERSION=$(fetch_latest_version)

  echo "Installing ${BINARY} ${VERSION} (${OS}/${ARCH})..."

  TMP=$(mktemp -d)
  trap 'rm -rf "${TMP}"' EXIT

  ARCHIVE="${BINARY}_${OS}_${ARCH}.tar.gz"
  BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

  download "${BASE_URL}/${ARCHIVE}" "${TMP}/${ARCHIVE}"
  download "${BASE_URL}/checksums.txt" "${TMP}/checksums.txt"

  verify_checksum "${TMP}" "${ARCHIVE}"

  tar -xzf "${TMP}/${ARCHIVE}" -C "${TMP}"

  INSTALL_DIR=$(pick_install_dir)
  install_binary "${TMP}/${BINARY}" "${INSTALL_DIR}"

  echo ""
  "${INSTALL_DIR}/${BINARY}" version
  echo ""
  echo "Installed to ${INSTALL_DIR}/${BINARY}"
}

detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "darwin" ;;
    Linux*)  echo "linux" ;;
    *)       echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64)       echo "amd64" ;;
    amd64)        echo "amd64" ;;
    arm64)        echo "arm64" ;;
    aarch64)      echo "arm64" ;;
    *)            echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
}

fetch_latest_version() {
  VERSION=$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' \
    | head -1 \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  if [ -z "${VERSION}" ]; then
    echo "Failed to fetch latest release version" >&2
    exit 1
  fi
  echo "${VERSION}"
}

download() {
  URL="$1"
  DEST="$2"
  if ! curl -fsSL -o "${DEST}" "${URL}"; then
    echo "Download failed: ${URL}" >&2
    exit 1
  fi
}

verify_checksum() {
  DIR="$1"
  FILE="$2"
  EXPECTED=$(grep "${FILE}" "${DIR}/checksums.txt" | awk '{print $1}')
  if [ -z "${EXPECTED}" ]; then
    echo "Checksum not found for ${FILE}" >&2
    exit 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL=$(sha256sum "${DIR}/${FILE}" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL=$(shasum -a 256 "${DIR}/${FILE}" | awk '{print $1}')
  else
    echo "Warning: no sha256sum or shasum found, skipping checksum verification" >&2
    return
  fi

  if [ "${ACTUAL}" != "${EXPECTED}" ]; then
    echo "Checksum mismatch for ${FILE}" >&2
    echo "  expected: ${EXPECTED}" >&2
    echo "  actual:   ${ACTUAL}" >&2
    exit 1
  fi
}

pick_install_dir() {
  if [ -w "/usr/local/bin" ]; then
    echo "/usr/local/bin"
  else
    DIR="${HOME}/.local/bin"
    mkdir -p "${DIR}"
    case ":${PATH}:" in
      *":${DIR}:"*) ;;
      *) echo "Warning: ${DIR} is not in your PATH. Add it:" >&2
         echo "  export PATH=\"${DIR}:\${PATH}\"" >&2 ;;
    esac
    echo "${DIR}"
  fi
}

install_binary() {
  SRC="$1"
  DIR="$2"
  DEST="${DIR}/${BINARY}"
  chmod +x "${SRC}"
  if [ -w "${DIR}" ] && { [ ! -e "${DEST}" ] || [ -w "${DEST}" ]; }; then
    mv "${SRC}" "${DEST}"
  else
    sudo mv "${SRC}" "${DEST}"
  fi
}

main
