#  SPDX-License-Identifier: MIT
#
#  Copyright (C) 2023 Advanced Micro Devices, Inc.
#

#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#

###   SNP Utility Script

# AMDSEV - snp-latest (UPM):
# 1. Enable host SNP options in BIOS
# 2. ./snp.sh setup-host
# 3. sudo reboot
# 4. ./snp.sh launch-guest
# 5. ./snp.sh attest-guest
# 6. ssh -p 10022 -i snp-guest-key amd@localhost

# AMDSEV - sev-snp-devel (non-UPM):
# 1. Enable host SNP options in BIOS
# 2. ./snp.sh --non-upm setup-host
# 3. sudo reboot
# 4. ./snp.sh --non-upm launch-guest
# 5. ./snp.sh attest-guest
# 6. ssh -p 10022 -i snp-guest-key amd@localhost

# BYOI Example:
# Image must have the GUEST_USER already added.
# Image must have the ssh key already injected for the specified user.
# Ensure enough space exists on the guest for the kernel installation.
#
# export IMAGE="guest.img"
# export GUEST_USER="user"
# export GUEST_SSH_KEY_PATH="guest-key"
# ./snp.sh launch-guest

# Enable host SNP options in CRB BIOS:
# CBS -> CPU Common ->
#        SEV-ES ASID space limit -> 100
#        SNP Memory Coverage -> Enabled
#        SMEE -> Enabled
#     -> NBIO common ->
#             SEV-SNP -> Enabled

# Tested on the following OS distributions:
# Ubuntu 20.04, 22.04

# Image formats supported:
# qcow2

# WARNING:
# This script installs developer packages on the system it is run on.
# Beware and check 'install_dependencies' if there are any admin concerns.

# WARNING:
# This script sets the default grub entry to the SNP kernel version that is
# built for this host in this script. Modifying the system grub can cause
# booting issues.

#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#

module env
module install
module usage
module os
module amdsev
module snp

set -eE
#set -o nounset
set -o pipefail

trap cleanup EXIT


main() {
  # A command must be specified
  if [ -z "${1}" ]; then
    usage
    return 1
  fi

  # Create working directory
  mkdir -p "${WORKING_DIR}"

  # Parse command args and options
  while [ -n "${1}" ]; do
    case "${1}" in
      -h|--help)
        usage
        ;;

      -n|--non-upm)
        UPM=false
        shift
        ;;

      -i|--image)
        IMAGE="${2}"
        SKIP_IMAGE_CREATE=true
        shift; shift
        ;;

      setup-host)
        COMMAND="setup-host"
        shift
        ;;

      launch-guest)
        COMMAND="launch-guest"
        shift
        ;;

      attest-guest)
        COMMAND="attest-guest"
        shift
        ;;

      stop-guests)
        COMMAND="stop-guests"
        shift
        ;;

      -*|--*)
        >&2 echo -e "Unsupported Option: [${1}]\n"
        usage
        return 1
        ;;

      *)
        >&2 echo -e "Unsupported Command: [${1}]\n"
        usage
        return 1
        ;;
    esac
  done

  # Set SETUP_WORKING_DIR for non-upm
  if ! $UPM; then
    SETUP_WORKING_DIR="${SETUP_WORKING_DIR}/non-upm"
  fi

  # Execute command
  case "${COMMAND}" in
    help)
      usage
      return 1
      ;;

    setup-host)
      install_dependencies

      if $UPM; then
        build_and_install_amdsev "${AMDSEV_DEFAULT_BRANCH}"
      else
        build_and_install_amdsev "${AMDSEV_NON_UPM_BRANCH}"
      fi

      source "${SETUP_WORKING_DIR}/source-bins"
      set_grub_default_snp
      echo -e "\nThe host must be rebooted for changes to take effect"
      ;;

    launch-guest)
      if [ ! -d "${SETUP_WORKING_DIR}" ]; then
        echo -e "Setup directory does not exist, please run 'setup-host' prior to 'launch-guest'"
        return 1
      fi

      copy_launch_binaries
      source "${LAUNCH_WORKING_DIR}/source-bins"

      verify_snp_host
      install_dependencies

      setup_and_launch_guest
      wait_and_retry_command verify_snp_guest

      echo -e "Guest SSH port forwarded to host port: ${HOST_SSH_PORT}"
      echo -e "The guest is running in the background. Use the following command to access via SSH:"
      echo -e "ssh -p ${HOST_SSH_PORT} -i ${LAUNCH_WORKING_DIR}/snp-guest-key amd@localhost"
      ;;

    attest-guest)
      install_rust
      install_sev_snp_measure
      install_dependencies
      wait_and_retry_command verify_snp_guest
      setup_guest_attestation
      attest_guest
      ;;

    stop-guests)
      stop_guests
      ;;

    *)
      >&2 echo -e "Unsupported Command: [${1}]\n"
      usage
      return 1
      ;;
  esac
}

