


get_linux_distro() {
  local linux_distro

  [ -e /etc/os-release ] && . /etc/os-release

  case ${ID,,} in
    ubuntu | debian)
      linux_distro='ubuntu'
      ;;
    rhel)
      linux_distro="rhel"
      ;;
    fedora)
      linux_distro="fedora"
      ;;
    *)
      linux_distro="Unsupported Linux Distribution: ${ID}"
      ;;
  esac

  echo "${linux_distro}"
}


# Retrieve SNP host kernel from the host kernel config file via host kernel version & kernel hash parameters
get_host_kernel_version() {
  local host_kernel_config="${SETUP_WORKING_DIR}/AMDSEV/linux/host/.config"
  local kernel_version=$(cat ${host_kernel_config} | grep "^# Linux/.*Kernel Configuration$" | awk -F ' ' '{print $3}')
  local kernel_hash=$(cat ${host_kernel_config} | grep "CONFIG_LOCALVERSION" | grep -v "^#" | awk -F '="' '{print $2}' | tr -d '"')
  local host_kernel="${kernel_version}${kernel_hash}"
  echo "${host_kernel}"
}

set_ubuntu_grub_default_snp() {
  # Get the path to host kernel and the version for setting grub default
  local host_kernel_version=$(get_host_kernel_version)

  if cat /etc/default/grub | grep "${host_kernel_version}" | grep -v "^#" 2>&1 >/dev/null; then
    echo -e "Default grub already has SNP [${host_kernel_version}] set"
    return 0
  fi

  # Retrieve snp submenu name from grub.cfg
  local snp_submenu_name=$(cat /boot/grub/grub.cfg \
    | sed -n "/submenu.*Advanced options/,\${p;/${host_kernel_version}/q}" \
    | grep "submenu" \
    | grep -o -P "(?<=').*" \
    | grep -o -P "^[^']*")

  # Retrieve snp menuitem name from grub.cfg
  local snp_menuitem_name=$(cat /boot/grub/grub.cfg \
    | grep "menuentry.*${host_kernel_version}" \
    | grep -v "(recovery mode)" \
    | grep -o -P "(?<=').*" \
    | grep -o -P "^[^']*")

  # Create default grub backup
  sudo cp /etc/default/grub /etc/default/grub_bkup

  # Replace grub default with snp menuitem name
  sudo sed -i -e "s|^\(GRUB_DEFAULT=\).*$|\1\"${snp_submenu_name}>${snp_menuitem_name}\"|g" "/etc/default/grub"

  sudo update-grub
}

set_rhel_grub_default_snp() {
  # Get the SNP host latest version from snp host kernel config
  local snp_host_kernel_version=$(get_host_kernel_version)

  # Retrieve snp menuitem name from grub.cfg
  local snp_menuitem_name=$(sudo cat /boot/grub2/grub.cfg \
    | grep "menuentry.*${snp_host_kernel_version}" \
    | grep -v "(recovery mode)" \
    | grep -o -P "(?<=').*" \
    | grep -o -P "^[^']*")

  # Create default grub backup
  sudo cp /etc/default/grub /etc/default/grub_bkup

  # Replace grub default with snp menuitem name
  sudo sed -i -e "s|^\(GRUB_DEFAULT=\).*$|\1\"${snp_menuitem_name}\"|g" "/etc/default/grub"

  # Regenerate GRUB configuration for UEFI based machine or BIOS based machine
  [ -d /sys/firmware/efi ] && sudo grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg || sudo grub2-mkconfig -o /boot/grub2/grub.cfg
}

