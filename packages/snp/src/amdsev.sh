

build_and_install_amdsev() {
  local amdsev_branch="${1:-${AMDSEV_DEFAULT_BRANCH}}"

  # Create directory
  mkdir -p "${SETUP_WORKING_DIR}"

  # Clone and switch branch
  pushd "${SETUP_WORKING_DIR}" >/dev/null
  if [ ! -d "AMDSEV" ]; then
    git clone -b "${amdsev_branch}" "${AMDSEV_URL}" "AMDSEV"
    git -C "AMDSEV" remote add current "${AMDSEV_URL}"
  fi

  # Fetch, checkout, update
  cd "AMDSEV"
  git remote set-url current "${AMDSEV_URL}"
  git fetch current "${amdsev_branch}"
  git checkout "${amdsev_branch}"

  # Based on latest AMDSEV documentation
  # Delete the ovmf/ directory prior to the build step for ovmf re-initialization
  [ ! -d "ovmf" ] || rm -rf "ovmf"

  # Build and copy files
  ./build.sh --package
  sudo cp kvm.conf /etc/modprobe.d/

  # Get guest kernel version from the guest config file
  local guest_kernel_version=$(get_guest_kernel_version)

  # To standardize guest kernel file location across different linux distributions
  local bzImage_file=$(find ${SETUP_WORKING_DIR}/AMDSEV/linux/guest -name "bzImage" | head -1)
  local guest_kernel_bin="${SETUP_WORKING_DIR}/AMDSEV/linux/guest/vmlinuz-${guest_kernel_version}"

  # Guest kernel binary is not present inside guest directory for some Linux Distributions like RH and Fedora,
  # because AMDSEV does not copy guest kernel file inside guest directory during SNP package build process in RH, fedora
  # so, copying bzImage file into guest kernel binary file if vmlinuz is absent inside the guest directory
  [ -f ${guest_kernel_bin} ] || cp -v ${bzImage_file} ${guest_kernel_bin}

  # Install latest snp-release
  cd $(ls -dt */ | grep snp-release- | head -1)
  sudo ./install.sh

  popd >/dev/null

  # Removing this from here for now, as the device gets recreated at various times,
  # therefore requiring the ACL to be reset. Moving to launch guest section.
  # Give kvm group rw access to /dev/sev
  #set_acl_for_sev_device

  # Add the user to kvm group so that qemu can be run without root permissions
  sudo usermod -a -G kvm "${USER}"

  # dracut initrd build is not working currently
  # Devices are failing to mount using the dracut built initrd
  # This step replaced by steps to install kernel and initrd in the guest during launch
  # Build the guest binary from the guest kernel
  #build_guest_initrd

  # Save binary paths in source file
  save_binary_paths
}
