
install_rust() {
  source "${HOME}/.cargo/env" 2>/dev/null || true

  if which rustc 2>/dev/null 1>&2; then
    echo -e "Rust previously installed"
    return 0
  fi

  # Install rust
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -sSf | sh -s -- -y
  source "${HOME}/.cargo/env" 2>/dev/null
}

install_sev_snp_measure() {
  # Install sev-snp-measure
  # pip issue on 20.04 - some openssl bug
  #sudo rm -f "/usr/lib/python3/dist-packages/OpenSSL/crypto.py"
  pip install sev-snp-measure==${SEV_SNP_MEASURE_VERSION}
}

install_ubuntu_dependencies() {
  # Build dependencies
  sudo apt install -y build-essential git

  # ACL for setting access to /dev/sev
  sudo apt install -y acl

  # qemu dependencies
  sudo apt install -y ninja-build pkg-config
  sudo apt install -y libglib2.0-dev
  sudo apt install -y libpixman-1-dev
  sudo apt install -y libslirp-dev

  # ovmf dependencies
  sudo apt install -y python-is-python3 uuid-dev iasl
  #sudo apt install -y nasm
  install_nasm_from_source

  # kernel dependencies
  sudo apt install -y bc rsync
  sudo apt install -y flex bison libncurses-dev libssl-dev libelf-dev dwarves zstd debhelper

  # dracut dependencies
  # dracut-core in native distro package manager too old with many issues. It is now
  # downloaded via source tarball URL in the environment variable above.
  # The asciidoc package is huge. It is commented because it is only needed for lsinitrd, and
  # the dracut build commands avoid the lsinitrd build.
  # The dracut initrd build is currently not working. Devices are failing to mount using the
  # dracut built initrd. This dependency is removed for now due to this reason. For now,
  # initrd is installed with the kernel debian package on the guest, and then scp-ed back to
  # the host for direct-boot use.
  #sudo apt install -y pkg-config libkmod-dev
  ##sudo apt install -y asciidoc
  ##sudo apt install -y dracut-core

  # cloud-utils dependency
  sudo apt install -y cloud-image-utils

  # Virtualization tools for resizing image
  # virt-resize currently does not work with cloud-init images. It changes the partition
  # names and grub gets messed up. This dependency is removed for now due to this reason.
  #sudo apt install -y libguestfs-tools
  sudo apt install -y qemu-utils

  # pip needed for sev-snp-measure
  sudo apt install -y python3-pip

  # Needed to find information about CPU
  sudo apt install -y cpuid

  # Needed to build 6.11.0-rc3 SNP kernel on the host
  pip install tomli
}

install_rhel_dependencies() {
  # Build dependencies
  sudo dnf install -y wget curl
  sudo dnf install -y git

  # Check if codeready-builder RH repository is enabled for ninja-build qemu dependency
  if [[ -z $(sudo dnf repolist | grep codeready-builder-for-rhel-9-x86_64-rpms) ]]; then
      echo "Install and enable codeready-builder RH repository"
      return 1
  fi

  # qemu dependencies
  sudo dnf install -y gcc
  sudo dnf install -y ninja-build
  sudo dnf install -y bzip2
  sudo dnf install -y glib2-devel

  # ovmf dependencies
  sudo dnf install -y  gcc-c++
  sudo dnf install -y libuuid-devel
  sudo dnf install -y iasl
  install_nasm_from_source

  # kernel dependencies
  sudo dnf install -y bison
  sudo dnf install -y flex
  sudo dnf install -y kernel-devel
  sudo dnf install -y bc
  sudo dnf install -y rpm-build
  sudo dnf install -y dwarves perl

  # cloud-utils dependency
  sudo dnf install -y cloud-init

  # sev-snp-measure
  sudo dnf install -y python3-pip

  # Needed to build 6.11.0-rc3 SNP kernel on the host
  pip install tomli
}

install_fedora_dependencies() {
  # Build dependencies
  sudo dnf install -y git make

  # ACL for setting access to /dev/sev
  sudo dnf install -y acl

  # qemu dependencies
  sudo dnf install -y ninja-build
  sudo dnf install -y gcc
  sudo dnf install -y glib2 glib2-devel
  sudo dnf install -y pixman pixman-devel
  sudo dnf install -y meson
  sudo dnf install -y libslirp-devel
  sudo dnf install -y libuuid libuuid-devel
  sudo dnf install -y python

  # ovmf dependencies
  install_nasm_from_source
  sudo dnf install -y acpica-tools zstd rpm-build dwarves perl

  # kernel dependencies
  sudo dnf install -y flex bison
  sudo dnf install -y openssl-devel
  sudo dnf install -y elfutils-libelf-devel # to resovle gelf.h: No such file or directory issue

  # cloud-utils dependency
  sudo dnf install -y cloud-init
}

install_nasm_from_source() {
  local nasm_dir_name=$(echo "${NASM_SOURCE_TAR_URL}" | sed "s|.*/\(.*\)|\1|g" | sed "s|.tar.gz||g")
  local nasm_dir="${WORKING_DIR}/${nasm_dir_name}"

  if [ -d "${nasm_dir}" ]; then
    echo -e "nasm directory detected, skipping the build and install for nasm"
    return 0
  fi

  pushd "${WORKING_DIR}" >/dev/null

  # Install from source
  wget ${NASM_SOURCE_TAR_URL} -O "${nasm_dir_name}.tar.gz"
  tar xzvf "${nasm_dir_name}.tar.gz"
  cd "${nasm_dir}"
  ./configure
  make
  sudo make install

  popd >/dev/null
}


install_dependencies() {
  local linux_distro=$(get_linux_distro)

  local dependencies_installed_file="${WORKING_DIR}/dependencies_already_installed"
  source "${HOME}/.cargo/env" 2>/dev/null || true

  if [ -f "${dependencies_installed_file}" ]; then
    echo -e "Dependencies previously installed"
    return 0
  fi

  # Perform the installation of dependencies specific to the linux distribution
  case ${linux_distro} in
    ubuntu)
      install_ubuntu_dependencies
      break
      ;;
    rhel)
      install_rhel_dependencies
      break
      ;;
    fedora)
      install_fedora_dependencies
      break
      ;;
    *)
      >&2 echo -e "ERROR: ${linux_distro}"
      return 1
      ;;
  esac

  echo "true" > "${dependencies_installed_file}"
}