set_fedora_grub_default_snp(){
  # Get the SNP host latest version from snp host kernel config
  local snp_host_kernel_version=$(get_host_kernel_version)

  # Retrieve snp menuitem name from the boot loader entries
  local snp_menuitem_name=$(sudo grep title /boot/loader/entries/* \
    | cut -d " " -f2- \
    | grep "Fedora Linux.*${snp_host_kernel_version}")

  # Create default grub backup
  sudo cp /etc/default/grub /etc/default/grub_bkup

  # Replace grub default with snp menuitem name
  sudo sed -i -e "s|^\(GRUB_DEFAULT=\).*$|\1\"${snp_menuitem_name}\"|g" "/etc/default/grub"

  # Regenerate GRUB configuration for fedora UEFI based machine or BIOS based machine
  [ -d /sys/firmware/efi ] && sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg || sudo grub2-mkconfig -o /boot/grub2/grub.cfg
}

set_grub_default_snp() {
  local linux_distro=$(get_linux_distro)

  # Set the host default GRUB Menu to boot into built SNP kernel based on specific linux distro
  case ${linux_distro} in
    ubuntu)
      set_ubuntu_grub_default_snp
      ;;
    rhel)
      set_rhel_grub_default_snp
      ;;
    fedora)
      set_fedora_grub_default_snp
      ;;
    *)
      >&2 echo -e "ERROR: ${linux_distro}"
      return 1
      ;;
  esac
}


# Pass a function and a register to collect its value
get_cpuid() {
  local function=$1
  local register=$2
  local result

  result=$(cpuid -1 -r -l "${function}" | grep -oE "${register}=[[:alnum:]]+ " | cut -c5- | tr -d '[:space:]')

  if [ -z "${result}" ]; then
    echo "Failed to find register ${register} for function ${function}"
  else
    echo "${result}"
  fi
}

# Get the socket type from cpuid
get_socket_type() {
  local ebx
  ebx=$(get_cpuid 0x80000001 ebx)

  local bin_value
  bin_value=$(echo "obase=2; ibase=16; ${ebx^^}" | bc | rev)

  # Bits 29:31 gives us socket type
  local socket_bin
  socket_bin=$(echo "${bin_value}" | cut -c29-32 | rev)

  echo $((2#${socket_bin}))
}

# Get the processor model name from the cpuid.
get_cpu_code_name() {
  # Read eax register from function 0x80000001
  local eax
  eax=$(get_cpuid 0x80000001 eax)

  local bin_value
  bin_value=$(echo "obase=2; ibase=16; ${eax^^}" | bc | rev)

  # Base family bits [11:8]
  local base_family
  base_family=$(echo "ibase=2; $(echo "${bin_value}" | cut -c9-12 | rev)" | bc)

  # Extended family bits [27:20]
  local extended_family
  extended_family=$(echo "ibase=2;$(echo "${bin_value}" | cut -c21-28 | rev)" | bc)

  # Base model bits [7:4]
  local base_model
  base_model=$(echo "${bin_value}" | cut -c5-8 | rev)

  # Extended model bits [19:16]
  local extended_model
  extended_model=$(echo "${bin_value}" | cut -c17-20 | rev)

  # Family = base family + extended family
  local family
  family=$((base_family + extended_family))

  # Model = extended_model:base model
  local model
  model=$(bc <<< "ibase=2;${extended_model}${base_model}")

  case "${family}" in
    23)
      if [ "${model}" -ge 0 ] && [ "$model" -le 15 ]; then
        echo "naples"
      elif [ "${model}" -ge 48 ] && [ "$model" -le 63 ]; then
        echo "rome"
      fi
      ;;
    25)
      if [ "${model}" -ge 0 ] && [ "${model}" -le 15 ]; then
        echo "milan"
      elif [ "${model}" -ge 16 ] && [ "${model}" -le 31 ]; then
        echo "genoa"
      elif [ "${model}" -ge 160 ] && [ "${model}" -le 175 ]; then
        local socket
        socket=$(get_socket_type)
        case "${socket}"  in
          4) echo "bergamo" ;;
          8) echo "siena" ;;
          *) echo "Invalid CPU" ;;
        esac
      fi
      ;;
    26)
      if [ "${model}" -ge 0 ] && [ "${model}" -le 17 ]; then
        echo "turin"
      fi
      ;;
    *)
      echo "Invalid CPU"
      ;;
  esac
}

