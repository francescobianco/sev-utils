

# Working directory setup
WORKING_DIR="${WORKING_DIR:-$HOME/snp}"
SETUP_WORKING_DIR="${SETUP_WORKING_DIR:-${WORKING_DIR}/setup}"
LAUNCH_WORKING_DIR="${LAUNCH_WORKING_DIR:-${WORKING_DIR}/launch}"
ATTESTATION_WORKING_DIR="${ATTESTATION_WORKING_DIR:-${WORKING_DIR}/attest}"

# Export environment variables
COMMAND="help"
UPM=true
SKIP_IMAGE_CREATE=false
HOST_SSH_PORT="${HOST_SSH_PORT:-10022}"
GUEST_NAME="${GUEST_NAME:-snp-guest}"
GUEST_SIZE_GB="${GUEST_SIZE_GB:-20}"
GUEST_MEM_SIZE_MB="${GUEST_MEM_SIZE_MB:-2048}"
GUEST_SMP="${GUEST_SMP:-4}"
CPU_MODEL="${CPU_MODEL:-EPYC-v4}"
GUEST_USER="${GUEST_USER:-amd}"
GUEST_PASS="${GUEST_PASS:-amd}"
GUEST_SSH_KEY_PATH="${GUEST_SSH_KEY_PATH:-${LAUNCH_WORKING_DIR}/${GUEST_NAME}-key}"
GUEST_ROOT_LABEL="${GUEST_ROOT_LABEL:-cloudimg-rootfs}"
GUEST_KERNEL_APPEND="root=LABEL=${GUEST_ROOT_LABEL} ro console=ttyS0"
QEMU_CMDLINE_FILE="${QEMU_CMDLINE:-${LAUNCH_WORKING_DIR}/qemu.cmdline}"
IMAGE="${IMAGE:-${LAUNCH_WORKING_DIR}/${GUEST_NAME}.img}"
GENERATED_INITRD_BIN="${SETUP_WORKING_DIR}/initrd.img"

# URLs and repos
AMDSEV_URL="https://github.com/confidential-containers/amdese-amdsev.git"
AMDSEV_DEFAULT_BRANCH="amd-snp"
AMDSEV_NON_UPM_BRANCH="amd-snp-202306070000"
SNPGUEST_URL="https://github.com/virtee/snpguest.git"
SNPGUEST_BRANCH="tags/v0.8.0"
NASM_SOURCE_TAR_URL="https://www.nasm.us/pub/nasm/releasebuilds/2.16.01/nasm-2.16.01.tar.gz"
CLOUD_INIT_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
DRACUT_TARBALL_URL="https://github.com/dracutdevs/dracut/archive/refs/tags/059.tar.gz"
SEV_SNP_MEASURE_VERSION="0.0.11"

