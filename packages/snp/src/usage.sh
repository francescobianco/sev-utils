
usage() {
  >&2 echo "Usage: $0 [OPTIONS] [COMMAND]"
  >&2 echo "  where COMMAND must be one of the following:"
  >&2 echo "    setup-host            Build required SNP components and set up host"
  >&2 echo "    launch-guest          Launch a SNP guest"
  >&2 echo "    attest-guest          Use virtee/snpguest and sev-snp-measure to attest a SNP guest"
  >&2 echo "    stop-guests           Stop all SNP guests started by this script"
  >&2 echo "  where OPTIONS are:"
  >&2 echo "    -n|--non-upm          Build AMDSEV non UPM kernel (sev-snp-devel)"
  >&2 echo "    -i|--image            Path to existing image file"
  >&2 echo "    -h|--help             Usage information"

  return 1
}
